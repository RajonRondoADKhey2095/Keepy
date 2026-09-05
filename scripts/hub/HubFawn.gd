extends Node3D
class_name HubFawn
## Carte-blanche V6 -- the fawn of the moor ("la Lande aux Moulins"), and
## THE APPROACH: the one verb this world did not have -- waiting.
##
## =====================================================================
## THE MECHANIC, ACTION -> ANIMATION -> FEEDBACK -> REWARD
##
## The fawn grazes at the edge of the western lavender field. It is
## SHY: any hop of Keepy's that LANDS within FLEE_R makes it bound away
## (a bounding gait, two leaps, region-clamped) -- so tapping it, the
## reflex every other prop rewards, is exactly what fails here, and the
## bound is the feedback that says so. What works is the opposite: stand
## still within CALM_R for CALM_S seconds and it comes to you, step by
## step, and NUZZLES (a lean, a little hop of joy) -- dropping a FLOWER
## from its neck (a new resource kind, drawn from the decor's flower_0)
## and counting a `fawn_nuzzles` in WorldSave. Then it FOLLOWS, two paces
## behind, wherever he walks on the moor, for a good minute -- or until
## he leaves the moor or gets carried by something.
##
## NO TAP CHANNEL, NO CARRIED STATE, NOTHING THAT CAN HOLD THE BODY: the
## fawn only ever moves ITSELF, and every one of its walks is a bounded,
## region-clamped trip of its own. Keepy's controls are untouched.
##
## WEATHER: rain and storm -- it shelters under the nearest olive and
## reacts to nothing there (an animal under a tree in the rain is not to
## be approached); sun -- back to grazing; snow -- it grazes, shivering.
##
## NUMBERS: model span 1.9000 on the imported vertices, lowest -0.9512
## (CritterInspect, journal V6); drawn at 1.15 x Keepy (1.5526) -- taller
## than him on its legs, slighter than the boar.

const SCENE: PackedScene = preload("res://assets/models/keepy_fawn_npc.glb")
const MODEL_SPAN: float = 1.9000
const MODEL_LOW: float = 0.9512
## V8 (karting lot 2, P2 -- Mathieu: "a la meme taille que Keepy"):
## MEASURED on the live scene before touching anything (throwaway probe,
## vertex extents through the drawn transform): Keepy is 1.350 u tall and
## 1.320 u WIDE; this animal was 1.565 x 0.649 u at 1.15 x. "Same size" is therefore not "same
## height" -- the fawn was already taller than Keepy and still read small,
## because it carries half his mass. Chosen (option D, journal V8): a
## drawn height of 1.35 x Keepy's 1.3501, the boar (1.837 u) staying the
## tallest. Every constant below that is a distance to THIS body was
## re-read and re-gated (V6CrittersProbe + captures), not just scaled.
const DRAWN_HEIGHT: float = 1.35 * 1.3501
const SCALE: float = DRAWN_HEIGHT / MODEL_SPAN
const LIFT: float = MODEL_LOW * SCALE

## Grazing spots along the EAST edge of the western lavender field
## (CozyPalette.LAVENDER_FIELDS[1]: x -30..-10, z -97..-89), between the
## lavender and the moor road (x ~ 9 at z -97): all inside HubRegion's
## moor rectangle, 15+ u off the road, 11+ u from the "ciel" dock.
const GRAZE_SPOTS: Array[Vector3] = [
	Vector3(-8.5, 0.0, -92.0), Vector3(-9.5, 0.0, -95.5), Vector3(-7.0, 0.0, -98.5),
	Vector3(-11.5, 0.0, -88.5), Vector3(-6.0, 0.0, -94.5),
]
const HOME_FACING: Vector3 = Vector3(1.0, 0.0, 0.35)
const FOOTPRINT: float = 1.0

## The heart of it: a landing this close scares; standing this close and
## this long calms.
const FLEE_R: float = 4.5
const CALM_R: float = 7.0
const CALM_S: float = 2.5
## Following ends on its own after this long: it drifts back to graze.
const FOLLOW_MAX_S: float = 75.0
## Notice: within this it lifts its head and watches him.
const NOTICE_R: float = 9.5
## The bound: two leaps of this length away from him, at this speed.
const BOUND_LEN: float = 4.0
const BOUND_SPEED: float = 7.5
const APPROACH_SPEED: float = 1.3
const FOLLOW_SPEED: float = 3.2
const FOLLOW_GAP: float = 1.9
const FOLLOW_SLACK: float = 2.4
const NUZZLE_S: float = 1.5
const NUZZLE_REACH: float = 1.1
const GRAZE_WANDER_EVERY_S: float = 11.0
const GRAZE_DIP_EVERY_S: float = 3.6
const GRAZE_DIP_S: float = 1.3
const GRAZE_DIP_DEG: float = 26.0
const SHELTER_OFFSET: float = 1.4

enum State { GRAZE, ALERT, FLEE, APPROACH, NUZZLE, FOLLOW, SHELTER }

signal nuzzled

var _critter: HubCritter = null
var _keepy: KeepyHopper = null
var _nuts: HubNuts = null
var _weather: Node = null
var _state: int = State.GRAZE
var _t: float = 0.0
var _still_s: float = 0.0
var _last_keepy: Vector3 = Vector3.INF
var _wander_in: float = 6.0
var _dip_in: float = 2.0
var _dip_t: float = -1.0
var _bounds_left: int = 0
var _shelter: Vector3 = Vector3.INF
var _rng := RandomNumberGenerator.new()
## For probes.
var flees_total: int = 0
var nuzzles_total: int = 0

func _ready() -> void:
	_rng.seed = 20260906
	_critter = HubCritter.new()
	_critter.name = "Critter"
	add_child(_critter)
	_critter.setup_model(SCENE, SCALE, LIFT)
	_critter.global_position = GRAZE_SPOTS[0]
	_critter.face(HOME_FACING)
	_critter.gait_stride = 1.0
	_critter.gait_bob = 0.05
	_critter.gait_roll_deg = 3.0
	_critter.turn_lambda = 7.0
	_critter.arrived.connect(_on_arrived)

## `trees`: the scatter's published climbable trees (the moor's olives
## among them) -- the nearest olive to the field becomes the shelter.
## The spots actually used: GRAZE_SPOTS, each nudged off anything that
## would hide or crowd it (a pale rock, an olive) -- see setup().
var _spots: Array[Vector3] = []

func setup(keepy: KeepyHopper, weather: Node, nuts: HubNuts, trees: Array, occluders: Array = []) -> void:
	_keepy = keepy
	_weather = weather
	_nuts = nuts
	_spots.clear()
	for spot in GRAZE_SPOTS:
		_spots.append(_clear_spot(spot, occluders))
	_critter.global_position = _spots[0]
	if _keepy != null:
		_keepy.hop_landed.connect(_on_keepy_landed)
	if _weather != null and _weather.has_signal("weather_changed"):
		_weather.weather_changed.connect(_on_weather_changed)
	var best_d: float = INF
	for t in trees:
		if String(t.get("glb", "")) != "olive_0":
			continue
		var at: Vector3 = t["at"]
		var d: float = at.distance_to(_spots[0])
		if d < best_d:
			best_d = d
			# Stand on the field side of the trunk, a trunk-and-a-bit out.
			var toward: Vector3 = (_spots[0] - at)
			toward = toward.normalized() if toward.length() > 0.01 else Vector3.FORWARD
			_shelter = at + toward * SHELTER_OFFSET
	if _shelter == Vector3.INF:
		# No olive published: shelter is simply the far graze spot.
		_shelter = _spots[_spots.size() - 1]

## `spot`, or the nearest of eight 1.6 u nudges of it that is clear of
## every occluder, on the moor, in the region. The constant is the
## intention; the scatter decides the last metre.
func _clear_spot(spot: Vector3, occluders: Array) -> Vector3:
	for ring in [0.0, 1.6, 3.2]:
		for k in 8:
			if ring == 0.0 and k > 0:
				break
			var a: float = TAU * float(k) / 8.0
			var p: Vector3 = spot + Vector3(cos(a) * ring, 0.0, sin(a) * ring)
			if not HubRegion.contains(p) or not HubRegion.in_moor(p):
				continue
			if HubCritters.hidden_at(p, occluders) or HubCritters.crowded_at(p, occluders, FOOTPRINT):
				continue
			return p
	return spot

func spots() -> Array[Vector3]:
	return _spots

static func footprints() -> Array:
	var out: Array = []
	for spot in GRAZE_SPOTS:
		out.append({"position": spot, "radius": FOOTPRINT})
	return out

func critter() -> HubCritter:
	return _critter

func state() -> int:
	return _state

func position_flat() -> Vector3:
	return _critter.flat()

func shelter_point() -> Vector3:
	return _shelter

func still_seconds() -> float:
	return _still_s

## ---- what Keepy does, as seen from here ---------------------------------

func _keepy_flat() -> Vector3:
	return Vector3(_keepy.global_position.x, 0.0, _keepy.global_position.z) if _keepy != null else Vector3.INF

func _keepy_free() -> bool:
	if _keepy == null:
		return false
	return not (_keepy.is_riding() or _keepy.is_on_carrier() or _keepy.is_on_zipline() or _keepy.is_on_tree() \
		or _keepy.is_on_owl_flight() or _keepy.is_on_board() or _keepy.is_on_turnstile() or _keepy.is_on_seesaw())

func _keepy_on_moor() -> bool:
	return _keepy != null and HubRegion.in_moor(_keepy_flat())

func _on_keepy_landed(position: Vector3) -> void:
	var d: float = Vector3(position.x, 0.0, position.z).distance_to(_critter.flat())
	match _state:
		State.GRAZE, State.ALERT, State.APPROACH:
			if d <= FLEE_R:
				_flee()
		State.FOLLOW:
			# NOT a scare. The first version fled from a landing within
			# SCARE_R, and the probe's own walk-away -- straight through the
			# fawn standing a pace behind him -- fled it at once. A companion
			# is walked through all the time; it steps aside instead (the
			# FOLLOW branch re-aims its goal every frame).
			pass
		_:
			pass

func _flee() -> void:
	flees_total += 1
	_state = State.FLEE
	_bounds_left = 2
	_dip_t = -1.0
	_critter.pose_pitch_deg = 0.0
	_critter.speed = BOUND_SPEED
	_critter.gait_stride = 2.6
	_critter.gait_bob = 0.42
	_critter.gait_pitch_deg = 9.0
	_bound()

## One leap directly away from him, region-clamped, and never off the
## moor: a fawn that fled through the corridor would be lost to the map.
func _bound() -> void:
	var here: Vector3 = _critter.flat()
	var away: Vector3 = here - _keepy_flat()
	away = Vector3(away.x, 0.0, away.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var target: Vector3 = here + away * BOUND_LEN
	if not HubRegion.contains(target) or not HubRegion.in_moor(target):
		# Slide along whichever side keeps it on the moor.
		var side := Vector3(-away.z, 0.0, away.x)
		for candidate in [here + side * BOUND_LEN, here - side * BOUND_LEN, here + away * 1.5]:
			if HubRegion.contains(candidate) and HubRegion.in_moor(candidate):
				target = candidate
				break
		if not HubRegion.contains(target) or not HubRegion.in_moor(target):
			target = HubRegion.clamp_to(here)
	_critter.walk_to(target)

func _graze_gait() -> void:
	_critter.gait_stride = 1.0
	_critter.gait_bob = 0.05
	_critter.gait_pitch_deg = 2.5
	_critter.pose_pitch_deg = 0.0

func _on_arrived() -> void:
	match _state:
		State.FLEE:
			_bounds_left -= 1
			if _bounds_left > 0:
				_bound()
			else:
				_graze_gait()
				_state = State.GRAZE
				_wander_in = GRAZE_WANDER_EVERY_S
				_still_s = 0.0
		State.APPROACH:
			_begin_nuzzle()
		State.SHELTER:
			_critter.turn_to(_spots[0] - _critter.flat())
		_:
			pass

func _begin_nuzzle() -> void:
	_state = State.NUZZLE
	_t = 0.0
	_graze_gait()
	_critter.face(_keepy_flat() - _critter.flat())

func _nearest_spot_index(where: Vector3) -> int:
	var best: int = 0
	var best_d: float = INF
	for i in _spots.size():
		var d: float = _spots[i].distance_to(where)
		if d < best_d:
			best_d = d
			best = i
	return best

## ---- per frame ----------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	var kind: int = _weather_kind()
	_critter.shiver = 1.0 if (kind == CozyWeather.Kind.SNOW and (_state == State.GRAZE or _state == State.ALERT)) else 0.0
	# How long he has stood still, measured here from his live position:
	# the fawn has no other way to know, and "still" is the whole verb.
	var kf: Vector3 = _keepy_flat()
	if _keepy != null and not _keepy.is_hopping() and _keepy_free() and _last_keepy != Vector3.INF and kf.distance_to(_last_keepy) < 0.01:
		_still_s += delta
	else:
		_still_s = 0.0
	_last_keepy = kf
	var d: float = kf.distance_to(_critter.flat()) if kf != Vector3.INF else INF
	match _state:
		State.GRAZE:
			_tick_graze(delta)
			if d <= NOTICE_R and _keepy_free():
				_state = State.ALERT
				_dip_t = -1.0
				_critter.pose_pitch_deg = 0.0
		State.ALERT:
			if d > NOTICE_R or not _keepy_free():
				_state = State.GRAZE
			else:
				if not _critter.is_walking():
					_critter.turn_to(kf - _critter.flat())
				if d <= CALM_R and _still_s >= CALM_S:
					_state = State.APPROACH
					_critter.speed = APPROACH_SPEED
					_critter.walk_to(_approach_point())
		State.APPROACH:
			if d > CALM_R + 1.5 or not _keepy_free():
				_critter.halt()
				_state = State.ALERT
			elif _critter.is_walking():
				# He is a moving target only if he moves; re-aim cheaply.
				var goal: Vector3 = _approach_point()
				if goal.distance_to(_critter.target()) > 0.3:
					_critter.walk_to(goal)
		State.NUZZLE:
			var u: float = clampf(_t / NUZZLE_S, 0.0, 1.0)
			_critter.pose_pitch_deg = 16.0 * sin(PI * u)
			if _t >= NUZZLE_S * 0.5 and nuzzles_total == 0 or (_t >= NUZZLE_S * 0.5 and _t - delta < NUZZLE_S * 0.5):
				pass
			if u >= 1.0:
				_finish_nuzzle()
		State.FOLLOW:
			if not _keepy_free() or not _keepy_on_moor() or _t >= FOLLOW_MAX_S:
				_go_graze()
			else:
				var gap: float = d
				if gap > FOLLOW_SLACK and not _critter.is_walking():
					_critter.speed = FOLLOW_SPEED
					var dir: Vector3 = (_critter.flat() - kf)
					dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
					var goal: Vector3 = kf + dir * FOLLOW_GAP
					if not HubRegion.contains(goal):
						goal = HubRegion.clamp_to(goal)
					_critter.walk_to(goal)
				elif _critter.is_walking() and gap > FOLLOW_SLACK:
					var dir2: Vector3 = (_critter.flat() - kf)
					dir2 = dir2.normalized() if dir2.length() > 0.01 else Vector3.FORWARD
					var goal2: Vector3 = kf + dir2 * FOLLOW_GAP
					if goal2.distance_to(_critter.target()) > 0.5:
						_critter.walk_to(HubRegion.clamp_to(goal2))
				elif not _critter.is_walking():
					_critter.turn_to(kf - _critter.flat())
		State.SHELTER, State.FLEE:
			pass
	_critter.step(delta)

func _approach_point() -> Vector3:
	var kf: Vector3 = _keepy_flat()
	var dir: Vector3 = (_critter.flat() - kf)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	return kf + dir * NUZZLE_REACH

func _tick_graze(delta: float) -> void:
	# The head dips to the grass every few seconds; the body drifts to
	# another spot every so often. Both are the animal being alive.
	if _dip_t >= 0.0:
		_dip_t += delta
		var u: float = clampf(_dip_t / GRAZE_DIP_S, 0.0, 1.0)
		_critter.pose_pitch_deg = GRAZE_DIP_DEG * sin(PI * u)
		if u >= 1.0:
			_dip_t = -1.0
			_dip_in = GRAZE_DIP_EVERY_S + _rng.randf_range(-1.0, 1.5)
	elif not _critter.is_walking():
		_dip_in -= delta
		if _dip_in <= 0.0:
			_dip_t = 0.0
	_wander_in -= delta
	if _wander_in <= 0.0 and not _critter.is_walking() and _dip_t < 0.0:
		_wander_in = GRAZE_WANDER_EVERY_S + _rng.randf_range(-3.0, 4.0)
		var next: int = _rng.randi_range(0, _spots.size() - 1)
		_critter.speed = APPROACH_SPEED
		_critter.walk_to(_spots[next])

func _finish_nuzzle() -> void:
	nuzzles_total += 1
	WorldSave.note("fawn_nuzzles")
	_critter.punch = 1.0
	_critter.pose_pitch_deg = 0.0
	if _nuts != null:
		var side: Vector3 = _critter.facing().rotated(Vector3.UP, 0.9)
		_nuts.drop_at(&"flower", _critter.global_position + Vector3(0.0, 1.05, 0.0), side * 1.1 + Vector3(0.0, 1.8, 0.0))
	nuzzled.emit()
	_state = State.FOLLOW
	_t = 0.0
	_still_s = 0.0

func _go_graze() -> void:
	_state = State.GRAZE
	_graze_gait()
	_critter.speed = APPROACH_SPEED
	_critter.walk_to(_spots[_nearest_spot_index(_critter.flat())])
	_wander_in = GRAZE_WANDER_EVERY_S

func _weather_kind() -> int:
	if _weather != null and _weather.has_method("kind"):
		return int(_weather.call("kind"))
	return CozyWeather.Kind.SUN

func _on_weather_changed(kind: int) -> void:
	var wet: bool = kind == CozyWeather.Kind.RAIN or kind == CozyWeather.Kind.STORM
	if wet and _state != State.SHELTER and _state != State.NUZZLE:
		_state = State.SHELTER
		_graze_gait()
		_dip_t = -1.0
		_critter.speed = FOLLOW_SPEED
		_critter.walk_to(_shelter)
	elif not wet and _state == State.SHELTER:
		_go_graze()
