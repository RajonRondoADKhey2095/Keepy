extends Control
class_name KartHud
## What the driver sees over the world: the chrono, the exit button and
## the ghost of the steering finger. Shown only while driving.
##
## Built in code rather than in the .tscn, like WorldHud's row: the layout
## is three numbers and a button, and a hand-written .tscn with typed node
## exports is the trap CLAUDE.md documents. The root passes every tap
## through (MOUSE_FILTER_IGNORE); only the button stops one -- a full-rect
## Control left at the default STOP would swallow the steering (the
## measured HubTapInput failure, in the other direction).
##
## V7b adds two things, both stopping a tap on purpose: a small "Direction
## (dev)" preset row (8/7/6, KartTuning), built only behind
## DevTools.enabled() so a normal player never sees or builds it; and a
## permanent one-line hint under the chrono for the new accelerator push
## (retour 1), shown to every driver. `_draw()`'s ghost also grew a
## vertical half for the same reason: the push has to be discoverable, not
## just documented in a journal nobody driving reads.

signal exit_pressed

const TOP: float = 150.0
const RECORD_FLASH_S: float = 2.6

var _panel: PanelContainer = null
var _lap_label: Label = null
var _best_label: Label = null
var _last_label: Label = null
var _lap_count_label: Label = null
var _wrong_label: Label = null
var _record_label: Label = null
var _exit_button: Button = null
var _flash_left: float = 0.0
var _ghost_anchor: Vector2 = Vector2.ZERO
var _ghost_finger: Vector2 = Vector2.ZERO
var _ghost_active: bool = false
## V7b dev-only steering preset row (DevTools.enabled()): empty for a
## normal player, so nothing is built or drawn for them.
var _preset_buttons: Array[Button] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.10, 0.08, 0.62)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(540.0 - 190.0, TOP)
	_panel.custom_minimum_size = Vector2(380.0, 0.0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)
	_lap_count_label = _label(box, 24, Color(1.0, 0.92, 0.72))
	_lap_label = _label(box, 54, Color(1.0, 0.98, 0.92))
	_best_label = _label(box, 26, Color(0.92, 0.88, 0.78))
	_last_label = _label(box, 22, Color(0.80, 0.78, 0.70))
	_wrong_label = Label.new()
	_wrong_label.text = "↩  DEMI-TOUR"
	_wrong_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wrong_label.add_theme_font_size_override("font_size", 44)
	_wrong_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.30))
	_wrong_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.05, 0.9))
	_wrong_label.add_theme_constant_override("outline_size", 8)
	_wrong_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wrong_label.set_anchors_preset(Control.PRESET_CENTER)
	_wrong_label.position = Vector2(540.0 - 220.0, 700.0)
	_wrong_label.size = Vector2(440.0, 60.0)
	_wrong_label.visible = false
	add_child(_wrong_label)
	_record_label = Label.new()
	_record_label.text = "★  NOUVEAU RECORD  ★"
	_record_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_record_label.add_theme_font_size_override("font_size", 46)
	_record_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
	_record_label.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.02, 0.9))
	_record_label.add_theme_constant_override("outline_size", 8)
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record_label.position = Vector2(540.0 - 300.0, 600.0)
	_record_label.size = Vector2(600.0, 60.0)
	_record_label.visible = false
	add_child(_record_label)
	# The exit: a real button, STOP filter, top-left under the safe area,
	# clear of WorldHud (top-right) and the dev menu button.
	_exit_button = Button.new()
	_exit_button.text = "⤓  Descendre"
	_exit_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_exit_button.add_theme_font_size_override("font_size", 30)
	_exit_button.custom_minimum_size = Vector2(260.0, 84.0)
	_exit_button.position = Vector2(32.0, TOP)
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.98, 0.93, 0.80, 0.94)
	bstyle.corner_radius_top_left = 22
	bstyle.corner_radius_top_right = 22
	bstyle.corner_radius_bottom_left = 22
	bstyle.corner_radius_bottom_right = 22
	_exit_button.add_theme_stylebox_override("normal", bstyle)
	_exit_button.add_theme_stylebox_override("hover", bstyle)
	_exit_button.add_theme_stylebox_override("pressed", bstyle)
	_exit_button.add_theme_color_override("font_color", Color(0.25, 0.18, 0.10))
	_exit_button.add_theme_color_override("font_pressed_color", Color(0.25, 0.18, 0.10))
	_exit_button.add_theme_color_override("font_hover_color", Color(0.25, 0.18, 0.10))
	_exit_button.pressed.connect(func(): exit_pressed.emit())
	add_child(_exit_button)
	# V7b: the hint for the new accelerator (retour 1) -- always shown,
	# unlike the preset row below, since every player gets the boost.
	var hint := _label(box, 16, Color(0.85, 0.80, 0.68))
	hint.text = "↑  pousser le pouce pour foncer"
	set_times(0, 0, 0, 0, false)
	if DevTools.enabled():
		_build_preset_row()

func _label(parent: Control, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label

func exit_button() -> Button:
	return _exit_button

## `lap_ms` is the running lap (0 before the first crossing).
func set_times(lap_ms: int, best_ms: int, last_ms: int, lap_count: int, timing: bool) -> void:
	_lap_count_label.text = ("TOUR %d" % (lap_count + 1)) if timing else "PASSE LA LIGNE"
	_lap_label.text = KartLap.format_ms(lap_ms) if timing else "--:--.--"
	_best_label.text = "MEILLEUR  " + KartLap.format_ms(best_ms)
	_last_label.text = ("DERNIER  " + KartLap.format_ms(last_ms)) if last_ms > 0 else ""

func set_wrong_way(on: bool) -> void:
	_wrong_label.visible = on

func flash_record() -> void:
	_flash_left = RECORD_FLASH_S
	_record_label.visible = true

func set_ghost(anchor: Vector2, finger: Vector2, active: bool) -> void:
	_ghost_anchor = anchor
	_ghost_finger = finger
	_ghost_active = active
	queue_redraw()

func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		_record_label.modulate.a = clampf(_flash_left / 0.6, 0.0, 1.0)
		if _flash_left <= 0.0:
			_record_label.visible = false
			_record_label.modulate.a = 1.0

func _draw() -> void:
	if not _ghost_active:
		return
	var a := _ghost_anchor
	# Steering: horizontal half of the drag, span from the active preset.
	var span: float = KartTuning.steer_span()
	var dx: float = clampf(_ghost_finger.x - a.x, -span, span)
	draw_line(a + Vector2(-span, 0.0), a + Vector2(span, 0.0), Color(1.0, 1.0, 1.0, 0.22), 6.0)
	draw_circle(a, 22.0, Color(1.0, 1.0, 1.0, 0.25))
	draw_circle(a + Vector2(dx, 0.0), 30.0, Color(1.0, 0.95, 0.80, 0.55))
	# V7b accelerator: the vertical half of the SAME drag, previously
	# unused (drawn so the push is discoverable, not just documented).
	var boost_span: float = KartTouchInput.BOOST_SPAN
	var dy: float = clampf(a.y - _ghost_finger.y, 0.0, boost_span)
	draw_line(a, a + Vector2(0.0, -boost_span), Color(1.0, 1.0, 1.0, 0.14), 6.0)
	var boost_t: float = clampf((dy - KartTouchInput.BOOST_DEAD_ZONE) / (boost_span - KartTouchInput.BOOST_DEAD_ZONE), 0.0, 1.0)
	draw_circle(a + Vector2(0.0, -dy), 24.0, Color(1.0, 0.55, 0.20, 0.22 + 0.5 * boost_t))

## ---- V7b dev-only steering presets (DevTools.enabled()) -----------------

func _build_preset_row() -> void:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.position = Vector2(32.0, TOP + 84.0 + 10.0)
	add_child(col)
	var caption := Label.new()
	caption.text = "Direction (dev)"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.75))
	col.add_child(caption)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	for i in KartTuning.PRESETS.size():
		var b := Button.new()
		b.text = String(KartTuning.PRESETS[i]["label"])
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(64.0, 56.0)
		b.pressed.connect(_on_preset_pressed.bind(i))
		row.add_child(b)
		_preset_buttons.append(b)
	_refresh_preset_row()

func _on_preset_pressed(i: int) -> void:
	KartTuning.set_index(i)
	_refresh_preset_row()

func _refresh_preset_row() -> void:
	for i in _preset_buttons.size():
		_preset_buttons[i].button_pressed = (i == KartTuning.index())
