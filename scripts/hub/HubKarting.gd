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
##      "hint": int, "active": bool, "player": bool}
##
## Every racer is DRIVEN the same way, in the same loop below: the kart
## reads its input, the track judges its surface, the lap reads its
## progress. The player's entry differs in exactly two facts -- its input
## is written by KartTouchInput, and Keepy sits in it -- and those two are
## the ONLY places this file says "player". A lot-2 opponent is an entry
## whose input is written by a follower; the loop does not change.
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

const KART_TAP_RADIUS: float = 2.4
## The accelerator waits this long after the mount: the camera blend
## (HubCamera.DRIVE_BLEND_S) plus a beat, so the kart leaves from a frame
## that is already the driving frame.
const MOUNT_HOLD_S: float = 1.2
const EXIT_SIDE: float = 1.8
const PLAYER_COLOUR: Color = Color(0.93, 0.40, 0.30)

var track: KartTrack = null
var racers: Array[Dictionary] = []
var touch: KartTouchInput = null

var _keepy: KeepyHopper = null
var _camera: HubCamera = null
var _hud: KartHud = null
var _intent: bool = false
var _driving: bool = false
var _player: int = -1
var _decor: KartDecor = null

func _ready() -> void:
	track = KartTrack.new()
	track.name = "Track"
	add_child(track)
	touch = KartTouchInput.new()
	touch.name = "Touch"
	add_child(touch)
	_player = add_racer("Keepy", PLAYER_COLOUR, true)
	_decor = KartDecor.new()
	_decor.name = "Decor"
	add_child(_decor)
	_decor.build(track)

## Adds a kart to the grid at the next slot. Returns its index. The
## player's is the one whose input KartTouchInput writes; any other
## racer's input is left for its own writer (lot 2).
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
	racers.append({"kart": kart, "input": input, "lap": lap, "hint": -1, "active": false, "player": player})
	return index

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

func is_driving() -> bool:
	return _driving

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
	racers[_player]["active"] = true
	racers[_player]["hint"] = -1
	(racers[_player]["lap"] as KartLap).reset()
	touch.enabled = true
	touch.hold_throttle(MOUNT_HOLD_S)
	if _camera != null:
		_camera.enter_drive(kart)
	if _hud != null:
		_hud.visible = true
		_refresh_hud()
	driving_changed.emit(true)
	return true

## The HUD button. Stops the kart where it is, gives the body back, and
## re-opens the kart to the tap.
func exit_kart() -> void:
	if not _driving:
		return
	var kart: KartBody = player_kart()
	touch.enabled = false
	touch.input.reset()
	kart.velocity = Vector3.ZERO
	kart.show_steer(0.0)
	racers[_player]["active"] = false
	_driving = false
	if _camera != null:
		_camera.exit_drive()
	if _hud != null:
		_hud.visible = false
		_hud.set_ghost(Vector2.ZERO, Vector2.ZERO, false)
	# Beside the kart, on the region: the circuit is region, so this is
	# a point a hop can end on. Right of travel, where the driver climbs
	# out; the far side if that is somehow off the region.
	var at: Vector3 = Vector3(kart.global_position.x, 0.0, kart.global_position.z)
	var landing: Vector3 = HubRegion.clamp_to(at + kart.right() * EXIT_SIDE)
	if landing.distance_to(at) < 0.8:
		landing = HubRegion.clamp_to(at - kart.right() * EXIT_SIDE)
	_keepy.leave_carrier(landing)
	driving_changed.emit(false)

## ---- the loop --------------------------------------------------------

func _physics_process(delta: float) -> void:
	if track == null:
		return
	var fence: Rect2 = track.fence()
	for i in racers.size():
		var r: Dictionary = racers[i]
		if not r["active"]:
			continue
		var kart: KartBody = r["kart"]
		var input: KartInput = r["input"]
		var progress: Dictionary = track.progress_at(kart.global_position, int(r["hint"]))
		var on_track: bool = absf(float(progress["lateral"])) <= KartTrack.HALF_WIDTH + KartTrack.ON_TRACK_MARGIN
		kart.drive(delta, input, on_track, fence)
		kart.show_steer(input.steer)
		progress = track.progress_at(kart.global_position, int(progress["index"]))
		r["hint"] = int(progress["index"])
		var along: float = kart.velocity.dot(progress["tangent"] as Vector3)
		(r["lap"] as KartLap).update(float(progress["s"]), along >= -0.5, delta)
		if r["player"] and _driving:
			_keepy.follow_carrier()
	if _driving and _hud != null:
		_refresh_hud()
		_hud.set_ghost(touch.anchor, touch.finger, touch.steering_active)

func _refresh_hud() -> void:
	var lap: KartLap = player_lap()
	if lap == null:
		return
	var best: int = WorldSave.kart_best_ms(KartTrack.TRACK_ID)
	_hud.set_times(int(round(lap.lap_time_s * 1000.0)), best, lap.last_lap_ms, lap.lap_count, lap.timing)
	_hud.set_wrong_way(lap.wrong_way)

func _on_lap(index: int, ms: int) -> void:
	if not racers[index]["player"]:
		return
	WorldSave.note("kart_laps")
	if WorldSave.kart_offer_lap(KartTrack.TRACK_ID, ms) and _hud != null:
		_hud.flash_record()
