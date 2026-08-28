extends Node
## Autoloaded as "SafeArea". Sets the colour painted behind the canvas, in
## the safe-area strip a notch/status bar sits in (viewport-fit=cover on
## the export shell -- see web/html_shell.html).
##
## That colour used to be the single hard-coded #101d0b baked into the
## shell's CSS (html/body/#status background-color). It reads correctly
## for every screen that keeps the swamp identity -- LoginScreen, Hub,
## TitleScreen -- because it IS that identity's colour. It reads wrong on
## QuizzHomeScreen, whose own background is the cream `Color(1.0, 0.9725,
## 0.9451)` from resources/themes/quizz_theme.tres: the safe-area strip
## sits above/below the canvas as a dark-green bar against a cream screen,
## exactly the seam confirmed on device (18 aout 2026, staging, iPhone
## Safari).
##
## Screens change the paint by CALLING this node from their own _ready(),
## not by this node watching scene changes: Godot has no signal for "a new
## scene just became current" that fires before the first frame, and
## polling get_tree().current_scene every frame to detect a transition
## would be a busier and less direct fix than one call in the two screens
## that actually need one (QuizzHomeScreen switches to cream, Hub -- the
## only way back out of Quizz today -- resets to the default on every
## entry, defensively, rather than each Quizz exit path having to remember
## to reset it itself).
##
## =====================================================================
## SAME GUARD AS Auth.gd, DELIBERATELY NOT A LIGHTER ONE
##
## `OS.has_feature("web")` and not a headless/editor check: the question is
## "does JavaScriptBridge exist", which is a property of the platform, not
## of how this run was launched. Every scripts/dev/*Audit.gd probe boots
## `--headless` and gets this autoload like every other one; off-web
## set_color() returns before JavaScriptBridge is touched at all, so a
## probe sees this file as an empty no-op, same as Auth.gd's own header
## documents for itself.
##
## No entry point here can throw into the game: JavaScriptBridge.eval()
## failing (missing global, thrown exception inside the snippet) yields
## null on the Godot side, and the return value is never used for
## anything -- there is nothing to marshal back, unlike Auth's sign-in
## flow, so there is nothing to inspect either.

const DEFAULT_COLOR := "#101d0b" ## Matches web/html_shell.html's static baseline (SWAMP_SKY family).
const CREAM_COLOR := "#FFF8F1" ## Matches QuizzHomeScreen.tscn's own Background ColorRect exactly.

## Sets the safe-area paint to the swamp default. Called defensively from
## Hub._ready() -- the one screen every path back out of Quizz passes
## through today -- rather than tracked per Quizz exit button, so a future
## Quizz screen that adds another way back to the hub inherits the reset
## for free instead of needing its own call.
func set_default() -> void:
	_set_color(DEFAULT_COLOR)

## Sets the safe-area paint to match QuizzHomeScreen's cream background.
func set_cream() -> void:
	_set_color(CREAM_COLOR)

func _set_color(hex: String) -> void:
	if not OS.has_feature("web"):
		return
	# Inline styles on the three elements the shell's static CSS paints
	# (html, body, #status -- see the block comment above), set directly
	# rather than through a shell-side helper: unlike Auth, this has no
	# state to publish back and no lifecycle to coordinate with, so a
	# self-contained snippet is the smaller surface. #status is usually
	# already removed by the time a screen calls this (the engine bootstrap
	# script deletes it once the game starts), so the null-check is the
	# common case, not a defensive extra.
	var js := "(function(){var c='%s';document.documentElement.style.backgroundColor=c;document.body.style.backgroundColor=c;var s=document.getElementById('status');if(s){s.style.backgroundColor=c;}})();" % hex
	JavaScriptBridge.eval(js, true)

## =====================================================================
## CANVAS ASPECT -- SECOND, SEPARATE JOB OF THIS NODE
##
## Same responsibility as the colour above ("what the edges of the screen
## look like on this device"), so it lives here rather than in a second
## autoload: both answer to the same question, and a screen that needs one
## almost always needs the other.
##
## The defect it fixes is NOT the safe-area strip -- that one is handled by
## _set_color() and works (verified on device: the status-bar strip is
## cream on Quizz, #101d0b on Hub). It is Godot's own LETTERBOXING, drawn
## INSIDE the canvas, which no CSS or JS can reach.
##
## Measured on a 1170x2532 device capture (iPhone, Safari, staging,
## 18 aout 2026):
##
##   y=0..140      141px  page colour   (correct -- _set_color above)
##   y=141..295    155px  BLACK         <- letterbox
##   content              2080px
##   y=2376..2531  156px  BLACK         <- letterbox
##
## 1170 * 1920/1080 = 2080 exactly. project.godot declares a 1080x1920
## (9:16) viewport with window/stretch/aspect="keep", the device is
## ~19.5:9, so Godot preserves the ratio and fills the remainder with
## black. Reproduced here at 1170x2532 with the engine's own numbers:
## visible_rect stays 1080x1920 and the final transform picks up an
## origin.y of 226 -- (2532 - 2080) / 2. On device the canvas is shorter
## than the window by the 141px safe-area strip, which is why the bars
## measure 155/156 there and 226 in a bare window: same mechanism, two
## canvas heights.
##
## =====================================================================
## WHY THIS IS A RUNTIME TOGGLE AND NOT project.godot
##
## Flipping window/stretch/aspect to "expand" project-wide would fix the
## UI screens and silently re-balance Chased. The viewport would grow from
## 1920 to ~2337 tall on that same device: ~417px MORE of the world
## visible ahead of Keepy, so obstacles enter the frame earlier, so the
## reaction budget the game is tuned around (Hitboxes.OBSTACLE_REACTION_
## BUDGET_S) changes without a single line of gameplay code moving. That
## is a gameplay change wearing a display setting's clothes, and it is
## exactly what this split avoids.
##
## So: UI screens ask for EXPAND, the game asks for KEEP. project.godot
## keeps "keep" as its default, which means every probe in scripts/dev/
## and every scene nobody has touched inherits the framing Chased was
## tuned at -- the safe value is the one you get by doing nothing.
##
## Verified at runtime before being relied on (Godot 4.3, gl_compatibility,
## X11 1170x2532): setting content_scale_aspect takes effect on the next
## frame without recreating the window, and setting it back reproduces the
## initial visible_rect, origin AND scale exactly. That round-trip is what
## makes keep_game_framing() a real restore rather than a hope.
##
## NO `OS.has_feature("web")` GUARD ON THESE TWO, unlike the colour
## functions above: content_scale_aspect is an engine property, not a
## JavaScriptBridge call, so there is nothing platform-specific to guard.
## The web guard above exists because JavaScriptBridge does not exist off
## web; this has no such dependency, and guarding it would make the local
## editor and the offscreen renders behave differently from the shipped
## build -- the one divergence that would hide this defect from every test
## that could catch it.

## Lets the canvas fill the whole screen, killing the black bars. Called
## from the _ready() of every UI screen (LoginScreen, Hub, TitleScreen,
## QuizzHomeScreen). Their roots are full-rect Controls, so a taller
## viewport re-lays-out rather than stretching anything.
##
## The three forest screens re-CROP their cover art as well, and that crop
## is what this call moves: their CoverImage used to be
## KEEP_ASPECT_COVERED, whose source region is always centred, so the extra
## side crop a taller canvas asks for ate the painted "PLAYER: KEEPY"
## signboard at the left edge (measured on device: its first pixel went
## from x=29 to x=0). They carry scripts/ui/CoverArt.gd since, which places
## that crop around the art's designed content instead of its geometric
## centre -- see that file's header. Any NEW screen that both calls this
## and paints something near an edge of its background needs the same
## script; the 9:16 canvas that made the centred crop harmless is gone.
func fill_screen() -> void:
	_set_aspect(Window.CONTENT_SCALE_ASPECT_EXPAND)

## Restores the 9:16 framing Chased is tuned at. Called from Game._ready()
## DEFENSIVELY -- not because the screen before it forgot, but so that the
## game scene never depends on which screen ran before it. A probe that
## boots Game.tscn directly, or a future entry point that skips the hub,
## has to get the tuned framing too.
func keep_game_framing() -> void:
	_set_aspect(Window.CONTENT_SCALE_ASPECT_KEEP)

func _set_aspect(aspect: int) -> void:
	var window := get_window()
	if window == null:
		return
	window.content_scale_aspect = aspect
