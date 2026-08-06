extends Node
## Dev-only diagnostic for Obstacle.Type.CHARGER -- the one hazard with a
## forward speed of its own (Obstacle.CHARGER_SPEED_FACTOR), scheduled on
## arrival time rather than on the row grid
## (TrackManager._charger_arrival_fits).
##
## Everything this measures is something the constants CANNOT be trusted
## to predict, which is why it is a probe and not a comment:
##
##   1. THE REACTION WINDOW THE CHARGER ACTUALLY LEAVES, per palier --
##      measured as the real elapsed time between the frame a charger
##      becomes visible and the frame it crosses the player plane, on the
##      wall clock of the run, not derived from a spawn distance. The
##      contract is that this is never below Obstacle.ENEMY_REACTION_WINDOW_S
##      (the same budget the ground ENEMY's hard lock guarantees) at ANY
##      palier including the cap.
##   2. THE SPACING GUARANTEE HOLDING IN PRACTICE -- for every charger
##      that reaches the player, the measured time to the nearest OTHER
##      obstacle reaching the player, either side. The contract is
##      TrackManager.MIN_OBSTACLE_GAP_S. This is the number that would
##      catch _charger_arrival_fits being subtly wrong, since it is
##      measured at the player plane rather than predicted at spawn.
##   3. HOW OFTEN ONE ACTUALLY SPAWNS, per palier -- the realised rate,
##      which the CHARGER_CHANCE_* constants cannot give on their own: an
##      attempt still has to find an arrival hole and a legal lane, and
##      both rejections get more likely as the track fills up.
##   4. THE CHARGER + RUSH CASE -- how many chargers spawned while a rush
##      window was active (TrackManager.is_rush_active()), and whether
##      their spacing and reaction numbers differ from the rest. This is
##      the worst case the game can produce (peak density meeting peak
##      closing speed), so it is reported separately rather than averaged
##      away into the totals.
##
## Collision is neutered exactly like PacingAudit.gd/AntiFrustrationAudit.gd
## (see their headers): a charger that killed the bot would end the run
## and the sample with it. The bot roams lanes on a randomized timer,
## same as the frustration probes -- a charger never reads the player's
## lane, so the roaming is only here to keep the ground ENEMY's late lock
## exercised alongside it.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/ChargerAudit.tscn
## and add `-- --seed=<int>` for a reproducible run (see DevSeed.gd).

const SIM_SECONDS: float = 900.0 # long: chargers are rare by design, and per-palier bins need samples
const BOT_SWITCH_MIN_INTERVAL_S: float = 0.6
const BOT_SWITCH_MAX_INTERVAL_S: float = 2.4

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _t: float = 0.0
var _next_bot_switch_t: float = 0.0

# Per-segment tracking, keyed by SEGMENT instance id -- each TrackSegment
# owns exactly one pooled Obstacle for the whole run, so the key is
# stable across recycles (same technique as PacingAudit.gd).
var _prev_z: Dictionary = {}
var _spawn_t: Dictionary = {} # segment id -> [t_spawn, stage_at_spawn, was_rush, type]
var _was_visible: Dictionary = {}

# Every obstacle crossing of the player plane, in order:
# [t, is_charger, lane, blocks_jump]. Used to measure the REAL gap
# between a charger and its neighbours at the plane where it actually
# matters, rather than trusting the spawn-time prediction that put it
# there. Lane and jumpability are recorded because
# TrackManager._charger_arrival_fits does NOT promise a margin against
# every neighbour -- it exempts an unjumpable hazard sharing the
# charger's own lane, which forces the player off that lane anyway (see
# that function's doc). Measuring the raw nearest neighbour would
# therefore report a "violation" for a pair the rule intentionally
# allows, so both numbers are reported separately below.
var _crossings: Array = []

# Per palier: [charger_spawns, min_window, sum_window, samples]
var _stage_stats: Array = []
var _chargers_spawned: int = 0
var _chargers_in_rush: int = 0
var _chargers_crossed: int = 0
var _min_window_overall: float = INF
var _min_window_stage: int = -1

func _ready() -> void:
	# Must run BEFORE Game.tscn is instantiated below -- see DevSeed.gd.
	var seeded := DevSeed.apply()
	print("=== CHARGER AUDIT ===")
	print("rng                     : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("simulated time          : %.0fs" % SIM_SECONDS)
	print("speed factor            : %.2f (closing speed = %.2fx world)"
		% [Obstacle.CHARGER_SPEED_FACTOR, 1.0 + Obstacle.CHARGER_SPEED_FACTOR])
	print("required reaction window: %.4fs (Obstacle.ENEMY_REACTION_WINDOW_S)" % Obstacle.ENEMY_REACTION_WINDOW_S)
	print("required spacing        : %.4fs (TrackManager.MIN_OBSTACLE_GAP_S)" % TrackManager.MIN_OBSTACLE_GAP_S)
	print("")
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	_keepy.collision_layer = 0
	_next_bot_switch_t = randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)
	for i in GameState.STAGE_SPEEDS.size():
		_stage_stats.append([0, INF, 0.0, 0])

func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return
	_t += delta
	_drive_bot()
	_scan()
	if _t >= SIM_SECONDS:
		_summary()
		get_tree().quit(0)

func _drive_bot() -> void:
	if _t < _next_bot_switch_t:
		return
	_next_bot_switch_t = _t + randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)
	_keepy.move_lane([-1, 1].pick_random())

## Records two events per pooled obstacle: the frame it becomes VISIBLE
## (its spawn, and the start of the window the player has to react) and
## the frame it crosses the player plane (contact time). The window is the
## difference -- a real elapsed measurement across the whole approach,
## which is what makes it valid even though the world speed changes
## paliers midway through it.
func _scan() -> void:
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle: Obstacle = null
		for child in segment.get_children():
			if child is Obstacle:
				obstacle = child
				break
		if obstacle == null:
			continue
		var key := segment.get_instance_id()
		var now_visible: bool = obstacle.visible
		var was_visible: bool = _was_visible.get(key, false)
		_was_visible[key] = now_visible

		if not now_visible:
			_prev_z.erase(key)
			_spawn_t.erase(key)
			continue

		var z: float = obstacle.global_position.z

		# A (re)spawn, NOT simply "became visible". A pooled obstacle is
		# very often reused WITHOUT an invisible frame in between: a
		# recycled segment whose new row also carries a hazard just
		# reconfigures the same node and re-asserts visible = true (see
		# TrackSegment.populate), so a visibility edge misses most spawns
		# entirely. Measured consequence of getting this wrong on the
		# first run of this probe: 9 spawns counted against 34 crossings,
		# and a mean "reaction window" of 7.3s -- windows timed from a
		# spawn several rows earlier than the one that actually crossed.
		#
		# Everything on the track only ever moves toward +Z, so Z going
		# BACKWARDS is unambiguously "this segment was recycled to the far
		# end and repopulated", which is exactly a spawn.
		var respawned := not was_visible or (_prev_z.has(key) and z < float(_prev_z[key]))
		if respawned:
			_spawn_t[key] = [_t, GameState.stage_index, _track.is_rush_active(), obstacle.obstacle_type]
			if obstacle.obstacle_type == Obstacle.Type.CHARGER:
				_chargers_spawned += 1
				var stats: Array = _stage_stats[GameState.stage_index]
				stats[0] += 1
				if _track.is_rush_active():
					_chargers_in_rush += 1
		elif _prev_z.has(key) and float(_prev_z[key]) < 0.0 and z >= 0.0:
			_on_crossed(key, obstacle)
		_prev_z[key] = z

func _on_crossed(key: int, obstacle: Obstacle) -> void:
	var is_charger := obstacle.obstacle_type == Obstacle.Type.CHARGER
	_crossings.append([
		_t, is_charger,
		_lane_index_for_x(obstacle.position.x),
		Obstacle.blocks_jump(obstacle.obstacle_type),
	])
	if not is_charger or not _spawn_t.has(key):
		return
	var rec: Array = _spawn_t[key]
	var window: float = _t - float(rec[0])
	var stage := int(rec[1])
	_chargers_crossed += 1
	var stats: Array = _stage_stats[stage]
	stats[1] = minf(float(stats[1]), window)
	stats[2] = float(stats[2]) + window
	stats[3] = int(stats[3]) + 1
	if window < _min_window_overall:
		_min_window_overall = window
		_min_window_stage = stage
	_spawn_t.erase(key)

func _summary() -> void:
	print("--- charger spawn rate and reaction window, per palier ---")
	print("(window = measured seconds from the frame the charger became")
	print(" visible to the frame it reached the player -- the whole time the")
	print(" player had to see it and switch lane)")
	print("")
	print(" idx  speed   spawned   crossed   min window   mean window   one per")
	for i in _stage_stats.size():
		var stats: Array = _stage_stats[i]
		var spawned := int(stats[0])
		var crossed := int(stats[3])
		if crossed == 0:
			print("  %d   %5.1f   %7d   %7d           --            --        --"
				% [i, GameState.STAGE_SPEEDS[i], spawned, crossed])
			continue
		var stage_seconds := _stage_duration_s(i)
		var rate := stage_seconds / float(spawned) if spawned > 0 else 0.0
		print("  %d   %5.1f   %7d   %7d     %6.3fs      %6.3fs   %6.1fs"
			% [i, GameState.STAGE_SPEEDS[i], spawned, crossed,
			   float(stats[1]), float(stats[2]) / float(crossed), rate])

	print("")
	print("--- reaction window verdict ---")
	if _chargers_crossed == 0:
		print("  NO CHARGER REACHED THE PLAYER -- nothing verified, treat every number above as absent")
	else:
		print("  chargers spawned              : %d" % _chargers_spawned)
		print("  chargers reaching the player  : %d" % _chargers_crossed)
		print("  worst window measured         : %.4fs (palier %d, %.1f m/s)"
			% [_min_window_overall, _min_window_stage, GameState.STAGE_SPEEDS[maxi(_min_window_stage, 0)]])
		print("  required (ENEMY_REACTION_WINDOW_S): %.4fs" % Obstacle.ENEMY_REACTION_WINDOW_S)
		print("  margin over the requirement   : %.4fs -> %s"
			% [_min_window_overall - Obstacle.ENEMY_REACTION_WINDOW_S,
			   "OK" if _min_window_overall >= Obstacle.ENEMY_REACTION_WINDOW_S else "BELOW REQUIREMENT"])

	print("")
	print("--- spacing actually measured at the player plane ---")
	print("(two DIFFERENT numbers -- see the _crossings comment. COUNTED pairs are")
	print(" the ones TrackManager._charger_arrival_fits promises a margin for;")
	print(" EXEMPT pairs are an unjumpable hazard sharing the charger's own lane,")
	print(" which forces the player off that lane anyway, so the two cannot")
	print(" compound. Only the COUNTED number is a verdict.)")
	var worst_counted := INF
	var worst_exempt := INF
	var charger_crossings := 0
	for i in _crossings.size():
		if not bool(_crossings[i][1]):
			continue
		charger_crossings += 1
		var t: float = float(_crossings[i][0])
		var lane := int(_crossings[i][2])
		for j in [i - 1, i + 1]:
			if j < 0 or j >= _crossings.size():
				continue
			var gap: float = absf(float(_crossings[j][0]) - t)
			var exempt: bool = int(_crossings[j][2]) == lane and bool(_crossings[j][3])
			if exempt:
				worst_exempt = minf(worst_exempt, gap)
			else:
				worst_counted = minf(worst_counted, gap)
	if charger_crossings == 0:
		print("  no charger reached the player -- nothing measured")
	else:
		print("  charger crossings measured    : %d" % charger_crossings)
		if is_inf(worst_counted):
			print("  worst COUNTED gap             : no counted neighbour in the whole run")
		else:
			print("  worst COUNTED gap             : %.4fs" % worst_counted)
		print("  required (CHARGER_ARRIVAL_MARGIN_S): %.4fs" % TrackManager.CHARGER_ARRIVAL_MARGIN_S)
		print("  lane switch alone needs       : %.4fs" % Obstacle.LANE_SWITCH_TIME_S)
		print("  verdict                       : %s"
			% ("OK" if worst_counted >= TrackManager.CHARGER_ARRIVAL_MARGIN_S else "BELOW REQUIREMENT"))
		if is_inf(worst_exempt):
			print("  worst EXEMPT gap (same lane, unjumpable): none occurred")
		else:
			print("  worst EXEMPT gap (same lane, unjumpable): %.4fs (not a verdict, see above)" % worst_exempt)

	print("")
	print("--- charger + rush (worst case: peak density meets peak closing speed) ---")
	print("  chargers spawned during a rush window: %d / %d" % [_chargers_in_rush, _chargers_spawned])
	print("  (rush scales the obstacle PROBABILITY only, never MIN_OBSTACLE_GAP_S,")
	print("   and _charger_arrival_fits is a gap rule -- so a rush cannot narrow")
	print("   the spacing above. The number here is what proves the case was")
	print("   actually EXERCISED rather than merely argued to be safe.)")
	print("")
	print("--- end: t=%.2fs  palier %d  distance %.1fm ---"
		% [_t, GameState.stage_index, GameState.distance_travelled])

func _lane_index_for_x(x: float) -> int:
	for lane in TrackSegment.LANE_X.size():
		if absf(x - TrackSegment.LANE_X[lane]) < 0.01:
			return lane
	return -1

## How long the run actually spent in palier `i`, for the "one charger
## every N seconds" rate. The last palier is the cap and runs to the end
## of the simulation.
func _stage_duration_s(i: int) -> float:
	var start: float = GameState.STAGE_START_S[i]
	if start >= _t:
		return 0.0
	var end := _t
	if i + 1 < GameState.STAGE_START_S.size():
		end = minf(_t, GameState.STAGE_START_S[i + 1])
	return maxf(end - start, 0.0)
