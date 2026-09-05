extends Node3D
class_name HubNuts
## Carte-blanche v4 P2 -- the nuts: shaken out of a wreath, falling,
## bouncing, rolling to a rest, picked up by walking over them.
##
## NO PHYSICS ENGINE. The plateau has no bodies and no colliders (taps
## resolve against a maths plane), and adding a physics world for a
## handful of acorns would be a second simulation nobody else uses. Each
## nut is a tiny integrator here: gravity, a ground plane at y = 0 with
## two damped bounces, a roll that decays exponentially, then REST. Rest
## is the only state the save knows: a nut in the air on a reload is
## simply not there, and the tree's stock -- which is what the player
## earned -- is what persists (WorldSave).
##
## PICKUP is proximity on the ground, every frame, against Keepy's feet:
## a hop that lands near a nut or passes over it collects it. The reward
## beat is the nut's own flight to his chest (a short tween, shrinking),
## THEN the counter (WorldSave -> WorldHud punch). One nut, one beat.

const ACORN_GLB: String = "acorn_0"
const HAZELNUT_GLB: String = "hazelnut_0"
const GRAVITY: float = 8.6
const BOUNCE: float = 0.34
const BOUNCE_MIN_VY: float = 0.9
const ROLL_DAMP: float = 2.6
const REST_SPEED: float = 0.12
## Resting pose: an acorn lies on its side (its body radius under the
## origin), a hazelnut stands.
const ACORN_LIE_Y: float = 0.11
const PICK_RADIUS: float = 0.85
const PICK_FEET_MAX_Y: float = 0.45
const FLY_S: float = 0.28
const FLY_HEIGHT: float = 0.95
## Where a nut leaves the wreath, in the tree's local space: under the
## lobes, a little out from the ring so it clears the pad on the way down.
const DROP_RING_R: float = 1.05
const DROP_Y: float = 3.05

var _nuts: Array[Dictionary] = []
var _keepy: Node3D = null
var _acorn: Mesh = null
var _hazelnut: Mesh = null
var _material: Material = null
var _rest_dirty: bool = false

## For probes: totals since boot.
var dropped_total: int = 0
var picked_total: int = 0

func _ready() -> void:
	_acorn = CozyPalette.glb_mesh(CozyPalette.decor_path(ACORN_GLB))
	_hazelnut = CozyPalette.glb_mesh(CozyPalette.decor_path(HAZELNUT_GLB))
	if _acorn == null or _hazelnut == null:
		push_error("HubNuts: acorn_0.glb / hazelnut_0.glb missing")
	_material = CozyPalette.decor_material()

func setup(keepy: Node3D) -> void:
	_keepy = keepy
	# The nuts left lying around last time.
	for item in WorldSave.ground_nuts():
		var nut: Dictionary = _spawn(StringName(item[2]), Vector3(item[0], 0.0, item[1]), Vector3.ZERO)
		_settle(nut)
	WorldSave.reset_done.connect(_on_reset)

func _on_reset() -> void:
	for nut in _nuts:
		nut["node"].queue_free()
	_nuts.clear()

func mesh_for(kind: StringName) -> Mesh:
	return _hazelnut if kind == &"hazelnut" else _acorn

func _spawn(kind: StringName, at: Vector3, velocity: Vector3) -> Dictionary:
	var node := MeshInstance3D.new()
	node.mesh = mesh_for(kind)
	node.material_override = _material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	add_child(node)
	var nut := {"node": node, "kind": kind, "pos": at, "vel": velocity, "bounces": 0,
		"resting": false, "spin": Vector3(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0), randf_range(-4.0, 4.0)),
		"flying": false, "yaw": randf() * TAU}
	_nuts.append(nut)
	return nut

## Shakes `count` nuts of `kinds` out of `tree` (a Node3D whose local
## frame is the family's), at a random point of the wreath, thrown a
## little outward so they clear the trunk and land where he can walk.
func drop_from_tree(tree: Node3D, kinds: Array) -> void:
	for kind in kinds:
		var a: float = randf() * TAU
		var r: float = DROP_RING_R * randf_range(0.9, 1.15)
		var local := Vector3(cos(a) * r, DROP_Y + randf_range(-0.15, 0.15), sin(a) * r)
		var world: Vector3 = tree.to_global(local)
		var out := Vector3(world.x - tree.global_position.x, 0.0, world.z - tree.global_position.z).normalized()
		var vel: Vector3 = out * randf_range(0.9, 1.7) + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 0.9), randf_range(-0.4, 0.4))
		_spawn(StringName(kind), world, vel)
		dropped_total += 1

func _settle(nut: Dictionary) -> void:
	nut["resting"] = true
	nut["vel"] = Vector3.ZERO
	var node: Node3D = nut["node"]
	var p: Vector3 = nut["pos"]
	if nut["kind"] == &"acorn":
		p.y = ACORN_LIE_Y
		node.rotation = Vector3(0.0, nut["yaw"], PI * 0.5)
	else:
		p.y = 0.0
		node.rotation = Vector3(deg_to_rad(randf_range(-14.0, 14.0)), nut["yaw"], deg_to_rad(randf_range(-14.0, 14.0)))
	nut["pos"] = p
	node.position = p
	_rest_dirty = true

func resting_count() -> int:
	var n: int = 0
	for nut in _nuts:
		if nut["resting"] and not nut["flying"]:
			n += 1
	return n

func airborne_count() -> int:
	var n: int = 0
	for nut in _nuts:
		if not nut["resting"]:
			n += 1
	return n

func _process(delta: float) -> void:
	var feet: Vector3 = _keepy.global_position if _keepy != null else Vector3.INF
	var can_pick: bool = _keepy != null and feet.y <= PICK_FEET_MAX_Y and not _keepy.call("is_on_tree") \
		and not _keepy.call("is_on_carrier") and not _keepy.call("is_riding") and not _keepy.call("is_on_zipline")
	for nut in _nuts:
		if nut["flying"]:
			continue
		var node: Node3D = nut["node"]
		if not nut["resting"]:
			var vel: Vector3 = nut["vel"]
			var pos: Vector3 = nut["pos"]
			vel.y -= GRAVITY * delta
			pos += vel * delta
			if pos.y <= 0.0:
				pos.y = 0.0
				if vel.y < -BOUNCE_MIN_VY and nut["bounces"] < 2:
					vel.y = -vel.y * BOUNCE
					vel.x *= 0.7
					vel.z *= 0.7
					nut["bounces"] += 1
				else:
					# Rolling: the horizontal velocity decays, no more air.
					vel.y = 0.0
					var damp: float = exp(-ROLL_DAMP * delta)
					vel.x *= damp
					vel.z *= damp
					if Vector2(vel.x, vel.z).length() < REST_SPEED:
						nut["pos"] = pos
						_settle(nut)
						continue
			nut["vel"] = vel
			nut["pos"] = pos
			node.position = pos
			node.rotation += nut["spin"] * delta
			continue
		if can_pick and Vector2(feet.x - nut["pos"].x, feet.z - nut["pos"].z).length() <= PICK_RADIUS:
			_pick(nut)
	if _rest_dirty:
		_rest_dirty = false
		_save_resting()

func _pick(nut: Dictionary) -> void:
	nut["flying"] = true
	nut["resting"] = false
	_rest_dirty = true
	picked_total += 1
	var node: Node3D = nut["node"]
	var kind: StringName = nut["kind"]
	var tween := create_tween()
	tween.set_parallel(true)
	var chest: Vector3 = _keepy.global_position + Vector3(0.0, FLY_HEIGHT, 0.0)
	tween.tween_property(node, "position", chest, FLY_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "scale", Vector3.ONE * 0.05, FLY_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		_nuts.erase(nut)
		node.queue_free()
		WorldSave.add_resource(kind, 1))

func _save_resting() -> void:
	var out: Array = []
	for nut in _nuts:
		if nut["resting"] and not nut["flying"]:
			out.append([nut["pos"].x, nut["pos"].z, String(nut["kind"])])
	WorldSave.set_ground_nuts(out)
