extends Control
## First real screen exercising Quizz.gd (autoloaded 18 aout 2026, deployed
## to staging, never yet called for real). Scope is deliberately narrow:
## create a quiz by title, and list the signed-in user's own quizzes. No
## question editing, no play loop -- that is QuizzEditorScreen /
## QuizzPlayScreen territory (docs/QUIZZ_SPEC.md section 7), not this file.
##
## Since 19 aout 2026 it also owns CATEGORIES: create one, filter the list
## by one, and file a new quiz into the selected one. Two things it does
## NOT do, and both are deliberate rather than forgotten -- there is no way
## to DELETE a category from here (Quizz.delete_category() exists and is
## wired to nothing yet: deleting a drawer silently dangles every quiz that
## named it, so it wants a confirmation this lot does not build), and no way
## to RE-file an existing quiz (the deployed rules would allow it, this
## screen has no editor to host it).
##
## Reached from scenes/Hub.tscn's "Keepy Quizz" button, which used to be
## disabled with a "Bientot disponible" caption. That guard is gone: this
## screen is the reason it could come off.

const CREATE_LABEL := "Creer"
const CREATING_LABEL := "Creation..."
const LOADING_LABEL := "Chargement..."
const EMPTY_LABEL := "Aucun questionnaire pour l'instant."
const GENERIC_ERROR_LABEL := "Erreur : impossible de contacter Firestore."
const CATEGORY_CREATING_LABEL := "Creation de la categorie..."
const CATEGORIES_LOADING_LABEL := "Chargement des categories..."

## Chip identifiers that are NOT category ids.
##
## FILTER_ALL is "" -- the same value `create_quiz()` reads as "no
## category", which is fine because the two are never compared to each
## other: _target_category_id() maps every non-category filter back to ""
## before it ever reaches Quizz.gd.
##
## FILTER_NONE is "-", and it CANNOT collide with a real id: an id comes
## from Quizz._generate_auto_id(), 20 characters drawn from an alphabet of
## letters and digits only. A one-character id, and a hyphen at that, is
## unreachable by construction rather than merely unlikely.
const FILTER_ALL := ""
const FILTER_NONE := "-"
const FILTER_ALL_LABEL := "Toutes"
const FILTER_NONE_LABEL := "Sans categorie"
## Firestore's own message for a missing composite index always carries this
## status and a ready-made console URL -- see Quizz.list_own_quizzes()'s doc
## comment. Detecting on the status string rather than guessing from the URL
## alone keeps this screen from ever mistaking an unrelated 400 for the
## expected first-run index gap.
const MISSING_INDEX_MARKER := "FAILED_PRECONDITION"

## Shared with scenes/QuizzHomeScreen.tscn (the two search bars use the same
## resource). Preloaded rather than rebuilt per row: a Gradient plus a
## GradientTexture2D per list row would be N allocations for one identical
## image.
const CARD_SHINE := preload("res://resources/gradients/quizz_shine_card.tres")

@onready var back_button: Button = $Margin/VBox/HeaderRow/BackButton
@onready var title_edit: LineEdit = $Margin/VBox/CreatePanel/CreatePad/CreateRow/TitleEdit
## Left the search bar on 19 aout 2026, and later the same day stopped
## being full-width too: it is a CENTRED BLOCK of 672x200 now, because at
## 1008x76 it read as a bar rather than as a call to action. Same node,
## same signal, same handler throughout -- only its place in the tree, its
## size and its styling have ever changed. See docs/QUIZZ_DESIGN.md.
@onready var create_button: Button = $Margin/VBox/CreateButton
## The CTA's two text levels live in child Labels now, not in Button.text,
## so the theme's `font_disabled_color` no longer reaches them: without
## this handle a busy CTA would keep fully-dark text over its peach
## disabled fill and read as still pressable. Purely presentational -- it
## is dimmed alongside the `disabled` flag _set_busy() already sets.
@onready var cta_text: VBoxContainer = $Margin/VBox/CreateButton/CtaText
@onready var create_hint_label: Label = $Margin/VBox/CreateHintLabel
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var index_help_panel: PanelContainer = $Margin/VBox/IndexHelpPanel
@onready var index_url_edit: LineEdit = $Margin/VBox/IndexHelpPanel/VBox/IndexUrlEdit
@onready var copy_url_button: Button = $Margin/VBox/IndexHelpPanel/VBox/CopyUrlButton
@onready var scroll: ScrollContainer = $Margin/VBox/Scroll
@onready var quiz_list: VBoxContainer = $Margin/VBox/Scroll/QuizList
@onready var empty_label: Label = $Margin/VBox/EmptyLabel
@onready var category_edit: LineEdit = $Margin/VBox/CategoryPanel/CategoryPad/CategoryRow/CategoryEdit
@onready var add_category_button: Button = $Margin/VBox/CategoryPanel/CategoryPad/CategoryRow/AddCategoryButton
@onready var chip_row: HBoxContainer = $Margin/VBox/ChipScroll/ChipRow

## True while a create or list call is in flight, so a second tap cannot
## queue a second request on top of one already running -- Quizz.gd itself
## queues rather than drops, but a screen that can double-fire on every tap
## is still worth guarding at the UI layer, same discipline as
## LoginScreen's sign_in_button.disabled during _on_sign_in_pressed().
var _busy := false

## Last fetched payloads, kept so that changing the chip selection can
## re-render without a round trip -- filtering is CLIENT-SIDE and that is
## a deliberate index decision, not laziness: adding `categoryId` to the
## server query would combine a second equality filter with the existing
## orderBy and demand a THIRD composite index, created by hand in the
## Console. See docs/QUIZZ_SPEC.md section 8.
var _quizzes: Array = []
var _categories: Array = []
## FILTER_ALL / FILTER_NONE / a real category id.
var _filter_id: String = FILTER_ALL
## True when the categories fetch itself failed. Kept separate from the
## quiz error path on purpose: the screen is fully usable without
## categories (every quiz is reachable under "Toutes"), so that failure
## gets its own inert chip rather than the status label, which stays
## reserved for the quiz list -- the thing this screen exists to show.
var _categories_failed := false

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
	title_edit.text_submitted.connect(func(_text: String) -> void: _on_create_pressed())
	copy_url_button.pressed.connect(_on_copy_url_pressed)
	add_category_button.pressed.connect(_on_add_category_pressed)
	category_edit.text_submitted.connect(func(_text: String) -> void: _on_add_category_pressed())
	Quizz.quiz_created.connect(_on_quiz_created)
	Quizz.quizzes_fetched.connect(_on_quizzes_fetched)
	Quizz.category_created.connect(_on_category_created)
	Quizz.categories_fetched.connect(_on_categories_fetched)
	_render_chips()
	_update_create_hint()
	# Categories FIRST, then the quiz list -- strictly sequenced rather than
	# fired together. Both would work (Quizz.gd queues rather than drops),
	# but two overlapping calls would need a pending counter and a rule for
	# whose error owns the status label; sequencing keeps the single _busy
	# flag this screen already had and keeps the quiz error path unchanged.
	_refresh_categories()

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
	Quizz.create_quiz(safe_title, _target_category_id())

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
	# Kept whatever happens, so a failed refresh clears the stale list
	# instead of leaving rows on screen that no longer describe anything.
	_quizzes = quizzes
	# Chips are rendered on BOTH branches: a missing composite index is the
	# documented shape of the very first call, and a screen whose category
	# row only appears once the quiz list succeeds would look broken exactly
	# when the help panel is trying to explain that it is not.
	_render_chips()
	_update_create_hint()
	if not success:
		_populate_list([])
		_show_error(error)
		return
	index_help_panel.visible = false
	_populate_list(_visible_quizzes())

func _set_busy(busy: bool, label: String) -> void:
	_busy = busy
	create_button.disabled = busy
	cta_text.modulate = Color(1, 1, 1, 0.55 if busy else 1.0)
	title_edit.editable = not busy
	add_category_button.disabled = busy
	category_edit.editable = not busy
	# Chips too: switching filter while a create is in flight would re-render
	# the list under the response about to arrive, and would silently change
	# which category that create is filing into.
	for chip in chip_row.get_children():
		if chip is Button:
			chip.disabled = busy
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
	# "Nothing here" and "nothing in THIS drawer" are different facts, and a
	# player who has just picked a filter needs to be told which one they are
	# looking at -- otherwise an empty filtered list reads as data loss.
	empty_label.text = EMPTY_LABEL if _filter_id == FILTER_ALL else "Aucun questionnaire dans cette categorie."
	for quiz in quizzes:
		quiz_list.add_child(_build_row(quiz))

## Presentation only -- no CRUD, signal or error path runs through here.
##
## Shape: [coral accent rule] [title / date column]. The rule is the screen's
## one piece of colour that is not orange, and it is deliberately a BAR and
## not the filled icon block the reference mockup puts in this slot: this
## project has no icon set for quiz rows, so a solid block would read as a
## slot waiting for an asset that never arrives. A rule reads as finished.
func _build_row(quiz: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"QuizRowPanel"
	# Matter, not decoration: the same sheen the CTA and the two search bars
	# carry, so a row reads as the same material rather than as a flat
	# rectangle sitting next to shiny ones. Added FIRST so it draws under
	# the text. It needs no corner mask: the gradient is RADIAL from the
	# bottom edge midpoint, so its alpha is already down to ~4% by the time
	# it reaches a corner -- the shape of the sheen does the masking. Both
	# masks tried before it failed, and why is in docs/QUIZZ_DESIGN.md,
	# "Matiere".
	var shine := TextureRect.new()
	shine.texture = CARD_SHINE
	shine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(shine)
	# Padding lives here, not in the stylebox: a PanelContainer insets EVERY
	# child by its content margin, which would have inset the sheen too and
	# stopped it short of the card edge with a hard line (measured on the
	# first render of this lot).
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 26)
	pad.add_theme_constant_override("margin_top", 24)
	pad.add_theme_constant_override("margin_right", 28)
	pad.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	pad.add_child(row)

	var accent := Panel.new()
	accent.theme_type_variation = &"AccentBar"
	accent.custom_minimum_size = Vector2(6, 0)
	# FILL, not EXPAND: the rule stretches to whatever height the text column
	# ends up at instead of claiming horizontal space away from it.
	accent.size_flags_vertical = Control.SIZE_FILL
	row.add_child(accent)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)

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


# ---------------------------------------------------------------------
# Categories -- fetch, create, chips, filtering
# ---------------------------------------------------------------------

func _refresh_categories() -> void:
	_set_busy(true, CATEGORIES_LOADING_LABEL)
	Quizz.list_own_categories()

func _on_add_category_pressed() -> void:
	if _busy:
		return
	var safe_name := category_edit.text.strip_edges()
	if safe_name.is_empty():
		status_label.text = "Donne un nom a la categorie d'abord."
		return
	# Refused HERE rather than round-tripped: two drawers with the same name
	# are indistinguishable on a chip row, and the rules cannot see sibling
	# documents so the server would happily accept the duplicate. Compared
	# case-insensitively, the same way _compare_categories sorts.
	for category in _categories:
		if String(category.get("name", "")).to_lower() == safe_name.to_lower():
			status_label.text = "Cette categorie existe deja."
			return
	_set_busy(true, CATEGORY_CREATING_LABEL)
	Quizz.create_category(safe_name)

func _on_category_created(success: bool, category_id: String, error: String) -> void:
	if not success:
		_set_busy(false, "")
		_show_error(error)
		return
	category_edit.text = ""
	# Select the brand-new drawer straight away: it is the one thing the
	# player just asked for, and it makes the create hint below the CTA say
	# something true about the very next quiz they make.
	_filter_id = category_id
	_refresh_categories()

func _on_categories_fetched(success: bool, categories: Array, error: String) -> void:
	_categories_failed = not success
	_categories = categories
	if not success:
		# Deliberately NOT routed through _show_error: the status label
		# belongs to the quiz list, which is about to load and to have its
		# own say. The failure is surfaced as an inert chip instead, and the
		# raw reason goes to stderr where a probe or a device log can find it.
		push_warning("QuizzHomeScreen: categories unavailable (%s)" % error)
	# A filter can outlive the category it names -- a drawer deleted from
	# another device, or simply a fetch that came back short. Falling back to
	# "Toutes" is the only choice that cannot hide quizzes from their owner.
	if not _filter_is_reachable():
		_filter_id = FILTER_ALL
	# The quiz list is refreshed in the same breath, and _on_quizzes_fetched
	# is what finally renders the chips -- by then both halves are known, so
	# the counts on the chips are never drawn from a half-loaded screen.
	_refresh_list()

## True when the current selection still corresponds to something the chip
## row will actually draw.
func _filter_is_reachable() -> bool:
	if _filter_id == FILTER_ALL or _filter_id == FILTER_NONE:
		return true
	for category in _categories:
		if String(category.get("id", "")) == _filter_id:
			return true
	return false

## The category a quiz is displayed under: its own `categoryId` when that
## id still resolves to one of the user's categories, and "" (uncategorised)
## otherwise.
##
## That fallback is what makes a DANGLING id harmless. Nothing deletes the
## field when a category disappears -- neither Firestore (no cascade) nor
## this screen (an N-write repair loop that can fail halfway is worse than a
## stale string). So resolution happens at display time, every time.
func _resolved_category_id(quiz: Dictionary) -> String:
	var raw := String(quiz.get("categoryId", ""))
	if raw.is_empty():
		return ""
	for category in _categories:
		if String(category.get("id", "")) == raw:
			return raw
	return ""

func _visible_quizzes() -> Array:
	if _filter_id == FILTER_ALL:
		return _quizzes
	var out: Array = []
	for quiz in _quizzes:
		var resolved := _resolved_category_id(quiz)
		if _filter_id == FILTER_NONE:
			if resolved.is_empty():
				out.append(quiz)
		elif resolved == _filter_id:
			out.append(quiz)
	return out

func _count_in(filter_id: String) -> int:
	if filter_id == FILTER_ALL:
		return _quizzes.size()
	var total := 0
	for quiz in _quizzes:
		var resolved := _resolved_category_id(quiz)
		if filter_id == FILTER_NONE:
			if resolved.is_empty():
				total += 1
		elif resolved == filter_id:
			total += 1
	return total

## The chip row: "Toutes", one chip per category, and "Sans categorie" only
## when there is actually something in it.
##
## That last condition is the whole reason the row is not just the category
## list: a quiz created before this lot -- or created with no drawer picked
## -- carries no `categoryId` and would otherwise be reachable only under
## "Toutes". Showing the chip unconditionally would instead put a permanent
## always-empty drawer on screen for a player who files everything.
func _render_chips() -> void:
	for child in chip_row.get_children():
		child.queue_free()
	if _categories_failed:
		# Not a Button: nothing here is pressable, and a disabled Button
		# would read as a filter that happens to be unavailable rather than
		# as a report about the fetch.
		var warning := Label.new()
		warning.text = "Categories indisponibles"
		warning.theme_type_variation = &"MutedLabel"
		chip_row.add_child(warning)
		return
	chip_row.add_child(_build_chip(FILTER_ALL, FILTER_ALL_LABEL))
	for category in _categories:
		chip_row.add_child(_build_chip(String(category.get("id", "")), String(category.get("name", ""))))
	if _count_in(FILTER_NONE) > 0:
		chip_row.add_child(_build_chip(FILTER_NONE, FILTER_NONE_LABEL))

## Presentation only. The selected state is carried by the `ChipSelected`
## theme variation, whose measured contrast is argued in
## docs/QUIZZ_DESIGN.md -- in short, the state indicator is the 2px dark
## ring (10.68:1 against the cream page, 4.84:1 against the orange fill),
## not the orange fill on its own, which measures 2.32:1 against a white
## chip and would fail WCAG SC 1.4.11.
func _build_chip(filter_id: String, label: String) -> Button:
	var chip := Button.new()
	if filter_id == _filter_id:
		chip.theme_type_variation = &"ChipSelected"
	else:
		chip.theme_type_variation = &"Chip"
	chip.text = "%s (%d)" % [label, _count_in(filter_id)]
	chip.custom_minimum_size = Vector2(0, 56)
	# _set_busy() only reaches the chips that exist when it runs; a row
	# rebuilt during a request has to re-apply the state itself.
	chip.disabled = _busy
	chip.pressed.connect(_on_chip_pressed.bind(filter_id))
	return chip

func _on_chip_pressed(filter_id: String) -> void:
	if _busy or filter_id == _filter_id:
		return
	_filter_id = filter_id
	# No round trip: both payloads are already in hand, which is exactly what
	# _quizzes/_categories are kept for.
	_render_chips()
	_update_create_hint()
	_populate_list(_visible_quizzes())

## The category a new quiz will be filed into: the current selection when it
## is a real category, and "" for "Toutes" and "Sans categorie" alike --
## neither of those is a drawer a document can point at.
func _target_category_id() -> String:
	if _filter_id == FILTER_ALL or _filter_id == FILTER_NONE:
		return ""
	return _filter_id

## Says out loud where the CTA is about to file. Without it the binding
## between the selected chip and create_quiz() would be invisible -- a
## player would have to create a quiz to discover it.
func _update_create_hint() -> void:
	var target := _target_category_id()
	if target.is_empty():
		create_hint_label.text = "Nouveau quizz : sans categorie."
		return
	for category in _categories:
		if String(category.get("id", "")) == target:
			create_hint_label.text = "Nouveau quizz range dans : %s" % String(category.get("name", ""))
			return
	create_hint_label.text = "Nouveau quizz : sans categorie."
