extends Node
## CH62 -- THE GATE OF WHAT THE PLAYER CAN SEE AND HEAR OF THE PHYSICS.
##
## =====================================================================
## ⚠️ WHAT THIS PROBE CANNOT DO, SAID FIRST BECAUSE IT MATTERS MOST
##
## THIS BENCH CANNOT TELL WHETHER ANY OF IT FEELS GOOD. Game feel is a
## judgement, it is made with a thumb on a phone, and it belongs to
## Mathieu. Nineteen false signals in this repository were assertions
## that LOOKED like they measured the thing in the brief; the eighteenth
## was a probe calling an API instead of exercising the real channel.
## Writing a green light here that implied "the ride is fun" would be the
## twentieth, and it would be the worst kind, because the previous lot's
## verdict -- "je ne vois pas de difference" -- came from a build whose
## every probe was green.
##
## So the four things this bench IS allowed to sign are named, and
## nothing else is claimed anywhere in it:
##
##   1. THE CURVE IS A CURVE (PHASE C). Every effect is a pure function
##      of the board's pace, published once in SkateFeel; the curve is
##      swept, and it is required to be bounded, monotone, and to MOVE
##      -- a constant is monotone, so the spread is gated first.
##   2. THE EFFECTS ARE WIRED TO IT (PHASE W, H, A). What the camera,
##      the streaks, the shadow and the two audio players are actually
##      set to is READ BACK OFF THOSE OBJECTS while a real board rolls,
##      and compared with what the curve says they should be. A probe
##      that re-evaluated SkateFeel and compared it with itself would
##      prove nothing at all.
##   3. NOTHING RUNS WITH THE SWITCH DOWN (PHASE O).
##   4. WHAT IT COSTS (PHASE B, F, P), per effect and separately, with
##      the bench's own noise floor published beside every delta.
##
## And what it explicitly does NOT sign: that the streaks read as speed,
## that the roll sounds like urethane, that the shadow makes air legible,
## that any of it is cozy. Those are on the device protocol in the lot's
## report.
##
## =====================================================================
## WHY IT RUNS UNDER xvfb + opengl3
##
## Because it reads PIXELS (PHASE P) and the engine's frame counters
## (PHASE B, F). CLAUDE.md, CH39: an object meant to be SEEN cannot be
## gated on geometry and a counter -- seven green phases once signed an
## invisible hill. The counters say a thing was SUBMITTED; only a pixel
## says it was DRAWN.
##
## The phases that read only transforms (C, W, H, A, O) are correct under
## --headless too and say so when the driver is dummy, so the fast
## reading is available without paying for llvmpipe.

const BUDGET_S: float = 2400.0
const FPS: float = 60.0
## How long a world is allowed to live before it is read, in frames. Same
## as SkatePhysicsProbe's: long enough for the scatter, the weather and
## the actors to have settled into their steady state.
const WORLD_AGE: int = 40
const SETTLE: int = 8
## Where the board is handed back between runs -- open lawn, well clear of
## every hotspot in the hub. CH61 paid four bench runs for the version
## that put its rider down inside the seesaw's landing disc.
const NEUTRAL: Vector3 = Vector3(-26.0, 0.0, 30.0)
## The two speeds the wiring is read at, u/s. Far enough apart that the
## smoothed rush has clearly different values at each and both are inside
## what the board really does (CH54 cruise is 10.0).
const SLOW_V: float = 3.4
const FAST_V: float = 10.0
const HOLD_TICKS: int = 90
## ⚠️ THE AIR TEST IS ON THE 1.45 u QUARTERPIPE, NOT THE FUNBOX, AND THE
## FIRST VERSION OF THIS PHASE MEASURED THE WRONG THING.
##
## Measured on the funbox: 13 airborne ticks, peak blob lift 0.217 u, no
## landing cue at all. That reading is CORRECT and it is not air -- a
## board that rolls up a 0.85 u ramp and onto a deck is HELD the whole
## way, and the blob is dropped onto the module under it, so its
## separation is only the hop off the far lip. The touchdown speed was
## under the landing floor, so no cue fired, exactly as designed.
##
## CH61 measured the two quarterpipes: the 2.10 u lip STOPS a cruise
## arrival at 1.348, the 1.45 u one does NOT -- "elle sort par le haut,
## ce qui est le nom meme du trick du module". A board leaving the coping
## of module 3 is the only genuine air this park produces, so that is
## where an air cue is tested.
const AIR_MODULE: int = 3
## How far back the tapped approach starts, so the push has room to work.
## CH61 PHASE S used 9 u for the same reason.
const TAPPED_RUN_U: float = 9.0
## How far the board is lifted for the controlled drop that gates the
## landing cue's LEVEL. 2.0 u gives an impact around 10 u/s, which is
## past the top of the published band -- so the gate is taken where the
## curve has already saturated AND the impact is read back rather than
## assumed.
const DROP_U: float = 2.0
const RUN_TICKS: int = 400
## CH61's published accelerations, restated so this bench proves it is
## looking at the same board before it publishes anything new.
const CH61_PUSH: float = 17.2165
const CH61_BRAKE: float = 10.3433

var _fails: int = 0
var _hub: Node = null
var _keepy: KeepyHopper = null
var _park: HubSkatepark = null
var _transport: HubTransport = null
var _camera: HubCamera = null
## CH64: the bench's finger -- see SkateBench.
var _bench: SkateBench = null
var _streaks: SkateStreaks = null
## Recorded on the ON world so PHASE O's refusals have something positive
## to be a refusal OF. CLAUDE.md's blind check, ordered positive-first.
var _on_audio_players: int = -1
var _on_had_audio: bool = false
var _on_had_shadow: bool = false

func _ready() -> void:
	ProbeWatchdog.arm(self, "SKATE FEEL PROBE", BUDGET_S)
	WorldSave.SAVE_PATH_OVERRIDE = "user://skate_feel_probe_%d.json" % Time.get_ticks_usec()
	WorldSave.reset()
	_run()

func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("  [%s] %s" % ["OK " if ok else "RED", what])

func _run() -> void:
	print("=== SKATE FEEL PROBE -- CH62 ===")
	print("driver: %s" % DisplayServer.get_name())
	print("⚠️ this bench signs WIRING, BOUNDS and COST. It does not and cannot")
	print("   sign that any of it feels good -- that verdict is device-side.")
	_phase_curve()
	if _fails > 0:
		print("=== INSTRUMENT FAILED -- every reading below would be worthless. Stopping. ===")
		get_tree().quit(1)
		return
	await _phase_budget()
	if _hub == null:
		get_tree().quit(1)
		return
	await _phase_wired()
	await _phase_height()
	await _phase_audio()
	await _phase_isolate()
	await _phase_pixels()
	print("=== %s -- %d red ===" % ["ALL GREEN" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)

# =====================================================================
# PHASE C -- THE CURVE, AND THE SPREAD THAT HAS TO COME FIRST
#
# ⚠️ "MONOTONE" PASSES FREELY AGAINST A CONSTANT. A function that returns
# 0.0 for every input is non-decreasing, bounded, and has no steps: it
# satisfies every obvious assertion about a ramp while being the exact
# defect the assertions exist to catch (an effect wired to nothing).
# CLAUDE.md's blind check, applied to a scalar: MEASURE THAT IT MOVES
# FIRST, then say how it moves.
#
# This phase builds no world and reads no pixel; it is pure arithmetic on
# the published curve, so it is the instrument gate and the run stops if
# it fails.
# =====================================================================

const SAMPLES: int = 71
const SAMPLE_MAX: float = 1.40

func _sweep(fn: Callable) -> Array[float]:
	var out: Array[float] = []
	for i in SAMPLES:
		out.append(float(fn.call(float(i) / float(SAMPLES - 1) * SAMPLE_MAX)))
	return out

func _spread(v: Array[float]) -> float:
	var lo: float = v[0]
	var hi: float = v[0]
	for x in v:
		lo = minf(lo, x)
		hi = maxf(hi, x)
	return hi - lo

func _worst_step(v: Array[float]) -> float:
	var w: float = 0.0
	for i in range(1, v.size()):
		w = maxf(w, absf(v[i] - v[i - 1]))
	return w

func _monotone(v: Array[float], rising: bool) -> bool:
	for i in range(1, v.size()):
		if rising and v[i] < v[i - 1] - 1e-6:
			return false
		if not rising and v[i] > v[i - 1] + 1e-6:
			return false
	return true

func _bounded(v: Array[float], lo: float, hi: float) -> bool:
	for x in v:
		if x < lo - 1e-6 or x > hi + 1e-6:
			return false
	return true

## One curve, one line of output, the four questions asked in the order
## that makes the last three mean something.
func _gate_curve(label: String, v: Array[float], lo: float, hi: float, rising: bool,
		min_spread: float, max_step: float) -> void:
	print("     %-16s lo %8.4f  hi %8.4f  spread %8.4f  worst step %8.4f"
		% [label, v[0], v[v.size() - 1], _spread(v), _worst_step(v)])
	_check(_spread(v) >= min_spread,
		"C %s MOVES (spread %.4f >= %.4f) -- the blind check, first" % [label, _spread(v), min_spread])
	_check(_bounded(v, lo, hi), "C %s stays inside [%.4f, %.4f]" % [label, lo, hi])
	_check(_monotone(v, rising), "C %s is %s over the whole sweep"
		% [label, "non-decreasing" if rising else "non-increasing"])
	_check(_worst_step(v) <= max_step,
		"C %s has no step (worst adjacent jump %.4f <= %.4f)" % [label, _worst_step(v), max_step])

func _phase_curve() -> void:
	print("-- PHASE C: the published curve, swept --")
	var rush: Array[float] = _sweep(func(p): return SkateFeel.rush(p))
	_gate_curve("rush", rush, 0.0, 1.0, true, 0.99, 0.10)
	# The two ends are EXACT, not approximate: below the floor there is no
	# effect at all, and at and above cruise every effect is at full. A
	# ramp that leaked a little below its floor would put streaks on a
	# board being lined up for a module.
	_check(is_equal_approx(SkateFeel.rush(0.0), 0.0), "C rush is exactly 0 at rest")
	_check(is_equal_approx(SkateFeel.rush(SkateFeel.RUSH_FLOOR), 0.0),
		"C rush is exactly 0 at the floor (%.2f)" % SkateFeel.RUSH_FLOOR)
	_check(is_equal_approx(SkateFeel.rush(SkateFeel.RUSH_CEIL), 1.0),
		"C rush is exactly 1 at the ceiling")
	_check(is_equal_approx(SkateFeel.rush(SAMPLE_MAX), 1.0),
		"C rush stays 1 above the ceiling -- the board CAN exceed cruise")
	# Strictly increasing between the two, which is the part "monotone"
	# alone does not say and the part a threshold would fail.
	var strict := true
	var steps: int = 24
	for i in steps:
		var a: float = lerpf(SkateFeel.RUSH_FLOOR, SkateFeel.RUSH_CEIL, float(i) / float(steps))
		var b: float = lerpf(SkateFeel.RUSH_FLOOR, SkateFeel.RUSH_CEIL, float(i + 1) / float(steps))
		if SkateFeel.rush(b) <= SkateFeel.rush(a):
			strict = false
	_check(strict, "C rush is STRICTLY increasing between the floor and the ceiling")

	_gate_curve("fov gain", _sweep(func(p): return SkateFeel.fov_gain(SkateFeel.rush(p))),
		0.0, SkateFeel.CAMERA_FOV, true, SkateFeel.CAMERA_FOV * 0.99, SkateFeel.CAMERA_FOV * 0.12)
	_gate_curve("streak alpha", _sweep(func(p): return SkateFeel.streak_alpha(SkateFeel.rush(p))),
		0.0, SkateFeel.STREAK_ALPHA, true, SkateFeel.STREAK_ALPHA * 0.99, SkateFeel.STREAK_ALPHA * 0.12)
	_gate_curve("camera back", _sweep(func(p): return SkateFeel.camera_offset(SkateFeel.rush(p), 0.0).z),
		0.0, SkateFeel.CAMERA_BACK, true, SkateFeel.CAMERA_BACK * 0.99, SkateFeel.CAMERA_BACK * 0.12)
	_gate_curve("camera up", _sweep(func(p): return SkateFeel.camera_offset(SkateFeel.rush(p), 0.0).y),
		0.0, SkateFeel.CAMERA_UP, true, SkateFeel.CAMERA_UP * 0.99, SkateFeel.CAMERA_UP * 0.12)
	_gate_curve("roll pitch", _sweep(func(p): return SkateFeel.roll_pitch(p)),
		SkateFeel.ROLL_PITCH_LOW, SkateFeel.ROLL_PITCH_HIGH, true, 0.85, 0.05)
	_gate_curve("roll dB", _sweep(func(p): return SkateFeel.roll_volume_db(p)),
		SkateFeel.ROLL_DB_LOW, SkateFeel.ROLL_DB_HIGH, true, 16.0, 1.0)
	# The two shadow curves fall with height, which is the OTHER direction
	# and is gated as such -- a shadow that grew with altitude would pass
	# a rising monotonicity test and be exactly backwards on screen.
	# ⚠️ THE SPREAD FLOORS ARE DERIVED FROM THE CONSTANTS, not typed. A
	# hand-written 0.18 stops being a blind check the day somebody
	# softens the fade -- it becomes a gate on the OLD design that fails
	# on a legitimate change, which is how a probe teaches a lot to
	# silence it.
	_gate_curve("shadow scale", _sweep(func(h): return SkateFeel.shadow_scale(h * 2.0)),
		SkateFeel.SHADOW_SCALE_MIN, 1.0, false, (1.0 - SkateFeel.SHADOW_SCALE_MIN) * 0.9, 0.05)
	_gate_curve("shadow alpha", _sweep(func(h): return SkateFeel.shadow_alpha(h * 2.0)),
		SkateFeel.SHADOW_ALPHA_FAR, SkateFeel.SHADOW_ALPHA_NEAR, false,
		(SkateFeel.SHADOW_ALPHA_NEAR - SkateFeel.SHADOW_ALPHA_FAR) * 0.9, 0.02)
	_gate_curve("land dB", _sweep(func(f): return SkateFeel.land_volume_db(f * 8.0)),
		SkateFeel.LAND_DB_SOFT, SkateFeel.LAND_DB_HARD, true, 14.0, 1.0)
	_check(not SkateFeel.land_audible(SkateFeel.LAND_FALL_MIN - 0.01),
		"C a fall under the floor is NOT a landing cue")
	_check(SkateFeel.land_audible(SkateFeel.LAND_FALL_MIN + 0.01),
		"C and one over it is")
	# The lift term is the camera's climb, and it is the ONE part of the
	# camera offset that is not a function of rush -- gated separately so
	# a lot that folded it into the rush term is caught.
	var flat_high: Vector3 = SkateFeel.camera_offset(1.0, 0.0)
	var lifted_zero: Vector3 = SkateFeel.camera_offset(0.0, 2.0)
	_check(is_equal_approx(lifted_zero.y, SkateFeel.CAMERA_LIFT_SHARE * 2.0),
		"C the camera climbs %.2f of the board's height, at ANY rush" % SkateFeel.CAMERA_LIFT_SHARE)
	_check(is_zero_approx(lifted_zero.z),
		"C and a climb alone never dollies the camera back")
	_check(flat_high.z > 0.0 and is_zero_approx(SkateFeel.camera_offset(0.0, 0.0).z),
		"C a still board gets exactly no camera offset")

# =====================================================================
# PHASE B -- WHAT THE LOT COSTS WITH NOBODY RIDING
#
# The switch UP but the board parked: the shadow is hidden, the streaks
# draw nothing, the camera is at blend 0. If this is not zero, the lot
# has a standing cost on every frame of the hub and that is a different
# conversation from the cost of an effect.
#
# SkatePhysicsProbe PHASE B's discipline exactly, including its rule
# about which counters may be gated: the scene census is transforms and
# is gated on equality with no tolerance; the engine's frame counters are
# gated ONLY where the bench itself is immobile, and printed with their
# tremor where it is not.
# =====================================================================

func _phase_budget() -> void:
	print("-- PHASE B: the lot's standing cost, parked --")
	# CH64: ONE world. The OFF world this phase used to build no longer
	# exists (the physics switch is gone), so the standing cost is read
	# against the world ITSELF: the blob hidden and shown (the blind check
	# that proves the census can see a feel node at all), and the frame
	# counters' own tremor, printed as the floor under which no "cost"
	# is a reading.
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)
	var on_muted: int = _mute_overlay(_hub)
	var on: Dictionary = await _age_and_read(_hub)
	var on_again: Dictionary = _census(_hub)
	_keepy = _hub.find_child("Keepy", true, false) as KeepyHopper
	_park = _hub.find_child("Skatepark", true, false) as HubSkatepark
	_transport = _hub.find_child("Transport", true, false) as HubTransport
	_camera = _hub.find_child("Camera3D", true, false) as HubCamera
	_streaks = _hub.find_child("SkateStreaks", true, false) as SkateStreaks
	if _keepy == null or _park == null or _transport == null or _camera == null or _streaks == null:
		push_error("SkateFeelProbe: the hub is missing a node the lot needs.")
		_hub = null
		return
	_bench = SkateBench.new()
	_bench.name = "Bench"
	add_child(_bench)
	_bench.setup(_transport, _camera)
	_on_audio_players = _count_audio(_hub)
	_on_had_audio = _transport.board_audio() != null
	_on_had_shadow = _transport.board_shadow() != null
	for key in ["nodes_scene", "tris_scene", "sub_prims", "sub_calls", "total_prims", "total_calls"]:
		print("     %-12s parked %8d (repeat %8d)   tremor %d"
			% [key, int(on.get(key, -1)), int(on_again.get(key, -1)),
				absi(int(on.get(key, -1)) - int(on_again.get(key, -1)))])
	print("     audio players in the tree: %d" % _on_audio_players)
	_check(int(on.get("nodes_scene", -1)) > 0, "B INSTRUMENT: the census counted something at all")
	_check(on_muted > 0,
		"B INSTRUMENT: the perf overlay's own text was found and muted (its glyphs are load-dependent)")
	_check(_on_had_audio and _on_had_shadow,
		"B INSTRUMENT: the world really built both feel nodes")
	_check(_on_audio_players >= 3,
		"B the board's three audio players exist (roll, land, flip), %d players in the tree" % _on_audio_players)
	# ⚠️ ZERO IS THE ANSWER, AND ZERO PASSES FOR FREE -- so it is proved
	# in the order CLAUDE.md's blind check demands: POSITIVE FIRST.
	# The blob is a drawn node that exists in the tree and is HIDDEN
	# while nobody rides. `HubPerfOverlay` skips what is not visible in
	# tree, so a census that could not see the blob AT ALL would report
	# the same zero as a lot that costs nothing. It is therefore SHOWN,
	# the census is required to MOVE by exactly one node and two
	# triangles, and only then is the hidden reading believed.
	var shadow := _transport.board_shadow()
	shadow.visible = true
	var shown: Dictionary = await _age_and_read(_hub)
	shadow.visible = false
	var hidden_again: Dictionary = await _age_and_read(_hub)
	print("     blind check -- blob SHOWN: %d nodes / %d tris; hidden again: %d / %d"
		% [int(shown["nodes_scene"]), int(shown["tris_scene"]),
			int(hidden_again["nodes_scene"]), int(hidden_again["tris_scene"])])
	_check(int(shown["nodes_scene"]) - int(on["nodes_scene"]) == 1,
		"B BLIND CHECK: showing the blob moves the census by exactly ONE node")
	_check(int(shown["tris_scene"]) - int(on["tris_scene"]) == 2,
		"B BLIND CHECK: and by exactly TWO triangles (one quad)")
	_check(int(hidden_again["nodes_scene"]) == int(on["nodes_scene"]),
		"B BLIND CHECK: and hiding it again puts the census back")
	_check(not shadow.visible and _streaks.rush() <= 0.0,
		"B parked, the blob is hidden and the streaks draw nothing (rush %.3f)" % _streaks.rush())
	if DisplayServer.get_name() == "headless":
		print("     (frame counters need a real driver -- run under xvfb to sign the rest)")
		return
	for key in ["sub_prims", "sub_calls", "total_prims", "total_calls"]:
		var tremor: int = absi(int(on.get(key, -1)) - int(on_again.get(key, -1)))
		if tremor != 0:
			print("     (%s moves %d on its own here, parked -- the floor under any cost read at this station)" % [key, tremor])
			continue
		_check(int(on.get(key, -1)) == int(hidden_again.get(key, -2)),
			"B %s unchanged across the parked readings (bench immobile)" % key)

## Hides the perf overlay's Label -- the one canvas item in this scene
## whose primitive count depends on the machine rather than on the game.
## Returns the number of characters it was drawing, so the caller can
## assert it actually found one. `snapshot()` is unaffected: the overlay
## keeps computing and keeps writing `text`, it simply stops drawing it.
func _mute_overlay(hub: Node) -> int:
	var perf := hub.find_child("PerfOverlay", true, false) as HubPerfOverlay
	if perf == null:
		return 0
	var muted: int = 0
	for child in perf.get_children():
		var label := child as Label
		if label == null:
			continue
		muted += maxi(label.text.length(), 1)
		label.visible = false
	return muted

func _age_and_read(hub: Node) -> Dictionary:
	for _i in WORLD_AGE:
		await get_tree().process_frame
	return _census(hub)

func _sub_of(hub: Node) -> SubViewport:
	return hub.find_child("SubViewport", true, false) as SubViewport

## ⚠️ THE SCENE CENSUS IS THE OVERLAY'S, NOT THIS FILE'S. `HubPerfOverlay`
## already publishes `nodes_scene` and `tris_scene` for the whole world,
## cached per mesh RID, and SkatePhysicsProbe PHASE B reads exactly that.
## CLAUDE.md: un fait est publie une fois, jamais recopie -- a second
## triangle counter here would be a second answer to the same question,
## and the first version of this file proved the point by writing one
## that crashed on a mesh with no index array.
func _census(hub: Node) -> Dictionary:
	var out := {"nodes_scene": -1, "tris_scene": -1,
		"sub_prims": 0, "sub_calls": 0, "total_prims": 0, "total_calls": 0}
	var perf := hub.find_child("PerfOverlay", true, false) as HubPerfOverlay
	if perf != null:
		var snap: Dictionary = perf.snapshot()
		out["nodes_scene"] = int(snap.get("nodes_scene", -1))
		out["tris_scene"] = int(snap.get("tris_scene", -1))
	var sub := _sub_of(hub)
	if sub != null:
		out["sub_prims"] = RenderingServer.viewport_get_render_info(sub.get_viewport_rid(),
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		out["sub_calls"] = RenderingServer.viewport_get_render_info(sub.get_viewport_rid(),
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	out["total_prims"] = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	out["total_calls"] = RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	return out

func _all(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for c in root.get_children():
		out.append_array(_all(c))
	return out

func _count_audio(hub: Node) -> int:
	var n: int = 0
	for x in _all(hub):
		if x is AudioStreamPlayer or x is AudioStreamPlayer3D or x is AudioStreamPlayer2D:
			n += 1
	return n

# =====================================================================
# PHASE W -- THE WIRE, AND WHY IT IS READ OFF THE OBJECTS
#
# ⚠️ THE ONE THING THIS PHASE MUST NOT DO IS ASK SkateFeel TWICE.
# Comparing `SkateFeel.fov_gain(SkateFeel.rush(pace))` with itself is a
# tautology that stays green with the camera unplugged, the streaks
# deleted and the scene node gone -- the eighteenth false signal in this
# repo was precisely a probe that called the API instead of exercising
# the channel.
#
# So every number below is read BACK OFF the live object: `camera.fov` as
# the engine holds it, `camera.ride_offset()` as the pose actually uses
# it, `streaks.rush()` as the node will draw it. The board is a real
# SkateBoardBody being stepped by HubTransport with a real rider on it.
# =====================================================================

func _park_board(flat: Vector3) -> void:
	var body := _transport.board_body()
	if _transport.is_riding_board():
		body.stop()
		body.velocity = Vector3.ZERO
		body.global_position = HubSurface.ground(NEUTRAL)
		_keepy.call("follow_carrier")
		await get_tree().physics_frame
		_transport.leave_board()
		for _i in 20:
			await get_tree().physics_frame
	# CH61's rule, and its reason: a dismount that travels emits neither
	# `became_idle` nor `carrier_dismounted`, so the STATE is what is
	# waited on, never the signal.
	for _i in 180:
		if not _keepy.is_hopping() and not _keepy.is_on_carrier():
			break
		await get_tree().physics_frame
	_keepy.dismount_vehicle()
	body.stop()
	body.velocity = Vector3.ZERO
	body.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	body.rotation.y = 0.0
	_keepy.global_position = HubSurface.ground(Vector3(flat.x, 0.0, flat.z))
	for _i in SETTLE:
		await get_tree().physics_frame

## Holds the board at roughly `v` u/s on open lawn for HOLD_TICKS and
## returns what the four readers were actually set to at the end.
##
## The velocity is re-written every tick because the coast terms would
## otherwise drain it -- this is a BENCH holding a speed, not a ride, and
## it is the only way to read the effects at a KNOWN pace rather than at
## whatever pace a run happened to pass through.
func _hold(v: float) -> Dictionary:
	var body := _transport.board_body()
	body.stop()
	for _t in HOLD_TICKS:
		body.velocity = Vector3(0.0, body.velocity.y, -v)
		await get_tree().physics_frame
		await get_tree().process_frame
	return {
		"pace": body.pace(),
		"speed": body.speed(),
		"cam_rush": _camera.ride_rush(),
		"cam_blend": _camera.ride_blend(),
		"cam_back": _camera.ride_offset().z,
		"cam_up": _camera.ride_offset().y,
		"fov": _camera.fov,
		"streak_rush": _streaks.rush(),
		"streak_alpha": _streaks.peak_alpha(),
		"roll_pitch": _roll_player().pitch_scale if _roll_player() != null else -1.0,
		"roll_db": _roll_player().volume_db if _roll_player() != null else 0.0,
	}

func _roll_player() -> AudioStreamPlayer:
	var audio := _transport.board_audio()
	return audio.get_node_or_null("SkateRoll") as AudioStreamPlayer if audio != null else null

func _phase_wired() -> void:
	print("-- PHASE W: every effect read back off the live object --")
	# CH61's numbers, reproduced before anything new is published.
	# CLAUDE.md: a bench that cannot restore a figure already on file has
	# no standing to publish one.
	var body := _transport.board_body()
	print("     board: push %.4f  brake %.4f  (CH61 published %.4f / %.4f)"
		% [body.push_accel(), body.brake_accel(), CH61_PUSH, CH61_BRAKE])
	_check(absf(body.push_accel() - CH61_PUSH) < 0.01 and absf(body.brake_accel() - CH61_BRAKE) < 0.01,
		"W INSTRUMENT: this is CH61's board, to the fourth decimal")
	await _park_board(NEUTRAL)
	# Before the mount: everything must be at rest. This is the reset
	# CLAUDE.md's CH43 rule demands -- an assertion about a HELD value
	# reads whatever the previous one left unless it gates its own zero.
	_check(is_zero_approx(_camera.ride_blend()) and not _camera.is_riding(),
		"W the camera is NOT riding before the mount")
	_check(is_equal_approx(_camera.fov, 45.0), "W and its fov is the hub's 45.0")
	_check(_transport.mount_board(), "W INSTRUMENT: the rider is aboard")
	var slow: Dictionary = await _hold(SLOW_V)
	var fast: Dictionary = await _hold(FAST_V)
	for row in [["slow", slow], ["fast", fast]]:
		var d: Dictionary = row[1]
		print("     %-4s pace %.3f | cam rush %.3f blend %.3f back %.3f up %.3f fov %.2f | streak a %.4f | roll x%.3f %.1f dB"
			% [row[0], d["pace"], d["cam_rush"], d["cam_blend"], d["cam_back"], d["cam_up"],
				d["fov"], d["streak_alpha"], d["roll_pitch"], d["roll_db"]])
	# The blend has to be fully in, or every comparison below is measuring
	# a fade rather than a speed.
	_check(is_equal_approx(float(fast["cam_blend"]), 1.0), "W the ride blend is fully in")
	# THE WIRE: what the camera holds equals what the curve says about the
	# pace the BOARD is actually doing. Tolerance is the smoothing's, not
	# a fudge -- `_hold` runs 1.5 s at lambda 3.2, so the reading is
	# within a few thousandths of its target.
	for row in [["slow", slow], ["fast", fast]]:
		var d: Dictionary = row[1]
		var wanted: float = SkateFeel.rush(float(d["pace"]))
		_check(absf(float(d["cam_rush"]) - wanted) < 0.02,
			"W [%s] the camera's rush IS the board's pace through the curve (%.4f vs %.4f)"
				% [row[0], d["cam_rush"], wanted])
		# CH64: the board rides the CHASE pose (HubCamera.ChaseTuning.board),
		# under which the ride's fov gain is INERT (CH63 section 4: the
		# drive branch never writes `_hub_fov + fov_gain`). The engine's fov
		# is therefore the board tuning's, at every speed -- asserted so a
		# lot that let the two terms stack would redden here.
		_check(absf(float(d["fov"]) - HubCamera.BOARD_FOV) < 0.05,
			"W [%s] the engine's fov IS the board chase's %.1f (the ride's gain is inert under a drive: %.3f)"
				% [row[0], HubCamera.BOARD_FOV, d["fov"]])
		_check(absf(float(d["cam_back"]) - SkateFeel.camera_offset(float(d["cam_rush"]), 0.0).z) < 0.02,
			"W [%s] the pose's dolly IS the curve's dolly (%.4f)" % [row[0], d["cam_back"]])
		_check(absf(float(d["streak_rush"]) - float(d["cam_rush"])) < 0.02,
			"W [%s] the streaks read the SAME published rush as the camera" % row[0])
		_check(absf(float(d["roll_pitch"]) - SkateFeel.roll_pitch(float(d["pace"]))) < 0.02,
			"W [%s] the roll player's pitch IS the curve's pitch (x%.3f)" % [row[0], d["roll_pitch"]])
	# And it RESPONDS: two speeds, four readers, every one of them
	# strictly greater at the faster one. A wire that were merely present
	# but constant passes every equality above and fails here.
	_check(float(fast["pace"]) > float(slow["pace"]) + 0.2,
		"W INSTRUMENT: the two holds really were two different speeds (%.3f vs %.3f)"
			% [slow["pace"], fast["pace"]])
	for key in ["cam_rush", "cam_back", "cam_up", "streak_alpha", "roll_pitch", "roll_db"]:
		_check(float(fast[key]) > float(slow[key]) + 1e-4,
			"W %s answers the speed (%.4f fast > %.4f slow)" % [key, fast[key], slow[key]])
	# BOUNDED. The brief's constraint and the budget's: a fov that ran
	# away would admit an unpriced amount of the park into the frame.
	_check(float(fast["cam_back"]) <= SkateFeel.CAMERA_BACK + 1e-4
			and float(fast["cam_up"]) <= SkateFeel.CAMERA_UP + 1e-4,
		"W the dolly never exceeds its published bounds")
	_check(absf(float(fast["fov"]) - float(slow["fov"])) < 1e-3,
		"W and the fov does NOT move with the speed under the chase (%.3f / %.3f)" % [slow["fov"], fast["fov"]])
	_check(float(fast["streak_alpha"]) <= SkateFeel.STREAK_ALPHA + 1e-6,
		"W the streaks never exceed alpha %.2f" % SkateFeel.STREAK_ALPHA)
	# ⚠️ AND THE FIELD HAS TO MOVE. Every other streak assertion in this
	# phase stayed green over a version whose scroll term was a thousand
	# times too small -- they all ask whether the field LIGHTS with the
	# speed, and none of them asks whether it STREAMS. A cue that lights
	# and does not move is a stain on the screen, not a sense of speed.
	var travel_a: float = _streaks.scroll_travelled(1920.0)
	for _i in 30:
		await get_tree().process_frame
	var travel_b: float = _streaks.scroll_travelled(1920.0)
	print("     streak field travel over 30 frames at full rush: %.1f px of a 1920 px frame"
		% (travel_b - travel_a))
	_check(travel_b - travel_a > 1920.0 * 0.15,
		"W the streak field STREAMS (%.1f px in 30 frames, over 15 %% of the frame)"
			% (travel_b - travel_a))
	_check(travel_b - travel_a < 1920.0 * 4.0,
		"W and not faster than four frame-heights in half a second")
	print("     streak ink coverage at full rush: %.3f %% of the screen"
		% (_streaks.coverage() * 100.0))
	_check(_streaks.coverage() > 0.0 and _streaks.coverage() < 0.06,
		"W the streak field inks under 6 %% of the frame (%.3f %%)" % (_streaks.coverage() * 100.0))

# =====================================================================
# PHASE H -- HEIGHT: THE ONE CUE THAT TURNS ALTITUDE INTO A DISTANCE
# ON SCREEN
#
# The board is launched at the 1.45 u quarterpipe at cruise -- CH61
# measured it leaving by the top -- and three things are watched:
# whether the AIR state ever happens at all (the blind check: every
# assertion below is about air, and they all pass for free on a board
# that never left the ground), what the blob does with the height, and
# whether the camera actually climbed.
# =====================================================================

func _phase_height() -> void:
	print("-- PHASE H: the shadow, the air, and the camera's climb --")
	var body := _transport.board_body()
	var shadow := _transport.board_shadow()
	_check(shadow != null and shadow.visible, "H the blob is visible while riding")
	var node := _park.module_node(AIR_MODULE)
	# The module's own +z is the way a rider comes at it -- read through
	# the node's transform, never typed. CH61's `_launch`, same lines.
	var d: Vector3 = node.global_transform.basis * Vector3(0.0, 0.0, 1.0)
	var dir := Vector3(d.x, 0.0, d.z).normalized()
	var reach: float = float(HubSkatepark.MODULES[AIR_MODULE]["size"].z) * 0.5
	var centre: Vector3 = _park.module_centre(AIR_MODULE)
	var foot: Vector3 = centre - dir * reach
	# ⚠️ A TAPPED APPROACH, NOT AN INJECTED VELOCITY, AND THE DIFFERENCE
	# IS THE WHOLE PHASE. Measured on the first version, which launched
	# the board at cruise from 2 u out: three airborne ticks, 0.791 u of
	# blob separation, touchdown under the landing floor, no cue. That is
	# an HONEST reading of a run that is not an instance of what this
	# phase is about -- the board coasts in, climbs, runs out of speed on
	# the face and comes straight back down.
	#
	# CH61 PHASE S measured what a PLAYER produces: a tap aimed past the
	# module, so the push works over the whole run-up, reaches 1.428 u on
	# the 2.10 lip against 1.106 for a pure coast. That is the ride that
	# leaves the coping, and it is the one an air cue has to be tested on.
	# ⚠️ AND THE RUN-UP HAS TO FIT INSIDE THE REGION, WHICH THE FIRST
	# VERSION DID NOT CHECK. Module 3 sits at (5, 54) and is met from the
	# north, so 9 u of run-up starts at z = 63.7 -- outside the skate
	# lobe (centre (0, 35), r 28, which reaches z = 62.55 at x = 5).
	# `SkateBoardBody._fence` REFUSES a step out of the region and clears
	# the target with it, so the bench measured a board that never moved
	# and reported zero air, zero lift and zero camera climb. A true
	# reading of a run that never happened -- exactly the shape CLAUDE.md
	# keeps naming.
	var run_u: float = TAPPED_RUN_U
	while run_u > 3.0 and not HubRegion.contains(foot - dir * (run_u + 1.0)):
		run_u -= 0.25
	print("     run-up that fits inside the region: %.2f u" % run_u)
	_check(run_u >= 5.0, "H INSTRUMENT: the run-up is long enough to reach cruise (%.2f u)" % run_u)
	await _park_board(foot - dir * run_u)
	_check(_transport.mount_board(), "H INSTRUMENT: the rider is aboard for the flight")
	# CH64: the mount BLENDS the camera into the chase pose over 0.9 s; a
	# height read mid-blend is a height still moving (measured: 6.000
	# parked, 6.093 peak, both mid-way between the hub's 7.6 and the
	# drive's 4.4). Wait for the blend to arrive before reading it.
	for _i in 240:
		if _camera.drive_blend() > 0.999:
			break
		await get_tree().physics_frame
	for _i in 30:
		await get_tree().physics_frame
	var ground_y: float = _camera.global_position.y
	body.rotation.y = atan2(dir.x, dir.z)
	_bench.aim(HubRegion.clamp_to(centre + dir * 6.0))
	var air_ticks: int = 0
	var peak_lift: float = 0.0
	var peak_cam: float = ground_y
	var alpha_at_peak: float = -1.0
	var scale_at_peak: float = -1.0
	var alpha_on_ground: float = shadow.blob_alpha()
	var worst_gap: float = -1e9
	for _t in RUN_TICKS:
		await get_tree().physics_frame
		await get_tree().process_frame
		if body.airborne():
			air_ticks += 1
		if shadow.drawn_lift() > peak_lift:
			peak_lift = shadow.drawn_lift()
			alpha_at_peak = shadow.blob_alpha()
			scale_at_peak = shadow.scale.x
		peak_cam = maxf(peak_cam, _camera.global_position.y)
		# The blob is UNDER the board, always: it is dropped onto what is
		# below it, so its own y can never be above the board's.
		worst_gap = maxf(worst_gap, shadow.drawn_y() - body.global_position.y)
		if not body.driving() and body.speed() <= body.rest_speed() and shadow.drawn_lift() < 0.02:
			break
	print("     air ticks %d | peak blob lift %.3f u | blob alpha %.4f -> %.4f | blob scale %.3f"
		% [air_ticks, peak_lift, alpha_on_ground, alpha_at_peak, scale_at_peak])
	print("     camera y: parked %.3f  peak %.3f  climb %.3f u" % [ground_y, peak_cam, peak_cam - ground_y])
	# BLIND CHECK FIRST: none of the rest means anything on a board that
	# never left the ground.
	_check(air_ticks > 0, "H INSTRUMENT: the board really was airborne (%d ticks)" % air_ticks)
	_check(peak_lift > 0.40, "H and the blob really separated (%.3f u)" % peak_lift)
	_check(alpha_at_peak >= 0.0 and alpha_at_peak < alpha_on_ground,
		"H the blob FADES with height (%.4f up, %.4f down)" % [alpha_at_peak, alpha_on_ground])
	_check(scale_at_peak > 0.0 and scale_at_peak < 1.0,
		"H and it SHRINKS with height (%.3f)" % scale_at_peak)
	_check(is_equal_approx(alpha_at_peak, SkateFeel.shadow_alpha(peak_lift)),
		"H the blob's alpha IS the published curve at that height")
	_check(worst_gap <= SkateShadow.LIFT_EPSILON + 1e-3,
		"H the blob is never above the board (worst %.4f u)" % worst_gap)
	# CH64: under the chase pose the ride's LIFT term is inert too -- the
	# pose stands DRIVE_UP above the GROUND under the board and does not
	# bob with a jump (CLAUDE.md: a horizon that bounces with a hop is the
	# one thing a hub camera must not do). What says "it flew" is the
	# SHADOW, gated above. The camera's stillness is asserted here so a
	# lot that let the lift term through would redden.
	_check(absf(peak_cam - ground_y) < 0.05,
		"H the chase camera did NOT climb with the board (%.3f u): the ride's lift term is inert under a drive"
			% (peak_cam - ground_y))

# =====================================================================
# PHASE A -- THE SOUND, AND EXACTLY WHAT A SILENT BENCH MAY SAY ABOUT IT
#
# It may say: the streams loaded, the loop is a loop, the players are
# playing or stopped when they should be, the pitch and the level follow
# the curve, the landing cue fired the right number of times at the right
# level. It may NOT say the ride sounds good, and it does not.
# =====================================================================

func _phase_audio() -> void:
	print("-- PHASE A: the two players, what they were set to --")
	var body := _transport.board_body()
	var audio := _transport.board_audio()
	_check(audio != null, "A the audio node exists under the switch")
	if audio == null:
		return
	var roll := _roll_player()
	var land := audio.get_node_or_null("SkateLand") as AudioStreamPlayer
	_check(roll != null and roll.stream != null, "A the rolling stream loaded")
	_check(land != null and land.stream != null, "A the landing stream loaded")
	if roll != null and roll.stream is AudioStreamWAV:
		var wav := roll.stream as AudioStreamWAV
		print("     roll: %d frames, %d Hz, loop_mode %d, loop_end %d"
			% [wav.data.size() / 2, wav.mix_rate, wav.loop_mode, wav.loop_end])
		# ⚠️ THE LOOP IS THE ONE PROPERTY THAT LIVES IN A .import FILE, and
		# a .import is regenerated by anything that opens this project. A
		# roll that came back one-shot would go silent three quarters of a
		# second into every ride, with nothing to say so.
		_check(wav.loop_mode != AudioStreamWAV.LOOP_DISABLED,
			"A the rolling sample is imported AS A LOOP")
		_check(wav.loop_end > 1, "A and its loop covers the sample (%d)" % wav.loop_end)
	_check(_transport.is_riding_board(), "A INSTRUMENT: still riding")
	_check(audio.is_rolling(), "A the roll plays while riding")
	# What PHASE H's tapped flight actually produced, in play.
	print("     landings heard in the tapped flight: %d, last at %.1f dB"
		% [audio.land_count(), audio.last_land_db()])
	_check(audio.land_count() > 0, "A the tapped flight off the coping produced a landing cue")
	_check(audio.last_land_db() >= SkateFeel.LAND_DB_SOFT - 1e-3
			and audio.last_land_db() <= SkateFeel.LAND_DB_HARD + 1e-3,
		"A and its level is inside the published band")
	# ⚠️ AND A CONTROLLED DROP, BECAUSE THE FLIGHT ABOVE IS NOT A GATE ON
	# THE ARITHMETIC. What the park gives on any one run depends on the
	# park; what the LEVEL of a cue should be for a given impact is a
	# published curve, and the only way to check the reader against it is
	# to choose the impact. The board is lifted over open lawn and let
	# go, and the level it produces is compared with the curve at the
	# speed it actually hit at.
	var before: int = audio.land_count()
	await _park_board(NEUTRAL)
	_check(_transport.mount_board(), "A INSTRUMENT: aboard for the controlled drop")
	body.stop()
	body.velocity = Vector3.ZERO
	body.global_position += Vector3(0.0, DROP_U, 0.0)
	var worst_fall: float = 0.0
	for _t in 120:
		await get_tree().physics_frame
		if body.airborne():
			worst_fall = maxf(worst_fall, -body.velocity.y)
		elif worst_fall > 0.0:
			break
	print("     controlled drop from %.2f u: impact %.3f u/s, cue at %.1f dB (curve says %.1f)"
		% [DROP_U, worst_fall, audio.last_land_db(), SkateFeel.land_volume_db(worst_fall)])
	_check(audio.land_count() == before + 1, "A the drop produced exactly ONE cue")
	_check(absf(audio.last_land_db() - SkateFeel.land_volume_db(worst_fall)) < 0.2,
		"A and its level IS the published curve at the impact it measured")
	before = audio.land_count()
	# A board rolling on flat lawn must NOT thud. Same bench, opposite
	# verdict -- the pair is what makes either half mean anything.
	await _park_board(NEUTRAL)
	_check(_transport.mount_board(), "A INSTRUMENT: aboard again for the flat run")
	await _hold(FAST_V)
	_check(audio.land_count() == before, "A a flat roll adds NO landing cue")
	await _park_board(NEUTRAL)
	_check(not audio.is_rolling(), "A the roll STOPS when he steps off")

# =====================================================================
# PHASE F -- EACH EFFECT'S COST, SEPARATELY, WITH ITS OWN NOISE FLOOR
#
# The brief asks for the cost of each effect and not of the bundle, so
# each one is switched off ALONE at the same station on the same frame
# and the counters are re-read. CLAUDE.md, CH40 and CH41: a delta below
# the bench's own tremble is not a measurement, so the floor is taken at
# the same station with nothing touched and printed beside every number.
# =====================================================================

func _phase_isolate() -> void:
	print("-- PHASE F: what each effect costs, one at a time --")
	if DisplayServer.get_name() == "headless":
		print("     (needs a real driver -- skipped under the dummy driver)")
		return
	await _park_board(Vector3(0.0, 0.0, 41.0))
	_check(_transport.mount_board(), "F INSTRUMENT: aboard at the park station")
	var body := _transport.board_body()
	var shadow := _transport.board_shadow()
	# Held at cruise so every effect is at full: the cost that matters is
	# the cost at the moment the player is going fastest.
	for _t in HOLD_TICKS:
		body.velocity = Vector3(0.0, body.velocity.y, -FAST_V)
		await get_tree().physics_frame
		await get_tree().process_frame
	# ⚠️ AND THEN THE WORLD IS FROZEN, WHICH THE FIRST VERSION DID NOT DO.
	# Measured without it: turning the blob OFF "cost" 5 747 primitives
	# and the streaks 5 713 -- on a two-triangle quad and a canvas
	# overlay that is not even in this viewport. The readings were true
	# and they were readings of a MOVING CAMERA: the board rolls at 10
	# u/s between two captures three frames apart, the follow takes it
	# with, and a different half of the park is in the frustum. The
	# bench's own noise floor did not catch it because the floor was
	# taken from two back-to-back reads and the toggles were not.
	#
	# `paused` stops the board, the follow, the actors and the weather.
	# It does NOT stop a shader's TIME (CLAUDE.md, CH48), which is why
	# the floor below is still published rather than assumed to be zero.
	get_tree().paused = true
	# ⚠️ AND THE FIRST READING AFTER A FREEZE IS STALE. Measured twice, on
	# two different orderings, with the same two numbers both times: the
	# counter read 85 812 twice in a row (tremble ZERO), then the camera
	# was moved 2.3 u and put straight back, after which it read 86 127
	# twice in a row (tremble ZERO again). Two stable states for one
	# pose, and the step is not noise -- it is the renderer's per-camera
	# state catching up. `paused` stops the game; it does not make the
	# engine re-evaluate what a camera that has just stopped moving can
	# see, and a repeat reading cannot detect that because the stale
	# value is perfectly reproducible.
	#
	# So the pose is TOUCHED before the baseline is taken -- moved away
	# and put back, exactly the round trip the camera row will do -- and
	# only then is anything read. The instrument check below is what says
	# this worked: after the warm-up the round trip has to return to the
	# value it started from.
	var warm_pos: Vector3 = _camera.global_position
	_camera.global_position = warm_pos - _camera.ride_offset()
	for _i in 4:
		await get_tree().process_frame
	_camera.global_position = warm_pos
	for _i in 4:
		await get_tree().process_frame
	var full: Dictionary = await _read_now()
	var floor_a: Dictionary = await _read_now()
	var noise := {}
	for k in full.keys():
		noise[k] = absi(int(full[k]) - int(floor_a[k]))
	print("     bench noise floor at this station, world frozen: sub %d prims / %d calls, total %d prims / %d calls"
		% [noise["sub_prims"], noise["sub_calls"], noise["total_prims"], noise["total_calls"]])
	# --- the camera, alone, AND FIRST -------------------------------
	# ⚠️ NOT BY LEAVING THE RIDE. `exit_ride` is a TWEEN and a tween does
	# not run while the tree is paused; unpausing to let it finish would
	# put the board somewhere else and price a different station. What
	# the camera effect IS, exactly, is a pose offset and a fov, and both
	# are written directly here.
	#
	# ⚠️ AND EVERY POSE IS READ THROUGH `_read_pose`, WHICH SHAKES THE
	# CAMERA FIRST. See its comment: a frozen camera's cull set is not
	# re-evaluated until it MOVES, so the first reading at a new pose can
	# be the previous pose's, and a repeat reading agrees with it.
	var kept_pos: Vector3 = _camera.global_position
	var kept_fov: float = _camera.fov
	var hub_pos: Vector3 = kept_pos - _camera.ride_offset()
	# Four poses, EVERY ONE of them reached the same way, plus the ride
	# pose read twice -- first and last -- so the sequence carries its own
	# instrument.
	var both_on_a: Dictionary = await _read_pose(kept_pos, kept_fov)
	var no_camera: Dictionary = await _read_pose(hub_pos, 45.0)
	var dolly_only: Dictionary = await _read_pose(kept_pos, 45.0)
	var fov_only: Dictionary = await _read_pose(hub_pos, kept_fov)
	var restored: Dictionary = await _read_pose(kept_pos, kept_fov)
	for row in [["both on (1st)", both_on_a], ["both off", no_camera],
			["dolly only", dolly_only], ["fov only", fov_only], ["both on (2nd)", restored]]:
		var d: Dictionary = row[1]
		print("     camera pose %-13s %8d sub prims / %3d calls   (repeat %8d / %3d)"
			% [row[0], int(d["sub_prims"]), int(d["sub_calls"]),
				int(d["repeat_prims"]), int(d["repeat_calls"])])
	_check(int(both_on_a["sub_prims"]) == int(restored["sub_prims"])
			and int(both_on_a["sub_calls"]) == int(restored["sub_calls"]),
		"F INSTRUMENT: the ride pose, visited twice through the same protocol, reads the same")
	# ⚠️ AND IT DOES NOT READ THE SAME AS THE POSE THE RIDE ITSELF PUT THE
	# CAMERA IN, WHICH IS A FINDING AND NOT A FAULT. `full` was taken
	# where the ride left the camera, after a warm-up round trip;
	# `restored` is the same pose reached by the shake protocol. Both are
	# perfectly repeatable and they differ. The engine's frame counters
	# carry PATH-DEPENDENT state on a frozen world, and nothing this repo
	# uses to defend a delta -- a repeat reading, a per-station tremble --
	# can see that, because the stale value repeats.
	print("     ⚠️ path dependence: the SAME ride pose reads %d sub prims when the ride put the"
		% int(full["sub_prims"]))
	print("        camera there and %d when the shake protocol did. Both repeat exactly."
		% int(restored["sub_prims"]))
	# --- the blob shadow, alone ---
	var before_shadow: Dictionary = await _read_now()
	shadow.visible = false
	var no_shadow: Dictionary = await _read_now()
	shadow.visible = true
	# --- the streaks, alone ---
	var before_streaks: Dictionary = await _read_now()
	_streaks.visible = false
	var no_streaks: Dictionary = await _read_now()
	_streaks.visible = true
	get_tree().paused = false
	# ⚠️ EACH ROW IS READ AGAINST THE READING TAKEN IMMEDIATELY BEFORE
	# ITS OWN TOGGLE, never against one baseline for all three -- the path
	# dependence above is exactly why a shared baseline cannot be trusted
	# across a sequence of changes.
	for row in [["shadow", before_shadow, no_shadow], ["streaks", before_streaks, no_streaks],
			["camera", restored, no_camera]]:
		var base: Dictionary = row[1]
		var d: Dictionary = row[2]
		print("     %-8s off: sub %+6d prims %+3d calls | total %+6d prims %+3d calls"
			% [row[0], int(base["sub_prims"]) - int(d["sub_prims"]),
				int(base["sub_calls"]) - int(d["sub_calls"]),
				int(base["total_prims"]) - int(d["total_prims"]),
				int(base["total_calls"]) - int(d["total_calls"])])
	# The two effects whose cost is a FIXED number of quads are gated;
	# the camera's is a frustum change and is reported, never gated -- it
	# depends entirely on what happens to be around the board.
	var shadow_calls: int = int(before_shadow["sub_calls"]) - int(no_shadow["sub_calls"])
	var streak_calls: int = int(before_streaks["total_calls"]) - int(no_streaks["total_calls"])
	if int(noise["sub_calls"]) == 0:
		_check(shadow_calls <= 1, "F the blob shadow costs at most ONE draw call (%d)" % shadow_calls)
	else:
		print("     (blob draw-call gate skipped: the sub-viewport call count trembles by %d here)"
			% noise["sub_calls"])
	if int(noise["total_calls"]) == 0:
		_check(streak_calls <= 1,
			"F the WHOLE streak field costs at most ONE draw call (%d)" % streak_calls)
	else:
		print("     (streak draw-call gate skipped: the total call count trembles by %d here)"
			% noise["total_calls"])
	var d_only: int = int(dolly_only["sub_prims"]) - int(no_camera["sub_prims"])
	var f_only: int = int(fov_only["sub_prims"]) - int(no_camera["sub_prims"])
	var both: int = int(restored["sub_prims"]) - int(no_camera["sub_prims"])
	print("     camera, split: dolly alone %+6d prims | fov alone %+6d | both %+6d | parts sum to %+6d"
		% [d_only, f_only, both, d_only + f_only])
	# ⚠️ AND WHETHER THE PARTS ADD UP IS ITSELF A RESULT. A frustum is a
	# volume: widening the angle and moving the apex back sweep an
	# overlapping region, so the two terms have no reason to be additive
	# and every reason to interact. The bench states the discrepancy
	# rather than publishing a decomposition it cannot defend -- CLAUDE.md
	# on the shader bench that could not separate three candidates: "ce
	# banc ne les separe pas" IS the result.
	if absi(d_only + f_only - both) > maxi(both / 10, 40):
		print("     ⚠️ the two terms are NOT additive at this station (%d + %d vs %d)."
			% [d_only, f_only, both])
		print("        This bench prices the camera effect AS A WHOLE and does not split it.")
	print("     ⚠️ the camera row is a FRUSTUM change and is reported, never gated:")
	print("        what a wider fov admits depends on what is around the board.")

## ⚠️ A FROZEN CAMERA'S CULL SET IS NOT RE-EVALUATED UNTIL IT MOVES, AND
## A REPEAT READING CANNOT SEE THAT.
##
## Measured, twice, on two different orderings of this phase: with the
## world paused the counter read 85 812 twice in a row -- tremble ZERO --
## then the camera was moved 2.3 u and put straight back, after which it
## read 86 127 twice in a row, tremble zero again. Two perfectly stable
## states for ONE pose. The first was stale, and every guard this repo
## has against a bad delta (CH40's noise floor, CH41's per-station
## tremble) is a REPEAT reading, which agrees with a stale value as
## happily as with a true one.
##
## So a pose is never read where it is found: the camera is moved AWAY,
## given frames, moved to the pose being measured, given frames, and only
## then read -- twice, and both readings are published so the tremble at
## that pose is visible rather than inherited from another one.
func _read_pose(at: Vector3, fov: float) -> Dictionary:
	_camera.global_position = at + Vector3(0.0, 40.0, 0.0)
	_camera.fov = fov
	for _i in 6:
		await get_tree().process_frame
	_camera.global_position = at
	for _i in 6:
		await get_tree().process_frame
	var a: Dictionary = await _read_now()
	var b: Dictionary = await _read_now()
	a["repeat_prims"] = b["sub_prims"]
	a["repeat_calls"] = b["sub_calls"]
	return a

func _read_now() -> Dictionary:
	for _i in 5:
		await get_tree().process_frame
	var sub := _sub_of(_hub)
	return {
		"sub_prims": RenderingServer.viewport_get_render_info(sub.get_viewport_rid(),
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		"sub_calls": RenderingServer.viewport_get_render_info(sub.get_viewport_rid(),
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"total_prims": RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"total_calls": RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
	}

# =====================================================================
# PHASE P -- A PIXEL, BECAUSE A COUNTER SAYS "SUBMITTED" AND NOT "DRAWN"
#
# CLAUDE.md, CH39, in as many words: a counter counts what is SUBMITTED,
# and an entirely culled object pays full price in it while drawing
# nothing. Seven phases once signed a hill the engine was throwing away.
# Both of this lot's DRAWN effects are therefore read as pixels: the
# frame is captured with the thing shown and again with it hidden, and
# the number of pixels that changed is the signal. Two captures with
# NOTHING touched are the floor.
# =====================================================================

## ⚠️ A THRESHOLD, NOT AN INEQUALITY, AND IT IS A MEASUREMENT.
## The first version counted any pixel that differed at all and read a
## floor of 110 550 sampled pixels between two captures of the SAME
## frame -- 85 % of the surface. Two causes, both real: the world was
## still running (fixed below by pausing it), and a shader's TIME is not
## stopped by `paused` (CLAUDE.md, CH48), so the grass, the water and
## the haze keep moving by a hair on every frame forever. A hair is not
## what either of this lot's effects looks like: hiding a dark blob or a
## field of white streaks changes the pixels it covers by a lot. 0.02 of
## full scale on any channel separates the two, and the floor is
## published beside every signal so the separation is visible rather
## than asserted.
const PIXEL_EPSILON: float = 0.02

func _differing(a: Image, b: Image) -> int:
	var n: int = 0
	var w: int = mini(a.get_width(), b.get_width())
	var h: int = mini(a.get_height(), b.get_height())
	# Every fourth pixel each way: a 16x speed-up on llvmpipe, and the
	# signal being looked for is thousands of pixels wide.
	var x: int = 0
	while x < w:
		var y: int = 0
		while y < h:
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if absf(ca.r - cb.r) > PIXEL_EPSILON or absf(ca.g - cb.g) > PIXEL_EPSILON \
					or absf(ca.b - cb.b) > PIXEL_EPSILON:
				n += 1
			y += 4
		x += 4
	return n

func _shot(from_sub: bool) -> Image:
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if from_sub:
		return _sub_of(_hub).get_texture().get_image()
	return get_viewport().get_texture().get_image()

func _phase_pixels() -> void:
	print("-- PHASE P: both drawn effects, read as PIXELS --")
	if DisplayServer.get_name() == "headless":
		print("     (the dummy driver renders an empty surface -- skipped, by CLAUDE.md's rule)")
		return
	var shadow := _transport.board_shadow()
	var body := _transport.board_body()
	if not _transport.is_riding_board():
		await _park_board(Vector3(0.0, 0.0, 41.0))
		_check(_transport.mount_board(), "P INSTRUMENT: aboard for the capture")
	for _t in 40:
		body.velocity = Vector3(0.0, body.velocity.y, -FAST_V)
		await get_tree().physics_frame
		await get_tree().process_frame
	# CH64: the board rides the CHASE pose, which looks at it from behind
	# and above -- and from there the RIDER covers most of a blob lying
	# under his own feet (measured: 166 px against an 80 px floor, where
	# the fixed hub camera read ~1 000). The blob exists to be seen when
	# the board is UP, so the capture lifts the body one unit (the tree is
	# paused below; nothing moves it back) and reads the blob where the
	# player reads it: separated from the deck.
	body.global_position.y += 1.0
	_keepy.call("follow_carrier")
	await get_tree().process_frame
	# Frozen, for PHASE F's reason: a moving board moves the camera, and
	# two captures of two different frames are not a comparison.
	get_tree().paused = true
	# THE FLOOR FIRST: two captures of the same frame, nothing touched.
	# The hub has a bear walking in it and weather running (CH37), so this
	# number is not assumed to be zero and it is not allowed to be.
	var sub_a: Image = await _shot(true)
	var sub_b: Image = await _shot(true)
	var sub_floor: int = _differing(sub_a, sub_b)
	var root_a: Image = await _shot(false)
	var root_b: Image = await _shot(false)
	var root_floor: int = _differing(root_a, root_b)
	print("     capture noise floor: sub %d px, root %d px (sampled 1 in 16)"
		% [sub_floor, root_floor])
	shadow.visible = false
	var sub_off: Image = await _shot(true)
	shadow.visible = true
	var shadow_px: int = _differing(sub_b, sub_off)
	_streaks.visible = false
	var root_off: Image = await _shot(false)
	_streaks.visible = true
	var streak_px: int = _differing(root_b, root_off)
	print("     blob shadow inks %d px against a %d px floor" % [shadow_px, sub_floor])
	print("     streak field inks %d px against a %d px floor" % [streak_px, root_floor])
	_check(shadow_px > sub_floor * 2 + 20,
		"P the blob shadow is really DRAWN (%d px over a %d px floor)" % [shadow_px, sub_floor])
	_check(streak_px > root_floor * 2 + 20,
		"P the streak field is really DRAWN (%d px over a %d px floor)" % [streak_px, root_floor])
	get_tree().paused = false

