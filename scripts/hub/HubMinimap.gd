extends Control
class_name HubMinimap
## CH46 -- THE PERMANENT MINIMAP: a north-fixed plan of the walkable world,
## drawn in the bottom-left corner, visible on foot AND in every vehicle.
##
## =====================================================================
## THE FIVE DECISIONS THIS FILE OBEYS (Mathieu, brief CH46) -- not to be
## re-opened here
##
## 1. PERMANENT, in a corner. No full-screen map, no button to open it.
## 2. NORTH FIXED. The plan never rotates with the camera.
## 3. THE FRAME IS THE WALKABLE WORLD ALONE (HubRegion.walkable_bounds(),
##    137 x 247 u), not the all-vehicle frame. Anything outside -- the
##    sailboat runs up to 82 u past it in x -- is CLAMPED to the border
##    and drawn with a different icon. Nothing ever disappears silently.
## 4. THE ZONE BOUNDARIES ARE THE PAINTED ONES (CozyPalette.*_EDGE_Z),
##    not the logical ones (HubRegion). They differ by 2 to 4 u, and the
##    map has to agree with what Mathieu sees through the glass.
## 5. NO SubViewport. CH44 axe 5 measured one at +74 085 primitives and
##    +421 draw calls -- more than the entire 3D scene.
##
## =====================================================================
## WHY ONE TEXTURE FOR EVERYTHING, AND WHAT IT BOUGHT
##
## CH44 axe 5 measured a `Control._draw` built from `draw_circle` at
## +2 619 primitives / +43 draw calls for 40 markers, and named the
## cause: `draw_circle` emits a POLYGON command, and polygons do not
## batch -- one draw call per marker, linear in the number of markers and
## nothing to do with their size.
##
## Everything this file draws is therefore a `draw_texture_rect_region`
## on ONE runtime-built atlas: the baked plan occupies the top of the
## image, the four marker icons a strip under it. Same texture, same
## material, same command kind -- so Godot's canvas renderer coalesces
## the whole map, background included, into a handful of calls whatever
## the marker count. The measurement of both approaches is in
## docs/lots/CH46_MINIMAP.md; it was taken on the CH38/CH40 bench, same
## protocol as CH44, so the two are comparable.
##
## THE ICONS ARE WHITE SHAPES WITH BLACK OUTLINES, AND THAT IS LOAD-BEARING.
## A marker is tinted by the `modulate` argument, which MULTIPLIES: white
## fill becomes the kind's colour, and black outline stays black under any
## colour whatsoever. So every marker keeps a hard dark edge against grass,
## sand, heather, lawn or sea without a single per-kind contrast decision
## -- CLAUDE.md's own warning that WCAG scores nothing INSIDE a luminance
## band, answered by construction rather than by a table of tones.
##
## =====================================================================
## WHY IT KNOWS NO NODE PATHS
##
## See MinimapMarkers.gd. Half the entities worth drawing have no stable
## name at all (CH44 axe 3: the bear is `@Node3D@228`), so the map
## enumerates four groups and asks nothing else. An entity joins or leaves
## the map by one line at its own construction site.
##
## =====================================================================
## MOUSE_FILTER_IGNORE IS NOT A DETAIL
##
## `Control`'s default is STOP, and both `HubTapInput._unhandled_input`
## and `KartTouchInput._unhandled_input` run AFTER the GUI pick. A minimap
## left at the default would swallow the tap-to-move under it on foot and
## the throttle/reverse anchor in a vehicle -- silently, with no error.
## It is set in `_ready()` AND in the scene file, and MinimapProbe proves
## it by pushing real events through the widget's rect.

## The plan's height in canvas pixels. The width follows from the world
## frame's own aspect, so the map is never stretched.
const MAP_PX_H: int = 280

## Bottom-left, and how far from the two edges. The bottom margin clears
## the home indicator (~94 canvas px on an iPhone with the hub's EXPAND
## scaling); the notch is at the OTHER end of the screen, which is why
## this corner was chosen at all. CH44 axe 4: the bottom third of the
## screen is free in both modes.
const MARGIN_X: float = 24.0
const MARGIN_Y: float = 150.0

## One atlas cell, in pixels. Every icon is drawn 1:1 at this size, so no
## icon is ever resampled.
const ICON_PX: int = 14

## Atlas cell indices. The order is the order they are baked in.
const ICON_DOT: int = 0
const ICON_DIAMOND: int = 1
const ICON_SQUARE: int = 2
const ICON_PLAYER: int = 3
const ICON_COUNT: int = 4

## Ground alpha inside the walkable world, and the tone everything outside
## it is washed with. The shape of the world IS the map's main information:
## a plan that painted grass everywhere would say the circuit is as wide as
## the plateau.
const GROUND_ALPHA: float = 0.92
const OUT_TONE: Color = Color(0.05, 0.06, 0.08, 0.52)
const EDGE_TONE: Color = Color(0.10, 0.13, 0.10, 0.80)
const TRACK_TONE: Color = Color(0.99, 0.97, 0.90, 0.95)
const BORDER_TONE: Color = Color(0.09, 0.11, 0.09, 0.95)

## Marker tints. Multiplied into a white fill, so these ARE the fill
## colours; the black outline baked beside them is untouched by any of
## them (see the atlas note above).
## ⚠️ NOT CREAM, AND THE PROBE IS WHY. A cream player marker (1.00, 0.99,
## 0.90) renders within 0.03 of the circuit's own line (0.97, 0.96, 0.87
## once the plan's alpha is applied) -- so the player standing on the
## karting circuit would be a pale dot on a pale line, and MinimapProbe's
## blind sweep read two plan pixels as "a player" during a red pass. A
## warm yellow is 0.71 away in blue from that line and clear of every
## painted band tone as well.
const PLAYER_TONE: Color = Color(1.00, 0.86, 0.16)
const VEHICLE_TONE: Color = Color(0.97, 0.44, 0.20)
const NPC_TONE: Color = Color(0.36, 0.60, 0.98)
const PLACE_TONE: Color = Color(0.74, 0.44, 0.96)

## Painted-zone bands, read off CozyPalette in the SAME ORDER the ground
## shader mixes them (cozy_ground.gdshader fragment(): grass, then autumn,
## then moor, then circuit lawn, then the cove's sand and sea). The order
## is the fact here, not the individual thresholds: reversing it would put
## heather over the circuit.
const _PAINTED_BASE: Color = CozyPalette.GRASS_A

## Back to front: places under animals under vehicles under the player, so
## the one marker a player is actually looking for is never the hidden one.
##
## ⚠️ PUBLISHED, because it is not only a drawing detail: whether a marker
## can be COVERED depends on it, and MinimapProbe has to know which markers
## it may legitimately not find. Written twice, the probe and the widget
## disagreed on the first run -- three balloon docks read back in the
## VEHICLE tone (a balloon parks ON its dock 0, at the same coordinates)
## and the probe called that a miss instead of an occlusion. One list, read
## by both.
const DRAW_ORDER: Array[StringName] = [
	MinimapMarkers.PLACE, MinimapMarkers.NPC, MinimapMarkers.VEHICLE, MinimapMarkers.PLAYER]

## The fill colour of a kind's marker, and the atlas cell it uses. Static so
## a probe asks for them rather than restating them.
static func tone_of(kind: StringName) -> Color:
	if kind == MinimapMarkers.PLAYER:
		return PLAYER_TONE
	if kind == MinimapMarkers.VEHICLE:
		return VEHICLE_TONE
	if kind == MinimapMarkers.NPC:
		return NPC_TONE
	return PLACE_TONE

static func icon_of(kind: StringName) -> int:
	if kind == MinimapMarkers.PLAYER:
		return ICON_PLAYER
	if kind == MinimapMarkers.PLACE:
		return ICON_DIAMOND
	return ICON_DOT

var _atlas: ImageTexture = null
var _frame: Rect2 = Rect2()
var _bg_size: Vector2i = Vector2i.ZERO
var _atlas_size: Vector2i = Vector2i.ZERO
var _route_baked: bool = false
var _route_retried: bool = false
var _scolded: Dictionary = {}

func _ready() -> void:
	# BOTH of these, and neither is redundant: the scene file carries it so
	# an author reading HubWorld.tscn sees it, and this line carries it so a
	# minimap built in code (every probe does) is never at the STOP default.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = HubRegion.walkable_bounds()
	var w: int = maxi(1, roundi(float(MAP_PX_H) * _frame.size.x / _frame.size.y))
	_bg_size = Vector2i(w, MAP_PX_H)
	_atlas_size = Vector2i(maxi(w, ICON_PX * ICON_COUNT), MAP_PX_H + ICON_PX)
	# ⚠️ ANCHORS AND OFFSETS WRITTEN OUT, NEVER set_anchors_preset() + position.
	# CLAUDE.md documents the trap and this repo has already paid it once (V7,
	# the kart's clock panel cut off on device): after a preset, `position` is
	# an OFFSET FROM THE ANCHOR, so a widget anchored bottom-left and given a
	# positive y lands off the bottom of the screen. Four offsets against two
	# anchors say exactly one thing.
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = MARGIN_X
	offset_right = MARGIN_X + float(w)
	offset_top = -(MARGIN_Y + float(MAP_PX_H))
	offset_bottom = -MARGIN_Y

func _process(_delta: float) -> void:
	# Baked on the first frame rather than in _ready(): the karting circuit
	# is built by KartTrack._ready(), and HubWorld's own _ready() cascade is
	# still running when this node's _ready() fires. Re-baked once if the
	# route turns up later, so an ordering change cannot silently cost the
	# circuit -- and MinimapProbe gates the drawn PIXELS of that line, not
	# the fact that this ran.
	if _atlas == null:
		_bake()
	elif not _route_baked and not _route_retried \
			and not get_tree().get_nodes_in_group(MinimapMarkers.ROUTE).is_empty():
		# ⚠️ EXACTLY ONE RETRY, and it is gated on the group being non-empty
		# rather than on `not _route_baked` alone. A bake is 43 400
		# HubRegion.contains() calls: a hub with no circuit (every probe
		# that builds a bare world) would otherwise pay that EVERY FRAME
		# forever, and a route member that turns out to publish nothing
		# drawable would do the same. `_route_retried` closes both.
		_route_retried = true
		_bake()
	queue_redraw()

## ---- the frame, and what falls outside it --------------------------

## The world frame the plan covers, in world units (x, z). Published so a
## probe reads the same rectangle the drawing does instead of restating it.
func frame() -> Rect2:
	return _frame

## Where a world point lands inside the widget, in local pixels, and
## whether it had to be pulled in. NORTH (+z) IS UP: v runs from the
## frame's +z edge down to its -z edge.
##
## The clamp is deliberately to the widget's inner edge minus half an icon,
## so a clamped marker is fully drawn instead of half-cut -- an entity that
## is off the map must still be READABLE, or "clamped" and "gone" look the
## same.
func project(world: Vector3) -> Dictionary:
	var u: float = (world.x - _frame.position.x) / _frame.size.x
	var v: float = (_frame.position.y + _frame.size.y - world.z) / _frame.size.y
	var outside: bool = u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0
	var half: float = float(ICON_PX) * 0.5
	var px: float = clampf(u * size.x, half, maxf(half, size.x - half))
	var py: float = clampf(v * size.y, half, maxf(half, size.y - half))
	return {"at": Vector2(px, py), "clamped": outside}

## ---- what the map draws --------------------------------------------

func _draw() -> void:
	if _atlas == null:
		return
	draw_texture_rect_region(_atlas, Rect2(Vector2.ZERO, size),
		Rect2(0.0, 0.0, float(_bg_size.x), float(_bg_size.y)), Color(1.0, 1.0, 1.0, 1.0))
	for kind in DRAW_ORDER:
		_draw_kind(kind, icon_of(kind), tone_of(kind))

func _draw_kind(group: StringName, icon: int, tone: Color) -> void:
	for node in members(group):
		var shot: Dictionary = project(node.global_position)
		var at: Vector2 = shot["at"]
		# A clamped marker changes SHAPE, not colour: it keeps saying which
		# kind it is while saying it is off the map.
		var cell: int = ICON_SQUARE if bool(shot["clamped"]) else icon
		draw_texture_rect_region(_atlas,
			Rect2(at - Vector2(float(ICON_PX), float(ICON_PX)) * 0.5,
				Vector2(float(ICON_PX), float(ICON_PX))),
			_icon_region(cell), tone)

## Every live Node3D of `group`. A member that is not a Node3D has no world
## position and cannot be drawn -- said out loud ONCE per group rather than
## dropped, because a marker that silently never appears is the failure
## this whole design exists to avoid.
func members(group: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(group):
		var spatial := node as Node3D
		if spatial == null:
			if not _scolded.has(group):
				_scolded[group] = true
				push_error("HubMinimap: group '%s' holds a %s, which has no world position." % [group, node.get_class()])
			continue
		if spatial.is_queued_for_deletion():
			continue
		out.append(spatial)
	return out

func _icon_region(cell: int) -> Rect2:
	return Rect2(float(cell * ICON_PX), float(_bg_size.y), float(ICON_PX), float(ICON_PX))

## ---- the atlas ------------------------------------------------------

func _bake() -> void:
	var img := Image.create(_atlas_size.x, _atlas_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	_bake_ground(img)
	_bake_zone_edges(img)
	_route_baked = _bake_route(img)
	_bake_border(img)
	_bake_icons(img)
	_atlas = ImageTexture.create_from_image(img)

## The plan itself: the painted ground where the region admits a point, the
## wash everywhere else.
func _bake_ground(img: Image) -> void:
	for py in _bg_size.y:
		for px in _bg_size.x:
			var world: Vector3 = _world_at(px, py)
			if HubRegion.contains(world):
				var col: Color = painted_tone(world)
				col.a = GROUND_ALPHA
				img.set_pixel(px, py, col)
			else:
				img.set_pixel(px, py, OUT_TONE)

## The ground colour the SHADER would paint at this point, minus its noise:
## same bands, same order, same constants (CozyPalette). Static so a probe
## can ask it the same question the bake asks.
static func painted_tone(world: Vector3) -> Color:
	var col: Color = _PAINTED_BASE
	if world.z <= CozyPalette.AUTUMN_EDGE_Z:
		col = CozyPalette.AUTUMN_A
	if world.z <= CozyPalette.MOOR_EDGE_Z:
		col = CozyPalette.MOOR_A
	if world.z <= CozyPalette.CIRCUIT_EDGE_Z:
		col = CozyPalette.LAWN_A
	var rect: Vector4 = CozyPalette.COVE_RECT
	if world.x >= rect.x and world.x <= rect.z and world.z >= rect.y and world.z <= rect.w:
		col = CozyPalette.SAND_A
		var d: float = HubRegion.shore_distance(world)
		if d < 0.0:
			col = CozyPalette.SEA_SHALLOW_BED.lerp(CozyPalette.SEA_BED, clampf(-d / 9.0, 0.0, 1.0))
		elif d < 3.5:
			col = CozyPalette.SAND_A.lerp(CozyPalette.SAND_WET, 1.0 - d / 3.5)
	return col

## The three painted hedges (and the cove's painted west edge) as lines, so
## a boundary reads as a boundary and not only as a change of tint -- two
## of the four bands are close enough in value that the tint alone is a
## guess. THE PAINTED z, per decision 4: CozyPalette, never HubRegion.
func _bake_zone_edges(img: Image) -> void:
	for edge_z in [CozyPalette.AUTUMN_EDGE_Z, CozyPalette.MOOR_EDGE_Z, CozyPalette.CIRCUIT_EDGE_Z]:
		var py: int = _pixel_z(float(edge_z))
		for px in _bg_size.x:
			_wash(img, px, py, EDGE_TONE)
	var rect: Vector4 = CozyPalette.COVE_RECT
	var px_edge: int = _pixel_x(rect.x)
	var z0: int = _pixel_z(rect.w)
	var z1: int = _pixel_z(rect.y)
	for py in range(mini(z0, z1), maxi(z0, z1) + 1):
		_wash(img, px_edge, py, EDGE_TONE)

## The karting circuit, from whatever joined MinimapMarkers.ROUTE. Returns
## false when nothing has, which is what makes _process bake again.
func _bake_route(img: Image) -> bool:
	var drew: bool = false
	for node in get_tree().get_nodes_in_group(MinimapMarkers.ROUTE):
		if not node.has_method("ideal_line"):
			continue
		var line: Array = node.call("ideal_line")
		if line.size() < 2:
			continue
		var spatial := node as Node3D
		var basis_xform: Transform3D = spatial.global_transform if spatial != null else Transform3D.IDENTITY
		var prev: Vector2 = Vector2.ZERO
		for i in range(line.size() + 1):
			var world: Vector3 = basis_xform * (line[i % line.size()] as Vector3)
			var here := Vector2(float(_pixel_x(world.x)), float(_pixel_z(world.z)))
			if i > 0:
				_segment(img, prev, here, TRACK_TONE)
			prev = here
		drew = true
	return drew

func _bake_border(img: Image) -> void:
	for px in _bg_size.x:
		img.set_pixel(px, 0, BORDER_TONE)
		img.set_pixel(px, _bg_size.y - 1, BORDER_TONE)
	for py in _bg_size.y:
		img.set_pixel(0, py, BORDER_TONE)
		img.set_pixel(_bg_size.x - 1, py, BORDER_TONE)

## The four icons, WHITE FILL / BLACK OUTLINE, antialiased by coverage.
## Every one of them is a distinct SHAPE at 14 px, because shape survives a
## background the colour cannot be chosen against.
func _bake_icons(img: Image) -> void:
	var c: float = float(ICON_PX) * 0.5 - 0.5
	for cell in ICON_COUNT:
		for py in ICON_PX:
			for px in ICON_PX:
				var dx: float = float(px) - c
				var dy: float = float(py) - c
				var metric: float = 0.0
				var r_in: float = 0.0
				var r_out: float = 0.0
				match cell:
					ICON_DIAMOND:
						metric = absf(dx) + absf(dy)
						r_in = 4.2
						r_out = 5.8
					ICON_SQUARE:
						metric = maxf(absf(dx), absf(dy))
						r_in = 3.7
						r_out = 5.1
					ICON_PLAYER:
						metric = sqrt(dx * dx + dy * dy)
						r_in = 4.2
						r_out = 6.0
					_:
						metric = sqrt(dx * dx + dy * dy)
						r_in = 3.9
						r_out = 5.3
				var a_out: float = clampf(r_out + 0.5 - metric, 0.0, 1.0)
				var a_in: float = clampf(r_in + 0.5 - metric, 0.0, 1.0)
				img.set_pixel(cell * ICON_PX + px, _bg_size.y + py, Color(a_in, a_in, a_in, a_out))

## ---- pixel <-> world -------------------------------------------------

func _world_at(px: int, py: int) -> Vector3:
	var x: float = _frame.position.x + (float(px) + 0.5) / float(_bg_size.x) * _frame.size.x
	var z: float = _frame.position.y + _frame.size.y - (float(py) + 0.5) / float(_bg_size.y) * _frame.size.y
	return Vector3(x, 0.0, z)

func _pixel_x(x: float) -> int:
	return int(floor((x - _frame.position.x) / _frame.size.x * float(_bg_size.x)))

func _pixel_z(z: float) -> int:
	return int(floor((_frame.position.y + _frame.size.y - z) / _frame.size.y * float(_bg_size.y)))

## Darken a plan pixel rather than replace it, so a hedge line drawn over
## the wash outside the world does not read as walkable ground.
func _wash(img: Image, px: int, py: int, tone: Color) -> void:
	if px < 0 or py < 0 or px >= _bg_size.x or py >= _bg_size.y:
		return
	var under: Color = img.get_pixel(px, py)
	img.set_pixel(px, py, Color(
		lerpf(under.r, tone.r, tone.a),
		lerpf(under.g, tone.g, tone.a),
		lerpf(under.b, tone.b, tone.a), under.a))

func _segment(img: Image, a: Vector2, b: Vector2, tone: Color) -> void:
	var steps: int = int(ceil(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	if steps <= 0:
		_wash(img, int(a.x), int(a.y), tone)
		return
	for i in range(steps + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(steps))
		_wash(img, int(round(p.x)), int(round(p.y)), tone)
