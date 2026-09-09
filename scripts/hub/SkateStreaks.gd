extends Control
class_name SkateStreaks
## CH62 EFFECT 2 -- THE ONE THING ON SCREEN THAT SAYS "FAST" WITHOUT
## BEING LOOKED AT.
##
## =====================================================================
## WHY STREAKS AT THE EDGE, AND NOT A TRAIL, A BLUR OR A BIG FOV PUMP
##
## Four candidates were on the brief. What decided it is the frame budget
## and the hub's style, in that order:
##
##   * A DIRECTIONAL BLUR is a full-screen fragment pass. CLAUDE.md
##     prices those explicitly ("un cout par fragment ne devient un cout
##     par frame qu'une fois multiplie par la COUVERTURE REELLE"), and
##     the north lobe has ZERO budget (CH52). A pass over 2 073 600
##     pixels on a phone that is already dropping one frame in three is
##     the one thing this lot must not ship.
##   * A TRAIL behind the board is world geometry: a MultiMesh or a ribbon,
##     so primitives AND a draw call AND a winding question (CH39). It is
##     also the least legible of the four on this camera -- the board is
##     124 px tall and a trail lives behind it, i.e. under Keepy.
##   * A BIG FOV PUMP is the runner-arcade tell the brief bans, and a
##     wider frustum admits more of the park, which costs primitives at
##     the exact station where there are none. A SMALL one ships anyway,
##     inside the camera, where it is measured.
##   * STREAKS drawn as textured rects from ONE texture are ONE DRAW CALL
##     for all of them (CH46 measured exactly this: 37 markers plus a
##     background from a single atlas cost +1 call and +76 primitives,
##     against +38 calls for the same thing drawn as circles), and their
##     coverage is a couple of percent of the screen rather than all of
##     it.
##
## And they are at the EDGE because that is where speed is actually read.
## The centre of the frame holds the board and the rider, which is what
## the player is looking AT; motion in the periphery is what the eye
## integrates as velocity without being pointed at it. It is also the
## half of the screen this game has nothing else in.
##
## =====================================================================
## COZY, NOT ARCADE -- THE THREE THINGS THAT KEEP IT QUIET
##
## 1. PEAK ALPHA 0.16 (SkateFeel.STREAK_ALPHA). A screenshot barely shows
##    them. The brief: "en cas de doute, moins fort plutot que plus".
## 2. NO HARD EDGE ANYWHERE. The strip texture is feathered across its
##    width AND along its length, so a streak has no ends and no sides --
##    it is a smear of light, not a line.
## 3. WARM WHITE, never cyan or white-hot. The hub's light is warm and a
##    cold streak would read as a different game's UI.
##
## =====================================================================
## WHAT IT READS, AND WHY IT READS IT FROM THE CAMERA
##
## `rush` comes from HubCamera -- `ride_rush() * ride_blend()` -- and is
## NOT recomputed here from the board's speed. CLAUDE.md: un fait est
## publie une fois. The camera already owns the smoothed reading and the
## fade in and out of the whole effect; a second copy here would be a
## second chance for the streaks to disagree with the dolly about how
## fast the player is going, and nothing on screen would say which was
## right.
##
## Consequence, stated rather than discovered: with the physics switch
## down nothing ever calls `enter_ride`, so `ride_blend()` is 0.0, so
## `_rush` is 0.0, so `_draw` returns on its first line and this node
## costs exactly nothing. That is the whole of PHASE O for this effect.

## How wide each edge band is, as a fraction of the control's width. The
## streaks are scattered inside these two bands and never enter the
## middle, where the board is.
const BAND: float = 0.17
## Streaks per side. Fourteen total: enough that the eye reads a FIELD
## rather than counting lines, few enough that the whole effect stays one
## batch of fourteen quads.
const PER_SIDE: int = 7
## ⚠️ EVERY DIMENSION BELOW IS A FRACTION OF THE CONTROL, NEVER A PIXEL
## COUNT, and that is a measurement and not a preference: written in
## absolute pixels the same field inked 0.694 % of a 1920-tall headless
## surface and 1.233 % of the xvfb window -- the SAME code reading twice
## as strong on one screen as on another, with nothing to say which one
## the phone would get. In fractions the ink is a constant and the bench
## can publish it as one.
##
## Screen HEIGHTS per second of downward scroll at full rush. The ground
## under a board at cruise crosses the frame in a bit under a second, so
## this is the same order and reads as belonging to the world rather than
## as an overlay running at its own speed.
const SCROLL: float = 1.35
const LENGTH_MIN: float = 0.080
const LENGTH_MAX: float = 0.220
const WIDTH_MIN: float = 0.0055
const WIDTH_MAX: float = 0.0115
## Warm white, deliberately not pure white.
const TINT: Color = Color(1.0, 0.97, 0.90)
## The feathered strip, baked once. Small on purpose: it is stretched to
## every streak's rect, and a 16 x 64 gradient has no detail to lose.
const STRIP_W: int = 16
const STRIP_H: int = 64
## Fixed seed: the scatter has to be the SAME every run, or a capture
## taken twice of the same tree would differ for no reason (CH37's rule
## about a bench that cannot reproduce itself).
const SEED: int = 620062

@export var camera_path: NodePath

var _camera: Node = null
var _strip: ImageTexture = null
var _rush: float = 0.0
var _t: float = 0.0
## One entry per streak: x fraction inside its band, phase offset, length,
## width, speed factor. Built once from SEED.
var _lanes: Array[Dictionary] = []

func _ready() -> void:
	# ⚠️ IGNORE, EXPLICITLY. CLAUDE.md: a Control defaults to STOP and a
	# full-screen one at STOP eats every tap on the plateau -- the exact
	# silent failure that shipped once already. This node must never see
	# an event.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_camera = get_node_or_null(camera_path)
	if _camera == null:
		push_error("SkateStreaks: camera_path does not resolve.")
	_build_lanes()
	_build_strip()

func _build_lanes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for side in [-1.0, 1.0]:
		for i in PER_SIDE:
			_lanes.append({
				"side": side,
				"across": rng.randf(),
				"phase": rng.randf(),
				# Fractions of the control, resolved against its real size
				# at draw time -- see the constants.
				"length": lerpf(LENGTH_MIN, LENGTH_MAX, rng.randf()),
				"width": lerpf(WIDTH_MIN, WIDTH_MAX, rng.randf()),
				# Different speeds so the field has parallax inside itself
				# -- a dozen streaks all moving at one speed reads as a
				# texture sliding, which is the arcade look.
				"rate": lerpf(0.65, 1.35, rng.randf()),
				"alpha": lerpf(0.45, 1.0, rng.randf()),
			})

## A vertical smear: opaque down the middle of its width, feathered to
## zero at both sides, and faded to zero at both ends of its length. Baked
## once, into ONE texture, which is what makes the whole field a single
## draw call.
func _build_strip() -> void:
	var img := Image.create(STRIP_W, STRIP_H, false, Image.FORMAT_RGBA8)
	for y in STRIP_H:
		var v: float = float(y) / float(STRIP_H - 1)
		# sin over the full length: zero at both ends, one in the middle.
		var along: float = sin(v * PI)
		along = along * along
		for x in STRIP_W:
			var u: float = float(x) / float(STRIP_W - 1)
			var across: float = sin(u * PI)
			across = across * across
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, along * across))
	_strip = ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	var wanted: float = 0.0
	if _camera != null and is_instance_valid(_camera) and _camera.has_method("ride_rush"):
		wanted = float(_camera.call("ride_rush")) * float(_camera.call("ride_blend"))
	# The scroll clock only advances while something is showing, so a
	# ride that starts an hour into a session starts at the same phase as
	# one that starts at the spawn -- the field cannot arrive mid-stride.
	if wanted <= 0.0:
		_t = 0.0
		if _rush != 0.0:
			# One last redraw to CLEAR the field. Without it the streaks
			# would freeze on screen at whatever alpha the last frame of
			# the fade-out left them.
			_rush = 0.0
			queue_redraw()
		return
	_rush = wanted
	_t += delta * _rush
	queue_redraw()

## Published for the bench: what the streaks are currently drawn at.
func rush() -> float:
	return _rush

func peak_alpha() -> float:
	return SkateFeel.streak_alpha(_rush)

## How much of the control's area the streaks cover at full rush, as a
## fraction. Published rather than estimated because CLAUDE.md prices a
## fragment effect by its COVERAGE and nothing else -- a probe reads this
## instead of guessing from the constants. Resolution-independent, since
## every dimension is itself a fraction.
func coverage() -> float:
	var r: Rect2 = get_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return 0.0
	var ink: float = 0.0
	for lane in _lanes:
		ink += float(lane["width"]) * float(lane["length"])
	return ink

func _draw() -> void:
	if _rush <= 0.0 or _strip == null:
		return
	var size: Vector2 = get_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var alpha: float = SkateFeel.streak_alpha(_rush)
	var band_px: float = size.x * BAND
	var region := Rect2(0.0, 0.0, float(STRIP_W), float(STRIP_H))
	for lane in _lanes:
		var length: float = float(lane["length"]) * size.y
		var width: float = float(lane["width"]) * size.x
		var span: float = size.y + length
		# Downward, because the camera sits behind and above: a board
		# moving away from the player has the ground streaming toward the
		# bottom of the frame whatever direction it is actually heading.
		var y: float = fmod(float(lane["phase"]) * span + _t * SCROLL * float(lane["rate"]), span) - length
		var x: float = float(lane["across"]) * (band_px - width)
		if float(lane["side"]) > 0.0:
			x = size.x - band_px + x
		var tint := TINT
		tint.a = alpha * float(lane["alpha"])
		# ⚠️ THE RECT IS ROUNDED TO WHOLE PIXELS. CLAUDE.md, CH48: a glyph
		# drawn 1:1 on a fractional origin loses its 1-to-2 pixel detail
		# -- a 6 px streak feathered to nothing at both sides is exactly
		# that kind of detail, and half of it would be thrown away by the
		# sampler for no gain at all.
		draw_texture_rect_region(_strip,
			Rect2(Vector2(x, y).round(), Vector2(width, length).round()), region, tint)
