extends CanvasLayer
class_name GameOverScreen
## Game over overlay: final score, local-record detection, global
## leaderboard submission and "Rejouer". Shows itself when GameState
## transitions to GAME_OVER and hides on any other state.
##
## Submission flow (see Leaderboard.gd for the actual REST calls):
##   1. The local best score is always updated synchronously and offline
##      (Leaderboard.record_local_best) -- independent of anything below.
##   2. A silent "precheck" fetch of the current top 10 decides whether
##      this run's score is worth asking for a pseudo: either it just
##      beat the local record, or it would place inside the current
##      top 10 (or the board has fewer than 10 entries yet).
##   3a. If it qualifies: the pseudo field appears, pre-filled with the
##       last saved name; submission waits for "Valider".
##   3b. If it doesn't: submission fires immediately with the last saved
##       pseudo (or the "Anonyme" default), no prompt shown.
##
## A failed precheck fetch (offline, Firestore down) is NOT the same as
## "doesn't qualify": in that case only the local-record condition can
## still be evaluated, so a new local record still prompts for a name
## even with no network -- submission itself will then also fail, but
## harmlessly (see Leaderboard.submit_score), and the game is never
## blocked either way.
##
## DEATH CAUSE: the headline distinguishes being caught from behind
## (GameState.DeathCause.PURSUER) from running into something in front.
## Presentation ONLY -- the score, the two pickup counts and therefore the
## whole leaderboard payload below are byte-identical either way, because
## being caught is a different EVENT, not a different kind of run. Nothing
## in _show_game_over / _handle_precheck_result / _begin_submit branches on
## it, and that is deliberate.
##
## Known limitation, accepted as-is: HTTPRequest is single-flight and
## GameState.state_changed can fire again (Rejouer) before an in-flight
## fetch/submit resolves. An extremely fast retry-before-reply could
## apply a stale network reply to the wrong run. Not guarded against on
## purpose -- worst case is a cosmetic mismatch in the prompt, and the
## round trip is normally far shorter than a full run.

enum _TopFetchStep { NONE, PRECHECK, FINAL }

@onready var root: Control = $Root
## Headline text per death cause, retargeted onto the EXISTING TitleLabel
## rather than a second label of its own -- that node already reads
## "Perdu !", so the COLLISION entry below is its authored value and the
## default path is unchanged.
const CAUSE_TEXT := {
	GameState.DeathCause.COLLISION: "Perdu !",
	GameState.DeathCause.PURSUER: "Rattrape !",
}

@onready var title_label: Label = $Root/CenterContainer/VBoxContainer/TitleLabel
@onready var score_label: Label = $Root/CenterContainer/VBoxContainer/ScoreLabel
@onready var record_label: Label = $Root/CenterContainer/VBoxContainer/RecordLabel
@onready var name_entry_container: HBoxContainer = $Root/CenterContainer/VBoxContainer/NameEntryContainer
@onready var name_input: LineEdit = $Root/CenterContainer/VBoxContainer/NameEntryContainer/NameInput
@onready var submit_name_button: Button = $Root/CenterContainer/VBoxContainer/NameEntryContainer/SubmitNameButton
@onready var top_list_label: Label = $Root/CenterContainer/VBoxContainer/TopListLabel
@onready var top_list_container: VBoxContainer = $Root/CenterContainer/VBoxContainer/TopListContainer
@onready var retry_button: Button = $Root/CenterContainer/VBoxContainer/RetryButton

var _top_fetch_step: int = _TopFetchStep.NONE
var _is_new_record: bool = false
var _pending_score: int = 0
var _pending_nuts: int = 0
var _pending_glands: int = 0

func _ready() -> void:
	retry_button.pressed.connect(_on_retry_pressed)
	submit_name_button.pressed.connect(_on_submit_name_pressed)
	GameState.state_changed.connect(_on_state_changed)
	Leaderboard.top_scores_fetched.connect(_on_top_scores_fetched)
	Leaderboard.submit_finished.connect(_on_submit_finished)
	root.visible = false

func _on_state_changed(new_state: int) -> void:
	if new_state == GameState.State.GAME_OVER:
		_show_game_over()
	else:
		root.visible = false

func _show_game_over() -> void:
	_pending_score = GameState.score
	_pending_nuts = GameState.nut_count
	_pending_glands = GameState.gland_count
	title_label.text = CAUSE_TEXT.get(GameState.death_cause, CAUSE_TEXT[GameState.DeathCause.COLLISION])
	score_label.text = "Score : %d" % _pending_score

	_is_new_record = Leaderboard.record_local_best(_pending_score)
	record_label.visible = _is_new_record

	name_entry_container.visible = false
	_set_top_list_status("Chargement du classement...")
	root.visible = true

	_top_fetch_step = _TopFetchStep.PRECHECK
	Leaderboard.fetch_top_scores()

func _on_top_scores_fetched(entries: Array, success: bool) -> void:
	match _top_fetch_step:
		_TopFetchStep.PRECHECK:
			_top_fetch_step = _TopFetchStep.NONE
			_handle_precheck_result(entries, success)
		_TopFetchStep.FINAL:
			_top_fetch_step = _TopFetchStep.NONE
			_render_top_scores(entries, success)
		_:
			pass  # stray/late reply (e.g. a fast Rejouer) -- see class doc

func _handle_precheck_result(entries: Array, success: bool) -> void:
	var qualifies := _is_new_record
	if success and not qualifies:
		qualifies = entries.size() < 10 or _pending_score > int(entries[entries.size() - 1].get("score", 0))
	if qualifies:
		name_input.text = Leaderboard.get_saved_name()
		name_entry_container.visible = true
	else:
		_begin_submit(Leaderboard.get_saved_name())

func _on_submit_name_pressed() -> void:
	Leaderboard.save_name(name_input.text)
	name_entry_container.visible = false
	_begin_submit(Leaderboard.get_saved_name())

func _begin_submit(player_name: String) -> void:
	Leaderboard.submit_score(player_name, _pending_score, _pending_nuts, _pending_glands)

## Fires after every submit attempt, success or failure alike -- either
## way the board may have changed (this run's own submission, or simply
## time passing), so it's re-fetched for display once more.
func _on_submit_finished(_success: bool) -> void:
	_set_top_list_status("Chargement du classement...")
	_top_fetch_step = _TopFetchStep.FINAL
	Leaderboard.fetch_top_scores()

func _render_top_scores(entries: Array, success: bool) -> void:
	_clear_top_list()
	if not success:
		_set_top_list_status("Classement indisponible")
		return
	if entries.is_empty():
		_set_top_list_status("Aucun score pour l'instant")
		return
	top_list_label.visible = false
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var row := Label.new()
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 22)
		row.text = "%d. %s -- %d" % [i + 1, entry.get("name", "?"), int(entry.get("score", 0))]
		top_list_container.add_child(row)

func _set_top_list_status(text: String) -> void:
	_clear_top_list()
	top_list_label.text = text
	top_list_label.visible = true

func _clear_top_list() -> void:
	for child in top_list_container.get_children():
		child.queue_free()

func _on_retry_pressed() -> void:
	GameState.start_run()
