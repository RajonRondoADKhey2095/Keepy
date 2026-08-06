extends Node
## Dev-only diagnostic for the STOMPER<->jump-blocking-hazard exclusion
## (see Obstacle.gd Type.STOMPER doc and TrackManager.gd's STOMPER
## SCHEDULING section, specifically _stomper_charger_margin_clear).
##
## THE SCENARIO THIS GUARDS AGAINST -- stated explicitly by the task that
## added STOMPER: a CHARGER blocking the lane a player would need to
## SWITCH to, while a STOMPER (which follows the player onto WHATEVER
## lane they are on, see Obstacle._process_stomper) simultaneously
## demands a jump, would leave the player with no move that satisfies
## both at once -- CHARGER demands "be off my lane", STOMPER demands "be
## airborne", and if both come due close enough together the two demands
## would need to be met at literally the same instant.
##
## THIS PROBE MEASURES THE GENERATION-TIME EXCLUSION EMPIRICALLY, over a
## real long run, rather than trusting the arrival-time arithmetic by
## inspection -- same "measure, don't assume" standard as ChargerAudit.gd,
## whose crossing-based methodology this borrows directly. Every obstacle
## crossing of the player plane (the Z=0 instant collision is actually
## tested, see Obstacle.time_to_contact_s's own doc) is recorded in order;
## for every STOMPER crossing, the nearest CHARGER crossing (either side)
## and the nearest DODGE crossing (either side) are measured and checked
## against the required margin.
##
## TWO DIFFERENT hazards checked, TWO DIFFERENT reasons they are safe:
##   - CHARGER: the ONLY hazard exempt from the ordinary row-grid spacing
##     rule (it is scheduled on arrival time, overtaking rows -- see
##     TrackManager's CHARGER SCHEDULING section), which is exactly why it
##     is the one type that needed a DEDICATED exclusion
##     (_stomper_charger_margin_clear) built into STOMPER's own scheduler.
##   - DODGE: never exempt from the row grid -- STOMPER and DODGE are
##     ALREADY kept _required_gap_rows() apart by the same
##     _rows_to_last_obstacle counter every pair of ordinary row-based
##     hazards shares, with NO STOMPER-specific code required. Measured
##     here anyway rather than assumed, because "the shared counter
##     provides it" is exactly the kind of claim this project's whole
##     dev/ folder exists to verify empirically rather than take on faith.
##
## Collision is neutered (same technique as ChargerAudit.gd/
## AntiFrustrationAudit.gd) so one continuous run covers the whole
## simulated window; the bot roams lanes on a randomized timer purely to
## keep STOMPER's late commit (Obstacle._process_stomper reads Keepy's
## actual position) exercised against a moving target.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . res://scripts/dev/StomperConflictAudit.tscn
## and add `-- --seed=<int>` for a reproducible run (see DevSeed.gd).

const SIM_SECONDS: float = 900.0 # long: both hazards are individually rare by design
const BOT_SWITCH_MIN_INTERVAL_S: float = 0.6
const BOT_SWITCH_MAX_INTERVAL_S: float = 2.4

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _t: float = 0.0
var _next_bot_switch_t: float = 0.0

var _prev_z: Dictionary = {} # segment instance id -> last-seen global Z
var _was_visible: Dictionary = {}

# Every obstacle crossing of the player plane, in order: [t, type].
var _crossings: Array = []

var _stompers_spawned: int = 0
var _stompers_crossed: int = 0
var _chargers_crossed: int = 0
var _dodges_crossed: int = 0
## STOMPER spawns that happened while TrackManager.is_rush_active() was
## true -- see the class doc's "cas croise" section: a rush only scales
## _obstacle_chance()'s output (TrackManager.gd), and STOMPER_CHANCE_PER_ROW
## is deliberately NOT scaled by it either (same "a rush must never also
## speed up the one hazard whose margin is a hard exclusion" precedent
## CHARGER_COOLDOWN_EARLY_S/_LATE_S's own doc already sets) -- but this is
## measured, not merely argued, exactly like ChargerAudit.gd's own
## "charger + rush" section does for CHARGER.
var _stompers_spawned_in_rush: int = 0

func _ready() -> void:
	# Must run BEFORE Game.tscn is instantiated below -- see DevSeed.gd.
	var seeded := DevSeed.apply()
	GameState.pursuer_enabled = false # see AntiFrustrationAudit.gd's own header for why
	print("=== STOMPER CONFLICT AUDIT ===")
	print("rng                : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("simulated time     : %.0fs" % SIM_SECONDS)
	print("required margin (STOMPER<->CHARGER): %.4fs (TrackManager.CHARGER_ARRIVAL_MARGIN_S)" % TrackManager.CHARGER_ARRIVAL_MARGIN_S)
	print("required margin (STOMPER<->DODGE)  : %.4fs (TrackManager.MIN_OBSTACLE_GAP_S, via the shared row-grid counter)" % TrackManager.MIN_OBSTACLE_GAP_S)
	print("")
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	_keepy.collision_layer = 0
	_next_bot_switch_t = randf_range(BOT_SWITCH_MIN_INTERVAL_S, BOT_SWITCH_MAX_INTERVAL_S)

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

## Same respawn-vs-crossing detection as ChargerAudit.gd's own _scan() --
## see that file's comment on why a visibility EDGE alone misses most
## respawns (a recycled segment very often reconfigures the same pooled
## node without an invisible frame in between).
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
			continue

		var z: float = obstacle.global_position.z
		var respawned := not was_visible or (_prev_z.has(key) and z < float(_prev_z[key]))
		if respawned and obstacle.obstacle_type == Obstacle.Type.STOMPER:
			_stompers_spawned += 1
			if _track.is_rush_active():
				_stompers_spawned_in_rush += 1
		elif not respawned and _prev_z.has(key) and float(_prev_z[key]) < 0.0 and z >= 0.0:
			_on_crossed(obstacle)
		_prev_z[key] = z

func _on_crossed(obstacle: Obstacle) -> void:
	var type := obstacle.obstacle_type
	if type != Obstacle.Type.STOMPER and type != Obstacle.Type.CHARGER and type != Obstacle.Type.DODGE:
		return
	_crossings.append([_t, type])
	match type:
		Obstacle.Type.STOMPER:
			_stompers_crossed += 1
		Obstacle.Type.CHARGER:
			_chargers_crossed += 1
		Obstacle.Type.DODGE:
			_dodges_crossed += 1

func _summary() -> void:
	print("--- crossings recorded ---")
	print("  STOMPER spawned  : %d" % _stompers_spawned)
	print("  STOMPER crossed  : %d" % _stompers_crossed)
	print("  CHARGER crossed  : %d" % _chargers_crossed)
	print("  DODGE crossed    : %d" % _dodges_crossed)
	print("")
	print("--- STOMPER + rush (worst case: peak density meets a single-issue-escape obstacle) ---")
	print("  STOMPER spawned during a rush window: %d / %d" % [_stompers_spawned_in_rush, _stompers_spawned])
	print("  (STOMPER_CHANCE_PER_ROW is never scaled by the rush density multiplier, same")
	print("   precedent as CHARGER_COOLDOWN_EARLY_S/_LATE_S -- so a rush cannot raise STOMPER's")
	print("   own rate, and _stomper_charger_margin_clear does not relax its margin during one")
	print("   either. The number here is what proves the case was actually EXERCISED rather")
	print("   than merely argued to be safe -- and RushFrustrationAudit.gd's own 0-violations")
	print("   result already covers the general escape guarantee specifically during rush.)")
	print("")

	var violations_charger := _report_pair(Obstacle.Type.STOMPER, Obstacle.Type.CHARGER, TrackManager.CHARGER_ARRIVAL_MARGIN_S, "CHARGER")
	var violations_dodge := _report_pair(Obstacle.Type.STOMPER, Obstacle.Type.DODGE, TrackManager.MIN_OBSTACLE_GAP_S, "DODGE")
	var total_violations := violations_charger + violations_dodge

	print("")
	print("--- verdict ---")
	print("STOMPER<->CHARGER conflicts (gap < margin): %d (must be 0)" % violations_charger)
	print("STOMPER<->DODGE conflicts (gap < margin)  : %d (must be 0)" % violations_dodge)
	if total_violations > 0:
		push_error("STOMPER CONFLICT AUDIT FAILED: %d occurrence(s) of a STOMPER and a jump-blocking hazard arriving too close together in time." % total_violations)
		get_tree().quit(1)
	else:
		print("PASSED: a STOMPER never coexisted with a jump-blocking hazard closely enough in time to leave the player without an option.")

## Checks every crossing of `type_a` against its nearest neighbour (either
## side) of `type_b`, reporting the worst (smallest) gap and counting how
## many fall below `margin`. Mirrors ChargerAudit._summary's own
## "spacing actually measured at the player plane" methodology.
func _report_pair(type_a: Obstacle.Type, type_b: Obstacle.Type, margin: float, label_b: String) -> int:
	var worst := INF
	var violations := 0
	var pairs_checked := 0
	for i in _crossings.size():
		if _crossings[i][1] != type_a:
			continue
		var t: float = _crossings[i][0]
		var nearest := INF
		for j in _crossings.size():
			if _crossings[j][1] != type_b:
				continue
			nearest = minf(nearest, absf(float(_crossings[j][0]) - t))
		if is_inf(nearest):
			continue
		pairs_checked += 1
		worst = minf(worst, nearest)
		if nearest < margin:
			violations += 1
	print("--- STOMPER vs %s ---" % label_b)
	if pairs_checked == 0:
		print("  no STOMPER had a %s anywhere on the same run -- nothing measured" % label_b)
	else:
		print("  STOMPER crossings with a nearby %-7s: %d" % [label_b, pairs_checked])
		print("  worst (smallest) gap measured        : %.4fs" % worst)
		print("  required margin                      : %.4fs" % margin)
		print("  verdict                              : %s" % ("OK" if worst >= margin else "BELOW REQUIREMENT"))
	return violations
