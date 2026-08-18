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
