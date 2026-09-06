extends Node3D
class_name HubKarting
## Carte-blanche V7 -- the karting coordinator. HubWorld talks to THIS
## node only (setup, one tap channel, one landing hook, one intent reset),
## on the shape HubTransport and HubCritters already have.
##
## =====================================================================
## WHAT IS GENERIC AND WHAT IS THE PLAYER
##
## `racers` is a LIST from the first commit (CLAUDE.md: a table is a list
## from the first entry -- the diving board's singleton cost a lot). Each
## entry is one kart on the track with its own input and its own lap
## state:
##
##     {"kart": KartBody, "input": KartInput, "lap": KartLap,
##      "hint": int, "active": bool, "player": bool,
##      "driver": KartAiDriver or null, "rider": HubCritter or null,
##      "finish_ms": int (-1 until the chequered flag), "s": float,
##      "lateral": float, "laps_ms": Array[int] (CH30, the dev readout)}
##
## Every racer is DRIVEN the same way, in the same loop below: the kart
## reads its input, the track judges its surface, the lap reads its
## progress. The player's entry differs in exactly two facts -- its input
## is written by KartTouchInput, and Keepy sits in it -- and those two are
## the ONLY places this file says "player". A lot-2 opponent (V8) is an
## entry whose input is written by a KartAiDriver and whose seat holds a
## HubCritter; the loop does not change.
##
## =====================================================================
## V8 -- THE RACE
##
## Climbing into the kart no longer just starts the accelerator: it lines
## the four karts up on the grid, holds every throttle through a 3-2-1
## on the HUD, and releases them together (RUNNING). Standings are the
## sort by (line crossings, abscissa) every frame; a racer finishes when
## its KartLap counts LAPS laps, the player's finish shows the results
## panel and records the race (WorldSave.kart_record_result), and the
## player then drives on freely -- the V7 time trial, chrono and best lap
## intact -- until the HUD button. Leaving the kart parks everyone back
## on the grid (RESET), so the next tap is a fresh race.
##
## Collisions between karts are DISCS on the ground plane, resolved by
## separation and a partial exchange of the normal velocity (soft, cozy:
## a bump and a jolt, never a crash) -- never a PhysicsBody3D, the hub
## has no physics and wants none (HubTapInput doctrine).
##
## The rubber band is a LEASH: an opponent more than RUBBER_DEAD u ahead
## of the player is capped a little, one more than that behind is let go
## a little, bounded by RUBBER_MIN / RUBBER_MAX and inert inside the dead
## band -- so a wheel-to-wheel fight is never touched, and a lost race
## stays lost.
##
## =====================================================================
## THE MODE SWITCH, and why it cannot leave the player stranded
##
## Walking -> driving: a tap on the parked kart arms an intent (the boat's
## model: tried on every landing AND on the spot, cleared by any other
## tap), the walk goes through the corridor gates like any other target,
## and the landing within KART_TAP_RADIUS calls mount_carrier(). From
## then on Keepy is ON_CARRIER, which every other hub branch already
## refuses by state -- there is no second flag to keep in step.
##
## Driving -> walking: the HUD button only. exit_kart() stops the kart,
## disables the writer, blends the camera back, and hands the body to
## leave_carrier() toward a point BESIDE the kart clamped to the region --
## the same arc the balloon and the boar use. The kart withdraws from the
## tap for the length of the drive (accepts_tap is false), so a tap then
## falls through to the ground path and is refused there by ON_CARRIER,
## and reappears the moment he is off.
##
## The invariant, gated by KartProbe: driving == keepy.is_on_carrier() on
## THIS kart == touch.enabled == camera.is_driving() == hud.visible. One
## function turns them all on, one turns them all off.

signal driving_changed(driving: bool)
signal race_state_changed(state: int)
signal race_finished(rank: int, total_ms: int)

enum Race { IDLE, COUNTDOWN, RUNNING, FINISHED }

const KART_TAP_RADIUS: float = 2.4
## The accelerator waits this long after the mount: the camera blend
## (HubCamera.DRIVE_BLEND_S) plus a beat, so the kart leaves from a frame
## that is already the driving frame.
const MOUNT_HOLD_S: float = 1.2
const EXIT_SIDE: float = 1.8
const PLAYER_COLOUR: Color = Color(0.93, 0.40, 0.30)
## V8: the race. Three laps: ~70-80 s at the lap times the drivers turn
## (journal V8), long enough for an overtake to be undone, short enough
## to replay on a phone.
const LAPS: int = 3
## Lights: 3-2-1 then GO, one second each, after the mount hold.
const COUNTDOWN_S: float = 3.0
## Collision discs: the kart body is 1.2 wide and 1.9 long; a disc of
## 0.95 touches at the pods, and two karts nose-to-tail overlap a little
## before they push, which is the soft feel wanted.
const KART_RADIUS: float = 0.95
const BUMP_RESTITUTION: float = 0.30
## Rubber band, see the header. CH30: the two BOUNDS moved onto the
## difficulty preset (KartDifficulty.rubber_min / rubber_max) -- the dead
## band and the span are geometry of the leash and stay here. The
## constants below are kept as the x1 preset's values and as what every
## reader that predates CH30 (KartProbe) still compares against.
const RUBBER_DEAD: float = 25.0
const RUBBER_SPAN: float = 60.0
const RUBBER_MIN: float = 0.93
const RUBBER_MAX: float = 1.05

## The three opponents (V8): name, kart colour, driver profile, and the
## published model of the hub inhabitant who sits in it. The hub's own
## cat, beaver and boar keep their places and their mechanics -- these
## are ADDITIONAL instances of the same GLB, never a move.
const OPPONENTS: Array[Dictionary] = [
	{"name": "Le Chat", "colour": Color(0.34, 0.56, 0.90), "profile": "cat"},
	{"name": "Le Castor", "colour": Color(0.42, 0.72, 0.40), "profile": "beaver"},
	{"name": "Le Sanglier", "colour": Color(0.95, 0.78, 0.28), "profile": "boar"},
]

var track: KartTrack = null
var racers: Array[Dictionary] = []
var touch: KartTouchInput = null
var race_state: int = Race.IDLE
## Seconds since the lights went out (RUNNING and after).
var race_clock_s: float = 0.0
## Seconds left before the lights go out (COUNTDOWN).
var countdown_left: float = 0.0
## The last finished race's rows (see results()), empty until one ends.
var last_results: Array = []

var _keepy: KeepyHopper = null
var _camera: HubCamera = null
var _hud: KartHud = null
var _intent: bool = false
var _driving: bool = false
var _player: int = -1
var _decor: KartDecor = null
var _seed: int = 20260905
## Rubber band inhibited (probes measure the raw profiles).
var rubber_band_enabled: bool = true

func _ready() -> void:
	track = KartTrack.new()
	track.name = "Track"
	add_child(track)
	touch = KartTouchInput.new()
	touch.name = "Touch"
	add_child(touch)
	_player = add_racer("Keepy", PLAYER_COLOUR, true)
	for o in OPPONENTS:
		add_opponent(String(o["name"]), o["colour"], String(o["profile"]))
	_decor = KartDecor.new()
	_decor.name = "Decor"
	add_child(_decor)
	_decor.build(track)

## Adds a kart to the grid at the next slot. Returns its index. The
## player's is the one whose input KartTouchInput writes; any other
## racer's input is left for its own writer.
func add_racer(racer_name: String, colour: Color, player: bool) -> int:
	var kart := KartBody.new()
	kart.name = "Kart_%d" % racers.size()
	kart.racer_name = racer_name
	kart.body_colour = colour
	add_child(kart)
	var pose: Dictionary = track.start_pose(racers.size())
	kart.place(pose["position"], pose["yaw"])
	var lap := KartLap.new()
	lap.setup(track.length())
	var index: int = racers.size()
	lap.on_lap = func(ms: int): _on_lap(index, ms)
	var input: KartInput = touch.input if player else KartInput.new()
	racers.append({"kart": kart, "input": input, "lap": lap, "hint": -1, "active": false, "player": player,
		"driver": null, "rider": null, "finish_ms": -1, "s": 0.0, "lateral": 0.0, "laps_ms": []})
	return index

## V8: an opponent = a racer whose input a KartAiDriver writes, with the
## named hub inhabitant's model seated on KartBody.SEAT. Returns its index.
func add_opponent(racer_name: String, colour: Color, profile: String) -> int:
	var index: int = add_racer(racer_name, colour, false)
	var driver := KartAiDriver.new()
	driver.setup(track, profile, _seed + index * 7919)
	driver.released = false
	racers[index]["driver"] = driver
	var rider: HubCritter = _make_rider(profile)
	if rider != null:
		var kart: KartBody = racers[index]["kart"]
		rider.name = "Rider"
		# On the seat, in the chassis' own space -- exactly where Keepy's
		# feet go (mount_carrier(chassis, SEAT)); the critter is an empty
		# carrier with the model's scale on its child, so the seat is not
		# multiplied by the animal's size (CLAUDE.md).
		kart.chassis().add_child(rider)
		rider.position = KartBody.SEAT
		racers[index]["rider"] = rider
	return index

## The published model of each inhabitant (scene, scale, lift live on
## its module and nowhere else). The critter's own distance cull (52 u)
## applies to the rider as to the walker.
func _make_rider(profile: String) -> HubCritter:
	var rider := HubCritter.new()
	match profile:
		"cat":
			rider.setup_model(HubCat.SCENE, HubCat.SCALE, HubCat.LIFT)
		"beaver":
			rider.setup_model(HubBeaver.SCENE, HubBeaver.SCALE, HubBeaver.LIFT)
		"boar":
			rider.setup_model(HubBoar.SCENE, HubBoar.SCALE, HubBoar.LIFT)
		_:
			rider.queue_free()
			return null
	rider.breath_amount = 0.02
	return rider

func setup(keepy: KeepyHopper, camera: HubCamera, hud: KartHud) -> void:
	_keepy = keepy
	_camera = camera
	_hud = hud
	if _hud != null:
		_hud.exit_pressed.connect(exit_kart)
		_refresh_hud()

## ---- what the scatter and the tap need -----------------------------

func player_kart() -> KartBody:
	return racers[_player]["kart"] if _player >= 0 else null

func player_lap() -> KartLap:
	return racers[_player]["lap"] if _player >= 0 else null

func player_index() -> int:
	return _player

func is_driving() -> bool:
	return _driving

func opponent_count() -> int:
	return racers.size() - 1

## Ground discs nothing should be sown in: every kart's park.
func footprints() -> Array:
	var out: Array = []
	for r in racers:
		var p: Vector3 = (r["kart"] as KartBody).global_position
		out.append({"position": Vector3(p.x, 0.0, p.z), "radius": KartBody.FOOTPRINT + 0.6})
	if _decor != null:
		out.append_array(_decor.footprints())
	return out

## True where the scatter must not sow: the ribbon and its verge, the
## grid, the decor.
func blocks(p: Vector3, own_radius: float) -> bool:
	if track != null and track.blocks(p, own_radius):
		return true
	for fp in footprints():
		if Vector2(p.x - fp["position"].x, p.z - fp["position"].z).length() < float(fp["radius"]) + own_radius:
			return true
	return false

## What a tap at `aim` (unclamped) means: the parked player kart, and
## only while nobody drives it (the boat's withdrawal).
func accepts_tap(aim: Vector3) -> bool:
	if _driving or _player < 0:
		return false
	var kart: KartBody = player_kart()
	var flat := Vector3(aim.x, 0.0, aim.z)
	return flat.distance_to(Vector3(kart.global_position.x, 0.0, kart.global_position.z)) <= KART_TAP_RADIUS

## Arms the intent and returns WHERE to walk (the kart's own position),
## so HubWorld routes the walk through the corridor gates.
func arm() -> Vector3:
	_intent = true
	var p: Vector3 = player_kart().global_position
	return Vector3(p.x, 0.0, p.z)

func cancel_intent() -> void:
	_intent = false

## A landing: the armed intent gets its try. True when the landing was
## consumed by the mount.
func on_landing(position: Vector3) -> bool:
	if not _intent:
		return false
	var kart: KartBody = player_kart()
	var here := Vector3(position.x, 0.0, position.z)
	if here.distance_to(Vector3(kart.global_position.x, 0.0, kart.global_position.z)) > KART_TAP_RADIUS + KeepyHopper.ARRIVE_EPSILON:
		return false
	_intent = false
	return _mount()

## ---- the mode switch -----------------------------------------------

func _mount() -> bool:
	if _driving or _keepy == null:
		return false
	var kart: KartBody = player_kart()
	if not _keepy.mount_carrier(kart.chassis(), KartBody.SEAT):
		return false
	_driving = true
	# V8: everyone to the grid BEFORE the camera reads the kart -- the
	# player's kart (Keepy attached) is re-placed on its slot, and the
	# blend then goes there.
	_grid_all()
	for r in racers:
		r["active"] = true
	touch.enabled = true
	touch.hold_throttle(MOUNT_HOLD_S + COUNTDOWN_S)
	_set_race_state(Race.COUNTDOWN)
	countdown_left = MOUNT_HOLD_S + COUNTDOWN_S
	race_clock_s = 0.0
	_keepy.follow_carrier()
	if _camera != null:
		_camera.enter_drive(kart)
	if _hud != null:
		_hud.visible = true
		_hud.set_results_visible(false)
		_refresh_hud()
	driving_changed.emit(true)
	return true

## The HUD button. Stops the kart where it is, gives the body back, and
## re-opens the kart to the tap. The opponents go back to the grid.
func exit_kart() -> void:
	if not _driving:
		return
	var kart: KartBody = player_kart()
	touch.enabled = false
	touch.input.reset()
	kart.velocity = Vector3.ZERO
	kart.show_steer(0.0)
	_driving = false
	if _camera != null:
		_camera.exit_drive()
	if _hud != null:
		_hud.visible = false
		_hud.set_ghost(Vector2.ZERO, Vector2.ZERO, false)
		_hud.set_results_visible(false)
	# Beside the kart, on the region: the circuit is region, so this is
	# a point a hop can end on. Right of travel, where the driver climbs
	# out; the far side if that is somehow off the region.
	var at: Vector3 = Vector3(kart.global_position.x, 0.0, kart.global_position.z)
	var landing: Vector3 = HubRegion.clamp_to(at + kart.right() * EXIT_SIDE)
	if landing.distance_to(at) < 0.8:
		landing = HubRegion.clamp_to(at - kart.right() * EXIT_SIDE)
	_keepy.leave_carrier(landing)
	# V8: the race is over for everyone; the opponents park on the grid,
	# the player's kart stays where he left it (it is what he taps next).
	_reset_race(false)
	driving_changed.emit(false)

## ---- V8: the race ----------------------------------------------------

func _set_race_state(state: int) -> void:
	if race_state == state:
		return
	race_state = state
	race_state_changed.emit(state)

## Every kart to its grid slot, stopped, laps reset, drivers held.
func _grid_all() -> void:
	for i in racers.size():
		var r: Dictionary = racers[i]
		var pose: Dictionary = track.start_pose(i)
		(r["kart"] as KartBody).place(pose["position"], pose["yaw"])
		(r["lap"] as KartLap).reset()
		r["hint"] = -1
		r["finish_ms"] = -1
		(r["laps_ms"] as Array).clear()
		var driver: KartAiDriver = r["driver"]
		if driver != null:
			driver.setup(track, driver.profile_id, _seed + i * 7919)
			driver.released = false
			(r["input"] as KartInput).reset()

## Back to IDLE. `player_too` re-grids the player's kart as well (a probe
## wants that); the HUD button leaves it where it stopped.
func _reset_race(player_too: bool) -> void:
	for i in racers.size():
		var r: Dictionary = racers[i]
		if r["player"] and not player_too:
			r["active"] = false
			continue
		var pose: Dictionary = track.start_pose(i)
		(r["kart"] as KartBody).place(pose["position"], pose["yaw"])
		(r["lap"] as KartLap).reset()
		r["hint"] = -1
		r["finish_ms"] = -1
		(r["laps_ms"] as Array).clear()
		r["active"] = false
		var driver: KartAiDriver = r["driver"]
		if driver != null:
			driver.released = false
			(r["input"] as KartInput).reset()
	_set_race_state(Race.IDLE)
	countdown_left = 0.0
	race_clock_s = 0.0

func _go() -> void:
	race_clock_s = 0.0
	for r in racers:
		var driver: KartAiDriver = r["driver"]
		if driver != null:
			driver.released = true
	_set_race_state(Race.RUNNING)

## Where a racer is in the race, in track units: line crossings times
## the length plus the abscissa. Before the first crossing the kart is
## parked short of the line (s near the length), so the crossing count
## is what makes this monotonic.
func progress_of(i: int) -> float:
	var r: Dictionary = racers[i]
	var lap: KartLap = r["lap"]
	var crossings: int = lap.lap_count + (1 if lap.timing else 0)
	return float(crossings) * track.length() + float(r["s"])

## The live standings: racer indices, leader first. A finished racer
## ranks by finish time ahead of every unfinished one; unfinished ones
## by progress.
func standings() -> Array[int]:
	var order: Array[int] = []
	for i in racers.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		var fa: int = int(racers[a]["finish_ms"])
		var fb: int = int(racers[b]["finish_ms"])
		if fa >= 0 and fb >= 0:
			return fa < fb
		if fa >= 0:
			return true
		if fb >= 0:
			return false
		return progress_of(a) > progress_of(b))
	return order

func rank_of(i: int) -> int:
	return standings().find(i) + 1

## The results table for the HUD and the save: one row per racer in
## finishing order, {name, colour, rank, finish_ms, best_lap_ms, player}.
func results() -> Array:
	var rows: Array = []
	var order: Array[int] = standings()
	for rank in order.size():
		var i: int = order[rank]
		var r: Dictionary = racers[i]
		var kart: KartBody = r["kart"]
		rows.append({"name": kart.racer_name, "colour": kart.body_colour, "rank": rank + 1,
			"finish_ms": int(r["finish_ms"]), "best_lap_ms": (r["lap"] as KartLap).best_lap_ms, "player": bool(r["player"]),
			"laps_ms": (r["laps_ms"] as Array).duplicate(), "profile": _profile_of(i)})
	return rows

## The driver profile racing in entry `i` ("" for the player). Published
## for the CH30 dev readout so a row can name WHICH personality set that
## lap time without the HUD reaching into the driver.
func _profile_of(i: int) -> String:
	var driver: KartAiDriver = racers[i]["driver"]
	return driver.profile_id if driver != null else ""

## The rubber band for opponent `i`: the leash of the header.
func rubber_band_for(i: int) -> float:
	if not rubber_band_enabled or _player < 0 or race_state != Race.RUNNING:
		return 1.0
	if int(racers[_player]["finish_ms"]) >= 0:
		return 1.0
	var gap: float = progress_of(i) - progress_of(_player)
	if gap > RUBBER_DEAD:
		return lerpf(1.0, KartDifficulty.rubber_min(), clampf((gap - RUBBER_DEAD) / RUBBER_SPAN, 0.0, 1.0))
	if gap < -RUBBER_DEAD:
		return lerpf(1.0, KartDifficulty.rubber_max(), clampf((-gap - RUBBER_DEAD) / RUBBER_SPAN, 0.0, 1.0))
	return 1.0

## ---- the loop --------------------------------------------------------

func _physics_process(delta: float) -> void:
	if track == null:
		return
	var fence: Rect2 = track.fence()
	if race_state == Race.COUNTDOWN:
		countdown_left -= delta
		if countdown_left <= 0.0:
			countdown_left = 0.0
			_go()
	elif race_state == Race.RUNNING or race_state == Race.FINISHED:
		race_clock_s += delta
	# The drivers read last frame's published positions of everyone else.
	var others: Array = []
	for r in racers:
		if r["active"]:
			others.append({"kart": r["kart"], "s": r["s"], "lateral": r["lateral"]})
	for i in racers.size():
		var r: Dictionary = racers[i]
		if not r["active"]:
			continue
		var kart: KartBody = r["kart"]
		var input: KartInput = r["input"]
		var driver: KartAiDriver = r["driver"]
		if driver != null:
			driver.speed_scale = rubber_band_for(i)
			var mine: Array = []
			for o in others:
				if o["kart"] != kart:
					mine.append(o)
			driver.drive(kart, input, delta, mine)
		var progress: Dictionary = track.progress_at(kart.global_position, int(r["hint"]))
		var on_track: bool = absf(float(progress["lateral"])) <= KartTrack.HALF_WIDTH + KartTrack.ON_TRACK_MARGIN
		kart.drive(delta, input, on_track, fence)
		kart.show_steer(input.steer)
		var rider: HubCritter = r["rider"]
		if rider != null:
			rider.step(delta)
	_collide()
	for i in racers.size():
		var r: Dictionary = racers[i]
		if not r["active"]:
			continue
		var kart: KartBody = r["kart"]
		var progress: Dictionary = track.progress_at(kart.global_position, int(r["hint"]))
		r["hint"] = int(progress["index"])
		r["s"] = float(progress["s"])
		r["lateral"] = float(progress["lateral"])
		var along: float = kart.velocity.dot(progress["tangent"] as Vector3)
		(r["lap"] as KartLap).update(float(progress["s"]), along >= -0.5, delta)
		if r["player"] and _driving:
			_keepy.follow_carrier()
	if _driving and _hud != null:
		_refresh_hud()
		_hud.set_ghost(touch.anchor, touch.finger, touch.steering_active)

## Discs on the plane: separate, exchange the closing speed along the
## normal with restitution, jolt both chassis. O(N^2) on N = 4.
func _collide() -> void:
	var n: int = racers.size()
	for i in n:
		if not racers[i]["active"]:
			continue
		var a: KartBody = racers[i]["kart"]
		for j in range(i + 1, n):
			if not racers[j]["active"]:
				continue
			var b: KartBody = racers[j]["kart"]
			var d := Vector3(b.global_position.x - a.global_position.x, 0.0, b.global_position.z - a.global_position.z)
			var dist: float = d.length()
			var min_d: float = 2.0 * KART_RADIUS
			if dist >= min_d or dist < 0.0001:
				continue
			var normal: Vector3 = d / dist
			var push: float = (min_d - dist) * 0.5
			a.global_position -= normal * push
			b.global_position += normal * push
			var va: float = a.velocity.dot(normal)
			var vb: float = b.velocity.dot(normal)
			var closing: float = va - vb
			if closing > 0.0:
				var mean: float = (va + vb) * 0.5
				var half: float = closing * 0.5 * BUMP_RESTITUTION
				a.velocity += normal * ((mean - half) - va)
				b.velocity += normal * ((mean + half) - vb)
				a.bump(clampf(closing / 6.0, 0.25, 1.0))
				b.bump(clampf(closing / 6.0, 0.25, 1.0))

func _refresh_hud() -> void:
	var lap: KartLap = player_lap()
	if lap == null:
		return
	var best: int = WorldSave.kart_best_ms(KartTrack.TRACK_ID)
	_hud.set_times(int(round(lap.lap_time_s * 1000.0)), best, lap.last_lap_ms, lap.lap_count, lap.timing)
	_hud.set_wrong_way(lap.wrong_way)
	var rows: Array = []
	for i in standings():
		var kart: KartBody = racers[i]["kart"]
		rows.append({"name": kart.racer_name, "colour": kart.body_colour, "player": bool(racers[i]["player"]), "finished": int(racers[i]["finish_ms"]) >= 0})
	_hud.set_race(race_state, countdown_left - MOUNT_HOLD_S if race_state == Race.COUNTDOWN else 0.0, rank_of(_player), racers.size(), lap.lap_count, LAPS, rows, race_clock_s)

func _on_lap(index: int, ms: int) -> void:
	var r: Dictionary = racers[index]
	# CH30: every racer's lap times, in order, for the dev readout -- the
	# thing that turns "je gagne large" into a number Mathieu can send back.
	(r["laps_ms"] as Array).append(ms)
	if r["player"]:
		WorldSave.note("kart_laps")
		if WorldSave.kart_offer_lap(KartTrack.TRACK_ID, ms) and _hud != null:
			_hud.flash_record()
	# V8: the chequered flag.
	if race_state == Race.RUNNING or race_state == Race.FINISHED:
		var lap: KartLap = r["lap"]
		if lap.lap_count >= LAPS and int(r["finish_ms"]) < 0:
			r["finish_ms"] = int(round(race_clock_s * 1000.0))
			if r["player"]:
				_finish_player()

func _finish_player() -> void:
	_set_race_state(Race.FINISHED)
	last_results = results()
	var rank: int = rank_of(_player)
	var r: Dictionary = racers[_player]
	WorldSave.kart_record_result(KartTrack.TRACK_ID, rank, racers.size(), int(r["finish_ms"]), (r["lap"] as KartLap).best_lap_ms)
	if _hud != null:
		_hud.show_results(last_results)
	race_finished.emit(rank, int(r["finish_ms"]))
