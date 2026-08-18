extends Control
## First real screen exercising Quizz.gd (autoloaded 18 aout 2026, deployed
## to staging, never yet called for real). Scope is deliberately narrow:
## create a quiz by title, and list the signed-in user's own quizzes. No
## question editing, no play loop -- that is QuizzEditorScreen /
## QuizzPlayScreen territory (docs/QUIZZ_SPEC.md section 7), not this file.
##
## Reached from scenes/Hub.tscn's "Keepy Quizz" button, which used to be
## disabled with a "Bientot disponible" caption. That guard is gone: this
## screen is the reason it could come off.

const CREATE_LABEL := "Creer"
const CREATING_LABEL := "Creation..."
const LOADING_LABEL := "Chargement..."
const EMPTY_LABEL := "Aucun questionnaire pour l'instant."
const GENERIC_ERROR_LABEL := "Erreur : impossible de contacter Firestore."
## Firestore's own message for a missing composite index always carries this
## status and a ready-made console URL -- see Quizz.list_own_quizzes()'s doc
## comment. Detecting on the status string rather than guessing from the URL
## alone keeps this screen from ever mistaking an unrelated 400 for the
## expected first-run index gap.
const MISSING_INDEX_MARKER := "FAILED_PRECONDITION"

@onready var back_button: Button = $Margin/VBox/HeaderRow/BackButton
@onready var title_edit: LineEdit = $Margin/VBox/CreatePanel/CreateRow/TitleEdit
@onready var create_button: Button = $Margin/VBox/CreatePanel/CreateRow/CreateButton
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var index_help_panel: PanelContainer = $Margin/VBox/IndexHelpPanel
@onready var index_url_edit: LineEdit = $Margin/VBox/IndexHelpPanel/VBox/IndexUrlEdit
@onready var copy_url_button: Button = $Margin/VBox/IndexHelpPanel/VBox/CopyUrlButton
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var quiz_list: VBoxContainer = $Margin/VBox/Scroll/QuizList
@onready var empty_label: Label = $Margin/VBox/EmptyLabel

## Style for each quiz row, built once in _ready() rather than duplicated
## per row -- same idea as the scrim/button StyleBoxFlat resources baked
## into Hub.tscn and LoginScreen.tscn, just assembled in code because rows
## are created at runtime and have no scene of their own.
var _row_style: StyleBoxFlat

## True while a create or list call is in flight, so a second tap cannot
## queue a second request on top of one already running -- Quizz.gd itself
## queues rather than drops, but a screen that can double-fire on every tap
## is still worth guarding at the UI layer, same discipline as
## LoginScreen's sign_in_button.disabled during _on_sign_in_pressed().
var _busy := false

func _ready() -> void:
	# Safe-area strip above/below the canvas is cream here, not the swamp
	# default the export shell paints statically -- see SafeArea.gd's own
	# header for why this is a call from the screen rather than a scene
	# change watcher.
	SafeArea.set_cream()
	# Canvas fills the screen here: this is a UI screen, so the 9:16 letterbox
	# Chased is tuned at would only be black bars. Game.tscn asks for KEEP back
	# in its own _ready() -- see SafeArea.gd's canvas-aspect block.
	SafeArea.fill_screen()
	_row_style = _build_row_style()
	back_button.pressed.connect(_on_back_pressed)
	create_button.pressed.connect(_on_create_pressed)
	title_edit.text_submitted.connect(func(_text: String) -> void: _on_create_pressed())
	copy_url_button.pressed.connect(_on_copy_url_pressed)
	Quizz.quiz_created.connect(_on_quiz_created)
	Quizz.quizzes_fetched.connect(_on_quizzes_fetched)
	_refresh_list()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Hub.tscn")

func _on_create_pressed() -> void:
	if _busy:
		return
	var safe_title := title_edit.text.strip_edges()
	if safe_title.is_empty():
		status_label.text = "Donne un titre au questionnaire d'abord."
		return
	_set_busy(true, CREATING_LABEL)
	Quizz.create_quiz(safe_title)

func _on_quiz_created(success: bool, _quiz_id: String, error: String) -> void:
	if not success:
		_set_busy(false, "")
		_show_error(error)
		return
	title_edit.text = ""
	# The freshly created quiz will not sort first by luck -- it refreshes
	# the real list rather than inserting a locally-guessed row, so the
	# order and the "date de derniere modif" the player sees always come
	# from the server, never from an assumption made here.
	_refresh_list()

func _refresh_list() -> void:
	_set_busy(true, LOADING_LABEL)
	Quizz.list_own_quizzes()

func _on_quizzes_fetched(success: bool, quizzes: Array, error: String) -> void:
	_set_busy(false, "")
	if not success:
		_show_error(error)
		return
	index_help_panel.visible = false
	_populate_list(quizzes)

func _set_busy(busy: bool, label: String) -> void:
	_busy = busy
	create_button.disabled = busy
	title_edit.editable = not busy
	# Always write status_label.text, not just while busy: the bug this
	# fixes was exactly that the busy==false, label=="" call (both
	# _on_quiz_created and _on_quizzes_fetched pass this on success) used
	# to be a no-op, leaving LOADING_LABEL/CREATING_LABEL on screen forever
	# after the response that was supposed to replace it had already
	# arrived.
	status_label.text = label
	if busy:
		index_help_panel.visible = false

## Splits the "expected first-run gap" from every other failure, exactly as
## the task requires: a missing composite index is not an error to hide
## behind a generic message, it is the documented, expected shape of the
## very first list_own_quizzes() call against a fresh index. Anything else
## -- offline, auth-required, a genuine server refusal -- stays a plain
## failure message, same tone as LoginScreen's _message_for().
func _show_error(error: String) -> void:
	var url := _extract_index_url(error)
	if error.contains(MISSING_INDEX_MARKER) and not url.is_empty():
		status_label.text = "Index Firestore manquant (normal au tout premier lancement). Ouvre ce lien pour le creer :"
		index_help_panel.visible = true
		index_url_edit.text = url
		return
	index_help_panel.visible = false
	status_label.text = "%s\n(%s)" % [GENERIC_ERROR_LABEL, error]

## Firestore's FAILED_PRECONDITION message embeds the console URL inline,
## e.g. "...index. You can create it here: https://console.firebase.google
## .com/...". The URL runs to the end of the message with no spaces (it is
## itself URL-encoded), so everything from the first "https://" onward is
## the URL -- no delimiter to search for on the other end.
func _extract_index_url(error: String) -> String:
	var idx := error.find("https://")
	if idx == -1:
		return ""
	return error.substr(idx).strip_edges()

func _on_copy_url_pressed() -> void:
	if index_url_edit.text.is_empty():
		return
	DisplayServer.clipboard_set(index_url_edit.text)
	copy_url_button.text = "Copie !"

func _populate_list(quizzes: Array) -> void:
	for child in quiz_list.get_children():
		child.queue_free()
	empty_label.visible = quizzes.is_empty()
	scroll.visible = not quizzes.is_empty()
	for quiz in quizzes:
		quiz_list.add_child(_build_row(quiz))

func _build_row(quiz: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _row_style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var title_label := Label.new()
	title_label.text = String(quiz.get("title", ""))
	title_label.theme_type_variation = &"CardTitleLabel"
	box.add_child(title_label)

	var date_label := Label.new()
	date_label.text = "Modifie le %s" % _format_timestamp(String(quiz.get("updatedAt", "")))
	date_label.theme_type_variation = &"MutedLabel"
	box.add_child(date_label)

	return panel

## Firestore's timestampValue is RFC3339 with sub-second precision, e.g.
## "2026-08-18T12:52:52.890123456Z". Time.get_datetime_dict_from_datetime_
## string() only understands whole seconds, so the fractional part and the
## trailing "Z" are stripped first. An unparseable input comes back with
## every field at 0 (measured, not documented by the engine) rather than an
## empty dictionary, so the year is what is checked, and the raw string is
## shown rather than a nonsense "00/00/0000" on the one field a player has
## no way to make sense of on their own.
func _format_timestamp(raw: String) -> String:
	if raw.is_empty():
		return "?"
	var trimmed := raw
	var dot := trimmed.find(".")
	if dot != -1:
		trimmed = trimmed.substr(0, dot)
	if trimmed.ends_with("Z"):
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	var parts := Time.get_datetime_dict_from_datetime_string(trimmed, false)
	if int(parts.get("year", 0)) == 0:
		return raw
	return "%02d/%02d/%04d %02d:%02d" % [
		int(parts.get("day", 0)), int(parts.get("month", 0)), int(parts.get("year", 0)),
		int(parts.get("hour", 0)), int(parts.get("minute", 0)),
	]

## Built once in _ready() rather than as a scene sub-resource: rows are
## created at runtime, one per quiz, and sharing a single StyleBoxFlat
## instance across all of them costs nothing (Godot resources are safe to
## reuse read-only across nodes) versus allocating one per row.
##
## Matches resources/themes/quizz_theme.tres's PanelContainer card style
## (white, 24px corner radius, soft orange-tinted shadow) rather than
## duplicating the theme's own StyleBoxFlat_panel: a quiz row is visually a
## smaller card, not a new shape in the Quizz identity, so it borrows the
## exact same recipe at a tighter radius and margin.
func _build_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 20.0
	style.content_margin_top = 14.0
	style.content_margin_right = 20.0
	style.content_margin_bottom = 14.0
	style.shadow_color = Color(1.0, 0.5412, 0.3569, 0.12)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 3)
	return style
