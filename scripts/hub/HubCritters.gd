extends Node3D
class_name HubCritters
## Carte-blanche V6 -- the coordinator of the new inhabitants. HubWorld
## talks to THIS node only (setup, one tap channel, one landing hook, one
## intent reset); each animal is its own module under it, on the shape
## HubTransport and HubTrees already have.
##
## Intents live here on the boat's model: set by the tap, tried on every
## landing AND immediately (a zero-length walk emits no landing), cleared
## by any other tap and when the chain runs out.

var boar: HubBoar = null
var cat: HubCat = null
var fawn: HubFawn = null
var beaver: HubBeaver = null
var _keepy: KeepyHopper = null
var _intent: StringName = &""
var _intent_index: int = -1
var _tick: float = 0.0

func _ready() -> void:
	boar = HubBoar.new()
	boar.name = "Boar"
	add_child(boar)
	cat = HubCat.new()
	cat.name = "Cat"
	add_child(cat)
	fawn = HubFawn.new()
	fawn.name = "Fawn"
	add_child(fawn)
	beaver = HubBeaver.new()
	beaver.name = "Beaver"
	add_child(beaver)

func setup(keepy: KeepyHopper, weather: Node, nuts: HubNuts, scatter: Node, blocked: Array, hud: Node = null) -> void:
	_keepy = keepy
	var piles: Array = []
	if scatter != null and scatter.has_method("instances"):
		piles = scatter.call("instances", "leafpile")
	var discs: Array = blocked.duplicate()
	discs.append_array(HubTrees.footprints())
	discs.append_array(HubTransport.footprints())
	var trees: Array = []
	if scatter != null and scatter.has_method("climb_trees"):
		trees = scatter.call("climb_trees")
	# WHAT HIDES A SMALL THING FROM THIS CAMERA. A pile under a giant
	# mushroom's cap or an autumn crown is invisible from 40 deg above
	# (captures cap_cat_pop / cap_cat_greet: the cat sprang out under a
	# bigshroom cap and was never seen). Radii are crown / cap reach, not
	# ground footprints -- this is an IMAGE question, not a clearance one.
	var occluders: Array = _occluders(scatter, trees)
	boar.setup(keepy, weather, nuts, piles, discs, occluders)
	# The cat hides in the piles the boar does NOT dig, clear of every rest
	# and of everything that would hide it.
	cat.setup(keepy, weather, nuts, piles, boar.sites(), HubCritters.footprints(), occluders)
	fawn.setup(keepy, weather, nuts, trees, occluders)
	beaver.setup(keepy, weather, nuts, hud)

## What each family puts between the camera and the ground behind it:
## a horizontal reach `r` and a vertical band [h0, h1] (units at scale 1).
const OCCLUDER_SHAPE: Dictionary = {
	"bigshroom": [1.3, 1.4, 2.4], "autumn_tree": [1.7, 1.5, 3.9], "olive": [1.3, 1.3, 2.5],
	"log": [0.8, 0.0, 0.6], "pumpkin": [0.7, 0.0, 0.7], "palerock": [0.9, 0.0, 0.9],
}
## tan(90 - 40 deg): the hub camera looks down at 40 deg, so a thing at
## height h hides the ground 1.19 h behind it (toward -z).
const HIDE_RUN_PER_HEIGHT: float = 1.19

func _occluders(scatter: Node, trees: Array) -> Array:
	var out: Array = []
	if scatter == null or not scatter.has_method("instances"):
		return out
	for family in ["bigshroom", "log", "pumpkin", "palerock"]:
		for inst in scatter.call("instances", family):
			var sc: float = maxf(float((inst["xform"] as Transform3D).basis.get_scale().x), 0.5)
			var shape: Array = OCCLUDER_SHAPE[family]
			out.append({"position": inst["at"], "r": float(shape[0]) * sc, "h0": float(shape[1]) * sc, "h1": float(shape[2]) * sc})
	for t in trees:
		var glb: String = String(t.get("glb", ""))
		var shape: Array = OCCLUDER_SHAPE["olive" if glb.begins_with("olive") else "autumn_tree"]
		var sc: float = maxf(float((t["xform"] as Transform3D).basis.get_scale().x), 0.5)
		out.append({"position": t["at"], "r": float(shape[0]) * sc, "h0": float(shape[1]) * sc, "h1": float(shape[2]) * sc})
	return out

## True when ground point `p` is hidden from the hub camera by one of
## `occluders`: the occluder is within `r` sideways and `p` lies in the
## band its body shadows toward -z. An IMAGE test, not a clearance one --
## a pile a metre SOUTH of a mushroom is in plain view.
static func hidden_at(p: Vector3, occluders: Array) -> bool:
	for o in occluders:
		var c: Vector3 = o["position"]
		if absf(p.x - c.x) > float(o["r"]):
			continue
		var near_z: float = c.z + float(o["r"]) - HIDE_RUN_PER_HEIGHT * float(o["h0"])
		var far_z: float = c.z - float(o["r"]) - HIDE_RUN_PER_HEIGHT * float(o["h1"])
		if p.z <= near_z and p.z >= far_z:
			return true
	return false

## True when `p` is within `margin` of an occluder's body on the ground.
static func crowded_at(p: Vector3, occluders: Array, margin: float) -> bool:
	for o in occluders:
		if p.distance_to(o["position"] as Vector3) < float(o["r"]) + margin:
			return true
	return false

## Every animal's ground discs, for the scatter and the exit searches.
static func footprints() -> Array:
	var out: Array = []
	out.append_array(HubBoar.footprints())
	out.append_array(HubFawn.footprints())
	out.append_array(HubBeaver.footprints())
	return out

## What a tap at `aim` (unclamped) means -- {"kind", "index"} -- or {}.
## Each module withdraws on its own terms for the length of its ride; the
## boar is asked first (a body over a pile beats the pile).
func accepts_tap(aim: Vector3) -> Dictionary:
	if boar != null and boar.accepts_tap(aim):
		return {"kind": &"boar", "index": 0}
	if beaver != null and beaver.accepts_tap(aim):
		return {"kind": &"beaver", "index": 0}
	if cat != null:
		var pile: int = cat.pile_tapped(aim)
		if pile >= 0:
			return {"kind": &"catpile", "index": pile}
	return {}

## A tap on `kind`: arms the intent and returns WHERE to walk (the
## animal's own feet, not the tap), so HubWorld can route the walk through
## the corridor gates like any other cross-zone target. The caller tries
## the zero-length walk on the spot.
func arm(kind: StringName, index: int, destination: Vector3) -> Vector3:
	_intent = kind
	_intent_index = index
	if kind == &"boar":
		boar.on_tapped()
		return boar.position_flat()
	if kind == &"catpile":
		return cat.look_point(index)
	if kind == &"beaver":
		return beaver.position_flat()
	return destination

## A landing: the armed intent gets its try. True when the landing was
## consumed by a mount (the caller stops looking at it).
func on_landing(position: Vector3) -> bool:
	if _intent == &"":
		return false
	if _intent == &"boar":
		if boar.try_mount(position):
			_intent = &""
			return _keepy.is_on_carrier()
		return false
	if _intent == &"catpile":
		# A look is not a mount: the landing is never consumed, only the
		# intent is spent once he is there.
		if cat.try_find(_intent_index, position):
			_intent = &""
		return false
	if _intent == &"beaver":
		if beaver.try_trade(position):
			_intent = &""
		return false
	_intent = &""
	return false

func cancel_intents() -> void:
	_intent = &""
	_intent_index = -1

func intent() -> StringName:
	return _intent

func intent_index() -> int:
	return _intent_index

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		boar.refresh_piles()
