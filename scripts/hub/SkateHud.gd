extends Control
class_name SkateHud
## CH53 -- WHAT A RIDER SEES, AND NOTHING ELSE.
##
## =====================================================================
## IT READS, IT NEVER DECIDES
##
## WorldHud reads WorldSave; KartHud reads HubKarting; this reads
## HubSkatepark. Zero business logic: it is handed a trick that has
## already been scored and a chain that has already been counted, and its
## whole job is to put them on the glass. CH51 asked for exactly that,
## and the reason is that a HUD which re-derives a rule is a second copy
## of that rule -- the "un fait est publié une fois" defect, in the one
## place nobody looks for it.
##
## =====================================================================
## TWO GATES THAT ARE NOT STYLE
##
## 1. `mouse_filter` IS WRITTEN EXPLICITLY, on the root and on every
##    child. Control's default is STOP, GUI picking runs BEFORE
##    `_unhandled_input`, and a full-rect Control left at the default
##    swallows every tap on the plateau -- measured, twice, in this repo
##    (HubTapInput's own header, and KartHud's). Nothing here is a
##    button, so everything is IGNORE.
##
## 2. THE RECT IS GATED AGAINST THE 1080 BAND, NOT THE CANVAS. After
##    `set_anchors_preset`, `position` is an OFFSET FROM THE ANCHOR. The
##    V7 kart panel wrote a canvas coordinate into it, landed its left
##    edge at 890 px on a 1080 px canvas, and shipped half-clipped --
##    invisible in headless, where the canvas is 1920 wide and everything
##    "fits". SkateparkProbe PHASE H asserts this panel's rect inside the
##    1080-wide band centred on the canvas middle, which is the shape
##    CLAUDE.md prescribes after that bill.
##
## =====================================================================
## WHY IT SAYS WHEN THE PARK STOPS PAYING
##
## Mathieu's G3 variant, in one line: the combo keeps running when the
## stock is empty, only the conversion stops. A HUD that showed the combo
## and said nothing about the nuts would make the guard read as a bug --
## the player sees a trick score and no nut appear, with no explanation
## anywhere on the screen. `WorldSave.award_from_activity` returns what
## it actually granted precisely so this label can be honest without
## re-deriving the guard.

## How long a trick stays up after the chain has gone.
const HOLD_S: float = 2.2
const FADE_S: float = 0.55
const PANEL_WIDTH: float = 420.0
const TOP: float = 210.0

var _panel: PanelContainer = null
var _trick_label: Label = null
var _chain_label: Label = null
var _note_label: Label = null
var _left: float = 0.0
var _park: HubSkatepark = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_panel = PanelContainer.new()
	_panel.name = "SkatePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	# Concrete, not the kart's warm brown: the panel belongs to the park.
	style.bg_color = Color(0.14, 0.15, 0.17, 0.62)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	# The OFFSET, not a canvas coordinate -- see the header.
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.position = Vector2(-PANEL_WIDTH * 0.5, TOP)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)
	_trick_label = _label(box, 46, Color(1.0, 0.99, 0.94))
	_chain_label = _label(box, 28, Color(0.98, 0.86, 0.52))
	_note_label = _label(box, 22, Color(0.82, 0.84, 0.88))

func _label(parent: Node, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.07, 0.09, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	return label

## Wired by HubWorld, the coordinator shape. The HUD listens to the park;
## the park never knows the HUD exists.
func setup(park: HubSkatepark) -> void:
	_park = park
	_park.trick_scored.connect(_on_trick_scored)
	_park.chain_broken.connect(_on_chain_broken)

func _on_trick_scored(_module: int, trick: StringName, points: int, chain: int) -> void:
	_trick_label.text = "%s  +%d" % [String(trick).to_upper(), points]
	_chain_label.text = "CHAÎNE x%d" % (chain + 1) if chain > 0 else ""
	_chain_label.visible = chain > 0
	# The guard, said out loud. `last_award()` is what the ledger actually
	# credited, never a re-derivation of the rule.
	if _park != null and _park.last_award() > 0:
		_note_label.text = "+%d 🌰" % _park.last_award()
	elif WorldSave.skate_stock() <= 0:
		_note_label.text = "le park est vide — il se recharge"
	else:
		_note_label.text = ""
	_note_label.visible = not _note_label.text.is_empty()
	_left = HOLD_S + FADE_S
	visible = true
	modulate.a = 1.0

func _on_chain_broken() -> void:
	_chain_label.visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		visible = false
		return
	modulate.a = clampf(_left / FADE_S, 0.0, 1.0)

## The panel's rect in canvas pixels. Read by SkateparkProbe rather than
## re-derived from the constants above: a probe that recomputes a layout
## measures its own arithmetic, not the widget.
func panel_rect() -> Rect2:
	return Rect2(_panel.global_position, _panel.size)
