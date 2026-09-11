extends Node
class_name OrbitCameraProbe
## CH73 -- gates the orbitable hub camera.
##
## ⚠️ RUNS UNDER xvfb + opengl3, NEVER --headless:
##
##   xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60 \
##     --path . res://scripts/dev/OrbitCameraProbe.tscn
##
## The brief asked for a headless probe. It cannot be one, and the model
## it named (FunfairProbe) is not one either. Every gesture below is
## delivered through `Input.parse_input_event` into the real nodes, and
## that needs a real window: under the dummy driver the container's rect
## is degenerate, `HubTapInput._handle_point` returns at its rect test
## and EVERY assertion here would pass by never running -- CLAUDE.md's
## own reason for asserting the rect rather than assuming it. PHASE I
## asserts it, first, and fails loudly instead of passing for free.
##
## =====================================================================
## WHY EVERY GESTURE GOES THROUGH THE ENGINE
##
## CLAUDE.md, CH58: "une sonde qui gate une INTERACTION entre par le
## canal du joueur [...] et n'appelle l'API du prop que pour LIRE le
## resultat". CH57 shipped 43 green assertions over a board no tap ever
## reached because its bench drove the API. The axis here is the same --
## ROUTING -- and it is worse than usual, because the thing being gated
## is a DISTINCTION between two gestures that arrive on the same wire.
## A bench that called `orbit_by()` would prove the arithmetic of a
## rotation and nothing about whether a finger ever reaches it.
##
## So: `HubCamera.orbit_by` is called NOWHERE in this file except by the
## engine, through HubTapInput, from a synthesised finger. The camera's
## accessors are read-only instruments.
##
## =====================================================================
## WHAT THIS PROBE CANNOT SIGN -- said first, CH62's rule
##
## Whether the orbit FEELS right is not gateable here. ORBIT_GAIN is a
## feel knob: this file proves that a known pixel travel produces a
## known angle, that the angle is bounded, and that the pose is a rigid
## rotation. Whether 0.005 rad/px is the right amount of turn for a
## thumb, whether the low bound is a view anyone wants, and whether a
## sticky camera is pleasant to live with are Mathieu's, on device.

const HUB := "res://scenes/HubWorld.tscn"

## ⚠️ EVERY PHASE PARKS HIM HERE FIRST, AND THE FIRST WRITING OF THIS
## PROBE DID NOT -- the red pass is what found it.
##
## Neutralising the drag latch was predicted to turn ONE assertion red
## (the drag emits no destination). It turned FOUR, and that one was not
## among them. The three extras were all the same defect IN THIS FILE:
## with the latch gone, the release at the end of an orbit stroke became
## a real tap, Keepy walked off to wherever it landed, and three later
## instruments -- "a tap started a walk", "a jitter is still a tap",
## "the camera is now turned" -- were then asking their questions about
## a world that had moved under them. One of them had plainly walked him
## onto a prop channel, which left him in a state where the orbit is
## correctly refused, so an INSTRUMENT read red on working code.
##
## CLAUDE.md, twice over: "le nombre d'echecs attendus fait partie de
## l'assertion", and "une neutralisation ne teste pas seulement le
## correctif, elle teste la sonde". The same open ground SkateInputProbe
## and SkateDismountProbe park on, for the same reason.
const OPEN_GROUND: Vector3 = Vector3(12.0, 0.0, 52.0)

var _hub: Node = null
var _camera: HubCamera = null
var _sub: SubViewport = null
var _container: SubViewportContainer = null
var _tap: HubTapInput = null
var _keepy: KeepyHopper = null

var _ok: int = 0
var _red: int = 0
var _ground_taps: int = 0
## Every tap channel, for the assertions that ask "was it a tap" rather
## than "was it a destination". See the wiring in `_ready`.
var _any_taps: int = 0

func _check(cond: bool, what: String) -> void:
	if cond:
		_ok += 1
		print("   ok   %s" % what)
	else:
		_red += 1
		print("   RED  %s" % what)

func _ready() -> void:
	ProbeWatchdog.arm(self, "ORBIT CAMERA PROBE")
	print("=== ORBIT CAMERA PROBE (CH73) ===")
	_hub = load(HUB).instantiate()
	add_child(_hub)
	await get_tree().process_frame
	await get_tree().process_frame
	_container = _hub.get_node("WorldViewport") as SubViewportContainer
	_sub = _container.get_node("SubViewport") as SubViewport
	_camera = _sub.get_node("World/Camera3D") as HubCamera
	_keepy = _sub.get_node("World/Keepy") as KeepyHopper
	_tap = _hub.get_node("TapInput") as HubTapInput
	_tap.tapped_ground.connect(func(_p: Vector3) -> void: _ground_taps += 1)
	# ⚠️ EVERY CHANNEL, NOT JUST THE GROUND ONE -- and RED PASS 6 is why.
	#
	# T3's question is "was this sub-slop jitter read as a TAP rather
	# than a drag", and its first writing answered it by watching
	# `tapped_ground` alone. That silently also asserts WHICH channel the
	# tap landed on: `_handle_point` emits exactly one signal, so a
	# jitter that happened to aim at a tree or a critter emits that
	# channel instead and reads as "no tap at all". Red pass 6 turned it
	# red for precisely that reason, on code whose tap path it did not
	# touch -- a red carrying the wrong explanation, which CLAUDE.md
	# rates worse than a silent one.
	#
	# So the tap COUNT is every channel, and the ground count stays
	# separate for the assertions that really are about a destination.
	for sig in ["tapped_ground", "tapped_boat", "tapped_zipline_badger",
			"tapped_zipline_solo", "tapped_owl", "tapped_cabin", "tapped_ladder",
			"tapped_campfire", "tapped_balloon", "tapped_vehicle", "tapped_tree",
			"tapped_critter", "tapped_kart", "tapped_castle", "tapped_funfair",
			"tapped_funfair_rider"]:
		_tap.connect(sig, func(_a = null, _b = null) -> void: _any_taps += 1)
	await _phase_instrument()
	await _phase_bounds()
	await _phase_gain()
	await _phase_double()
	await _phase_sticky()
	await _phase_tap_unaffected()
	await _phase_licence()
	print("")
	print("=== ORBIT CAMERA PROBE: %d ok / %d RED ===" % [_ok, _red])
	get_tree().quit(1 if _red > 0 else 0)

# =====================================================================
# PHASE I -- THE INSTRUMENT, AND THE REST POSE IS BYTE-IDENTICAL
#
# The positive half first (CLAUDE.md: "le POSITIF d'abord, les refus
# ensuite"), and the rest-pose check is the one this whole lot rests on:
# if the orbit at (0, 0) were not the identity, every claim that the
# shipped frame is untouched would be a promise instead of arithmetic.

func _phase_instrument() -> void:
	print("-- PHASE I: the bench can see a real screen, and rest is rest --")
	var rect: Rect2 = _container.get_global_rect()
	_check(rect.size.x > 0.0 and rect.size.y > 0.0,
		"I1 the container has a real rect %s (xvfb, not --headless)" % rect)
	_check(_sub.size.x > 0 and _sub.size.y > 0,
		"I2 the subviewport has a real size %s" % _sub.size)
	_check(_camera != null and _tap != null and _keepy != null,
		"I3 camera, tap input and hopper all resolve")
	_check(_tap.hub_camera == _camera,
		"I4 the tap input resolved the HUB camera (not a bare Camera3D)")
	_check(_tap.hopper == _keepy,
		"I5 the tap input resolved the hopper (the licence's state half)")
	_check(_camera.orbit_is_rest(),
		"I6 the orbit starts at the pose the scene authored")
	# ⚠️ THE REST POSE, READ OFF THE LIVE CAMERA AND COMPARED TO THE
	# AUTHORED CONSTANTS. Not "close to": the rotation is the IDENTITY at
	# rest, so these are exact.
	_check(_camera._orbit_rotation() == Basis.IDENTITY,
		"I7 at rest the orbit rotation IS the identity")
	_check(_camera._orbit_offset() == HubCamera.OFFSET,
		"I8 at rest the offset IS OFFSET %s" % HubCamera.OFFSET)
	_check(_camera._hub_pose_basis() == _camera._hub_basis,
		"I9 at rest the pose basis IS the authored basis")
	await get_tree().process_frame

# =====================================================================
# PHASE B -- THE TWO BOUNDS, RE-MEASURED ON THE LIVE CAMERA
#
# Not "the constant reads what it reads" -- that is a tautology. Each
# bound is checked against the PROPERTY it was chosen for, read off the
# camera parked there, so a future OFFSET or fov that moved the property
# fails here instead of shipping a frame nobody looked at.

func _phase_bounds() -> void:
	print("-- PHASE B: the pitch band, and the property each bound is anchored on --")
	var e0: float = HubCamera.rest_elevation()
	_check(absf(rad_to_deg(e0) - 40.4951) < 0.01,
		"B1 the resting elevation is %.4f deg (published 40.4951)" % rad_to_deg(e0))
	# --- the LOW bound: clearance, and a still-downward camera pitch ---
	await _park_at(HubCamera.ORBIT_PITCH_MIN)
	var cam: Vector3 = _camera.global_position
	var clear: float = cam.y - HubSurface.ground(cam).y
	_check(clear > 2.0 * 1.7,
		"B2 at the low bound the camera clears the surface by %.4f u -- over twice Keepy's 1.7 u crown" % clear)
	var pitch_deg: float = -rad_to_deg(_camera.global_transform.basis.get_euler().x)
	_check(pitch_deg > 5.0,
		"B3 at the low bound the camera still looks DOWN, by %.2f deg" % pitch_deg)
	_check(_camera.orbit_pitch() == HubCamera.ORBIT_PITCH_MIN,
		"B4 the clamp holds the low bound against a push past it")
	# --- the HIGH bound: yaw must still be a live control ---
	await _park_at(HubCamera.ORBIT_PITCH_MAX)
	var off: Vector3 = _camera._orbit_offset()
	var horiz: float = Vector2(off.x, off.z).length()
	_check(horiz > 1.0,
		"B5 at the high bound the offset keeps %.4f u of HORIZONTAL radius -- a yaw still moves the camera" % horiz)
	_check(_camera.orbit_pitch() == HubCamera.ORBIT_PITCH_MAX,
		"B6 the clamp holds the high bound against a push past it")
	_check(absf(off.length() - HubCamera.OFFSET.length()) < 0.0001,
		"B7 and the distance is unchanged at the bound: %.4f u against %.4f" % [off.length(), HubCamera.OFFSET.length()])
	# --- the rotation is rigid at every step of the band ---
	var worst_dist: float = 0.0
	var worst_roll: float = 0.0
	var p: float = HubCamera.ORBIT_PITCH_MIN
	while p <= HubCamera.ORBIT_PITCH_MAX:
		_camera._orbit_pitch = p
		_camera._orbit_yaw = p * 3.0
		var o: Vector3 = _camera._orbit_offset()
		worst_dist = maxf(worst_dist, absf(o.length() - HubCamera.OFFSET.length()))
		# roll = how far the basis's X axis leaves the horizontal plane
		worst_roll = maxf(worst_roll, absf(_camera._hub_pose_basis().x.y))
		p += 0.02
	_camera._orbit_yaw = 0.0
	_camera._orbit_pitch = 0.0
	_check(worst_dist < 0.0001,
		"B8 across the whole band the distance never moves (worst %.7f u)" % worst_dist)
	_check(worst_roll < 0.000001,
		"B9 and the roll is exactly zero across it (worst |basis.x.y| %.9f)" % worst_roll)
	await _settle(4)

# =====================================================================
# PHASE G -- A KNOWN PIXEL TRAVEL PRODUCES A KNOWN ANGLE
#
# The gain, gated from the OUTSIDE: a finger is dragged a measured
# number of pixels through the engine and the angle that came out is
# compared with ORBIT_GAIN times that travel. This is what makes the
# constant a published fact rather than an unchecked feel knob, and it
# is also what would catch a sign flip -- the two minus signs in
# HubTapInput._gesture_move are gated HERE, not read.

func _phase_gain() -> void:
	print("-- PHASE G: the gain, and the signs, through the engine --")
	await _reset()
	var mid: Vector2 = _centre()
	var travel: float = 200.0
	await _stroke(mid, Vector2(travel, 0.0), 8)
	var yaw: float = _camera.orbit_yaw()
	var want: float = -travel * HubCamera.ORBIT_GAIN
	_check(absf(yaw - want) < 0.0005,
		"G1 a %.0f px drag RIGHT yawed %.5f rad, wanted %.5f" % [travel, yaw, want])
	_check(yaw < 0.0,
		"G2 and the sign is the turntable's: dragging right sweeps the world left")
	await _reset()
	await _stroke(mid, Vector2(0.0, -travel), 8)
	var pitch: float = _camera.orbit_pitch()
	_check(pitch > 0.0,
		"G3 a drag UP lifts the camera toward the overhead view (%.5f rad)" % pitch)
	await _reset()
	await _stroke(mid, Vector2(0.0, travel), 8)
	_check(_camera.orbit_pitch() < 0.0,
		"G4 a drag DOWN lowers it toward the horizon (%.5f rad)" % _camera.orbit_pitch())
	# ⚠️ THE POSE ACTUALLY MOVED -- a blind check, because every assertion
	# above reads the ANGLE and an angle that no pose followed would
	# satisfy all four of them. CLAUDE.md: an assertion of a value passes
	# for free against a mechanism that was never wired.
	await _reset()
	var before: Vector3 = _camera.global_position
	await _stroke(mid, Vector2(travel, 0.0), 8)
	await _settle(60)
	_check(_camera.global_position.distance_to(before) > 1.0,
		"G5 BLIND CHECK: and the camera itself moved %.4f u, not just the number" % _camera.global_position.distance_to(before))

# =====================================================================
# PHASE D -- THE DOUBLE DISPATCH, THE PRE-EXISTING DEBT, NEUTRALISED
#
# CLAUDE.md and SkateInputProbe both record it: one real finger arrives
# as InputEventMouseButton device=-1 FIRST and then as
# InputEventScreenTouch device=0, and HubTapInput reads both classes
# because a desktop browser produces only the first. CH73 does not fix
# the debt (out of scope) -- it is shaped so the debt cannot reach the
# orbit, and BOTH halves of that shape are gated here rather than
# claimed.
#
# The gesture below is the full twin pair, hand-interleaved in the
# measured order, delivered through the engine.

func _phase_double() -> void:
	print("-- PHASE D: a phone's twin pair turns the camera ONCE, and eats no tap --")
	await _reset()
	var mid: Vector2 = _centre()
	var travel: float = 200.0
	var taps_before: int = _ground_taps
	var any_before: int = _any_taps
	# ⚠️ THE STROKE ENDS ON A PIXEL THAT WOULD OTHERWISE HAVE BEEN A
	# DESTINATION, and D0 proves it. Without that, "no ground tap" is
	# satisfied for free by a release aimed at the sky -- a refusal that
	# never had to refuse anything. The red pass found exactly this: with
	# the latch neutralised D3 stayed GREEN, because the release happened
	# to land where no ray meets the ground. CLAUDE.md's "un seuil qui ne
	# separe pas le correctif de son absence".
	_check(_resolves(mid + Vector2(travel, 0.0)),
		"D0 INSTRUMENT: the pixel the drag ends on DOES resolve to ground")
	# press: the emulated mouse first, then the real finger
	Input.parse_input_event(_mouse(mid, true))
	Input.parse_input_event(_press(mid))
	await _settle(2)
	for i in range(1, 9):
		var at: Vector2 = mid + Vector2(travel * float(i) / 8.0, 0.0)
		Input.parse_input_event(_mouse_motion(at))
		Input.parse_input_event(_drag(at))
		await _settle(2)
	var at_end: Vector2 = mid + Vector2(travel, 0.0)
	Input.parse_input_event(_mouse(at_end, false))
	Input.parse_input_event(_release(at_end))
	await _settle(4)
	var yaw: float = _camera.orbit_yaw()
	var want: float = -travel * HubCamera.ORBIT_GAIN
	_check(absf(yaw - want) < 0.0005,
		"D1 the twin pair yawed %.5f rad -- the SINGLE-channel amount %.5f, not twice it" % [yaw, want])
	_check(absf(yaw - 2.0 * want) > 0.0005,
		"D2 and it is measurably NOT the doubled amount %.5f" % (2.0 * want))
	_check(_ground_taps == taps_before and _any_taps == any_before,
		"D3 neither release became a destination, on ANY channel (%d ground, %d total)" % [
			_ground_taps - taps_before, _any_taps - any_before])
	# ⚠️ D4 EXISTS BECAUSE RED PASS 2 CAME BACK ALL GREEN, and that is
	# the more useful half of what the pass found.
	#
	# Removing the one-gesture-one-channel claim was predicted to turn D1
	# and D2 red. It turned NOTHING red, and the reason is worth writing
	# down: the orbit integrates the difference between CONSECUTIVE
	# SAMPLES (`at - _last`), so a twin pair delivered at the SAME pixel
	# contributes the delta once and exactly ZERO the second time. The
	# doubling this lot set out to prevent is neutralised by the
	# integration, not by the claim -- D5 gates that, by neutralising the
	# integration instead.
	#
	# What the claim DOES buy is this, and it is a desktop defect rather
	# than a phone one: `_dragged` survives a gesture by design (both
	# releases of a twin pair must read the same latch), so a mouse MOVED
	# WITH NO BUTTON DOWN after a drag would be a motion with a stale
	# `_last`, a latched `_dragged`, and nothing to stop it turning the
	# camera. A hover is not a gesture.
	var held: float = _camera.orbit_yaw()
	Input.parse_input_event(_mouse_motion(mid + Vector2(-400.0, 220.0)))
	await _settle(2)
	_check(_camera.orbit_yaw() == held,
		"D4 a mouse moved with NO button down is a hover, and turns nothing")
	# D5: the integration itself, gated from the outside. Two samples at
	# the same pixel must be worth ONE step, which is the property the
	# whole double-dispatch defence actually rests on.
	await _reset()
	var start: Vector2 = _centre()
	Input.parse_input_event(_press(start))
	await _settle(2)
	var to: Vector2 = start + Vector2(120.0, 0.0)
	Input.parse_input_event(_drag(to))
	await _settle(2)
	Input.parse_input_event(_drag(to))
	await _settle(2)
	Input.parse_input_event(_release(to))
	await _settle(2)
	_check(absf(_camera.orbit_yaw() - (-120.0 * HubCamera.ORBIT_GAIN)) < 0.0005,
		"D5 the SAME pixel delivered twice is worth one step (%.5f rad)" % _camera.orbit_yaw())

# =====================================================================
# PHASE S -- STICKY. THE CONTRACT, AND IT IS AN EQUALITY.
#
# "Doigt releve: la camera reste exactement la ou elle a ete laissee.
# Aucun recentrage automatique, aucun delai, aucune interpolation de
# retour." That is an assertion of ABSENCE, so it passes for free
# against a camera that was never turned -- CLAUDE.md's blind check.
# S1 is the positive half and it runs first: the pose must have MOVED
# before "it does not move back" means anything.

func _phase_sticky() -> void:
	print("-- PHASE S: the camera stays where it was left --")
	await _reset()
	var rest_yaw: float = _camera.orbit_yaw()
	await _stroke(_centre(), Vector2(180.0, -90.0), 8)
	await _settle(60)
	var yaw: float = _camera.orbit_yaw()
	var pitch: float = _camera.orbit_pitch()
	var pose: Transform3D = _camera.global_transform
	_check(absf(yaw - rest_yaw) > 0.1 and absf(pitch) > 0.05,
		"S1 BLIND CHECK: the gesture moved the orbit at all (yaw %.5f, pitch %.5f)" % [yaw, pitch])
	# 600 frames with the finger off the glass. No timer, no tween, no
	# recentre: the equality is exact, not a tolerance.
	await _settle(600)
	_check(_camera.orbit_yaw() == yaw and _camera.orbit_pitch() == pitch,
		"S2 600 frames later the orbit is bit-for-bit where it was left")
	# ⚠️ S3 IS NOT "the pose stopped moving", AND ITS FIRST WRITING WAS.
	# That version compared the basis 600 frames later with the basis 60
	# frames after the lift and came back RED on correct code: the pose
	# was still ARRIVING. `_apply_orbit` lags the basis at FOLLOW_LAMBDA
	# exactly as the position has always been lagged, so a sample taken
	# one second after the finger lifts still carries exp(-5) = 0.67 % of
	# the error. Convergence toward what the player asked for is not a
	# recentring, and an assertion that cannot tell the two apart is not
	# the assertion this phase needs.
	#
	# What "sticky" actually forbids is the pose converging on the
	# AUTHORED basis. So both distances are measured and published, and
	# the gate is that the live pose has arrived at the orbit the player
	# left and is nowhere near the one the scene authored.
	var to_left: float = _basis_angle(_camera.global_transform.basis, _camera._hub_pose_basis())
	var to_authored: float = _basis_angle(_camera.global_transform.basis, _camera._hub_basis)
	_check(to_left < deg_to_rad(0.05),
		"S3 the pose ARRIVED at the orbit he left (%.5f deg from it)" % rad_to_deg(to_left))
	_check(to_authored > deg_to_rad(20.0),
		"S3b and it is %.2f deg from the AUTHORED pose -- nothing pulled it back" % rad_to_deg(to_authored))
	_check(pose.basis != _camera._hub_basis,
		"S3c INSTRUMENT: the two poses are different bases, so S3b is not vacuous")
	# ⚠️ AND IT SURVIVES A WALK. The pose FOLLOWS Keepy (it always has);
	# what must not change is the ANGLE. A recentre-on-move would show up
	# here and nowhere else.
	var tapped: Vector2 = _walk_pixel()
	_check(tapped != Vector2.ZERO,
		"S4a INSTRUMENT: a pixel that resolves to walkable ground was found")
	Input.parse_input_event(_press(tapped))
	await _settle(2)
	Input.parse_input_event(_release(tapped))
	await _settle(4)
	_check(_keepy.is_hopping(),
		"S4 INSTRUMENT: a tap started a walk, so the next check is not vacuous")
	var frames: int = 0
	while _keepy.is_hopping() and frames < 900:
		await get_tree().process_frame
		frames += 1
	_check(_camera.orbit_yaw() == yaw and _camera.orbit_pitch() == pitch,
		"S5 and a whole walk (%d frames) left the orbit untouched" % frames)

# =====================================================================
# PHASE T -- THE TAP PATH IS NOT REGRESSED
#
# The half of the brief that is about what must NOT change. A gesture
# under the slop has to reach `_handle_point` exactly as it always did,
# whatever the camera is doing -- including AFTER an orbit, which is the
# case a test written before the orbit existed would never cover.

func _phase_tap_unaffected() -> void:
	print("-- PHASE T: a short tap still walks, before and after an orbit --")
	await _reset()
	var target: Vector2 = _walk_pixel()
	_check(target != Vector2.ZERO,
		"T0 INSTRUMENT: a pixel that resolves to walkable ground was found")
	var taps_before: int = _ground_taps
	Input.parse_input_event(_press(target))
	await _settle(2)
	Input.parse_input_event(_release(target))
	await _settle(4)
	_check(_ground_taps > taps_before,
		"T1 a motionless tap still emits tapped_ground (%d)" % (_ground_taps - taps_before))
	_check(_keepy.is_hopping(), "T2 and it still starts a walk")
	await _settle_walk()
	# a jitter UNDER the slop is still a tap -- the threshold gated from
	# the side that must not become a drag. SkateInputProbe gates the
	# board's from both sides; this is the same number, so is this.
	await _reset()
	# ⚠️ RE-DERIVED, NOT REUSED. `_reset` puts Keepy back at OPEN_GROUND
	# and re-snaps the camera, so the pixel that meant walkable ground
	# one phase ago is a claim about a world that has been put back.
	target = _walk_pixel()
	_check(target != Vector2.ZERO, "T2a INSTRUMENT: and again after the reset")
	var any_before: int = _any_taps
	var jitter: float = SkateTouchInput.SLOP_PX - 4.0
	Input.parse_input_event(_press(target))
	await _settle(2)
	Input.parse_input_event(_drag(target + Vector2(jitter, 0.0)))
	await _settle(2)
	Input.parse_input_event(_release(target + Vector2(jitter, 0.0)))
	await _settle(4)
	_check(_any_taps > any_before,
		"T3 a %.0f px jitter (under the %.0f px slop) is still a tap (%d emitted)" % [
			jitter, SkateTouchInput.SLOP_PX, _any_taps - any_before])
	# ⚠️ T3b GATES A DECISION, NOT A MECHANISM: the hub takes `SLOP_PX`
	# and declines `TAP_MAX_S` (see HubTapInput._gesture_was_tap). A
	# finger pressed, held motionless for well over the board's 0.45 s
	# window and lifted is still a destination, because in this screen a
	# held finger has no other meaning. Timed in WALL CLOCK and the
	# duration published, since that is the quantity the declined
	# constant would have measured.
	await _reset()
	any_before = _any_taps
	var hold_from: Vector2 = _walk_pixel()
	_check(hold_from != Vector2.ZERO, "T3a INSTRUMENT: a walkable pixel for the long press")
	var t0: float = float(Time.get_ticks_msec()) / 1000.0
	Input.parse_input_event(_press(hold_from))
	await _settle(12)
	Input.parse_input_event(_release(hold_from))
	await _settle(4)
	var held_s: float = float(Time.get_ticks_msec()) / 1000.0 - t0
	_check(held_s > SkateTouchInput.TAP_MAX_S,
		"T3b INSTRUMENT: the press lasted %.3f s, past the board's %.3f s window" % [
			held_s, SkateTouchInput.TAP_MAX_S])
	_check(_any_taps > any_before,
		"T3c and a long motionless press is STILL a tap (%d emitted)" % (_any_taps - any_before))
	await _settle_walk()
	_check(_camera.orbit_is_rest(),
		"T4 and it turned the camera not at all")
	await _settle_walk()
	# and the same, AFTER the camera has been turned
	await _stroke(_centre(), Vector2(300.0, 0.0), 8)
	await _settle(60)
	_check(not _camera.orbit_is_rest(), "T5 INSTRUMENT: the camera is now turned")
	taps_before = _ground_taps
	# ⚠️ AND THIS ONE IS DERIVED UNDER THE **TURNED** CAMERA, which is
	# the whole point of T6: the pixel that means ground is a different
	# pixel once the camera has moved, and a probe that reused the old
	# one would be asking whether a stale pixel still works.
	var after: Vector2 = _walk_pixel()
	_check(after != Vector2.ZERO,
		"T5a INSTRUMENT: a walkable pixel exists under the turned camera too")
	Input.parse_input_event(_press(after))
	await _settle(2)
	Input.parse_input_event(_release(after))
	await _settle(4)
	_check(_ground_taps > taps_before,
		"T6 a tap under a TURNED camera still emits tapped_ground")
	_check(_keepy.is_hopping(), "T7 and still starts a walk")
	await _settle_walk()

# =====================================================================
# PHASE L -- THE LICENCE, AND IT IS TESTED AS A LICENCE
#
# CLAUDE.md CH58: a guard that throws an input away is tested on the
# PROPERTY that licenses it, never on a state some other user shares.
# The orbit throws nothing away -- below the slop every release takes
# the shipped path -- but it is ARMED on a licence, and an armed-when-it
# -should-not-be orbit would turn the camera during a ride.

func _phase_licence() -> void:
	print("-- PHASE L: no orbit while somebody else owns the frame --")
	await _reset()
	_check(_tap._orbit_licensed(),
		"L1 INSTRUMENT: on his feet and at rest, the orbit IS licensed")
	# a POV is running: CH72's own exit gesture is a tap, and a finger
	# there must not be turning a camera that is somebody's head.
	_camera.enter_pov(_keepy.head_anchor(), 0.0)
	await _settle(4)
	_check(not _tap._orbit_licensed(),
		"L2 under a POV the orbit is refused")
	var held: float = _camera.orbit_yaw()
	await _stroke(_centre(), Vector2(300.0, 0.0), 8)
	_check(_camera.orbit_yaw() == held,
		"L3 and a 300 px drag under it moved the orbit not at all")
	_camera.exit_pov()
	await _settle(40)
	# a chase is running: the vehicle owns the frame.
	_camera.enter_drive(_keepy)
	await _settle(4)
	_check(not _tap._orbit_licensed(),
		"L4 under a chase the orbit is refused")
	held = _camera.orbit_yaw()
	await _stroke(_centre(), Vector2(300.0, 0.0), 8)
	_check(_camera.orbit_yaw() == held,
		"L5 and a 300 px drag under it moved the orbit not at all")
	_camera.exit_drive()
	await _settle(70)
	_check(_tap._orbit_licensed(),
		"L6 and the licence comes back when the frame is his own again")

# =====================================================================
# helpers -- events built the way SkateInputProbe builds them

func _press(at: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = true
	e.position = at
	return e

func _release(at: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = false
	e.position = at
	return e

func _drag(at: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = at
	return e

func _mouse(at: Vector2, down: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	return e

func _mouse_motion(at: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = at
	return e

## The angle between two bases, in radians -- how far one would have to
## be turned to become the other. A single number for "how different are
## these two poses", so a drift can be published rather than merely
## detected.
func _basis_angle(a: Basis, b: Basis) -> float:
	return absf(a.get_rotation_quaternion().angle_to(b.get_rotation_quaternion())) * 2.0


## True when a RAW SCREEN pixel resolves to a point on the ground -- the
## mapping `HubTapInput._handle_point` does, run here so an instrument
## can say whether a refusal actually had something to refuse.
func _resolves(at: Vector2) -> bool:
	var rect: Rect2 = _container.get_global_rect()
	if not rect.has_point(at):
		return false
	var local: Vector2 = at - rect.position
	local.x *= float(_sub.size.x) / rect.size.x
	local.y *= float(_sub.size.y) / rect.size.y
	return HubSurface.intersect_ray(_camera.project_ray_origin(local),
		_camera.project_ray_normal(local)) != null

## A screen pixel that is known to mean a real walk: it resolves to a
## point on the ground, that point is reachable, and it is far enough
## from Keepy that the walk is not the zero-length one CLAUDE.md
## records (which emits `became_idle` and never `hop_landed`, so an
## instrument written as "he is hopping" would read red on a tap that
## worked perfectly).
##
## Returns Vector2.ZERO if no candidate resolves, and every caller
## ASSERTS it did -- an instrument that silently found nothing to tap
## would make every assertion after it pass by never running.
func _walk_pixel() -> Vector2:
	var rect: Rect2 = _container.get_global_rect()
	for v in [0.34, 0.40, 0.46, 0.28, 0.52]:
		for u in [0.5, 0.42, 0.58, 0.36, 0.64]:
			var sp := Vector2(float(_sub.size.x) * u, float(_sub.size.y) * v)
			var o: Vector3 = _camera.project_ray_origin(sp)
			var d: Vector3 = _camera.project_ray_normal(sp)
			var hit: Variant = HubSurface.intersect_ray(o, d)
			if hit == null:
				continue
			var point: Vector3 = hit
			var dest: Vector3 = HubRegion.clamp_to(point)
			var here: Vector3 = _keepy.global_position
			if Vector2(dest.x - here.x, dest.z - here.z).length() < 3.0:
				continue
			var scale := Vector2(rect.size.x / float(_sub.size.x), rect.size.y / float(_sub.size.y))
			return rect.position + sp * scale
	return Vector2.ZERO

## The middle of the container, in the raw screen pixels an event carries.
func _centre() -> Vector2:
	var rect: Rect2 = _container.get_global_rect()
	return rect.position + rect.size * 0.5

## One whole gesture, delivered through the engine: press, `steps` drags
## along `by`, release. The TOUCH class only -- PHASE D is the one that
## delivers the twin pair.
func _stroke(from: Vector2, by: Vector2, steps: int) -> void:
	Input.parse_input_event(_press(from))
	await _settle(2)
	for i in range(1, steps + 1):
		Input.parse_input_event(_drag(from + by * (float(i) / float(steps))))
		await _settle(2)
	Input.parse_input_event(_release(from + by))
	await _settle(2)

## Puts the orbit back at the authored pose and lets the follow settle.
## A SETUP rather than a teardown, on SkateInputProbe's own reasoning: a
## phase cannot know which phase ran before it.
func _reset() -> void:
	_camera._orbit_yaw = 0.0
	_camera._orbit_pitch = 0.0
	_tap._claim = HubTapInput.Claim.NONE
	_tap._dragged = false
	# ⚠️ THE WORLD IS PUT BACK, NOT JUST THE CAMERA. See OPEN_GROUND.
	_keepy.global_position = HubSurface.ground(OPEN_GROUND)
	_keepy._has_target = false
	_camera.snap_to_target()
	await _settle(10)

## Parks the orbit at one pitch by PUSHING PAST it through the public
## writer, so what is read back is the clamp's answer and not a value
## this file wrote.
func _park_at(pitch: float) -> void:
	_camera._orbit_yaw = 0.0
	_camera._orbit_pitch = 0.0
	_camera.orbit_by(0.0, pitch * 2.0)
	_camera.snap_to_target()
	await _settle(10)

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

func _settle_walk() -> void:
	var frames: int = 0
	while _keepy.is_hopping() and frames < 900:
		await get_tree().process_frame
		frames += 1
