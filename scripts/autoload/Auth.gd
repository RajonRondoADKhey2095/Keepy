extends Node
## Autoloaded as "Auth". Google Sign-In gate in front of the game.
##
## =====================================================================
## WHY THIS IS A JS BRIDGE AND NOT REST, UNLIKE Leaderboard.gd
##
## Leaderboard.gd talks to Firestore over the plain REST API with no
## Firebase SDK at all, because nothing there needs browser UI. Auth is
## the opposite case: the Google consent screen is browser UI the browser
## has to draw itself -- since 17 aout 2026 in a popup window -- so it can
## never happen inside the WebGL canvas. The Firebase JS SDK therefore
## lives in the export shell (web/html_shell.html) and this file is only
## the wire between it and GDScript. The shell's own header explains why
## the popup replaced signInWithRedirect; nothing in THIS file changed
## with it, which is the point of the snapshot contract below.
##
## What IS shared with Leaderboard.gd is the robustness contract, and it
## is the part that matters: no entry point here can crash or block the
## game, every path ends in a signal, and off-web the whole thing degrades
## to a defined "signed out" instead of erroring.
##
## =====================================================================
## HEADLESS / NON-WEB
##
## Every scripts/dev/*Audit.gd probe boots with `--headless`, and an
## autoload runs in EVERY one of them -- probes launch their own .tscn
## directly, so they never load run/main_scene, but they do get this node.
## `OS.has_feature("web")` is false there, so `_ready()` returns before
## touching JavaScriptBridge at all: no callback is created, no eval is
## issued, no timer is started, and `is_signed_in()` answers false for
## ever. A probe therefore sees this file as an empty Node, which is why
## adding it leaves the gated probes byte-identical.
##
## The guard is `OS.has_feature("web")` and not Leaderboard.gd's
## `DisplayServer.get_name() == "headless"`, and the difference is
## deliberate: Leaderboard asks "am I under a probe?" (it wants to run in
## a desktop editor), while this file asks "does JavaScriptBridge exist?"
## -- which is a property of the PLATFORM, and is the only condition
## under which any line below is meaningful. Testing for headless here
## would leave a desktop editor run calling into a bridge that is not
## there.

## Emitted on every transition, and once on startup as soon as the browser
## side has resolved (SDK loaded AND the first auth state restored from
## persistence). Never emitted before that: a listener that drew a
## signed-out screen while a stored session was still loading would flash
## the login page at a user who is already authenticated.
signal auth_state_changed(signed_in: bool)
## Emitted when the browser side reports a machine-readable outcome worth
## surfacing. `code` is one of the values written by web/html_shell.html
## ('sdk-load-failed', 'init-failed', 'popup-blocked', 'popup-cancelled',
## 'popup-start-failed'), or 'bridge-timeout' / 'not-ready' / 'unsupported'
## from this file.
##
## NOT every code is a failure: 'popup-cancelled' means the player closed
## the Google window, and it travels here only because the login screen
## disabled its button on press and this is what re-enables it.
## LoginScreen.gd owns that distinction -- see its NEUTRAL_CODES.
signal auth_error(code: String, detail: String)

## The bridge publishes its state through this global; the shell defines
## it in a plain <script> BEFORE the module that fills it, so it is always
## present even if the SDK never loads.
const SNAPSHOT_JS := "window.keepyAuthSnapshot ? window.keepyAuthSnapshot() : ''"
const SIGN_IN_JS := "window.keepySignInWithGoogle ? (window.keepySignInWithGoogle() ? 1 : 0) : 0"

## If the shell has not reported `ready` within this many seconds, we stop
## waiting and surface it. Without this the login screen would sit on its
## loading state for ever whenever the SDK import is blocked in a way that
## kills the module before its own try/catch can report -- an unbounded
## wait with no way out, which is the failure mode ProbeWatchdog exists to
## prevent everywhere else in this project.
const BRIDGE_TIMEOUT_S := 12.0
## Polling backstop, and ONLY a backstop: the shell pushes every change
## into `keepyAuthNotify`, so this exists purely to close the startup
## window between this node registering its callback and the shell's own
## listeners firing. It stops for good once the bridge reports `ready` --
## see _process(). Leaving a twice-a-second JavaScriptBridge.eval running
## for the rest of the session would put browser round-trips inside the
## frame budget of a 60 fps runner, to watch for a sign-out that nothing
## in this game can currently trigger.
const POLL_INTERVAL_S := 0.5

var _available := false
var _ready_reported := false
var _signed_in := false
var _uid := ""
var _id_token := ""
var _status := "loading"
var _error := ""
var _error_detail := ""
var _elapsed := 0.0
## MUST be held in a member: JavaScriptBridge.create_callback() returns a
## reference-counted object, and letting it go out of scope frees the
## callback while JS still holds the name -- the call then throws on the
## browser side, silently, and the push path just stops working.
var _js_callback: JavaScriptObject = null
var _poll_accum := 0.0

func _ready() -> void:
	if not OS.has_feature("web"):
		# Desktop editor or any headless probe. Nothing below is meaningful
		# and none of it is attempted -- see the header.
		set_process(false)
		return
	_available = true
	_js_callback = JavaScriptBridge.create_callback(_on_js_auth_event)
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window != null:
		window.keepyAuthNotify = _js_callback
	# Read once, immediately after registering: the shell may already have
	# resolved before this node existed, in which case its notify fired into
	# nothing. Without this read that state would only be picked up by the
	# poll, one interval later.
	_read_snapshot()

func _process(delta: float) -> void:
	if not _available:
		return
	if _ready_reported:
		# Startup window closed: the push callback owns every further
		# transition, so take this node out of the frame loop entirely.
		set_process(false)
		return
	_elapsed += delta
	if _elapsed >= BRIDGE_TIMEOUT_S:
		_ready_reported = true
		_status = "error"
		_error = "bridge-timeout"
		_error_detail = "no response from the Firebase bridge after %.0fs" % BRIDGE_TIMEOUT_S
		auth_error.emit(_error, _error_detail)
		auth_state_changed.emit(false)
		set_process(false)
		return
	_poll_accum += delta
	if _poll_accum >= POLL_INTERVAL_S:
		_poll_accum = 0.0
		_read_snapshot()


# ---------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------

## True only once the browser side has confirmed a signed-in user. False
## everywhere else, including off-web and while still loading -- callers
## never have to special-case those.
func is_signed_in() -> bool:
	return _signed_in

## Empty string when signed out, off-web, or while the token is still
## being fetched (the uid is published before the token, so a caller can
## already know WHO is signed in while this is still empty).
func get_id_token() -> String:
	return _id_token

func get_current_uid() -> String:
	return _uid

## True once the browser side has settled, whether signed in or not.
## Off-web this stays false for ever, which is what keeps the login screen
## from claiming a definitive "signed out" it cannot know.
func is_ready() -> bool:
	return _ready_reported

func get_status() -> String:
	return _status

func get_error_code() -> String:
	return _error

func get_error_detail() -> String:
	return _error_detail

## Opens the Google sign-in popup. No-op off-web, and a no-op with a
## reported error if the bridge has not loaded -- never a crash.
##
## Returning 1 means the popup was ASKED FOR, not that it opened: the
## browser can still refuse it, and that arrives later as a
## 'popup-blocked' snapshot rather than through this call.
func sign_in() -> void:
	if not _available:
		auth_error.emit("unsupported", "sign-in is only available in the web build")
		return
	# eval() answers null when the expression throws or yields something it
	# cannot marshal, and int(null) is a hard error in GDScript -- so the
	# result is inspected, never coerced blind.
	var raw = JavaScriptBridge.eval(SIGN_IN_JS, true)
	var started := 0
	if raw != null and (typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT):
		started = int(raw)
	if started != 1:
		# The stub in the shell answers 0 until the SDK module has replaced
		# it; read the snapshot back so the reason it left behind surfaces
		# instead of a generic failure.
		_read_snapshot()
		if _error == "":
			_error = "not-ready"
			_error_detail = "sign-in requested before the Firebase bridge was ready"
		auth_error.emit(_error, _error_detail)


# ---------------------------------------------------------------------
# Bridge plumbing
# ---------------------------------------------------------------------

func _on_js_auth_event(args: Array) -> void:
	if args.is_empty():
		return
	_apply_snapshot(str(args[0]))

func _read_snapshot() -> void:
	var raw = JavaScriptBridge.eval(SNAPSHOT_JS, true)
	if raw == null:
		return
	_apply_snapshot(str(raw))

func _apply_snapshot(raw: String) -> void:
	if raw.is_empty():
		return
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed

	var new_status := str(data.get("status", "loading"))
	var new_uid := str(data.get("uid", ""))
	var new_token := str(data.get("idToken", ""))
	var new_error := str(data.get("error", ""))
	var new_detail := str(data.get("detail", ""))
	var new_ready := bool(data.get("ready", false))
	var new_signed_in := new_status == "signed_in" and not new_uid.is_empty()

	_uid = new_uid
	_id_token = new_token
	_status = new_status

	if new_error != "" and new_error != _error:
		_error = new_error
		_error_detail = new_detail
		auth_error.emit(new_error, new_detail)
	elif new_error == "":
		_error = ""
		_error_detail = ""

	# Emit on the first ready, then only on real transitions -- the poll
	# runs twice a second and must not spam listeners with unchanged state.
	var was_reported := _ready_reported
	if new_ready:
		_ready_reported = true
	if _signed_in != new_signed_in or (_ready_reported and not was_reported):
		_signed_in = new_signed_in
		auth_state_changed.emit(_signed_in)
