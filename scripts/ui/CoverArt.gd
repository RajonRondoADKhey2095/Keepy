extends TextureRect
class_name CoverArt
## Horizontal framing for the forest cover art shared by LoginScreen, Hub and
## TitleScreen (assets/textures/ui/title_cover.png). Attached to their
## CoverImage node; nothing else in the project uses it.
##
## =====================================================================
## THE DEFECT IT FIXES -- MEASURED, NOT SPOTTED BY EYE
##
## The art is 720x1280 (9:16 exactly) and carries two PAINTED UI elements at
## its top: the "PLAYER: KEEPY / STATUS: CHASED" signboard on the left and the
## "KEEPY CHASED" banner in the middle. They are pixels of the background, not
## Controls, so nothing in the scene tree keeps them on screen.
##
## Until the letterbox lot the canvas was 9:16 too (window/stretch/aspect=
## "keep"), so KEEP_ASPECT_COVERED had nothing to crop and the signboard kept
## its margin. SafeArea.fill_screen() then made UI screens EXPAND, and on a
## 1170x2532 phone the canvas became 1080x2337 -- taller than 9:16, so COVERED
## started scaling the art by HEIGHT and cropping 117 canvas px off EACH side.
## The signboard starts 17px from the left edge of the source (31 canvas px
## once scaled), so it lost its margin and then some.
##
## Measured the same way on device and here, scanning each row from x=0 for the
## first warm pixel (luminance>70 and r>g+15 -- wood/cream against foliage), at
## the real 1170x2532 device resolution:
##
##   canvas KEEP   (pre-letterbox-fix)   x = 28   <- device photo IMG_1888: 29
##   canvas EXPAND (letterbox fix)       x = 0    <- device photo IMG_1894: 0
##
## All three screens measured 0, identically: they share one texture and one
## node configuration, and that was checked by rendering all three rather than
## inferred from the scene files.
##
## =====================================================================
## WHY A SCRIPT AND NOT A SCENE PROPERTY
##
## TextureRect's STRETCH_KEEP_ASPECT_COVERED always CENTRES its source region
## (Godot 4.3 computes region.position as half the overflow); there is no
## alignment property to bias that crop, so no value of stretch_mode fixes
## this. Widening the rect with a static offset does not work either: the
## overflow needed depends on the canvas HEIGHT, so any constant that frames
## the art on a 19.5:9 phone crops the top of the signboard off on a 16:9 one.
##
## Lifting the signboard out of the art into its own Control was considered and
## rejected on a measurement, not a preference: the painted one stays in the
## background, and once the background is cropped it slides 117 canvas px left
## of an overlay pinned at a fixed margin, leaving a visible strip of painted
## sign edge beside the clean one. Removing it from the art would mean
## repainting the foliage behind it.
##
## =====================================================================
## THE RULE
##
## Scale to cover, exactly as before; then place the source window so the
## PROTECTED span -- everything designed rather than scenery -- is centred in
## it, clamped so the art never stops covering the canvas.
##
## Vertical placement is deliberately left EXACTLY as COVERED had it (centred).
## On every portrait canvas the scale is height-driven, so there is no vertical
## crop at all and the choice is moot; changing it would move something this
## lot never measured.
##
## PROTECTED_* are measured off title_cover.png, in its own pixels:
##   signboard          x  17 .. 222
##   banner + leaves    x 237 .. 519
## so the designed content is the left 72% of the art and the right 28% is
## foliage. Swapping the texture without re-measuring these two numbers is what
## would break this -- hence they are named, not buried in an offset.

const ART_SIZE := Vector2(720.0, 1280.0)
const PROTECTED_LEFT := 17.0
const PROTECTED_RIGHT := 519.0

func _ready() -> void:
	# Asserted rather than silently forced: the scene is the source of truth
	# for how this node draws, and a scene that disagrees with the script is
	# the "fixture that diverges from the real thing" trap AlarmRampAudit
	# exists to close. Same posture as HUD's pip-count check.
	if stretch_mode != TextureRect.STRETCH_SCALE:
		push_error("CoverArt: stretch_mode must be STRETCH_SCALE -- this script owns the crop, COVERED would fight it.")
	if expand_mode != TextureRect.EXPAND_IGNORE_SIZE:
		push_error("CoverArt: expand_mode must be EXPAND_IGNORE_SIZE -- the texture's own size must not drive layout.")
	# The canvas aspect changes AFTER this runs: children are ready before
	# their screen, and the screen's _ready() is what calls
	# SafeArea.fill_screen(). Viewport.size_changed fires on that change (the
	# 2D size override moves even though the window does not), which is what
	# reframes us; the direct call below only covers the first frame.
	get_viewport().size_changed.connect(_reframe)
	_reframe()

func _reframe() -> void:
	var view := get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var cover_scale := maxf(view.x / ART_SIZE.x, view.y / ART_SIZE.y)
	var drawn := ART_SIZE * cover_scale
	var protected_centre := (PROTECTED_LEFT + PROTECTED_RIGHT) * 0.5 * cover_scale
	# Negative x scrolls the art left, i.e. crops its left edge. The clamp
	# floor is the most we may scroll before the right edge of the art would
	# pull inside the canvas and leave a gap.
	var x := clampf(view.x * 0.5 - protected_centre, minf(view.x - drawn.x, 0.0), 0.0)
	position = Vector2(x, (view.y - drawn.y) * 0.5)
	size = drawn
