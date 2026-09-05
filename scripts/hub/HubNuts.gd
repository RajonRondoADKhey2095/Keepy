extends Node3D
class_name HubNuts
## Carte-blanche v4 P2 -- the nuts: shaken out of a wreath, falling,
## bouncing, rolling to a rest, picked up by walking over them.
##
## Carte-blanche v5 P2 -- and what else falls. LEAVES on every shake: no
## counter, no save, they flutter down, lie a few seconds and are gone --
## the feedback that a crown was shaken, made of six to nine quads. A
## LADYBUG now and then: it lands like a nut, then SCURRIES -- wanders,
## and flees Keepy when he comes near -- and after LADYBUG_LIFE_S flies
## off; catching it is walking onto it before that, the same proximity as
## a nut. Never saved: an insect that survived a reload would be a rock.
## A GOLDEN acorn on a paced shake (HubWorld.shake_extras): the acorn
## mesh under a gold tint, spinning and glinting at rest, saved like a
## nut, its own counter.
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
const LADYBUG_GLB: String = "ladybug_0"
## Two leaf sets: the hollow's autumn oranges and (v5) the plateau's greens
## -- tinting one into the other gave olive-brown lozenges on capture.
const LEAF_SETS: Dictionary = {"leaf": ["leaf_0", "leaf_1", "leaf_2"], "greenleaf": ["greenleaf_0", "greenleaf_1", "greenleaf_2"]}
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

## v5 -- the ladybug: a beat still after landing, then a wander at
## LADYBUG_WALK, a flight at LADYBUG_FLEE when Keepy is within
## LADYBUG_FLEE_R (his hop covers 5.4 u/s, so a chase is winnable but not
## free), a heading that drifts, a turn-back at the region's edge, and
## after LADYBUG_LIFE_S it takes off (rises, shrinks, gone -- no reward).
const LADYBUG_STILL_S: float = 0.6
const LADYBUG_WALK: float = 0.7
const LADYBUG_FLEE: float = 2.6
const LADYBUG_FLEE_R: float = 1.9
const LADYBUG_LIFE_S: float = 9.0
const LADYBUG_TAKEOFF_S: float = 0.7
## v5 -- the leaves: they fall against drag toward LEAF_TERMINAL, sway
## sideways as they go, lie LEAF_LIE_S, then shrink away in LEAF_FADE_S.
const LEAF_TERMINAL: float = 1.1
const LEAF_SWAY: float = 0.55
const LEAF_LIE_S: float = 3.5
const LEAF_FADE_S: float = 0.6
const LEAF_SCALE: float = 2.0
## v5 -- the golden acorn's tint: brown vertex colours times this read as
## bright gold (components above 1 are meant).
const GOLD_TINT: Color = Color(1.9, 1.7, 0.45)

var _nuts: Array[Dictionary] = []
var _leaves: Array[Dictionary] = []
var _keepy: Node3D = null
var _acorn: Mesh = null
var _hazelnut: Mesh = null
var _ladybug: Mesh = null
var _leaf_meshes: Dictionary = {}
var _material: Material = null
var _gold: Material = null
var _rest_dirty: bool = false
var _time: float = 0.0

## For probes: totals since boot.
var dropped_total: int = 0
var picked_total: int = 0
var leaves_dropped_total: int = 0
var ladybugs_escaped_total: int = 0

func _ready() -> void:
	_acorn = CozyPalette.glb_mesh(CozyPalette.decor_path(ACORN_GLB))
	_hazelnut = CozyPalette.glb_mesh(CozyPalette.decor_path(HAZELNUT_GLB))
	_ladybug = CozyPalette.glb_mesh(CozyPalette.decor_path(LADYBUG_GLB))
	if _acorn == null or _hazelnut == null:
		push_error("HubNuts: acorn_0.glb / hazelnut_0.glb missing")
	if _ladybug == null:
		push_error("HubNuts: ladybug_0.glb missing")
	for set_name in LEAF_SETS:
		var meshes: Array[Mesh] = []
		for name in LEAF_SETS[set_name]:
			var mesh: Mesh = CozyPalette.glb_mesh(CozyPalette.decor_path(name))
			if mesh != null:
				meshes.append(mesh)
		_leaf_meshes[set_name] = meshes
	_material = CozyPalette.decor_material()
	_gold = CozyPalette.decor_material_tinted(GOLD_TINT)

func setup(keepy: Node3D) -> void:
	_keepy = keepy
	# The nuts left lying around last time.
	for item in WorldSave.ground_nuts():
		var kind := StringName(item[2])
		if kind == &"ladybug":
			continue
		var nut: Dictionary = _spawn(kind, Vector3(item[0], 0.0, item[1]), Vector3.ZERO)
		_settle(nut)
	WorldSave.reset_done.connect(_on_reset)

func _on_reset() -> void:
	for nut in _nuts:
		nut["node"].queue_free()
	_nuts.clear()
	for leaf in _leaves:
		leaf["node"].queue_free()
	_leaves.clear()

func mesh_for(kind: StringName) -> Mesh:
	match kind:
		&"hazelnut":
			return _hazelnut
		&"ladybug":
			return _ladybug if _ladybug != null else _hazelnut
		_:
			return _acorn

func _spawn(kind: StringName, at: Vector3, velocity: Vector3) -> Dictionary:
	var node := MeshInstance3D.new()
	node.mesh = mesh_for(kind)
	node.material_override = _gold if kind == &"golden" else _material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	add_child(node)
	var nut := {"node": node, "kind": kind, "pos": at, "vel": velocity, "bounces": 0,
		"resting": false, "spin": Vector3(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0), randf_range(-4.0, 4.0)),
		"flying": false, "yaw": randf() * TAU,
		"critter": kind == &"ladybug", "still": LADYBUG_STILL_S, "life": LADYBUG_LIFE_S,
		"heading": randf() * TAU, "escaping": false}
	_nuts.append(nut)
	return nut

## Shakes `count` nuts of `kinds` out of `tree` (a Node3D whose local
## frame is the family's), at a random point of the wreath, thrown a
## little outward so they clear the trunk and land where he can walk.
## v5: `ring_r` / `drop_y` let a decor tree (HubTrees.drop_geometry) name
## its own crown rim; the defaults are the perchoir wreath's.
func drop_from_tree(tree: Node3D, kinds: Array, ring_r: float = DROP_RING_R, drop_y: float = DROP_Y) -> void:
	for kind in kinds:
		var a: float = randf() * TAU
		var r: float = ring_r * randf_range(0.9, 1.15)
		var local := Vector3(cos(a) * r, drop_y + randf_range(-0.15, 0.15), sin(a) * r)
		var world: Vector3 = tree.to_global(local)
		var out := Vector3(world.x - tree.global_position.x, 0.0, world.z - tree.global_position.z).normalized()
		var vel: Vector3 = out * randf_range(0.9, 1.7) + Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 0.9), randf_range(-0.4, 0.4))
		_spawn(StringName(kind), world, vel)
		dropped_total += 1

## v5: `count` leaves leave the crown, from all over its rim and a little
## inside it, barely thrown -- they are lighter than the nuts and the sway
## does the rest.
func drop_leaves(tree: Node3D, count: int, ring_r: float = DROP_RING_R, drop_y: float = DROP_Y, leaf_set: String = "greenleaf", tint: Color = Color.WHITE) -> void:
	var meshes: Array = _leaf_meshes.get(leaf_set, [])
	if meshes.is_empty():
		return
	var material: Material = CozyPalette.decor_material_tinted(tint) if tint != Color.WHITE else _material
	for i in count:
		var a: float = randf() * TAU
		var r: float = ring_r * randf_range(0.55, 1.15)
		var local := Vector3(cos(a) * r, drop_y + randf_range(-0.1, 0.45), sin(a) * r)
		var world: Vector3 = tree.to_global(local)
		var out := Vector3(world.x - tree.global_position.x, 0.0, world.z - tree.global_position.z).normalized()
		var node := MeshInstance3D.new()
		node.mesh = meshes[randi() % meshes.size()]
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = world
		node.scale = Vector3.ONE * LEAF_SCALE
		node.rotation = Vector3(randf_range(-0.6, 0.6), randf() * TAU, randf_range(-0.6, 0.6))
		add_child(node)
		_leaves.append({"node": node, "pos": world, "vel": out * randf_range(0.3, 0.9) + Vector3(0.0, randf_range(-0.2, 0.3), 0.0),
			"phase": randf() * TAU, "spin": Vector3(randf_range(-2.5, 2.5), randf_range(-3.0, 3.0), randf_range(-2.5, 2.5)),
			"landed": false, "lie": LEAF_LIE_S + randf_range(-0.8, 0.8), "fade": LEAF_FADE_S})
		leaves_dropped_total += 1

func _settle(nut: Dictionary) -> void:
	nut["resting"] = true
	nut["vel"] = Vector3.ZERO
	var node: Node3D = nut["node"]
	var p: Vector3 = nut["pos"]
	match nut["kind"]:
		&"acorn", &"golden":
			p.y = ACORN_LIE_Y
			node.rotation = Vector3(0.0, nut["yaw"], PI * 0.5)
		&"ladybug":
			# On its feet, facing the way it will walk; the wander starts
			# after a beat of stillness (STILL_S), which is the tell.
			p.y = 0.0
			node.rotation = Vector3(0.0, nut["heading"], 0.0)
		_:
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

## For probes: live ladybugs (landed or not, not yet caught or gone).
func ladybug_count() -> int:
	var n: int = 0
	for nut in _nuts:
		if nut["critter"] and not nut["flying"]:
			n += 1
	return n

func ladybug_position() -> Vector3:
	for nut in _nuts:
		if nut["critter"] and not nut["flying"]:
			return nut["pos"]
	return Vector3.INF

func leaf_count() -> int:
	return _leaves.size()

func _process(delta: float) -> void:
	_time += delta
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
		if nut["critter"]:
			_scurry(nut, delta, feet)
			if nut["flying"]:
				continue
		elif nut["kind"] == &"golden":
			# The glint: a slow turn and a breath of height at rest.
			node.rotation.y += delta * 1.4
			node.position.y = ACORN_LIE_Y + 0.03 + 0.03 * sin(_time * 3.1 + nut["yaw"])
		if can_pick and Vector2(feet.x - nut["pos"].x, feet.z - nut["pos"].z).length() <= PICK_RADIUS:
			_pick(nut)
	_update_leaves(delta)
	if _rest_dirty:
		_rest_dirty = false
		_save_resting()

## The ladybug's life on the ground: still, then walking, fleeing, gone.
func _scurry(nut: Dictionary, delta: float, feet: Vector3) -> void:
	var node: Node3D = nut["node"]
	if nut["still"] > 0.0:
		nut["still"] -= delta
		return
	nut["life"] -= delta
	if nut["life"] <= 0.0:
		_escape(nut)
		return
	var pos: Vector3 = nut["pos"]
	var heading: float = nut["heading"]
	var speed: float = LADYBUG_WALK
	var to_keepy := Vector2(feet.x - pos.x, feet.z - pos.z)
	if feet != Vector3.INF and to_keepy.length() < LADYBUG_FLEE_R:
		# Away from him, with a little zigzag so the chase is a chase.
		heading = atan2(-to_keepy.x, -to_keepy.y) + 0.6 * sin(_time * 7.0 + nut["yaw"])
		speed = LADYBUG_FLEE
	else:
		heading += randf_range(-2.2, 2.2) * delta
	var step := Vector3(sin(heading), 0.0, cos(heading)) * speed * delta
	var next: Vector3 = pos + step
	if not HubRegion.contains(next):
		heading += PI
		next = pos - step
		if not HubRegion.contains(next):
			next = pos
	nut["heading"] = heading
	nut["pos"] = next
	node.position = next
	node.rotation = Vector3(0.0, heading, 0.08 * sin(_time * 18.0) * (speed / LADYBUG_FLEE))

## The ladybug takes off: up and away, shrinking; no counter moves.
func _escape(nut: Dictionary) -> void:
	nut["flying"] = true
	nut["resting"] = false
	ladybugs_escaped_total += 1
	var node: Node3D = nut["node"]
	var tween := create_tween()
	tween.set_parallel(true)
	var away: Vector3 = nut["pos"] + Vector3(randf_range(-1.0, 1.0), 1.6, randf_range(-1.0, 1.0))
	tween.tween_property(node, "position", away, LADYBUG_TAKEOFF_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(node, "scale", Vector3.ONE * 0.05, LADYBUG_TAKEOFF_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		_nuts.erase(nut)
		node.queue_free())

func _update_leaves(delta: float) -> void:
	var gone: Array = []
	for leaf in _leaves:
		var node: Node3D = leaf["node"]
		if not leaf["landed"]:
			var vel: Vector3 = leaf["vel"]
			var pos: Vector3 = leaf["pos"]
			# Drag toward a slow terminal fall; sideways sway on two sines.
			vel.y = lerpf(vel.y, -LEAF_TERMINAL, minf(delta * 3.0, 1.0))
			vel.x = lerpf(vel.x, 0.0, minf(delta * 1.5, 1.0))
			vel.z = lerpf(vel.z, 0.0, minf(delta * 1.5, 1.0))
			var t: float = _time + leaf["phase"]
			pos += vel * delta + Vector3(sin(t * 2.3), 0.0, cos(t * 1.7)) * LEAF_SWAY * delta
			node.rotation += leaf["spin"] * delta
			if pos.y <= 0.02:
				pos.y = 0.02
				leaf["landed"] = true
				node.rotation = Vector3(deg_to_rad(randf_range(-8.0, 8.0)), randf() * TAU, deg_to_rad(randf_range(-8.0, 8.0)))
			leaf["pos"] = pos
			leaf["vel"] = vel
			node.position = pos
			continue
		if leaf["lie"] > 0.0:
			leaf["lie"] -= delta
			continue
		leaf["fade"] -= delta
		if leaf["fade"] <= 0.0:
			gone.append(leaf)
			continue
		node.scale = Vector3.ONE * LEAF_SCALE * maxf(leaf["fade"] / LEAF_FADE_S, 0.0)
	for leaf in gone:
		_leaves.erase(leaf)
		leaf["node"].queue_free()

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

## Only what will still be there tomorrow: nuts at rest, never an insect.
func _save_resting() -> void:
	var out: Array = []
	for nut in _nuts:
		if nut["resting"] and not nut["flying"] and not nut["critter"]:
			out.append([nut["pos"].x, nut["pos"].z, String(nut["kind"])])
	WorldSave.set_ground_nuts(out)
