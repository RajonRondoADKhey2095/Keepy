extends Node3D
class_name HubBoar
## Carte-blanche V6 -- the scout boar of the autumn hollow, and the
## TRUFFLE DIG: the one thing on this plateau Keepy cannot do himself.
##
## =====================================================================
## THE MECHANIC, ACTION -> ANIMATION -> FEEDBACK -> REWARD
##
## Tap the boar -> Keepy walks to it and climbs on its shoulders
## (`mount_carrier`, the balloon's rail: this node moves, and the rider is
## written right after it in the SAME call) -> it trots to a RIPE dig site
## of its table (the hollow's leaf piles: truffles grow under leaves, and
## the piles are already where the scatter put them) -> it digs: nose
## down, a crouch, two bursts of earth clods (HubNuts' leaf channel,
## tinted soil) and the pile itself collapses to half -> a TRUFFLE pops
## out (a new resource kind, drawn from pebble_0 in dark brown) -> Keepy
## is set down beside it and picks it up by walking (HubNuts' ordinary
## pick) -> the boar walks home. A dug site RECHARGES on the wall clock,
## so there is a reason to come back; the pile grows back with it.
##
## =====================================================================
## THE BOAT PATTERN, DOOR BY DOOR
##
##   1. APPROACH: an ordinary hop chain; the intent lives in HubCritters
##      and any other tap cancels it (HubWorld resets intents on every
##      ordinary tap, and `became_idle` drops it when the chain runs out).
##   2. THE RIDE: this node WITHDRAWS from the tap the moment the rider
##      mounts (`accepts_tap` is false until it is home), so a tap
##      meanwhile falls to the ground path and reaches
##      `_on_tapped_ground`'s `is_on_carrier()` branch, where it is
##      DROPPED. That licence is the zipline's and it is narrow: the trip
##      is BOUNDED -- a constant-speed walk to a fixed site, a dig timer,
##      a dismount hop -- and always ends with the rider on the ground.
##   3. ARRIVAL: `leave_carrier` puts Keepy on the ground beside the
##      truffle and hands the body back; the walk home is the boar's
##      own business and Keepy is free for the whole of it.
##
## Nothing here can hold the body: the dig ends on a timer, the walk ends
## on a distance, and `KeepyHopper.follow_carrier()` itself drops him to
## IDLE if this node ever disappeared under him.
##
## =====================================================================
## NUMBERS -- measured, and where
##
## Model span 1.9022 on the imported vertices (CritterInspect, journal
## V6); drawn at 1.35 x Keepy (1.8226) -- under the bear's 1.89 so the
## size order badger < bear is not inverted a second time (CH21).
## Lowest vertex at -0.9519, so the model is lifted by 0.9519 x scale.

const SCENE: PackedScene = preload("res://assets/models/keepy_boar_npc.glb")
const MODEL_SPAN: float = 1.9022
const MODEL_LOW: float = 0.9519
const DRAWN_HEIGHT: float = 1.35 * 1.3501
const SCALE: float = DRAWN_HEIGHT / MODEL_SPAN
const LIFT: float = MODEL_LOW * SCALE

## Where it waits: the west edge of the Mother Tree clearing, beside the
## end of the autumn road (-5.6, -58.4) and outside the giant-mushroom
## ring (r 7.5 +- 0.6 round (0, -62)); 10.8 u from the trunk. Faces the
## road, so a player arriving down it meets its eyes.
const REST: Vector3 = Vector3(-8.5, 0.0, -55.5)
const REST_FACING: Vector3 = Vector3(0.55, 0.0, 0.83)
## Shelter under the Mother Tree's canopy when the sky turns (the bear's
## BEAR_SHELTER rule): 5.5 u from the trunk at an azimuth BETWEEN two ring
## mushrooms (k = 0 at 0 rad and k = 1 at 0.90 rad; this is 0.45 rad).
const SHELTER: Vector3 = Vector3(4.9, 0.0, -59.6)
const NEAR: float = 1.2

## Tap disc and ground footprint (published for the scatter and the
## exit-point searches).
const TAP_RADIUS: float = 1.9
const FOOTPRINT: float = 1.1
## Keepy on its shoulders, in THIS node's space (Keepy units, never scaled
## by the boar -- the carrier rule). 1.22 puts his feet on the chest of a
## 1.82-tall body; -0.05 tucks him a hair behind the head.
const SEAT: Vector3 = Vector3(0.0, 1.32, -0.12)

const TROT_SPEED: float = 4.2
const HOME_SPEED: float = 2.4
## Site choice: ripe, and at a trip length that reads as a ride -- not
## next door, not across the map.
const SITE_MIN_D: float = 5.0
const SITE_MAX_D: float = 26.0
const SITE_IDEAL_D: float = 12.0
const SITE_RECHARGE_S: float = 150.0
## 12, not every pile: the cat hides in the ones the boar does not dig.
const MAX_SITES: int = 12
const MOTHER_CLEAR: float = 6.5
## The dig: total seconds, the two clod bursts and the truffle's release
## as fractions of it.
const DIG_S: float = 2.6
const DIG_PITCH_DEG: float = 34.0
const DIG_SQUASH: float = 0.86
const CLOD_AT: Array[float] = [0.30, 0.62]
const TRUFFLE_AT: float = 0.82
const CLODS_PER_BURST: int = 5
const CLOD_TINT: Color = Color(0.46, 0.33, 0.22)
## A dug pile is drawn at this fraction of itself until it recharges.
const DUG_PILE_SCALE: float = 0.55
## Keepy is set down this far to the boar's side, so the dismount hop
## lands within HubNuts.PICK_RADIUS (0.85) of a truffle that lay still.
const EXIT_SIDE: float = 0.7

enum Phase { FREE, RIDING, DIGGING, RETURNING }

signal ride_finished

var _critter: HubCritter = null
var _keepy: KeepyHopper = null
var _nuts: HubNuts = null
var _weather: Node = null
var _phase: int = Phase.FREE
## Every dig site: {"at": Vector3, "dug_at": int unix (0 = ripe),
## "multi": MultiMeshInstance3D, "slot": int, "xform": Transform3D}.
var _sites: Array[Dictionary] = []
var _site: int = -1
var _dig_t: float = -1.0
var _clods_done: int = 0
var _truffle_done: bool = false
var _marker: Node3D = null
## For probes: counts.
var digs_total: int = 0
var refusals_total: int = 0

func _ready() -> void:
	_critter = HubCritter.new()
	_critter.name = "Critter"
	add_child(_critter)
	_critter.setup_model(SCENE, SCALE, LIFT)
	_critter.global_position = REST
	_critter.face(REST_FACING)
	_critter.gait_stride = 1.25
	_critter.gait_bob = 0.085
	_critter.gait_roll_deg = 5.0
	_critter.gait_pitch_deg = 3.0
	_critter.arrived.connect(_on_arrived)
	_marker = Node3D.new()
	_marker.name = "DigMarker"
	add_child(_marker)

## Handed its collaborators once. `piles` is the scatter's published
## leaf-pile instance list; `blocked` the ground discs a site must clear.
func setup(keepy: KeepyHopper, weather: Node, nuts: HubNuts, piles: Array, blocked: Array, occluders: Array = []) -> void:
	_keepy = keepy
	_weather = weather
	_nuts = nuts
	if _weather != null and _weather.has_signal("weather_changed"):
		_weather.weather_changed.connect(_on_weather_changed)
	_build_sites(piles, blocked, occluders)

## Ground discs nobody should sow in or be set down on.
static func footprints() -> Array:
	return [{"position": REST, "radius": FOOTPRINT}, {"position": SHELTER, "radius": FOOTPRINT}]

func critter() -> HubCritter:
	return _critter

func phase() -> int:
	return _phase

func position_flat() -> Vector3:
	return _critter.flat()

func sites() -> Array[Dictionary]:
	return _sites

func site_ripe(index: int) -> bool:
	if index < 0 or index >= _sites.size():
		return false
	var dug: int = int(_sites[index]["dug_at"])
	return dug == 0 or float(_now() - dug) >= SITE_RECHARGE_S

func ripe_count() -> int:
	var n: int = 0
	for i in _sites.size():
		if site_ripe(i):
			n += 1
	return n

## The pile the current or last ride dug, for probes.
func last_site() -> int:
	return _site

## Probes: makes every site ripe again, or none.
func set_all_dug(dug: bool) -> void:
	for i in _sites.size():
		_sites[i]["dug_at"] = _now() if dug else 0
		_write_pile(i)

## ---- the tap door -------------------------------------------------------

## True when a tap at `aim` means "the boar": on it, and it is not busy.
## FALSE FOR THE WHOLE OF A RIDE -- the withdrawal.
func accepts_tap(aim: Vector3) -> bool:
	if _phase == Phase.RIDING or _phase == Phase.DIGGING:
		return false
	return Vector3(aim.x, 0.0, aim.z).distance_to(_critter.flat()) <= TAP_RADIUS

## A tap on it while it walks home (or to shelter): it stops and waits.
func on_tapped() -> void:
	if _phase == Phase.RETURNING:
		_phase = Phase.FREE
	if _critter.is_walking():
		_critter.halt()

## Mounts if `position` (a landing) is on it. Returns true when the ride
## started OR the intent was consumed (a refusal); false when not there
## yet, so the intent survives (the boat's measured defect).
func try_mount(position: Vector3) -> bool:
	if _phase != Phase.FREE:
		return false
	if Vector3(position.x, 0.0, position.z).distance_to(_critter.flat()) > TAP_RADIUS:
		return false
	var site: int = _choose_site()
	if site < 0:
		# Nothing ripe within reach: a snort and a shake of the head, and
		# the tap is spent. Never a mount that ends where it began.
		_critter.punch = 1.0
		_critter.turn_to(_critter.facing().rotated(Vector3.UP, 0.6))
		refusals_total += 1
		return true
	if not _keepy.mount_carrier(_critter, SEAT):
		return false
	_site = site
	_phase = Phase.RIDING
	_critter.halt()
	_critter.speed = TROT_SPEED
	# Stop a stride short of the pile, facing it, so it digs at its feet.
	var at: Vector3 = _sites[site]["at"]
	var dir: Vector3 = (at - _critter.flat())
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	_critter.walk_to(at - dir * 0.95)
	return true

## Distance-scored: ripe, inside [MIN, MAX], nearest to IDEAL.
func _choose_site() -> int:
	var here: Vector3 = _critter.flat()
	var best: int = -1
	var best_score: float = INF
	for i in _sites.size():
		if not site_ripe(i):
			continue
		var d: float = here.distance_to(_sites[i]["at"])
		if d < SITE_MIN_D or d > SITE_MAX_D:
			continue
		var score: float = absf(d - SITE_IDEAL_D)
		if score < best_score:
			best_score = score
			best = i
	return best

## ---- per frame: carrier first, rider right after ----------------------

func _process(delta: float) -> void:
	_critter.shiver = 1.0 if (_weather != null and _weather.has_method("kind") and _weather.call("kind") == CozyWeather.Kind.SNOW and _phase == Phase.FREE) else 0.0
	if _phase == Phase.DIGGING:
		_dig(delta)
	_critter.step(delta)
	if (_phase == Phase.RIDING or _phase == Phase.DIGGING) and _keepy != null and _keepy.is_on_carrier():
		_keepy.follow_carrier()

func _on_arrived() -> void:
	match _phase:
		Phase.RIDING:
			if _keepy == null or not _keepy.is_on_carrier():
				# The rider is gone (something else took the body): no dig
				# for nobody, straight home.
				_go_home()
				return
			_phase = Phase.DIGGING
			_dig_t = 0.0
			_clods_done = 0
			_truffle_done = false
			var at: Vector3 = _sites[_site]["at"]
			_critter.turn_to(at - _critter.flat())
			_marker.global_position = at
		Phase.RETURNING:
			_phase = Phase.FREE
			_critter.turn_to(REST_FACING if _critter.flat().distance_to(REST) < NEAR else (REST - _critter.flat()))

func _dig(delta: float) -> void:
	_dig_t += delta
	var t: float = clampf(_dig_t / DIG_S, 0.0, 1.0)
	# Nose down and a crouch, pawing at 5 Hz.
	var envelope: float = sin(PI * t)
	_critter.pose_pitch_deg = DIG_PITCH_DEG * envelope + 5.0 * sin(_dig_t * TAU * 5.0) * envelope
	_critter.pose_squash = 1.0 - (1.0 - DIG_SQUASH) * envelope
	while _clods_done < CLOD_AT.size() and t >= CLOD_AT[_clods_done]:
		_clods_done += 1
		if _nuts != null:
			_nuts.drop_leaves(_marker, CLODS_PER_BURST, 0.35, 0.28, "leaf", CLOD_TINT)
		if _clods_done == 1:
			_sites[_site]["dug_at"] = _now()
			_write_pile(_site)
	if not _truffle_done and t >= TRUFFLE_AT:
		_truffle_done = true
		digs_total += 1
		WorldSave.note("boar_digs")
		if _nuts != null:
			var side: Vector3 = _exit_side()
			var at: Vector3 = _marker.global_position + Vector3(0.0, 0.32, 0.0)
			_nuts.drop_at(&"truffle", at, side * 0.9 + Vector3(0.0, 2.2, 0.0))
	if t >= 1.0:
		_critter.pose_pitch_deg = 0.0
		_critter.pose_squash = 1.0
		_set_down()

## Keepy's side of the boar: its right, so the hop off lands beside the
## pile and not in it.
func _exit_side() -> Vector3:
	var f: Vector3 = _critter.facing()
	return Vector3(f.z, 0.0, -f.x)

func _set_down() -> void:
	var landing: Vector3 = _marker.global_position + _exit_side() * EXIT_SIDE
	if not HubRegion.contains(landing):
		landing = HubRegion.clamp_to(landing)
	if _keepy != null and _keepy.is_on_carrier():
		_keepy.leave_carrier(landing)
	_go_home()
	ride_finished.emit()

func _go_home() -> void:
	_phase = Phase.RETURNING
	_critter.speed = HOME_SPEED
	_critter.walk_to(REST)

## ---- the sites ------------------------------------------------------------

func _build_sites(piles: Array, blocked: Array, occluders: Array = []) -> void:
	_sites.clear()
	var ranked: Array = []
	for pile in piles:
		var at: Vector3 = pile["at"]
		if not HubRegion.contains(at):
			continue
		var d: float = at.distance_to(REST)
		if d < SITE_MIN_D or d > SITE_MAX_D:
			continue
		# The Mother Tree's roots flare ~3.5 u: no digging in them.
		if at.distance_to(HubRegion.MOTHER_TREE_AT) < MOTHER_CLEAR:
			continue
		var free: bool = true
		for fp in blocked:
			if at.distance_to(fp["position"] as Vector3) < float(fp["radius"]) + FOOTPRINT + 0.4:
				free = false
				break
		if not free:
			continue
		# A dig nobody can see is no dig: nothing between the camera and
		# the pile (HubCritters.hidden_at), nothing pressed against it.
		if HubCritters.hidden_at(at, occluders) or HubCritters.crowded_at(at, occluders, 0.6):
			continue
		ranked.append({"at": at, "d": d, "pile": pile})
	ranked.sort_custom(func(a, b): return a["d"] < b["d"])
	for entry in ranked:
		if _sites.size() >= MAX_SITES:
			break
		var pile: Dictionary = entry["pile"]
		_sites.append({"at": entry["at"], "dug_at": 0, "multi": pile.get("node", null), "slot": int(pile.get("index", -1)), "xform": pile.get("xform", Transform3D.IDENTITY)})

## Writes the pile instance at full size (ripe) or collapsed (dug).
## set_instance_transform on the one slot -- no reallocation, the v5 rule.
func _write_pile(index: int) -> void:
	var site: Dictionary = _sites[index]
	var multi: MultiMeshInstance3D = site.get("multi", null) as MultiMeshInstance3D
	var slot: int = int(site["slot"])
	if multi == null or multi.multimesh == null or slot < 0:
		return
	var xform: Transform3D = site["xform"]
	if not site_ripe(index):
		xform = Transform3D(xform.basis.scaled(Vector3(1.0, DUG_PILE_SCALE, 1.0)), xform.origin)
	multi.multimesh.set_instance_transform(slot, xform)

func _now() -> int:
	return int(Time.get_unix_time_from_system())

## The bear's rule: shelter when free, come out in the sun. Not gated on
## "is he walking" (the ranger's measured defect): a FREE boar can only be
## on a weather walk, and re-aiming that bounded walk is harmless.
func _on_weather_changed(kind: int) -> void:
	if _phase != Phase.FREE:
		return
	var here: Vector3 = _critter.flat()
	var bad: bool = kind != CozyWeather.Kind.SUN
	_critter.speed = HOME_SPEED
	if bad and here.distance_to(SHELTER) > NEAR * 0.5:
		_critter.walk_to(SHELTER)
	elif not bad and here.distance_to(REST) > NEAR * 0.5:
		_critter.walk_to(REST)

## Recharged piles grow back: polled once a second by the coordinator.
func refresh_piles() -> void:
	for i in _sites.size():
		if int(_sites[i]["dug_at"]) != 0 and site_ripe(i):
			_sites[i]["dug_at"] = 0
			_write_pile(i)
