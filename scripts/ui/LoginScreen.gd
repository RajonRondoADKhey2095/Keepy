extends Control
## Boot screen since the Google Sign-In gate (17 aout 2026): run/main_scene
## points here, and TitleScreen.tscn is only reachable once Auth reports a
## signed-in user. TitleScreen itself is unchanged and still loads
## standalone, so nothing about the existing boot path had to move.
##
## Session persistence is entirely the Firebase SDK's (browserLocalPersistence
## by default), so a returning player never sees this screen: Auth resolves
## to signed-in during the loading state and _go_to_title() fires without the
## button ever being enabled. That is why the button starts DISABLED in the
## scene rather than enabled-and-then-hidden -- there is no frame in which a
## signed-in user can see a live "Se connecter" button.

const TITLE_SCENE := "res://scenes/TitleScreen.tscn"
## `detail` can carry two full URLs (a failed dynamic import reports both the
## base and the module it could not fetch), which measured at 4 wrapped lines
## and pushed the panel to 26 px from the screen bottom -- inside the iOS
## home-indicator strip, on the one screen state the player actually has to
## read. Bounded here rather than by shrinking the panel further: the untruncated
## string is still in the browser console for anyone debugging with one attached.
const DETAIL_MAX_CHARS := 120
## The one string a signed-out player is meant to read. Held in a constant
## because two paths render it -- the plain signed-out state, and the neutral
## codes below -- and they must not drift apart.
const SIGNED_OUT_PROMPT := "Connecte-toi pour jouer."
## Codes that travel through auth_error but do NOT report a failure. A popup
## the player closed, or a second tap that superseded their own first attempt,
## is not something to show in the language of breakage. They still have to
## arrive as codes rather than silently: _on_sign_in_pressed() disables the
## button, and auth_error is the only channel that re-enables it -- staying
## quiet would leave a dead button under a stale "Connexion a Google...".
const NEUTRAL_CODES := ["popup-cancelled"]

@onready var status_label: Label = $CenterContainer/TitlePanel/VBoxContainer/StatusLabel
@onready var sign_in_button: Button = $CenterContainer/TitlePanel/VBoxContainer/SignInButton
@onready var offline_button: Button = $CenterContainer/TitlePanel/VBoxContainer/OfflineButton

## Guards against a double scene change: auth_state_changed can legitimately
## fire again (poll backstop, token refresh) between change_scene_to_file()
## being requested and the swap actually happening at the end of the frame.
var _leaving := false

func _ready() -> void:
	sign_in_button.pressed.connect(_on_sign_in_pressed)
	offline_button.pressed.connect(_go_to_title)
	Auth.auth_state_changed.connect(_on_auth_state_changed)
	Auth.auth_error.connect(_on_auth_error)

	if not OS.has_feature("web"):
		# Editor / desktop only: there is no JavaScriptBridge to sign in
		# with, so Auth stays signed-out for ever by design. Without this
		# escape hatch the game would be unreachable outside a web export,
		# which would make every future local check of Game.tscn impossible.
		# It cannot appear in the shipped build -- the web export always has
		# the "web" feature -- so the gate itself is not weakened.
		status_label.text = "Mode editeur : Google Sign-In indisponible hors web."
		sign_in_button.visible = false
		offline_button.visible = true
		return

	# The state may already be resolved: Auth reads a snapshot in its own
	# _ready(), and autoloads are ready before this scene is.
	if Auth.is_signed_in():
		_go_to_title()
		return
	_refresh_from_auth()

func _on_auth_state_changed(signed_in: bool) -> void:
	if signed_in:
		_go_to_title()
		return
	_refresh_from_auth()

func _on_auth_error(code: String, detail: String) -> void:
	# Every failure the browser side can report is surfaced verbatim rather
	# than collapsed into "connexion impossible": these are diagnosed on a
	# phone with no console, which is exactly the situation that made the
	# leaderboard gzip bug take three rounds to pin down.
	sign_in_button.disabled = false
	if code in NEUTRAL_CODES:
		# No parenthesised detail: 'auth/popup-closed-by-user' under a line
		# telling the player nothing is wrong reads as a contradiction.
		status_label.text = _message_for(code)
		return
	status_label.text = "%s\n(%s)" % [_message_for(code), _short(detail)]

func _refresh_from_auth() -> void:
	if not Auth.is_ready():
		status_label.text = "Connexion en cours..."
		sign_in_button.disabled = true
		return
	sign_in_button.disabled = false
	var code := Auth.get_error_code()
	if code.is_empty() or code in NEUTRAL_CODES:
		status_label.text = SIGNED_OUT_PROMPT
	else:
		status_label.text = "%s\n(%s)" % [_message_for(code), _short(Auth.get_error_detail())]

func _on_sign_in_pressed() -> void:
	status_label.text = "Connexion a Google..."
	sign_in_button.disabled = true
	Auth.sign_in()

func _go_to_title() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(TITLE_SCENE)

func _short(detail: String) -> String:
	if detail.length() <= DETAIL_MAX_CHARS:
		return detail
	return detail.substr(0, DETAIL_MAX_CHARS - 1) + "\u2026"

## The redirect-* codes cannot be emitted by the current shell any more -- the
## popup migration deleted every path that produced them -- and they are kept
## anyway. A player whose browser or service worker is still serving a cached
## build of the old shell is exactly the person most in need of a readable
## message, and dropping the arms would hand them the "_" fallback instead.
## They cost three lines; the leaderboard gzip round showed what a stale cached
## build costs when the code that meets it has forgotten it existed.
func _message_for(code: String) -> String:
	match code:
		"sdk-load-failed":
			return "Impossible de charger Firebase."
		"init-failed":
			return "Firebase n'a pas pu demarrer."
		"popup-blocked":
			return "Ton navigateur bloque les popups. Autorise les popups pour ce site et reessaie."
		"popup-cancelled":
			return SIGNED_OUT_PROMPT
		"popup-start-failed":
			return "La connexion Google a echoue."
		"redirect-lost":
			return "Google n'a rien renvoye au retour. Reessaie."
		"redirect-failed", "redirect-start-failed":
			return "La connexion Google a echoue."
		"bridge-timeout":
			return "Le module de connexion ne repond pas."
		"not-ready":
			return "Connexion pas encore prete, patiente une seconde."
		"unsupported":
			return "Connexion disponible uniquement dans la version web."
		_:
			return "Connexion impossible."
