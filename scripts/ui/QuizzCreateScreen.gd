extends Control
## Quiz creation screen (ecran 2 of the 20 aout 2026 flow) -- opened by the
## home screen's "Creer ton quizz" CTA. Owns everything that used to
## crowd the home screen: the title field (mandatory), the optional
## category picker, and on-the-spot category creation.
##
## On validation it calls Quizz.create_quiz(title, category_id) and, on
## success, goes STRAIGHT to the question editor for the freshly created
## quiz -- never back to the home screen: the player just created an empty
## quiz, the next thing they need is to put questions in it.
##
## Cancellation is the back button: nothing is persisted anywhere until
## "Creer le quizz" is pressed, so leaving IS cancelling -- there is no
## separate "Annuler" control to keep in sync with it.
##
## =====================================================================
## CATEGORIES DEGRADE, THEY NEVER BLOCK -- expected state on staging
##
## The `categories` Firestore rules are NOT deployed yet (main does not
## contain them; they only ship on the next main push). On staging every
## category call therefore answers 403. That is EXPECTED, not a bug to
## fix here: this screen degrades to a clear hint ("categories
## indisponibles"), hides the category tooling's chips, and keeps quiz
## creation fully functional without a category. Validation is NEVER
## blocked by anything category-related.

const HOME_SCENE := "res://scenes/QuizzHomeScreen.tscn"
const CREATING_LABEL := "Creation du quizz..."
const CATEGORY_CREATING_LABEL := "Creation de la categorie..."
const CATEGORIES_LOADING_LABEL := "Chargement des categories..."
const CATEGORY_HINT_DEFAULT := "Choisis une categorie, ou cree-en une ci-dessous."
const CATEGORIES_UNAVAILABLE_HINT := "Categories indisponibles pour l'instant -- ton quizz sera cree sans categorie."
const CATEGORY_CREATE_FAILED_LABEL := "Impossible de creer la categorie pour l'instant. Ton quizz peut quand meme etre cree sans categorie."
const GENERIC_ERROR_LABEL := "Erreur : impossible de contacter Firestore."
const NO_CATEGORY := ""

const QuestionsScreen := preload("res://scripts/ui/QuizzQuestionsScreen.gd")

@onready var back_button: Button = $Margin/VBox/HeaderRow/BackButton
@onready var title_edit: LineEdit = $Margin/VBox/TitlePanel/TitlePad/TitleEdit
@onready var category_hint_label: Label = $Margin/VBox/CategoryHintLabel
@onready var chip_scroll: ScrollContainer = $Margin/VBox/ChipScroll
@onready var chip_row: HBoxContainer = $Margin/VBox/ChipScroll/ChipRow
@onready var category_panel: PanelContainer = $Margin/VBox/CategoryPanel
@onready var category_edit: LineEdit = $Margin/VBox/CategoryPanel/CategoryPad/CategoryRow/CategoryEdit
@onready var add_category_button: Button = $Margin/VBox/CategoryPanel/CategoryPad/CategoryRow/AddCategoryButton
@onready var create_quiz_button: Button = $Margin/VBox/CreateQuizButton
@onready var status_label: Label = $Margin/VBox/StatusLabel

## True while any call is in flight, so a second tap cannot queue a second
## request on top of one already running -- Quizz.gd itself queues rather
## than drops, but a screen that can double-fire on every tap is still
## worth guarding at the UI layer.
var _busy := false
var _categories: Array = []
## NO_CATEGORY or a real category id -- what create_quiz() will receive.
var _selected_category_id: String = NO_CATEGORY
var _categories_failed := false

func _ready() -> void:
	SafeArea.set_cream()
	# UI screen: canvas fills the screen, no letterbox -- see SafeArea.gd.
	SafeArea.fill_screen()
	back_button.pressed.connect(_on_back_pressed)
	create_quiz_button.pressed.connect(_on_create_quiz_pressed)
	title_edit.text_submitted.connect(func(_text: String) -> void: _on_create_quiz_pressed())
	add_category_button.pressed.connect(_on_add_category_pressed)
	category_edit.text_submitted.connect(func(_text: String) -> void: _on_add_category_pressed())
	Quizz.quiz_created.connect(_on_quiz_created)
	Quizz.category_created.connect(_on_category_created)
	Quizz.categories_fetched.connect(_on_categories_fetched)
	_render_chips()
	_refresh_categories()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)

func _refresh_categories() -> void:
	_set_busy(true, CATEGORIES_LOADING_LABEL)
	Quizz.list_own_categories()

func _on_create_quiz_pressed() -> void:
	if _busy:
		return
	var safe_title := title_edit.text.strip_edges()
	if safe_title.is_empty():
		status_label.text = "Donne un titre a ton quizz d'abord."
		return
	_set_busy(true, CREATING_LABEL)
	Quizz.create_quiz(safe_title, _selected_category_id)

func _on_quiz_created(success: bool, quiz_id: String, error: String) -> void:
	if not success:
		_set_busy(false, "")
		status_label.text = "%s\n(%s)" % [GENERIC_ERROR_LABEL, error]
		return
	# Straight to the question editor -- the quiz exists but is empty, and
	# the whole point of creating it is to put questions in it.
	QuestionsScreen.open(get_tree(), quiz_id, title_edit.text.strip_edges())

func _on_add_category_pressed() -> void:
	if _busy:
		return
	var safe_name := category_edit.text.strip_edges()
	if safe_name.is_empty():
		status_label.text = "Donne un nom a la categorie d'abord."
		return
	# Refused HERE rather than round-tripped: two drawers with the same name
	# are indistinguishable on a chip row, and the rules cannot see sibling
	# documents so the server would happily accept the duplicate.
	for category in _categories:
		if String(category.get("name", "")).to_lower() == safe_name.to_lower():
			status_label.text = "Cette categorie existe deja."
			return
	_set_busy(true, CATEGORY_CREATING_LABEL)
	Quizz.create_category(safe_name)

func _on_category_created(success: bool, category_id: String, error: String) -> void:
	if not success:
		_set_busy(false, "")
		# Degrade, never block: on staging this is the EXPECTED 403 (rules
		# not deployed yet, see the header). The message says so in player
		# terms and the quiz path stays fully usable. The raw reason goes
		# to stderr where a device log can find it.
		push_warning("QuizzCreateScreen: category create failed (%s)" % error)
		status_label.text = CATEGORY_CREATE_FAILED_LABEL
		return
	category_edit.text = ""
	# Select the brand-new drawer straight away: it is the one thing the
	# player just asked for.
	_selected_category_id = category_id
	_refresh_categories()

func _on_categories_fetched(success: bool, categories: Array, error: String) -> void:
	_set_busy(false, "")
	_categories_failed = not success
	_categories = categories
	if not success:
		# Same degradation rule as the header spells out. Not routed through
		# the status label -- that one belongs to the two CREATE actions.
		push_warning("QuizzCreateScreen: categories unavailable (%s)" % error)
	# A selection can outlive the category it names (deleted elsewhere, or
	# a fetch that came back short). Falling back to "no category" is the
	# only choice that can never file a quiz into a drawer that is gone.
	if not _selection_is_reachable():
		_selected_category_id = NO_CATEGORY
	_render_chips()

func _selection_is_reachable() -> bool:
	if _selected_category_id == NO_CATEGORY:
		return true
	for category in _categories:
		if String(category.get("id", "")) == _selected_category_id:
			return true
	return false

## "Sans categorie" first (the default), then one chip per category. When
## the fetch failed, the whole category tooling collapses to the hint --
## chips that could never be filled and an "Ajouter" that can only 403
## would read as broken, not as optional.
func _render_chips() -> void:
	for child in chip_row.get_children():
		child.queue_free()
	if _categories_failed:
		category_hint_label.text = CATEGORIES_UNAVAILABLE_HINT
		chip_scroll.visible = false
		category_panel.visible = false
		return
	category_hint_label.text = CATEGORY_HINT_DEFAULT
	chip_scroll.visible = true
	category_panel.visible = true
	chip_row.add_child(_build_chip(NO_CATEGORY, "Sans categorie"))
	for category in _categories:
		chip_row.add_child(_build_chip(String(category.get("id", "")), String(category.get("name", ""))))

func _build_chip(category_id: String, label: String) -> Button:
	var chip := Button.new()
	if category_id == _selected_category_id:
		chip.theme_type_variation = &"ChipSelected"
	else:
		chip.theme_type_variation = &"Chip"
	chip.text = label
	chip.custom_minimum_size = Vector2(0, 56)
	chip.disabled = _busy
	chip.pressed.connect(_on_chip_pressed.bind(category_id))
	return chip

func _on_chip_pressed(category_id: String) -> void:
	if _busy or category_id == _selected_category_id:
		return
	_selected_category_id = category_id
	_render_chips()

func _set_busy(busy: bool, label: String) -> void:
	_busy = busy
	create_quiz_button.disabled = busy
	title_edit.editable = not busy
	add_category_button.disabled = busy
	category_edit.editable = not busy
	for chip in chip_row.get_children():
		if chip is Button:
			chip.disabled = busy
	# Always written, not just while busy: the busy==false, label=="" call
	# is what clears the in-flight message off the screen.
	status_label.text = label
