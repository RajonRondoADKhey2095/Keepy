extends Node
## Carte-blanche v4 -- where can a climbable tree stand? Headless, pure
## geometry: instantiates the hub, walks a grid per zone, measures the
## clearance of every candidate against everything that already occupies
## the ground (layout props, paths, waters, docks, ball, campfire, actor
## rests, the scatter's own blockers) and projects it into the SPAWN
## camera by hand (the dummy driver reports a 0x0 viewport, so
## unproject_position is not trusted here -- the maths is the same).
##
## Prints the best candidates per zone; the choice is made by a human
## reading (and a capture), not by this script.
##
## KEPT past the branch that wrote it, although it asserts nothing, for the
## reason CLAUDE.md gives for keeping any measuring instrument: the tree
## sites shipped in HubTrees.gd cite THIS probe as where their clearance
## numbers came from (see its SITES table and HubTapInput's tap radii). A
## number whose source has been deleted is the "chiffre fantôme" that file
## documents -- repeated from brief to brief with nothing left to reopen.
## Deleting this script would turn three shipped constants into exactly
## that, and re-deriving them would cost a lot more than the file does.
##
## Exit 0 always (it is a recon, not a gate);
## ProbeWatchdog.EXIT_TIMEOUT = INCONCLUSIVE (ran out of wall clock).

const CAM_OFFSET: Vector3 = Vector3(0.0, 7.6, 8.9)
const CAM_PITCH_COS: float = 0.82904
const CAM_PITCH_SIN: float = 0.55919
const HFOV_DEG: float = 45.0
const W: float = 1080.0
const H: float = 1920.0
## The tree's own ground radius (the wreath is 1.64 u wide) plus room to
## walk round it.
const OWN: float = 1.7

var _hub: Node = null
var _frames: int = 0

func _ready() -> void:
	# FIRST statement, per ProbeWatchdog's contract. 300s, not the 900s
	# default: the grid walk is four zones at 0.5 u and finishes in well
	# under a minute; there is no simulation here to be legitimately slow.
	ProbeWatchdog.arm(self, "V4 SITE PROBE", 300.0)
	_hub = load("res://scenes/HubWorld.tscn").instantiate()
	add_child(_hub)

func _screen(point: Vector3, keepy_ground: Vector3) -> Vector2:
	var cam: Vector3 = Vector3(keepy_ground.x, 0.0, keepy_ground.z) + CAM_OFFSET
	var v: Vector3 = point - cam
	var cx: float = v.x
	var cy: float = v.y * CAM_PITCH_COS - v.z * CAM_PITCH_SIN
	var cz: float = v.y * CAM_PITCH_SIN + v.z * CAM_PITCH_COS
	if cz >= -0.01:
		return Vector2(-9999, -9999)
	var th: float = tan(deg_to_rad(HFOV_DEG * 0.5))
	var tv: float = th * H / W
	var xn: float = cx / (-cz) / th
	var yn: float = cy / (-cz) / tv
	return Vector2((xn + 1.0) * 0.5 * W, (1.0 - yn) * 0.5 * H)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames < 3:
		return
	set_process(false)
	var builder: HubBuilder = _hub.get_node("WorldViewport/SubViewport/World/Props")
	var scatter: Node = _hub.get_node("WorldViewport/SubViewport/World/CozyScatter")
	var world: Node = _hub
	# Everything on the ground, with the radius to keep from it.
	var occupied: Array = []
	for entry in builder.layout.props:
		var t: StringName = entry.get("type", &"")
		var p: Vector3 = entry.get("position", Vector3.ZERO)
		var sc: float = entry.get("scale", 1.0)
		var r: float = 1.0
		match t:
			&"tree": r = 1.5 * sc * 0.8 + 0.3
			&"portal": r = 2.6
			&"landmark", &"stump", &"rock", &"bush", &"flower": r = 1.0 * sc
			&"cabin": r = 6.0
			&"divingboard": r = 2.5
			&"turnstile", &"seesaw": r = 3.0
			&"owl": r = 2.5
			&"boat": r = 2.0
			&"zipline": r = 3.0
			_: r = 0.0
		if r > 0.0:
			occupied.append([Vector2(p.x, p.z), r, String(t)])
		if t == &"zipline":
			var f: Vector3 = entry.get("far_end", p)
			occupied.append([Vector2(f.x, f.z), 3.0, "zipline_far"])
	for fp in HubTransport.footprints():
		occupied.append([Vector2(fp["position"].x, fp["position"].z), float(fp["radius"]), "transport"])
	occupied.append([HubCampfire.SITE, 3.2, "campfire"])
	occupied.append([Vector2(world.BEAR_REST.x, world.BEAR_REST.z), 2.5, "bear_rest"])
	occupied.append([Vector2(world.BEAR_SHELTER.x, world.BEAR_SHELTER.z), 2.0, "bear_shelter"])
	occupied.append([Vector2(0.0, 0.0), 3.5, "spawn"])
	occupied.append([Vector2(HubRegion.MOTHER_TREE_AT.x, HubRegion.MOTHER_TREE_AT.z), 9.0, "mother_tree"])
	occupied.append([Vector2(HubRegion.WINDMILL_AT.x, HubRegion.WINDMILL_AT.z), 4.5, "windmill"])
	occupied.append([Vector2(scatter.MOOR_HAMLET.x, scatter.MOOR_HAMLET.z), 4.0, "hamlet"])
	# [lo, hi, focus, min clearance]: ranked by distance to the focus (where
	# the player arrives) among candidates clearing at least the minimum.
	var zones := {
		"A_spawn_frame": [Vector2(-9, -16), Vector2(9, -1), Vector2(0, 0), 0.3],
		"B_plateau": [Vector2(-24, -2), Vector2(24, 34), Vector2(0, 0), 1.2],
		"C_hollow": [Vector2(-30, -76), Vector2(30, -44), Vector2(11, -55), 1.5],
		"D_moor": [Vector2(-34, -124), Vector2(34, -88), Vector2(2, -100), 1.5],
	}
	for zone in zones.keys():
		var lo: Vector2 = zones[zone][0]
		var hi: Vector2 = zones[zone][1]
		var best: Array = []
		var x: float = lo.x
		while x <= hi.x:
			var z: float = lo.y
			while z <= hi.y:
				var p := Vector3(x, 0.0, z)
				if HubRegion.contains(p) and HubRegion.contains(p + Vector3(OWN, 0, 0)) and HubRegion.contains(p - Vector3(OWN, 0, 0)) \
						and HubRegion.contains(p + Vector3(0, 0, OWN)) and HubRegion.contains(p - Vector3(0, 0, OWN)):
					var clear: float = INF
					var who: String = ""
					for o in occupied:
						var d: float = Vector2(x, z).distance_to(o[0]) - float(o[1])
						if d < clear:
							clear = d
							who = o[2]
					var blocked: bool = false
					var zone_id: int = HubRegion.zone_of(p)
					if zone_id == 0:
						blocked = scatter.call("_blocked", p, OWN)
					elif zone_id == 1:
						blocked = scatter.call("_autumn_blocked", p, OWN)
					else:
						blocked = scatter.call("_moor_blocked", p, OWN)
					if not blocked and clear > 0.0:
						best.append([clear, x, z, who])
				z += 0.5
			x += 0.5
		var focus: Vector2 = zones[zone][2]
		var min_clear: float = zones[zone][3]
		best = best.filter(func(c): return c[0] >= min_clear)
		best.sort_custom(func(a, b): return Vector2(a[1], a[2]).distance_to(focus) < Vector2(b[1], b[2]).distance_to(focus))
		print("ZONE %s: %d candidates" % [zone, best.size()])
		for i in mini(best.size(), 14):
			var c: Array = best[i]
			var at := Vector3(c[1], 0.0, c[2])
			var s_spawn: Vector2 = _screen(at + Vector3(0, 3.42, 0), Vector3.ZERO)
			var s_self: Vector2 = _screen(at + Vector3(0, 3.42, 0), at)
			print("  d_focus %.1f clear %.2f at (%.1f, %.1f) nearest=%s | seat@spawn px=(%d,%d)" % [Vector2(c[1], c[2]).distance_to(focus), c[0], c[1], c[2], c[3], s_spawn.x, s_spawn.y])
	get_tree().quit(0)
