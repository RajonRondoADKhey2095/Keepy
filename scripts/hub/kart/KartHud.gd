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
const PANEL_WIDTH: float = 380.0
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
## CH31 -- the accelerator gauge. Written every frame while driving, so it
## is drawn whether or not a finger is on the screen.
var _boost: float = 0.0
var _speed: float = 0.0
var _speed_max: float = 1.0
var _gauge_live: bool = false
## V7b dev-only steering preset row (DevTools.enabled()): empty for a
## normal player, so nothing is built or drawn for them.
var _preset_buttons: Array[Button] = []
var _difficulty_buttons: Array[Button] = []
var _preset_row: Control = null
## V8 race widgets: the lights, the position, the standings, the results.
var _lights: Array[ColorRect] = []
var _lights_box: HBoxContainer = null
var _go_label: Label = null
var _position_label: Label = null
var _standings_box: VBoxContainer = null
var _standings_rows: Array[Dictionary] = []
var _results_panel: PanelContainer = null
var _results_box: VBoxContainer = null
var _clock_label: Label = null

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
	# V8 P0: anchored CENTER_TOP, so `position` is an OFFSET FROM THE
	# ANCHOR (the canvas' horizontal middle), not a canvas coordinate. The
	# V7 build wrote the canvas coordinate (540 - 190) here, which put the
	# panel's left edge at 540 + 350 = 890 px on a 1080 px canvas: 190 px
	# visible, 190 px clipped by the right edge -- Mathieu's device capture
	# ("TOUR / MEILLEUR / DERNIER coupes"). The right offset is -190, and
	# the panel is then centred whatever the canvas width (SafeArea's
	# EXPAND aspect grows the canvas vertically only, so the middle is
	# always x = width / 2).
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(-PANEL_WIDTH * 0.5, TOP)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
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
	# Same anchor rule (V8 P0): PRESET_CENTER makes `position` an offset
	# from the canvas centre, so the V7 (320, 700) put this label at
	# x = 860..1300 -- clipped like the panel. Centred now, 260 px above
	# the middle of the screen.
	_wrong_label.set_anchors_preset(Control.PRESET_CENTER)
	_wrong_label.position = Vector2(-220.0, -260.0)
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
	_build_race_widgets()
	if DevTools.enabled():
		_build_preset_row()

## ---- V8: the race widgets --------------------------------------------------
## All anchored by OFFSET FROM THE ANCHOR (P0's lesson): a canvas
## coordinate written after set_anchors_preset() is a clipped widget.
## Everything here passes taps through (IGNORE); nothing is a button.

const LIGHT_SIZE: float = 74.0
const LIGHT_OFF: Color = Color(0.20, 0.16, 0.14, 0.85)
const LIGHT_RED: Color = Color(0.95, 0.24, 0.20, 1.0)
const LIGHT_GREEN: Color = Color(0.36, 0.90, 0.40, 1.0)
const STANDINGS_WIDTH: float = 250.0

func _build_race_widgets() -> void:
	# The lights: three discs in a row, centred, above the middle of the
	# screen, lit one by one through the countdown, all green at GO.
	_lights_box = HBoxContainer.new()
	_lights_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lights_box.add_theme_constant_override("separation", 26)
	_lights_box.set_anchors_preset(Control.PRESET_CENTER)
	var row_w: float = 3.0 * LIGHT_SIZE + 2.0 * 26.0
	_lights_box.position = Vector2(-row_w * 0.5, -420.0)
	_lights_box.visible = false
	add_child(_lights_box)
	for i in 3:
		var light := ColorRect.new()
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		light.custom_minimum_size = Vector2(LIGHT_SIZE, LIGHT_SIZE)
		light.color = LIGHT_OFF
		_lights_box.add_child(light)
		_lights.append(light)
	_go_label = Label.new()
	_go_label.text = "GO !"
	_go_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_go_label.add_theme_font_size_override("font_size", 96)
	_go_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	_go_label.add_theme_color_override("font_outline_color", Color(0.05, 0.25, 0.08, 0.95))
	_go_label.add_theme_constant_override("outline_size", 12)
	_go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_label.set_anchors_preset(Control.PRESET_CENTER)
	_go_label.position = Vector2(-250.0, -330.0)
	_go_label.size = Vector2(500.0, 120.0)
	_go_label.visible = false
	add_child(_go_label)
	# The position: big, under the exit button, left.
	_position_label = Label.new()
	_position_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_position_label.add_theme_font_size_override("font_size", 64)
	_position_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	_position_label.add_theme_color_override("font_outline_color", Color(0.15, 0.10, 0.06, 0.9))
	_position_label.add_theme_constant_override("outline_size", 8)
	_position_label.position = Vector2(36.0, TOP + 84.0 + 96.0)
	_position_label.visible = false
	add_child(_position_label)
	# The standings: four rows of a colour chip and a name, top-right
	# under the Menu button, in the column the resource counter leaves
	# free while driving.
	_standings_box = VBoxContainer.new()
	_standings_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_standings_box.add_theme_constant_override("separation", 6)
	_standings_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_standings_box.position = Vector2(-STANDINGS_WIDTH - 24.0, TOP + 4.0)
	_standings_box.custom_minimum_size = Vector2(STANDINGS_WIDTH, 0.0)
	_standings_box.visible = false
	add_child(_standings_box)
	# The race clock, under the standings.
	_clock_label = Label.new()
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_label.add_theme_font_size_override("font_size", 22)
	_clock_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock_label.position = Vector2(-STANDINGS_WIDTH - 24.0, TOP + 4.0 + 4.0 * 46.0 + 8.0)
	_clock_label.size = Vector2(STANDINGS_WIDTH, 30.0)
	_clock_label.visible = false
	add_child(_clock_label)
	# The results: a centred panel, one row per racer, shown at the flag.
	_results_panel = PanelContainer.new()
	_results_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.10, 0.08, 0.80)
	style.set_corner_radius_all(22)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 18
	style.content_margin_bottom = 20
	_results_panel.add_theme_stylebox_override("panel", style)
	_results_panel.set_anchors_preset(Control.PRESET_CENTER)
	_results_panel.position = Vector2(-260.0, -80.0)
	_results_panel.custom_minimum_size = Vector2(520.0, 0.0)  # CH31: the dev rows below set their own font small enough to fit
	_results_panel.visible = false
	add_child(_results_panel)
	_results_box = VBoxContainer.new()
	_results_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_box.add_theme_constant_override("separation", 8)
	_results_panel.add_child(_results_box)

func _standings_row(index: int) -> Dictionary:
	while _standings_rows.size() <= index:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		var rank := Label.new()
		rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rank.add_theme_font_size_override("font_size", 24)
		rank.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
		rank.custom_minimum_size = Vector2(34.0, 0.0)
		row.add_child(rank)
		var chip := ColorRect.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.custom_minimum_size = Vector2(22.0, 22.0)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)
		var name_label := Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
		name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05, 0.9))
		name_label.add_theme_constant_override("outline_size", 6)
		row.add_child(name_label)
		_standings_box.add_child(row)
		_standings_rows.append({"row": row, "rank": rank, "chip": chip, "name": name_label})
	return _standings_rows[index]

static func ordinal(rank: int) -> String:
	return "1er" if rank == 1 else "%de" % rank

## The race widgets, once per frame from HubKarting. `rows` are the
## standings, leader first: {name, colour, player, finished}.
func set_race(state: int, countdown_left: float, rank: int, racers: int, lap_count: int, laps: int, rows: Array, clock_s: float) -> void:
	# CH30: a HUD lent to the yacht never shows race furniture, whatever
	# the karting coordinator is doing behind it.
	if _vehicle_mode:
		return
	var racing: bool = state != HubKarting.Race.IDLE
	_standings_box.visible = racing
	_position_label.visible = racing
	_clock_label.visible = state == HubKarting.Race.RUNNING or state == HubKarting.Race.FINISHED
	if state == HubKarting.Race.COUNTDOWN:
		_lights_box.visible = true
		_go_label.visible = false
		# The lights come on over the LAST three seconds: countdown_left is
		# the time to GO (the mount hold is already taken off by the caller).
		var lit: int = 0
		if countdown_left <= 3.0:
			lit = clampi(3 - int(ceil(countdown_left)) + 1, 0, 3)
		for i in 3:
			_lights[i].color = LIGHT_RED if i < lit else LIGHT_OFF
	elif state == HubKarting.Race.RUNNING:
		for i in 3:
			_lights[i].color = LIGHT_GREEN
		# Lights and GO linger for the first second and a half of the race.
		_lights_box.visible = clock_s < 1.5
		_go_label.visible = clock_s < 1.5
	else:
		_lights_box.visible = false
		_go_label.visible = false
	if racing:
		_position_label.text = "%s / %d" % [ordinal(rank), racers]
		_lap_count_label.text = "TOUR %d / %d" % [clampi(lap_count + 1, 1, laps), laps] if state != HubKarting.Race.FINISHED else "ARRIVÉE"
		for i in rows.size():
			var r: Dictionary = _standings_row(i)
			(r["row"] as HBoxContainer).visible = true
			(r["rank"] as Label).text = str(i + 1)
			(r["chip"] as ColorRect).color = rows[i]["colour"]
			var label: Label = r["name"]
			label.text = String(rows[i]["name"]) + ("  ✓" if bool(rows[i]["finished"]) else "")
			label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30) if bool(rows[i]["player"]) else Color(1.0, 0.96, 0.86))
		for i in range(rows.size(), _standings_rows.size()):
			(_standings_rows[i]["row"] as HBoxContainer).visible = false
		_clock_label.text = KartLap.format_ms(int(round(clock_s * 1000.0)))

## The results table at the flag: {name, colour, rank, finish_ms,
## best_lap_ms, player}, finishing order.
func show_results(rows: Array) -> void:
	for c in _results_box.get_children():
		c.queue_free()
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mine: int = 0
	for r in rows:
		if bool(r["player"]):
			mine = int(r["rank"])
	title.text = "★  VICTOIRE  ★" if mine == 1 else "%s place" % ordinal(mine)
	_results_box.add_child(title)
	for r in rows:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		var rank := Label.new()
		rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rank.text = ordinal(int(r["rank"]))
		rank.add_theme_font_size_override("font_size", 28)
		rank.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
		rank.custom_minimum_size = Vector2(70.0, 0.0)
		row.add_child(rank)
		var chip := ColorRect.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.custom_minimum_size = Vector2(24.0, 24.0)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.color = r["colour"]
		row.add_child(chip)
		var name_label := Label.new()
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.text = String(r["name"])
		name_label.add_theme_font_size_override("font_size", 28)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30) if bool(r["player"]) else Color(1.0, 0.96, 0.86))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var time_label := Label.new()
		time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ms: int = int(r["finish_ms"])
		time_label.text = KartLap.format_ms(ms) if ms > 0 else "…"
		time_label.add_theme_font_size_override("font_size", 26)
		time_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
		row.add_child(time_label)
		_results_box.add_child(row)
	if DevTools.enabled():
		_append_dev_readout(rows)
	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "roule encore, ou Descendre pour une nouvelle course"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.85, 0.80, 0.68))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_box.add_child(hint)
	_results_panel.visible = true

## CH30 -- THE DEV READOUT (?keepydev=1). Every racer's lap times and the
## gap at the flag, under the results panel, so a retour can be a table of
## numbers instead of "je gagne large". It is behind DevTools like the
## preset rows -- a player is shown the finishing order, not a timing
## sheet -- and it reads ONLY what HubKarting.results() already publishes.
func _append_dev_readout(rows: Array) -> void:
	var sep := Label.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.text = "— dev: tours, moyenne, pointe, contact (difficulte %s) —" % String(KartDifficulty.current()["label"])
	sep.add_theme_font_size_override("font_size", 16)
	sep.add_theme_color_override("font_color", Color(0.75, 0.72, 0.62))
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_results_box.add_child(sep)
	var winner_ms: int = 0
	for r in rows:
		var f: int = int(r["finish_ms"])
		if f > 0 and (winner_ms == 0 or f < winner_ms):
			winner_ms = f
	for r in rows:
		var line := Label.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var laps: Array = r.get("laps_ms", [])
		var texts: PackedStringArray = PackedStringArray()
		for ms in laps:
			texts.append("%.2f" % (float(int(ms)) / 1000.0))
		var f2: int = int(r["finish_ms"])
		var gap: String = "--" if (f2 <= 0 or winner_ms <= 0) else "%+.2f" % (float(f2 - winner_ms) / 1000.0)
		# CH31: mean lap, the top speed REALLY reached and the time spent
		# touching another kart, so a retour can be a table rather than an
		# impression (brief). Every field comes from HubKarting.results().
		line.text = "%-11s %-7s | %s | moy %.2f | pointe %.1f | contact %.1fs | ecart %s" % [
			String(r["name"]), String(r.get("profile", "")).substr(0, 7), " ".join(texts),
			float(int(r.get("mean_lap_ms", 0))) / 1000.0, float(r.get("top_speed", 0.0)),
			float(r.get("contact_s", 0.0)), gap]
		line.add_theme_font_size_override("font_size", 17)
		line.add_theme_color_override("font_color", Color(0.88, 0.84, 0.74))
		_results_box.add_child(line)

## CH30 -- VEHICLE MODE. The sand yacht is driven with the same thumb and
## the same writer as the kart, so it wants the same two widgets: the
## exit button and the steering ghost. Everything the RACE owns -- the
## lap panel, the lights, the standings, the clock, the results, the
## wrong-way banner, the two dev preset rows -- is hidden, rather than a
## second HUD scene existing to hold one button.
##
## The mode is a property of this node and not of the caller, so leaving
## either vehicle restores the race widgets and nothing has to remember
## which one it was.
var _vehicle_mode: bool = false

func set_vehicle_mode(on: bool) -> void:
	_vehicle_mode = on
	_gauge_live = false
	_panel.visible = not on
	_wrong_label.visible = false
	_record_label.visible = false
	if _lights_box != null:
		_lights_box.visible = false
	if _go_label != null:
		_go_label.visible = false
	if _position_label != null:
		_position_label.visible = false
	if _standings_box != null:
		_standings_box.visible = false
	if _clock_label != null:
		_clock_label.visible = false
	if _results_panel != null:
		_results_panel.visible = false
	if _preset_row != null:
		_preset_row.visible = not on

func vehicle_mode() -> bool:
	return _vehicle_mode

func set_results_visible(on: bool) -> void:
	_results_panel.visible = on

func results_visible() -> bool:
	return _results_panel.visible

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

## CH31 -- what the drive is DOING, for the accelerator gauge: the live
## boost 0..1, the speed, and the speed at full boost. Called every frame
## by HubKarting while the player is in the kart.
func set_drive_readout(boost: float, speed: float, speed_max: float) -> void:
	_boost = clampf(boost, 0.0, 1.0)
	_speed = speed
	_speed_max = maxf(speed_max, 0.01)
	_gauge_live = true
	queue_redraw()

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

## CH31 -- THE GAUGE IS DRAWN BEFORE THE GHOST, AND WITHOUT IT.
##
## The V7b ghost only existed while a finger was down (`_ghost_active`),
## so the accelerator's only permanent trace on screen was one 16 px line
## of text. Mathieu drove the kart and did not know the command existed.
## The gauge below is drawn for the whole drive: empty it is an invitation,
## full it is feedback, and it needs no sentence to explain it.
const GAUGE_W: float = 26.0
const GAUGE_H: float = 260.0
const GAUGE_MARGIN: float = 34.0

func _draw() -> void:
	if _gauge_live and not _vehicle_mode:
		_draw_boost_gauge()
	if not _ghost_active:
		return
	var a := _ghost_anchor
	# Steering: horizontal half of the drag, span from the active preset.
	var span: float = KartTuning.steer_span()
	var dx: float = clampf(_ghost_finger.x - a.x, -span, span)
	draw_line(a + Vector2(-span, 0.0), a + Vector2(span, 0.0), Color(1.0, 1.0, 1.0, 0.22), 6.0)
	draw_circle(a, 22.0, Color(1.0, 1.0, 1.0, 0.25))
	draw_circle(a + Vector2(dx, 0.0), 30.0, Color(1.0, 0.95, 0.80, 0.55))
	# V7b accelerator: the vertical half of the SAME drag, drawn so the
	# push is discoverable at the thumb as well as at the gauge.
	var boost_span: float = _touch_boost_span()
	var dy: float = clampf(a.y - _ghost_finger.y, 0.0, boost_span)
	draw_line(a, a + Vector2(0.0, -boost_span), Color(1.0, 1.0, 1.0, 0.14), 6.0)
	draw_circle(a + Vector2(0.0, -dy), 24.0, Color(1.0, 0.55, 0.20, 0.22 + 0.5 * _boost))
	# An arrow head at the top of the push track: it points where the thumb
	# has to go, and it is the only part of this that is a HINT rather than
	# a readout. It fades out as the push arrives, so it stops nagging.
	var tip: Vector2 = a + Vector2(0.0, -boost_span)
	var hint_a: float = 0.42 * (1.0 - _boost)
	if hint_a > 0.01:
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0.0, -14.0), tip + Vector2(-13.0, 8.0), tip + Vector2(13.0, 8.0)]),
			Color(1.0, 0.72, 0.30, hint_a))

## The push span of the KART's touch input. Read through the instance the
## HUD is actually serving rather than the class constant: the yacht keeps
## the V7b numbers and the kart does not (KartTouchInput, CH31).
func _touch_boost_span() -> float:
	return KartTouchInput.KART_BOOST_SPAN

## A vertical bar on the right: how much of the accelerator is being held,
## with the current speed under it. Bottom-anchored so a phone's notch and
## the lap panel are both out of its way.
func _draw_boost_gauge() -> void:
	var vp: Vector2 = size
	var x: float = vp.x - GAUGE_MARGIN - GAUGE_W
	var y: float = vp.y * 0.5 - GAUGE_H * 0.5
	var track_rect := Rect2(x, y, GAUGE_W, GAUGE_H)
	draw_rect(track_rect, Color(0.10, 0.09, 0.08, 0.42), true)
	draw_rect(track_rect, Color(1.0, 0.96, 0.86, 0.28), false, 2.0)
	# The FILL is the speed, not the boost: a bar that only moved when the
	# thumb moved would say "you are pushing", and what a driver wants to
	# read is "you are going faster". The boost is the bright cap on top.
	var t: float = clampf(_speed / _speed_max, 0.0, 1.0)
	var h: float = GAUGE_H * t
	draw_rect(Rect2(x, y + GAUGE_H - h, GAUGE_W, h), Color(1.0, 0.72, 0.30, 0.55 + 0.35 * _boost), true)
	# Where cruise ends and the push begins: the one tick a player needs.
	var cruise_t: float = clampf(1.0 / maxf(KartBody.BOOST_SPEED_RATIO, 1.0001), 0.0, 1.0)
	var cy: float = y + GAUGE_H * (1.0 - cruise_t)
	draw_line(Vector2(x - 6.0, cy), Vector2(x + GAUGE_W + 6.0, cy), Color(1.0, 0.96, 0.86, 0.55), 2.0)

## ---- V7b dev-only steering presets (DevTools.enabled()) -----------------

func _build_preset_row() -> void:
	var col := VBoxContainer.new()
	_preset_row = col
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
	# CH30: the difficulty row, on exactly the V7b pattern above -- same
	# column, same button size, switchable mid-session. It takes effect on
	# the NEXT race (KartAiDriver reads the preset in setup(), which
	# HubKarting calls on every grid-up), so a tap here is never a change
	# of pace in the middle of a corner.
	var caption2 := Label.new()
	caption2.text = "Difficulte (dev)"
	caption2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption2.add_theme_font_size_override("font_size", 16)
	caption2.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.75))
	col.add_child(caption2)
	var row2 := HBoxContainer.new()
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row2)
	for i in KartDifficulty.PRESETS.size():
		var b := Button.new()
		b.text = String(KartDifficulty.PRESETS[i]["label"])
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(76.0, 56.0)
		b.pressed.connect(_on_difficulty_pressed.bind(i))
		row2.add_child(b)
		_difficulty_buttons.append(b)
	_refresh_preset_row()

func _on_preset_pressed(i: int) -> void:
	KartTuning.set_index(i)
	_refresh_preset_row()

func _on_difficulty_pressed(i: int) -> void:
	KartDifficulty.set_index(i)
	_refresh_preset_row()

func _refresh_preset_row() -> void:
	for i in _preset_buttons.size():
		_preset_buttons[i].button_pressed = (i == KartTuning.index())
	for i in _difficulty_buttons.size():
		_difficulty_buttons[i].button_pressed = (i == KartDifficulty.index())
