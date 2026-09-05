extends PanelContainer
class_name WorldHud
## Carte-blanche v4 -- the resource counter, top-right, and deliberately
## shy: full opacity for a few seconds after something changes, then it
## settles to a ghost so the environment stays the star. It reads
## WorldSave and nothing else, and WorldSave tells it when to wake.
##
## Legible under the four weathers by construction: a dark translucent
## pill behind pale text is the one combination that survives the storm
## overlay (dark), the snow look (near white) and the plain sun -- the perf
## overlay proved the pairing on device. Icons are DRAWN (an acorn, a
## hazelnut) rather than fonted: the font may have no such glyphs on iOS
## and a missing glyph is a tofu box on the first frame.

const AWAKE_S: float = 4.0
const GHOST_ALPHA: float = 0.42
const FADE_S: float = 0.9
const BUMP_SCALE: float = 1.18

var _labels: Dictionary = {}
var _awake_left: float = 0.0
var _fade: Tween = null
var _bump: Tween = null
var _row: HBoxContainer = null

## A tiny vector nut. `kind` picks the silhouette: an acorn (oval body,
## flat cap, a stalk) or a hazelnut (round, with a pale base).
class NutIcon extends Control:
	var kind: StringName = &"acorn"
	func _init(what: StringName) -> void:
		kind = what
		custom_minimum_size = Vector2(30, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := size * 0.5
		if kind == &"acorn":
			# Body: warm tan oval, slightly pointed at the bottom.
			draw_circle(c + Vector2(0, 3), 9.0, Color(0.80, 0.56, 0.28))
			draw_circle(c + Vector2(-3, 1), 3.0, Color(0.92, 0.72, 0.42))
			# Cap: darker brown dome with a little stalk.
			var cap := PackedVector2Array()
			for i in 13:
				var a := PI + PI * float(i) / 12.0
				cap.append(c + Vector2(cos(a) * 10.0, sin(a) * 6.0 - 2.0))
			draw_colored_polygon(cap, Color(0.45, 0.28, 0.14))
			draw_rect(Rect2(c + Vector2(-1.0, -13.0), Vector2(2.0, 5.0)), Color(0.45, 0.28, 0.14))
		elif kind == &"golden":
			# v5: the acorn again, in gold, with a glint.
			draw_circle(c + Vector2(0, 3), 9.0, Color(0.98, 0.80, 0.30))
			draw_circle(c + Vector2(-3, 1), 3.0, Color(1.0, 0.96, 0.72))
			var gcap := PackedVector2Array()
			for i in 13:
				var a := PI + PI * float(i) / 12.0
				gcap.append(c + Vector2(cos(a) * 10.0, sin(a) * 6.0 - 2.0))
			draw_colored_polygon(gcap, Color(0.78, 0.56, 0.16))
			draw_rect(Rect2(c + Vector2(-1.0, -13.0), Vector2(2.0, 5.0)), Color(0.78, 0.56, 0.16))
			draw_line(c + Vector2(9, -9), c + Vector2(13, -13), Color(1.0, 0.98, 0.85), 2.0)
			draw_line(c + Vector2(13, -9), c + Vector2(9, -13), Color(1.0, 0.98, 0.85), 2.0)
		elif kind == &"ladybug":
			# v5: a red dome, a black head, spots and a seam.
			draw_circle(c + Vector2(0, 5), 4.5, Color(0.10, 0.07, 0.08))
			var dome := PackedVector2Array()
			for i in 15:
				var a := PI + PI * float(i) / 14.0
				dome.append(c + Vector2(cos(a) * 10.0, sin(a) * 9.0 + 3.0))
			draw_colored_polygon(dome, Color(0.90, 0.18, 0.16))
			draw_line(c + Vector2(0, -6), c + Vector2(0, 3), Color(0.10, 0.07, 0.08), 1.5)
			for spot in [Vector2(-5, -1), Vector2(5, -1), Vector2(-3, -5), Vector2(3, -5)]:
				draw_circle(c + spot, 1.7, Color(0.10, 0.07, 0.08))
		else:
			draw_circle(c + Vector2(0, 1), 9.5, Color(0.62, 0.40, 0.20))
			draw_circle(c + Vector2(-3, -2), 3.2, Color(0.80, 0.58, 0.34))
			# Pale base scar of a hazelnut.
			var base := PackedVector2Array()
			for i in 13:
				var a := PI * float(i) / 12.0
				base.append(c + Vector2(cos(a) * 7.0, sin(a) * 4.0 + 4.5))
			draw_colored_polygon(base, Color(0.88, 0.78, 0.60))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.09, 0.62)
	style.set_corner_radius_all(18)
	style.content_margin_left = 14.0
	style.content_margin_right = 16.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 14)
	add_child(_row)
	for kind in WorldSave.KINDS:
		var icon := NutIcon.new(kind)
		_row.add_child(icon)
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
		label.text = str(WorldSave.resource(kind))
		label.custom_minimum_size = Vector2(36, 0)
		_row.add_child(label)
		_labels[kind] = label
		_icons[kind] = icon
	_apply_visibility()
	WorldSave.resources_changed.connect(_on_resources_changed)
	WorldSave.reset_done.connect(_refresh)
	# Anchored top-right by hand; the scene may not know our size yet.
	pivot_offset = size * 0.5
	_awake_left = AWAKE_S + 1.0
	modulate.a = 1.0

func _process(delta: float) -> void:
	if _awake_left <= 0.0:
		return
	_awake_left -= delta
	if _awake_left <= 0.0:
		_fade_to(GHOST_ALPHA)

func _refresh() -> void:
	for kind in _labels.keys():
		_labels[kind].text = str(WorldSave.resource(kind))
	_apply_visibility()
	_wake()

## v5: the rare kinds only appear once the player holds one -- the HUD
## stays two counters wide until the world has shown it has more to give.
const APPEARS_WHEN_HELD: Array[StringName] = [&"ladybug", &"golden"]
var _icons: Dictionary = {}

func _apply_visibility() -> void:
	for kind in _labels.keys():
		var show: bool = not APPEARS_WHEN_HELD.has(kind) or WorldSave.resource(kind) > 0
		_labels[kind].visible = show
		if _icons.has(kind):
			_icons[kind].visible = show

func _on_resources_changed(kind: StringName, total: int, delta: int) -> void:
	if _labels.has(kind):
		_labels[kind].text = str(total)
	_apply_visibility()
	_wake()
	if delta > 0:
		_punch()

func _wake() -> void:
	_awake_left = AWAKE_S
	_fade_to(1.0)

func _fade_to(alpha: float) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, FADE_S if alpha < 1.0 else 0.15)

## A short scale punch on a pickup: the counter is the reward's last beat.
func _punch() -> void:
	pivot_offset = size * 0.5
	if _bump != null and _bump.is_valid():
		_bump.kill()
	scale = Vector2.ONE * BUMP_SCALE
	_bump = create_tween()
	_bump.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## For probes: the text currently shown per kind.
func shown() -> Dictionary:
	var out := {}
	for kind in _labels.keys():
		out[String(kind)] = _labels[kind].text
	return out
