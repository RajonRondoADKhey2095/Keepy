extends Node3D
class_name HubCat
## Carte-blanche V6 -- the detective cat of the autumn hollow, and
## HIDE-AND-SEEK in the leaf piles.
##
## =====================================================================
## THE MECHANIC, ACTION -> ANIMATION -> FEEDBACK -> REWARD
##
## The cat is HIDDEN in one of the hollow's leaf piles (the scatter's own
## instances, published -- never re-derived). The occupied pile RUSTLES
## every couple of seconds (the v5 rule: `set_instance_transform` on the
## one slot, restored exactly): that is the clue. A tap on any pile walks
## Keepy there. If the cat is in it: leaves burst, the cat springs up,
## faces him with a squeak (a scale punch), drops the HAZELNUT it was
## hoarding (an existing resource -- "il en cache partout"), then curls
## into a ball and ROLLS to another pile far from him and burrows in.
## If it is not: three leaves puff ("rien ici") and the real pile rustles
## hard right then -- the warmer/colder beat. Finds are counted in
## WorldSave (`cat_found`).
##
## NO RIDE, NO CARRIED STATE: Keepy never mounts anything, every tap stays
## a walk, so there is no body to hand back and nothing that can hold it.
## The cat's own roll is a BOUNDED straight line at constant speed to a
## fixed pile; a tap meanwhile is an ordinary walk (the pile it hides in
## next simply answers the next tap).
##
## WEATHER: rain and storm -- a cat will not sit in wet leaves: it comes
## OUT and sits curled in the open beside its pile, plainly visible (an
## easy find, and a visible reaction); snow -- it stays hidden and the
## pile does NOT rustle (a hard find); sun -- hidden, rustling.
##
## NUMBERS: model span 1.9017 on the imported vertices, lowest -0.9522
## (CritterInspect, journal V6); drawn at 0.75 x Keepy (1.0126) -- a cat.

const SCENE: PackedScene = preload("res://assets/models/keepy_cat_npc.glb")
const MODEL_SPAN: float = 1.9017
const MODEL_LOW: float = 0.9522
const DRAWN_HEIGHT: float = 0.75 * 1.3501
const SCALE: float = DRAWN_HEIGHT / MODEL_SPAN
const LIFT: float = MODEL_LOW * SCALE

## A tap this close to a candidate pile's centre means "look there".
const PILE_TAP_RADIUS: float = 1.35
## A landing this close to the pile is "there" (a walk ends ~0.4 short).
const FIND_RADIUS: float = 1.7
## The cat sitting in the open (rain) answers a tap this close.
const CAT_TAP_RADIUS: float = 1.4
## Where it sits beside its pile when out.
const OPEN_OFFSET: float = 0.95
## The rustle: period, length, tilt and swell of the occupied pile.
const RUSTLE_EVERY_S: float = 2.4
const RUSTLE_S: float = 0.55
const RUSTLE_TILT_DEG: float = 5.0
const RUSTLE_SWELL: float = 1.07
const HINT_STRENGTH: float = 2.2
## The pop: rise and time; the pause facing him; the roll.
const POP_HEIGHT: float = 0.9
const POP_TOWARD_CAMERA: float = 0.75
const POP_S: float = 0.55
const GREET_S: float = 1.1
const ROLL_SPEED: float = 6.5
const ROLL_SPIN_DPS: float = 900.0
const ROLL_SQUASH: float = 0.72
const BURROW_S: float = 0.45
## Next hiding pile: far from him, not across the map.
const FLEE_MIN_D: float = 11.0
const FLEE_MAX_D: float = 30.0
const FLEE_IDEAL_D: float = 17.0
## The roll's straight line keeps this clear of the Mother Tree's trunk.
const TRUNK_CLEAR: float = 3.4
## Piles this close to another inhabitant's rest are not candidates.
const OTHER_CLEAR: float = 2.5
const MOTHER_CLEAR: float = 6.5
const LEAVES_FOUND: int = 9
const LEAVES_MISS: int = 3
const LEAVES_BURROW: int = 6

enum State { HIDDEN, POPPING, GREETING, ROLLING, BURROWING, OPEN }

signal found(index: int)

var _critter: HubCritter = null
var _keepy: KeepyHopper = null
var _nuts: HubNuts = null
var _weather: Node = null
var _marker: Node3D = null
## Candidate piles: {"at", "xform", "multi", "slot"}.
var _piles: Array[Dictionary] = []
var _state: int = State.HIDDEN
var _site: int = -1
var _to_site: int = -1
var _t: float = 0.0
var _rustle_clock: float = 0.0
var _rustle_t: float = -1.0
var _rustle_strength: float = 1.0
var _rng := RandomNumberGenerator.new()
## For probes.
var found_total: int = 0
var misses_total: int = 0

func _ready() -> void:
	_rng.seed = 20260905
	_critter = HubCritter.new()
	_critter.name = "Critter"
	add_child(_critter)
	_critter.setup_model(SCENE, SCALE, LIFT)
	_critter.gait_stride = 0.7
	_critter.gait_bob = 0.05
	_critter.gait_roll_deg = 3.0
	_critter.visible = false
	_marker = Node3D.new()
	_marker.name = "PileMarker"
	add_child(_marker)

## `piles`: the scatter's leaf piles; `taken`: piles another inhabitant
## owns (the boar's dig sites), excluded; `others`: rests to keep clear of.
func setup(keepy: KeepyHopper, weather: Node, nuts: HubNuts, piles: Array, taken: Array, others: Array, occluders: Array = []) -> void:
	_keepy = keepy
	_weather = weather
	_nuts = nuts
	if _weather != null and _weather.has_signal("weather_changed"):
		_weather.weather_changed.connect(_on_weather_changed)
	_piles.clear()
	for pile in piles:
		var at: Vector3 = pile["at"]
		if not HubRegion.contains(at):
			continue
		var skip: bool = false
		for t in taken:
			if at.distance_to(t["at"] as Vector3) < 0.01:
				skip = true
		for o in others:
			if at.distance_to(o["position"] as Vector3) < float(o["radius"]) + OTHER_CLEAR:
				skip = true
		# Well clear of the Mother Tree: its roots flare ~3.5 u from the
		# centre, and a pile the scatter put at 3.5-4.2 u sits INSIDE them
		# (capture cap_cat_roll: the cat popped out of the roots, unseen).
		if at.distance_to(HubRegion.MOTHER_TREE_AT) < MOTHER_CLEAR:
			skip = true
		# Nothing may hide the pile from the camera, and nothing may be
		# pressed against it (the cat sits OPEN_OFFSET beside it in rain).
		if HubCritters.hidden_at(at, occluders) or HubCritters.crowded_at(at, occluders, OPEN_OFFSET * 0.6):
			skip = true
		if skip:
			continue
		_piles.append({"at": at, "xform": pile.get("xform", Transform3D.IDENTITY), "multi": pile.get("node", null), "slot": int(pile.get("index", -1))})
	if _piles.is_empty():
		push_error("HubCat: no candidate pile -- the cat has nowhere to hide")
		return
	# First hiding place: the pile nearest the road's end, so the first
	# rustle a player sees is near where they arrive.
	var best: int = 0
	var best_d: float = INF
	for i in _piles.size():
		var d: float = _piles[i]["at"].distance_to(Vector3(-5.6, 0.0, -58.4))
		if d < best_d:
			best_d = d
			best = i
	_hide_in(best)

func critter() -> HubCritter:
	return _critter

func state() -> int:
	return _state

func hidden_site() -> int:
	return _site

func piles() -> Array[Dictionary]:
	return _piles

func pile_position(index: int) -> Vector3:
	return _piles[index]["at"] if index >= 0 and index < _piles.size() else Vector3.INF

func is_out() -> bool:
	return _state == State.OPEN

## ---- the tap door -------------------------------------------------------

## The pile index a tap at `aim` means, or -1. Every candidate pile
## answers (a player may look anywhere); the cat in the open answers as
## its own pile. Nothing withdraws: there is no ride to protect.
func pile_tapped(aim: Vector3) -> int:
	var flat := Vector3(aim.x, 0.0, aim.z)
	if _state == State.OPEN and _site >= 0 and flat.distance_to(_critter.flat()) <= CAT_TAP_RADIUS:
		return _site
	var best: int = -1
	var best_d: float = PILE_TAP_RADIUS
	for i in _piles.size():
		var d: float = flat.distance_to(_piles[i]["at"])
		if d <= best_d:
			best_d = d
			best = i
	return best

## Where to walk for a look at pile `index`.
func look_point(index: int) -> Vector3:
	if _state == State.OPEN and index == _site:
		return _critter.flat()
	return pile_position(index)

## A landing at pile `index`: the find, or the miss. True when the
## landing is there (the intent is spent either way); false when not yet.
func try_find(index: int, position: Vector3) -> bool:
	if index < 0 or index >= _piles.size():
		return true
	var target: Vector3 = look_point(index)
	if Vector3(position.x, 0.0, position.z).distance_to(target) > FIND_RADIUS:
		return false
	if index == _site and (_state == State.HIDDEN or _state == State.OPEN):
		_found()
	else:
		_miss(index)
	return true

func _found() -> void:
	found_total += 1
	WorldSave.note("cat_found")
	var at: Vector3 = _piles[_site]["at"]
	_write_pile(_site, 0.0, 1.0)
	_marker.global_position = at
	if _nuts != null:
		_nuts.drop_leaves(_marker, LEAVES_FOUND, 0.5, 0.35, "leaf")
	if _state == State.HIDDEN:
		# A hand toward the camera (+z): he is standing on the pile by
		# now, and a cat that pops out exactly under him is a cat nobody
		# sees (capture cap_cat_greet3).
		_critter.global_position = at + Vector3(0.0, 0.0, POP_TOWARD_CAMERA)
	_critter.visible = true
	_critter.pose_squash = 1.0
	_critter.pose_pitch_deg = 0.0
	_critter.punch = 1.0
	_state = State.POPPING
	_t = 0.0
	found.emit(_site)

func _miss(index: int) -> void:
	misses_total += 1
	_marker.global_position = _piles[index]["at"]
	if _nuts != null:
		_nuts.drop_leaves(_marker, LEAVES_MISS, 0.4, 0.3, "leaf")
	# The real pile answers, hard: warmer / colder.
	if _state == State.HIDDEN and _weather_kind() != CozyWeather.Kind.SNOW:
		_rustle_t = 0.0
		_rustle_strength = HINT_STRENGTH

## ---- per frame ----------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	match _state:
		State.HIDDEN:
			_tick_rustle(delta)
		State.POPPING:
			var u: float = clampf(_t / POP_S, 0.0, 1.0)
			_critter.global_position = Vector3(_critter.global_position.x, POP_HEIGHT * 4.0 * u * (1.0 - u), _critter.global_position.z)
			if _keepy != null:
				_critter.face(_keepy.global_position - _critter.global_position)
			if u >= 1.0:
				_critter.global_position.y = 0.0
				_state = State.GREETING
				_t = 0.0
				if _nuts != null:
					var away: Vector3 = _critter.facing()
					_nuts.drop_at(&"hazelnut", _critter.global_position + Vector3(0.0, 0.7, 0.0), away * 1.4 + Vector3(0.0, 1.6, 0.0))
		State.GREETING:
			if _t >= GREET_S:
				_to_site = _choose_flee()
				if _to_site < 0:
					_to_site = _site
				_state = State.ROLLING
				_critter.pose_squash = ROLL_SQUASH
				_critter.speed = ROLL_SPEED
				_critter.face(_piles[_to_site]["at"] - _critter.flat())
				_critter.walk_to(_piles[_to_site]["at"])
		State.ROLLING:
			_critter.pose_pitch_deg += ROLL_SPIN_DPS * delta
			if not _critter.is_walking():
				_state = State.BURROWING
				_t = 0.0
				_marker.global_position = _piles[_to_site]["at"]
				if _nuts != null:
					_nuts.drop_leaves(_marker, LEAVES_BURROW, 0.45, 0.3, "leaf")
		State.BURROWING:
			if _t >= BURROW_S:
				_hide_in(_to_site)
		State.OPEN:
			pass
	_critter.step(delta)

func _hide_in(index: int) -> void:
	_site = index
	_to_site = -1
	_critter.pose_pitch_deg = 0.0
	_critter.pose_squash = 1.0
	_critter.halt()
	var bad: int = _weather_kind()
	if bad == CozyWeather.Kind.RAIN or bad == CozyWeather.Kind.STORM:
		_sit_out()
		return
	_state = State.HIDDEN
	_critter.visible = false
	var at: Vector3 = _piles[index]["at"]
	_critter.global_position = at
	_rustle_clock = 0.6
	_rustle_t = -1.0
	_write_pile(index, 0.0, 1.0)

## Sits in the open beside its pile, curled.
func _sit_out() -> void:
	if _site < 0:
		return
	_state = State.OPEN
	_rustle_t = -1.0
	_write_pile(_site, 0.0, 1.0)
	var at: Vector3 = _piles[_site]["at"]
	var side: Vector3 = (Vector3(0.0, 0.0, 1.0) if _keepy == null else (_keepy.global_position - at))
	side = Vector3(side.x, 0.0, side.z)
	side = side.normalized() if side.length() > 0.01 else Vector3(0.0, 0.0, 1.0)
	_critter.global_position = at + side * OPEN_OFFSET
	_critter.face(side)
	_critter.visible = true
	_critter.pose_squash = 0.82

func _choose_flee() -> int:
	var from: Vector3 = _critter.flat()
	var keepy_at: Vector3 = Vector3(_keepy.global_position.x, 0.0, _keepy.global_position.z) if _keepy != null else from
	var best: int = -1
	var best_score: float = INF
	for i in _piles.size():
		if i == _site:
			continue
		var at: Vector3 = _piles[i]["at"]
		var d_k: float = at.distance_to(keepy_at)
		if d_k < FLEE_MIN_D or d_k > FLEE_MAX_D:
			continue
		if _segment_hits_trunk(from, at):
			continue
		var score: float = absf(d_k - FLEE_IDEAL_D) + _rng.randf() * 3.0
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		return best
	# Nothing far enough: the FARTHEST other pile, trunk line permitting,
	# then regardless -- a cat that hides in the pile it just left is a
	# cat that was found for nothing (the probe's "a different pile").
	var far: int = -1
	var far_d: float = -1.0
	for pass_trunk in [true, false]:
		for i in _piles.size():
			if i == _site:
				continue
			var at: Vector3 = _piles[i]["at"]
			if pass_trunk and _segment_hits_trunk(from, at):
				continue
			var d_k: float = at.distance_to(keepy_at)
			if d_k > far_d:
				far_d = d_k
				far = i
		if far >= 0:
			return far
	return -1

func _segment_hits_trunk(a: Vector3, b: Vector3) -> bool:
	var c: Vector3 = HubRegion.MOTHER_TREE_AT
	var ab: Vector3 = b - a
	var len2: float = ab.length_squared()
	if len2 < 0.0001:
		return a.distance_to(c) < TRUNK_CLEAR
	var t: float = clampf((c - a).dot(ab) / len2, 0.0, 1.0)
	return (a + ab * t).distance_to(c) < TRUNK_CLEAR

## ---- the rustle: the clue -----------------------------------------------

func _tick_rustle(delta: float) -> void:
	if _weather_kind() == CozyWeather.Kind.SNOW:
		# A rustle caught by the snow ends at once, pile restored -- left
		# running it would hold `rustle_active()` true for the whole
		# winter (found by the probe's blind check, not by reading).
		if _rustle_t >= 0.0:
			_rustle_t = -1.0
			_write_pile(_site, 0.0, 1.0)
		return
	if _rustle_t < 0.0:
		_rustle_clock -= delta
		if _rustle_clock <= 0.0:
			_rustle_t = 0.0
			_rustle_strength = 1.0
			_rustle_clock = RUSTLE_EVERY_S + _rng.randf_range(-0.5, 0.7)
		return
	_rustle_t += delta
	var u: float = _rustle_t / RUSTLE_S
	if u >= 1.0:
		_rustle_t = -1.0
		_write_pile(_site, 0.0, 1.0)
		return
	var w: float = sin(PI * u) * _rustle_strength
	_write_pile(_site, deg_to_rad(RUSTLE_TILT_DEG) * sin(u * TAU * 2.0) * w, 1.0 + (RUSTLE_SWELL - 1.0) * w)

## Writes the pile's slot: its authored transform, tilted about world X
## by `tilt` and swollen by `swell`. Restored exactly with (0, 1).
func _write_pile(index: int, tilt: float, swell: float) -> void:
	if index < 0 or index >= _piles.size():
		return
	var pile: Dictionary = _piles[index]
	var multi: MultiMeshInstance3D = pile.get("multi", null) as MultiMeshInstance3D
	var slot: int = int(pile["slot"])
	if multi == null or multi.multimesh == null or slot < 0:
		return
	var xform: Transform3D = pile["xform"]
	if tilt != 0.0 or swell != 1.0:
		xform = Transform3D(Basis(Vector3.RIGHT, tilt) * xform.basis.scaled(Vector3.ONE * swell), xform.origin)
	multi.multimesh.set_instance_transform(slot, xform)

func rustle_active() -> bool:
	return _rustle_t >= 0.0

func _weather_kind() -> int:
	if _weather != null and _weather.has_method("kind"):
		return int(_weather.call("kind"))
	return CozyWeather.Kind.SUN

func _on_weather_changed(kind: int) -> void:
	var wet: bool = kind == CozyWeather.Kind.RAIN or kind == CozyWeather.Kind.STORM
	if wet and _state == State.HIDDEN:
		_sit_out()
	elif not wet and _state == State.OPEN:
		_hide_in(_site)
