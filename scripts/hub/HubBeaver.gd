extends Node3D
class_name HubBeaver
## Carte-blanche V6 -- the beaver ranger of the moor, and THE TRADE: the
## first thing in this world that SPENDS a resource.
##
## =====================================================================
## THE MECHANIC, ACTION -> ANIMATION -> FEEDBACK -> REWARD
##
## The ranger keeps his station at the foot of the tree-house (the
## "hedgehog" GLB of journal V6, a tree with a hut in its trunk -- a
## ranger's post if there ever was one), beside the moor road. He wants
## one of each thing the other three inhabitants give: a TRUFFLE (the
## boar), a HAZELNUT (the cat's hoard, or any tree) and a FLOWER (the
## fawn). Tap him -> Keepy walks over -> if he holds all three, they fly
## from him to the ranger one by one (HubNuts.fly_between), the ranger
## salutes (a punch, a bow) and a GOLDEN ACORN drops from his pack -- the
## rare kind, otherwise paced by the 12th/19th shake (v5). If Keepy is
## short, the ranger shakes his head, and the resource counter WAKES so
## the player sees what he holds. Trades are counted (`beaver_trades`).
##
## So the loop closes: boar -> truffle, cat -> hazelnut, fawn -> flower,
## ranger -> gold. Three zones, one reason to visit all three.
##
## NO RIDE, NO CARRIED STATE: a tap is a walk, the exchange is a timer, and
## every tap during it is an ordinary walk that the exchange ignores (it
## is BOUNDED -- three flights and a bow -- and never holds the body).
##
## WEATHER: rain and storm -- he steps under the hut's porch (a point
## against the trunk, out of the drip line) and still trades; snow -- he
## stamps his feet (shiver).

const SCENE: PackedScene = preload("res://assets/models/keepy_beaver_npc.glb")
const HOUSE_SCENE: PackedScene = preload("res://assets/models/keepy_treehouse_prop.glb")
const MODEL_SPAN: float = 1.9024
const MODEL_LOW: float = 0.9527
## V8 (karting lot 2, P2 -- Mathieu: "a la meme taille que Keepy"):
## MEASURED on the live scene before touching anything (throwaway probe,
## vertex extents through the drawn transform): Keepy is 1.350 u tall and
## 1.320 u WIDE; this animal was 1.156 x 0.845 u at 0.85 x. "Same size" is therefore not "same
## height" -- the fawn was already taller than Keepy and still read small,
## because it carries half his mass. Chosen (option D, journal V8): a
## drawn height of 1.20 x Keepy's 1.3501, the boar (1.837 u) staying the
## tallest. Every constant below that is a distance to THIS body was
## re-read and re-gated (V6CrittersProbe + captures), not just scaled.
const DRAWN_HEIGHT: float = 1.20 * 1.3501
const SCALE: float = DRAWN_HEIGHT / MODEL_SPAN
const LIFT: float = MODEL_LOW * SCALE
## The tree-house: 1.8929 x 1.5901 x 1.5461 on the imported vertices,
## lowest -0.8004. Drawn 2.6x: 4.9 u wide, 4.1 u tall -- a landmark of the
## moor, under the balloon's cruise height (4.0 + basket) by a hand.
const HOUSE_SPAN_Y: float = 1.5901
const HOUSE_LOW: float = 0.8004
const HOUSE_SCALE: float = 2.6
const HOUSE_LIFT: float = HOUSE_LOW * HOUSE_SCALE
const HOUSE_FOOTPRINT: float = 2.6

## Where the station stands: east of the moor road (x ~ 12.5 at z -92),
## north of the eastern lavender field (z > -98), inside the moor
## rectangle. The house behind (further from the camera, -z), the ranger
## in front of its door, facing the road.
const HOUSE_AT: Vector3 = Vector3(21.5, 0.0, -93.5)
const REST: Vector3 = Vector3(20.0, 0.0, -90.2)
const REST_FACING: Vector3 = Vector3(-0.7, 0.0, 0.7)
const PORCH: Vector3 = Vector3(21.5, 0.0, -91.4)
const FOOTPRINT: float = 1.1
const TAP_RADIUS: float = 2.0
const NEAR: float = 1.25

## What a trade costs and pays.
const PRICE: Dictionary = {&"truffle": 1, &"hazelnut": 1, &"flower": 1}
const PAYS: StringName = &"golden"
const FLY_EVERY_S: float = 0.45
const BOW_S: float = 0.9
const REFUSE_S: float = 0.8

enum Phase { FREE, TAKING, PAYING, REFUSING }

signal traded

var _critter: HubCritter = null
var _house: Node3D = null
var _keepy: KeepyHopper = null
var _nuts: HubNuts = null
var _weather: Node = null
var _hud: Node = null
var _phase: int = Phase.FREE
var _t: float = 0.0
var _flights_left: Array = []
var _next_flight: float = 0.0
var trades_total: int = 0
var refusals_total: int = 0

func _ready() -> void:
	_critter = HubCritter.new()
	_critter.name = "Critter"
	add_child(_critter)
	_critter.setup_model(SCENE, SCALE, LIFT)
	_critter.global_position = REST
	_critter.face(REST_FACING)
	_critter.gait_stride = 0.8
	_critter.gait_bob = 0.05
	_critter.gait_roll_deg = 4.0
	_house = HOUSE_SCENE.instantiate() as Node3D
	if _house != null:
		_house.name = "TreeHouse"
		_house.scale = Vector3.ONE * HOUSE_SCALE
		_house.position = HOUSE_AT + Vector3(0.0, HOUSE_LIFT, 0.0)
		# Door toward the road (the model's door faces +Z at yaw zero).
		_house.rotation.y = atan2(-0.55, 0.85)
		add_child(_house)
		for mi in _meshes(_house):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = HubCritter.CULL_DISTANCE + 20.0
			mi.visibility_range_end_margin = 4.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out

func setup(keepy: KeepyHopper, weather: Node, nuts: HubNuts, hud: Node) -> void:
	_keepy = keepy
	_weather = weather
	_nuts = nuts
	_hud = hud
	if _weather != null and _weather.has_signal("weather_changed"):
		_weather.weather_changed.connect(_on_weather_changed)

static func footprints() -> Array:
	return [{"position": REST, "radius": FOOTPRINT}, {"position": HOUSE_AT, "radius": HOUSE_FOOTPRINT}]

func critter() -> HubCritter:
	return _critter

func house() -> Node3D:
	return _house

func phase() -> int:
	return _phase

func position_flat() -> Vector3:
	return _critter.flat()

## V8 P2: where Keepy WALKS for a trade -- a hand (NEAR) short of the
## ranger on Keepy's own side, never his feet. The V6 walk targeted the
## feet themselves (a landing ends ~0.4 u short, which a 1.16 u ranger
## hid behind Keepy already; at 1.62 u the capture p2_beaver showed the
## ranger drawn INSIDE him). try_trade's TAP_RADIUS (2.0) still accepts
## the landing.
func approach_point(from: Vector3) -> Vector3:
	var feet: Vector3 = _critter.flat()
	var dir: Vector3 = Vector3(from.x - feet.x, 0.0, from.z - feet.z)
	if dir.length() < 0.05:
		dir = -REST_FACING
	return feet + dir.normalized() * NEAR

## True when Keepy holds the whole price.
static func can_pay() -> bool:
	for kind in PRICE:
		if WorldSave.resource(kind) < int(PRICE[kind]):
			return false
	return true

## ---- the tap door -------------------------------------------------------

## On him, and he is free. Withdrawn for the length of an exchange.
func accepts_tap(aim: Vector3) -> bool:
	if _phase != Phase.FREE:
		return false
	return Vector3(aim.x, 0.0, aim.z).distance_to(_critter.flat()) <= TAP_RADIUS

## A landing beside him: the trade, or the refusal. True when the landing
## is there (intent spent); false when not yet.
func try_trade(position: Vector3) -> bool:
	if _phase != Phase.FREE:
		return true
	if Vector3(position.x, 0.0, position.z).distance_to(_critter.flat()) > TAP_RADIUS:
		return false
	_critter.halt()
	_critter.turn_to(_keepy.global_position - _critter.global_position)
	if not can_pay():
		refusals_total += 1
		_phase = Phase.REFUSING
		_t = 0.0
		if _hud != null and _hud.has_method("wake"):
			_hud.call("wake")
		return true
	for kind in PRICE:
		WorldSave.add_resource(kind, -int(PRICE[kind]))
	_phase = Phase.TAKING
	_t = 0.0
	_flights_left = PRICE.keys()
	_next_flight = 0.0
	return true

## ---- per frame ----------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_critter.shiver = 1.0 if (_weather != null and _weather.has_method("kind") and _weather.call("kind") == CozyWeather.Kind.SNOW and _phase == Phase.FREE) else 0.0
	match _phase:
		Phase.TAKING:
			_next_flight -= delta
			if _next_flight <= 0.0 and not _flights_left.is_empty():
				var kind: StringName = _flights_left.pop_front()
				if _nuts != null and _keepy != null:
					_nuts.fly_between(kind, _keepy.global_position + Vector3(0.0, 0.9, 0.0), _critter.global_position + Vector3(0.0, 1.1, 0.0))
				_critter.punch = 0.6
				_next_flight = FLY_EVERY_S
			if _flights_left.is_empty() and _next_flight <= 0.0:
				_phase = Phase.PAYING
				_t = 0.0
		Phase.PAYING:
			# The bow: a lean over BOW_S, and the pay at its deepest.
			var u: float = clampf(_t / BOW_S, 0.0, 1.0)
			_critter.pose_pitch_deg = 22.0 * sin(PI * u)
			if _t >= BOW_S * 0.5 and _t - delta < BOW_S * 0.5:
				trades_total += 1
				WorldSave.note("beaver_trades")
				_critter.punch = 1.0
				if _nuts != null:
					var toward: Vector3 = _critter.facing()
					_nuts.drop_at(PAYS, _critter.global_position + Vector3(0.0, 1.4, 0.0) - toward * 0.2, toward * 1.3 + Vector3(0.0, 2.0, 0.0))
				traded.emit()
			if u >= 1.0:
				_critter.pose_pitch_deg = 0.0
				_phase = Phase.FREE
		Phase.REFUSING:
			# A shake of the head: yaw wags for REFUSE_S.
			var u: float = clampf(_t / REFUSE_S, 0.0, 1.0)
			_critter.model().rotation.y = deg_to_rad(18.0) * sin(u * TAU * 2.0) * (1.0 - u)
			if u >= 1.0:
				_critter.model().rotation.y = 0.0
				_phase = Phase.FREE
		_:
			pass
	_critter.step(delta)

## NOT gated on "is he walking": a sky that turns while he is still on
## his way to the porch must still send him home when it clears (the
## probe caught a ranger left under the porch in the sun -- the SUN
## change had arrived one stride before he got there and was dropped).
## Both walks are bounded, fixed-target trips; re-aiming one is harmless.
func _on_weather_changed(kind: int) -> void:
	if _phase != Phase.FREE:
		return
	var wet: bool = kind == CozyWeather.Kind.RAIN or kind == CozyWeather.Kind.STORM
	var here: Vector3 = _critter.flat()
	_critter.speed = 1.6
	if wet and here.distance_to(PORCH) > NEAR * 0.5:
		_critter.walk_to(PORCH)
	elif not wet and here.distance_to(REST) > NEAR * 0.5:
		_critter.walk_to(REST)
