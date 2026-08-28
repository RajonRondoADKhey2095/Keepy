extends Control
## TEMPORARY, THROWAWAY. Not a feature -- a live readout of Keepy's own
## world x/z, so Mathieu can walk to the exact spot he wants the future
## cabin on `keepy-staging.vercel.app` and read back the two numbers this
## repo needs to place it. Screenshots cannot answer that (no reliable
## world-space reading from a picture); two prior marker-based attempts
## could not either. Once he has the coordinate, this whole file and its
## one call site in HubWorld.gd are deleted, same as
## `CabinPlacementMarkers.gd` before it -- this branch is scoped to
## `staging` only, per the session brief.
##
## READS THE KEEPY NODE DIRECTLY, NEVER THE CAMERA. `HubCamera` lerps
## towards Keepy every frame and is offset from him by a fixed vector
## (`HubCamera.OFFSET`) -- reading the camera would report a position that
## is neither where Keepy stands nor a fixed offset from it once the lerp
## is mid-flight. `_keepy.global_position` is the single source of truth
## every other system on this screen (the hopper itself, `HubRegion`,
## `HubWater`) already reads.
##
## TOP-LEFT, NEVER THE CENTRE. `FallbackButton` in HubWorld.tscn owns the
## top-right corner (offset_top 32..116); nothing else claims screen space
## in this project's UI screens except centred panels. Top-left is clear
## on every screen that reuses this scene's chrome, and mirrors the
## reflex of putting a debug HUD where the eye checks first.
##
## MOUSE_FILTER LEFT AT DEFAULT (IGNORE for both Control and Label),
## NEVER SET TO STOP -- this repo has already paid for that mistake once
## on this exact screen (HubWorld's own root Control had to be forced to
## MOUSE_FILTER_IGNORE after it silently ate every tap under it). A
## Label's own default is already IGNORE; this file does not touch it,
## precisely so a future edit that copies this pattern does not have to
## remember to.


const REFRESH_S: float = 0.2

const _PANEL_MARGIN: float = 24.0
const _PANEL_TOP: float = 32.0


var _keepy: Node3D = null
var _label: Label = null
var _elapsed: float = REFRESH_S # forces a first draw on the very first frame


## Called once by HubWorld._ready() right after this node is added to the
## tree. Takes the live KeepyHopper reference rather than a NodePath so
## there is exactly one place (HubWorld.gd) that knows where Keepy lives.
func track(keepy: Node3D) -> void:
	_keepy = keepy
	_refresh_text()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = _PANEL_MARGIN
	offset_top = _PANEL_TOP

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	# Semi-opaque scrim behind the text, not just an outline -- the decor
	# this overlay sits on top of cycles from a lit-ish swamp green to a
	# near-black "deep mist" phase (GameState's mist cycle, mirrored in
	# this hub's own fog), so a fixed-colour outline alone would wash out
	# against whichever phase happens to be behind it at the moment.
	style.bg_color = Color(0.086, 0.055, 0.031, 0.82)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 28)
	# Outline on top of the panel scrim, belt-and-braces: the panel alone
	# already clears WCAG-style contrast against both mist phases, but an
	# outline costs nothing and is what every other on-screen label in
	# this project (Label3D markers, HUD text) already carries.
	_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	_label.add_theme_constant_override("outline_size", 4)
	panel.add_child(_label)

	_refresh_text()


func _process(delta: float) -> void:
	if _keepy == null:
		return
	_elapsed += delta
	if _elapsed < REFRESH_S:
		return
	_elapsed = 0.0
	_refresh_text()


func _refresh_text() -> void:
	if _label == null:
		return
	if _keepy == null:
		_label.text = "x: --  z: --"
		return
	var pos: Vector3 = _keepy.global_position
	_label.text = "x: %.2f  z: %.2f" % [pos.x, pos.z]
