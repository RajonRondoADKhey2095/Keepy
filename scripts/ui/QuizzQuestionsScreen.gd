extends Control
## Question editor (ecran 3 of the 20 aout 2026 flow): lists the questions
## of ONE quiz and appends new ones. Opened from the home screen (tap on a
## quiz row) and from the creation screen (right after create_quiz
## succeeds). Nothing here edits or deletes an existing question -- that is
## a future lot; this one makes a quiz FILLABLE at all.
##
## =====================================================================
## ONE HOST SCENE, THREE FORMAT PANELS -- the section-7 architecture
##
## The three question formats (mcq4 / truefalse / free) are PANELS inside
## this one scene, toggled by a chip row -- not three scenes. That is the
## same decision docs/QUIZZ_SPEC.md section 7 already arbitrated for the
## future PLAY screen ("hote unique + panneaux par format"), applied for
## the same reason: the chrome (prompt field, counter, add button, status,
## the question list above) is common to all three formats, and a player
## switches format per QUESTION, not per session -- three scenes would
## triple the chrome and put a scene change inside a form.
##
## =====================================================================
## HOW THE QUIZ ID GETS HERE -- static open(), because
## change_scene_to_file() cannot carry arguments
##
## The repo's navigation convention is get_tree().change_scene_to_file(),
## which passes nothing. Callers therefore go through the static open()
## below, which parks the id/title in static vars the new instance reads
## in _ready(). Statics on a script survive the scene change by
## construction (the script resource lives as long as the ResourceCache),
## and each open() overwrites them, so stale state cannot leak from one
## visit into the next. A DIRECT boot of this scene (a probe, a debug F6)
## finds them empty and degrades: list untouched, form disabled, message
## on screen, back button still works.
##
## =====================================================================
## SEQUENTIAL, NEVER PARALLEL -- the Quizz.gd FIFO is respected
##
## Quizz.gd serialises everything through one HTTPRequest and one queue.
## This screen adds its own UI-layer guarantee on top: _busy stays true
## from the moment "Ajouter la question" is pressed until BOTH the create
## AND the follow-up list refresh have answered, so a second add cannot
## even be requested while the first is anywhere in flight. Bounds are
## enforced before sending (max_length on every field, inline checks
## here), so the player never discovers a limit through a server refusal.

const HOME_SCENE := "res://scenes/QuizzHomeScreen.tscn"
const SCENE_PATH := "res://scenes/QuizzQuestionsScreen.tscn"
const LOADING_LABEL := "Chargement des questions..."
const ADDING_LABEL := "Ajout de la question..."
const NO_QUIZ_LABEL := "Aucun quizz selectionne. Reviens a l'accueil."
const GENERIC_ERROR_LABEL := "Erreur : impossible de contacter Firestore."

## Answer-state sentinel: -1 = nothing picked yet. The player must pick
## explicitly (no silent default), so a question can never be saved with an
## answer nobody chose.
const ANSWER_UNSET := -1

## Display names of the three formats, keyed by the Quizz.gd type strings.
## Also the source of the format chip row -- one entry, one chip.
const FORMAT_LABELS := {
	"mcq4": "QCM",
	"truefalse": "Vrai ou faux",
	"free": "Reponse libre",
}

const CARD_SHINE := preload("res://resources/gradients/quizz_shine_card.tres")

## Handed from the previous screen through open() -- see the header.
static var pending_quiz_id: String = ""
static var pending_quiz_title: String = ""

## The one way to navigate here with a quiz attached.
static func open(tree: SceneTree, quiz_id: String, quiz_title: String) -> void:
	pending_quiz_id = quiz_id
	pending_quiz_title = quiz_title
	tree.change_scene_to_file(SCENE_PATH)

@onready var back_button: Button = $Margin/VBox/HeaderRow/BackButton
@onready var header_label: Label = $Margin/VBox/HeaderRow/HeaderCol/HeaderLabel
@onready var question_list: VBoxContainer = $Margin/VBox/Scroll/ContentVBox/QuestionList
@onready var empty_label: Label = $Margin/VBox/Scroll/ContentVBox/EmptyLabel
@onready var format_chips: HBoxContainer = $Margin/VBox/Scroll/ContentVBox/FormatChips
@onready var form_panel: PanelContainer = $Margin/VBox/Scroll/ContentVBox/FormPanel
@onready var prompt_edit: LineEdit = $Margin/VBox/Scroll/ContentVBox/FormPanel/FormVBox/PromptEdit
@onready var prompt_counter: Label = $Margin/VBox/Scroll/ContentVBox/FormPanel/FormVBox/PromptCounter
@onready var mcq4_panel: VBoxContainer = $Margin/VBox/Scroll/ContentVBox/FormPanel/FormVBox/Mcq4Panel
@onready var choice_edits: Array[LineEdit] = [
	$Margin/VBox/Scroll/ContentVBox/FormPanel/FormVBox/Mcq4Panel/Choice0Edit,
	$Margin/VBox/Scroll/ContentVBox/FormPanel/FormVBox/Mcq4Panel/Choice1Edit,
	$Margin/VBox/Scroll/ContentVBox/FormPanel/FormVBox/Mcq4Panel/Choice2Edit,
	$Margin/VBox/Scroll/ContentVBox/FormPanel/FormVBox/Mcq4Panel/Choice3Edit,
]
@onready var mcq_answer_chips: HBoxContainer = $Margin/VBox/Scroll/ContentVBox/FormPanel/FormVBox/Mcq4Panel/McqAnswerChips
@onready var truefalse_panel: VBoxContainer = $Margin/VBox/Scroll/ContentVBox/FormPanel/FormVBox/TrueFalsePanel
@onready var tf_answer_chips: HBoxContainer = $Margin/VBox/Scroll/ContentVBox/FormPanel/FormVBox/TrueFalsePanel/TfAnswerChips
@onready var free_panel: VBoxContainer = $Margin/VBox/Scroll/ContentVBox/FormPanel/FormVBox/FreePanel
@onready var free_answer_edit: LineEdit = $Margin/VBox/Scroll/ContentVBox/FormPanel/FormVBox/FreePanel/FreeAnswerEdit
@onready var add_button: Button = $Margin/VBox/Scroll/ContentVBox/AddButton
@onready var status_label: Label = $Margin/VBox/Scroll/ContentVBox/StatusLabel

var _quiz_id: String = ""
var _quiz_title: String = ""
## Last fetched questions, sorted (order, id) by Quizz.gd. What the list
## renders, what _next_order() reads, and what the 50-question cap counts.
var _questions: Array = []
## One of Quizz.QUESTION_TYPES -- which format panel is active.
var _format: String = Quizz.TYPE_MCQ4
## ANSWER_UNSET, or 0..3 (mcq4) / 0=faux 1=vrai (truefalse).
var _mcq_answer: int = ANSWER_UNSET
var _tf_answer: int = ANSWER_UNSET
## True from an add OR a list call leaving until its answer arrives --
## see the sequencing note in the header.
var _busy := false

func _ready() -> void:
	SafeArea.set_cream()
	# UI screen: canvas fills the screen, no letterbox -- see SafeArea.gd.
	SafeArea.fill_screen()
	_quiz_id = pending_quiz_id
	_quiz_title = pending_quiz_title
	if not _quiz_title.is_empty():
		header_label.text = _quiz_title
	back_button.pressed.connect(_on_back_pressed)
	add_button.pressed.connect(_on_add_pressed)
	prompt_edit.text_changed.connect(_on_prompt_changed)
	Quizz.questions_fetched.connect(_on_questions_fetched)
	Quizz.question_created.connect(_on_question_created)
	_build_format_chips()
	_build_answer_chips()
	_apply_format()
	if _quiz_id.is_empty():
		# Direct boot with no quiz in hand (probe, debug run): degrade to a
		# message instead of round-tripping an invalid-quiz-id refusal.
		status_label.text = NO_QUIZ_LABEL
		add_button.disabled = true
		return
	_refresh_questions()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(HOME_SCENE)


# ---------------------------------------------------------------------
# Question list
# ---------------------------------------------------------------------

func _refresh_questions() -> void:
	_set_busy(true, LOADING_LABEL)
	Quizz.list_questions(_quiz_id)

func _on_questions_fetched(success: bool, quiz_id: String, questions: Array, error: String) -> void:
	if quiz_id != _quiz_id:
		return
	_set_busy(false, "")
	# Kept whatever happens, so a failed refresh clears a stale list
	# instead of leaving rows that no longer describe anything.
	_questions = questions
	_populate_list()
	if not success:
		status_label.text = "%s\n(%s)" % [GENERIC_ERROR_LABEL, error]

func _populate_list() -> void:
	for child in question_list.get_children():
		child.queue_free()
	empty_label.visible = _questions.is_empty()
	for i in _questions.size():
		question_list.add_child(_build_question_row(_questions[i], i))

## Presentation only. A question row is NOT pressable in this lot (there is
## no per-question editor yet), so it stays a PanelContainer, unlike the
## home screen's rows which became Buttons when they gained a destination.
func _build_question_row(question: Dictionary, index: int) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"QuizRowPanel"
	var shine := TextureRect.new()
	shine.texture = CARD_SHINE
	shine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(shine)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 26)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_right", 28)
	pad.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	pad.add_child(box)

	# "Question N" is the DISPLAY position (1-based index in the sorted
	# list), deliberately not the stored `order`: order is neither unique
	# nor contiguous (the deployed rules say so themselves), so echoing it
	# would show gaps the player never created.
	var meta_label := Label.new()
	var type_name: String = FORMAT_LABELS.get(String(question.get("type", "")), "?")
	meta_label.text = "Question %d -- %s" % [index + 1, type_name]
	meta_label.theme_type_variation = &"MutedLabel"
	box.add_child(meta_label)

	var prompt_label := Label.new()
	prompt_label.text = String(question.get("prompt", ""))
	prompt_label.theme_type_variation = &"CardTitleLabel"
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(prompt_label)

	return panel


# ---------------------------------------------------------------------
# Format selection
# ---------------------------------------------------------------------

func _build_format_chips() -> void:
	for type in Quizz.QUESTION_TYPES:
		var chip := Button.new()
		chip.text = FORMAT_LABELS[type]
		chip.custom_minimum_size = Vector2(0, 56)
		chip.pressed.connect(_on_format_pressed.bind(String(type)))
		format_chips.add_child(chip)
	_restyle_format_chips()

func _restyle_format_chips() -> void:
	for i in format_chips.get_child_count():
		var chip: Button = format_chips.get_child(i)
		var type: String = String(Quizz.QUESTION_TYPES[i])
		chip.theme_type_variation = &"ChipSelected" if type == _format else &"Chip"

func _on_format_pressed(type: String) -> void:
	if _busy or type == _format:
		return
	_format = type
	_apply_format()

func _apply_format() -> void:
	_restyle_format_chips()
	mcq4_panel.visible = _format == Quizz.TYPE_MCQ4
	truefalse_panel.visible = _format == Quizz.TYPE_TRUEFALSE
	free_panel.visible = _format == Quizz.TYPE_FREE

## The answer pickers are chips too -- same selected-state language
## (dark ring on orange, measured in docs/QUIZZ_DESIGN.md) as every other
## exclusive choice in Quizz. Built once; selection restyles them.
func _build_answer_chips() -> void:
	for i in Quizz.MCQ4_CHOICE_COUNT:
		var chip := Button.new()
		chip.text = char(65 + i)  # A / B / C / D, matching the placeholders.
		chip.custom_minimum_size = Vector2(76, 56)
		chip.pressed.connect(_on_mcq_answer_pressed.bind(i))
		mcq_answer_chips.add_child(chip)
	# 1 = vrai first: the natural reading order of "Vrai ou faux".
	for value in [1, 0]:
		var chip := Button.new()
		chip.text = "Vrai" if value == 1 else "Faux"
		chip.custom_minimum_size = Vector2(120, 56)
		chip.pressed.connect(_on_tf_answer_pressed.bind(value))
		tf_answer_chips.add_child(chip)
	_restyle_answer_chips()

func _restyle_answer_chips() -> void:
	for i in mcq_answer_chips.get_child_count():
		var chip: Button = mcq_answer_chips.get_child(i)
		chip.theme_type_variation = &"ChipSelected" if i == _mcq_answer else &"Chip"
	# Child order is [vrai, faux] -- see _build_answer_chips.
	for i in tf_answer_chips.get_child_count():
		var chip: Button = tf_answer_chips.get_child(i)
		var value: int = 1 - i
		chip.theme_type_variation = &"ChipSelected" if value == _tf_answer else &"Chip"

func _on_mcq_answer_pressed(index: int) -> void:
	if _busy:
		return
	_mcq_answer = index
	_restyle_answer_chips()

func _on_tf_answer_pressed(value: int) -> void:
	if _busy:
		return
	_tf_answer = value
	_restyle_answer_chips()

func _on_prompt_changed(text: String) -> void:
	prompt_counter.text = "%d/%d" % [text.length(), Quizz.PROMPT_MAX_LEN]


# ---------------------------------------------------------------------
# Adding a question
# ---------------------------------------------------------------------

## Every bound the deployed rules enforce is checked HERE first, so the
## player gets an inline message instead of a server refusal. The
## max_length on each LineEdit already makes the upper bounds unreachable;
## what remains to check inline is the empties, the unpicked answers, and
## the two per-quiz caps.
func _on_add_pressed() -> void:
	if _busy:
		return
	if _questions.size() >= Quizz.QUESTION_COUNT_MAX:
		status_label.text = "Ce quizz a deja %d questions, le maximum." % Quizz.QUESTION_COUNT_MAX
		return
	var order := _next_order()
	if order > Quizz.QUESTION_ORDER_MAX:
		status_label.text = "Limite de questions atteinte pour ce quizz."
		return
	var prompt := prompt_edit.text.strip_edges()
	if prompt.is_empty():
		status_label.text = "Ecris l'enonce de la question d'abord."
		return
	var payload := { "prompt": prompt, "order": order }
	match _format:
		Quizz.TYPE_MCQ4:
			for i in Quizz.MCQ4_CHOICE_COUNT:
				var choice := choice_edits[i].text.strip_edges()
				if choice.is_empty():
					status_label.text = "Remplis les 4 choix (le %s est vide)." % choice_edits[i].placeholder_text
					return
				payload["choice%d" % i] = choice
			if _mcq_answer == ANSWER_UNSET:
				status_label.text = "Choisis la bonne reponse (A, B, C ou D)."
				return
			payload["answerIndex"] = _mcq_answer
		Quizz.TYPE_TRUEFALSE:
			if _tf_answer == ANSWER_UNSET:
				status_label.text = "Choisis la bonne reponse (Vrai ou Faux)."
				return
			payload["answerBool"] = _tf_answer == 1
		Quizz.TYPE_FREE:
			var answer := free_answer_edit.text.strip_edges()
			if answer.is_empty():
				status_label.text = "Ecris la reponse attendue."
				return
			payload["answerText"] = answer
	_set_busy(true, ADDING_LABEL)
	Quizz.create_question(_quiz_id, _format, payload)

## Next `order` value: one past the highest existing one, NOT the list
## size and NOT a restart from 0 -- orders are neither unique nor
## contiguous (a deleted question leaves a gap for ever), so only max+1
## is guaranteed to sort a new question after every existing one.
func _next_order() -> int:
	var next := 0
	for question in _questions:
		next = maxi(next, int(question.get("order", 0)) + 1)
	return next

func _on_question_created(success: bool, quiz_id: String, _question_id: String, error: String) -> void:
	if quiz_id != _quiz_id:
		return
	if not success:
		_set_busy(false, "")
		status_label.text = "%s\n(%s)" % [GENERIC_ERROR_LABEL, error]
		return
	_clear_form()
	# The list is refreshed from the server rather than patched locally, so
	# what the player sees is always what is stored -- and _busy stays true
	# through it, which is what makes back-to-back adds strictly
	# sequential (see the header).
	_refresh_questions()

## Clears the per-question inputs but keeps the FORMAT: a player writing
## ten QCM in a row should not have to re-pick "QCM" ten times.
func _clear_form() -> void:
	prompt_edit.text = ""
	_on_prompt_changed("")
	for edit in choice_edits:
		edit.text = ""
	free_answer_edit.text = ""
	_mcq_answer = ANSWER_UNSET
	_tf_answer = ANSWER_UNSET
	_restyle_answer_chips()

func _set_busy(busy: bool, label: String) -> void:
	_busy = busy
	add_button.disabled = busy
	prompt_edit.editable = not busy
	for edit in choice_edits:
		edit.editable = not busy
	free_answer_edit.editable = not busy
	for chip in format_chips.get_children():
		if chip is Button:
			chip.disabled = busy
	for chip in mcq_answer_chips.get_children():
		if chip is Button:
			chip.disabled = busy
	for chip in tf_answer_chips.get_children():
		if chip is Button:
			chip.disabled = busy
	# Always written -- the busy==false, label=="" call is what clears the
	# in-flight message off the screen.
	status_label.text = label
