extends Control
## Keepy Quizz home screen -- reset to its TARGET shape on 20 aout 2026:
## title + back button + the "Creer ton quizz" CTA block + the quiz list,
## and NOTHING else. The title field, inline "Creer" button, category
## field/"Ajouter" button, filter chips and both section labels that
## previous lots had accreted here all moved OFF this screen -- creation
## now lives on its own screen (QuizzCreateScreen), which the CTA opens,
## and the category tooling moved there with it. See docs/QUIZZ_DESIGN.md,
## "La cible de l'accueil".
##
## Tapping a quiz row opens the question editor (QuizzQuestionsScreen) for
## that quiz -- the wiring that had nowhere to go while no editor existed.
##
## Since this lot the one and only term on every Quizz screen is "quizz"
## (titles, labels, placeholders, error messages) -- the older, longer
## synonym is banned from the whole Quizz UI.

const LOADING_LABEL := "Chargement..."
const GENERIC_ERROR_LABEL := "Erreur : impossible de contacter Firestore."
## Firestore's own message for a missing composite index always carries this
## status and a ready-made console URL -- see Quizz.list_own_quizzes()'s doc
## comment. Detecting on the status string rather than guessing from the URL
## alone keeps this screen from ever mistaking an unrelated 400 for the
## expected first-run index gap.
const MISSING_INDEX_MARKER := "FAILED_PRECONDITION"
const CREATE_SCENE := "res://scenes/QuizzCreateScreen.tscn"

## Same sheen resource as the CTA's sibling -- see docs/QUIZZ_DESIGN.md,
## "Matiere". Preloaded rather than rebuilt per row.
const CARD_SHINE := preload("res://resources/gradients/quizz_shine_card.tres")
## The question editor exposes a static open() that carries the quiz id and
## title across the scene change -- change_scene_to_file() itself cannot
## pass arguments. Preloaded so the path lives in exactly one file.
const QuestionsScreen := preload("res://scripts/ui/QuizzQuestionsScreen.gd")

@onready var back_button: Button = $Margin/VBox/HeaderRow/BackButton
@onready var create_button: Button = $Margin/VBox/CreateButton
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var index_help_panel: PanelContainer = $Margin/VBox/IndexHelpPanel
@onready var index_url_edit: LineEdit = $Margin/VBox/IndexHelpPanel/VBox/IndexUrlEdit
@onready var copy_url_button: Button = $Margin/VBox/IndexHelpPanel/VBox/CopyUrlButton
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var quiz_list: VBoxContainer = $Margin/VBox/Scroll/QuizList
@onready var empty_label: Label = $Margin/VBox/EmptyLabel

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
	back_button.pressed.connect(_on_back_pressed)
	create_button.pressed.connect(_on_create_pressed)
	copy_url_button.pressed.connect(_on_copy_url_pressed)
	Quizz.quizzes_fetched.connect(_on_quizzes_fetched)
	_refresh_list()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Hub.tscn")

## Navigation only -- the creation form (title, optional category) lives on
## QuizzCreateScreen since 20 aout 2026.
func _on_create_pressed() -> void:
	get_tree().change_scene_to_file(CREATE_SCENE)

## The CTA deliberately stays ENABLED while the list call is in flight,
## unlike the old in-place create button: pressing it is pure navigation now
## (no network call of its own), and a player who wants to create a quiz
## should never have to wait for the list of old ones. Quizz.gd's own FIFO
## queue keeps the in-flight list request safe across the scene change --
## the HTTPRequest node belongs to the autoload, not to this screen.
func _refresh_list() -> void:
	status_label.text = LOADING_LABEL
	index_help_panel.visible = false
	Quizz.list_own_quizzes()

func _on_quizzes_fetched(success: bool, quizzes: Array, error: String) -> void:
	# Always cleared, not just on success: the error path writes its own
	# message right after, and the success path must not leave
	# LOADING_LABEL on screen.
	status_label.text = ""
	if not success:
		_populate_list([])
		_show_error(error)
		return
	index_help_panel.visible = false
	_populate_list(quizzes)

## Splits the "expected first-run gap" from every other failure: a missing
## composite index is not an error to hide behind a generic message, it is
## the documented, expected shape of the very first list_own_quizzes() call
## against a fresh index. Anything else -- offline, auth-required, a genuine
## server refusal -- stays a plain failure message.
func _show_error(error: String) -> void:
	var url := _extract_index_url(error)
	if error.contains(MISSING_INDEX_MARKER) and not url.is_empty():
		status_label.text = "Index Firestore manquant (normal au tout premier lancement). Ouvre ce lien pour le creer :"
		index_help_panel.visible = true
		index_url_edit.text = url
		return
	index_help_panel.visible = false
	status_label.text = "%s\n(%s)" % [GENERIC_ERROR_LABEL, error]

## Firestore's FAILED_PRECONDITION message embeds the console URL inline and
## it runs to the end of the message with no spaces (it is itself
## URL-encoded), so everything from the first "https://" onward is the URL.
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

## A row is a BUTTON since 20 aout 2026, because tapping it opens the
## question editor -- before that lot there was nowhere to go, so rows were
## inert PanelContainers. The `QuizRowButton` theme variation reuses the
## exact row-panel stylebox (white card, soft shadow) for every state and a
## peach fill for `pressed`, so the card look is unchanged and the tap gets
## real feedback; the styling stays in the theme, per the design-system
## rule.
##
## One structural consequence: a Button does not size itself to child
## Controls the way a PanelContainer does, so the row carries an explicit
## minimum height and its content pad anchors to the full rect -- the same
## pattern the CTA block already uses for its two text levels.
func _build_row(quiz: Dictionary) -> Control:
	var row_button := Button.new()
	row_button.theme_type_variation = &"QuizRowButton"
	row_button.custom_minimum_size = Vector2(0, 128)
	row_button.pressed.connect(_on_row_pressed.bind(
		String(quiz.get("id", "")), String(quiz.get("title", ""))))
	# Same sheen as every other card -- added FIRST so it draws under the
	# text. Radial from the bottom edge midpoint, so no corner mask is
	# needed (docs/QUIZZ_DESIGN.md, "Matiere").
	var shine := TextureRect.new()
	shine.texture = CARD_SHINE
	shine.set_anchors_preset(Control.PRESET_FULL_RECT)
	shine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_button.add_child(shine)
	# Padding lives in a MarginContainer, not in the stylebox, so the sheen
	# reaches the card edge -- same constraint as every shiny panel here.
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 26)
	pad.add_theme_constant_override("margin_top", 24)
	pad.add_theme_constant_override("margin_right", 28)
	pad.add_theme_constant_override("margin_bottom", 24)
	row_button.add_child(pad)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	pad.add_child(row)

	var accent := Panel.new()
	accent.theme_type_variation = &"AccentBar"
	accent.custom_minimum_size = Vector2(6, 0)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.size_flags_vertical = Control.SIZE_FILL
	row.add_child(accent)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

	var title_label := Label.new()
	title_label.text = String(quiz.get("title", ""))
	title_label.theme_type_variation = &"CardTitleLabel"
	# A row has a fixed height now (Button, see above), so a long title
	# truncates with an ellipsis instead of growing the card.
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_label)

	var date_label := Label.new()
	date_label.text = "Modifie le %s" % _format_timestamp(String(quiz.get("updatedAt", "")))
	date_label.theme_type_variation = &"MutedLabel"
	date_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(date_label)

	return row_button

func _on_row_pressed(quiz_id: String, quiz_title: String) -> void:
	if quiz_id.is_empty():
		return
	QuestionsScreen.open(get_tree(), quiz_id, quiz_title)

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
