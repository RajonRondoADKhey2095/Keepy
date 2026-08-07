extends Node
## Autoloaded as "Leaderboard". Two independent responsibilities kept in
## one place because they share the same "never block/crash the game"
## contract:
##   1. Local best-score + pseudo persistence via `user://` (FileAccess),
##      which Godot's Web export backs with IndexedDB automatically -- it
##      survives a reload/relaunch without any network call.
##   2. Best-effort submission/fetch against the global "scores" collection
##      of the standalone Firebase project keepy-8df91, over the Firestore
##      REST API directly (no Firebase SDK). Every network entry point
##      degrades to a signal carrying `success = false` instead of raising
##      -- callers (GameOverScreen) never have to special-case "offline".
##
## Firestore REST field encoding used throughout this file: every field is
## wrapped in its Firestore "Value" type -- `stringValue` for text,
## `integerValue` for whole numbers (sent as a JSON STRING per the REST
## spec's int64 mapping, to avoid precision loss -- `str(int)` handles
## that), `timestampValue` for RFC3339 UTC instants.

signal submit_finished(success: bool)
## `entries` is an Array of {"name": String, "score": int} sorted
## score-descending (already the order Firestore returned), capped at 10.
## Always emitted, even on failure (with an empty array).
signal top_scores_fetched(entries: Array, success: bool)

const PROJECT_ID := "keepy-8df91"
const API_KEY := "AIzaSyD7Kxu14Ukuj5l8_0SkUpjWwTu5_na2J3A"
const DOCUMENTS_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % PROJECT_ID
const COLLECTION_ID := "scores"

const BEST_SCORE_PATH := "user://leaderboard_best_score.txt"
const PLAYER_NAME_PATH := "user://leaderboard_player_name.txt"
const DEFAULT_NAME := "Anonyme"
## Matches the deployed rule `name.size() <= 12` exactly -- verified
## against the live project (13 chars rejected with permission-denied,
## 12 chars accepted). Truncate to this everywhere a pseudo is used.
const NAME_MAX_LEN := 12
const AUTO_ID_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
const AUTO_ID_LEN := 20

## Gates BOTH network entry points below (submit_score AND
## fetch_top_scores) -- true by default, so a normal play session behaves
## exactly as before this flag existed. Set to false to make every call
## degrade instantly to its existing "offline" signal path (no HTTPRequest
## ever fires), the very same path already exercised whenever the device
## has no network -- callers need no new branch to handle this.
## See _ready() below for where this actually gets flipped off.
var network_enabled: bool = true

var _submit_request: HTTPRequest
var _query_request: HTTPRequest

func _ready() -> void:
	_submit_request = HTTPRequest.new()
	add_child(_submit_request)
	_submit_request.request_completed.connect(_on_submit_completed)

	_query_request = HTTPRequest.new()
	add_child(_query_request)
	_query_request.request_completed.connect(_on_query_completed)


# ---------------------------------------------------------------------
# Local persistence (no network, never fails loudly)
# ---------------------------------------------------------------------

func get_best_score() -> int:
	if not FileAccess.file_exists(BEST_SCORE_PATH):
		return 0
	var f := FileAccess.open(BEST_SCORE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var value := f.get_as_text().strip_edges()
	f.close()
	if not value.is_valid_int():
		return 0
	return value.to_int()

## Persists `score` as the new local best if it beats the current one.
## Returns true when this run set a new record. A failure to open the
## file for writing is swallowed on purpose (worst case: the record
## doesn't survive a relaunch, which is never worse than the in-memory-only
## behaviour this replaces).
func record_local_best(score: int) -> bool:
	if score <= get_best_score():
		return false
	var f := FileAccess.open(BEST_SCORE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(str(score))
		f.close()
	return true

func get_saved_name() -> String:
	if not FileAccess.file_exists(PLAYER_NAME_PATH):
		return DEFAULT_NAME
	var f := FileAccess.open(PLAYER_NAME_PATH, FileAccess.READ)
	if f == null:
		return DEFAULT_NAME
	var value := f.get_as_text().strip_edges()
	f.close()
	return value if not value.is_empty() else DEFAULT_NAME

func save_name(player_name: String) -> void:
	var trimmed := player_name.strip_edges().substr(0, NAME_MAX_LEN)
	if trimmed.is_empty():
		return
	var f := FileAccess.open(PLAYER_NAME_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(trimmed)
		f.close()


# ---------------------------------------------------------------------
# Network: submit a run
# ---------------------------------------------------------------------

## Fire-and-forget submission of a completed run to the global
## leaderboard. `submit_finished` always fires exactly once per call
## (success or failure) -- callers never need a timeout of their own.
##
## Deliberately NOT a plain "POST .../documents/scores" create (the
## simplest REST shape, and the one implied by a naive reading of the
## Firestore REST docs): the deployed rule on `scores` requires
## `createdAt == request.time` exactly, which only the server can
## produce. A client-supplied literal timestamp -- however close to
## "now" -- never satisfies that equality and was verified (live,
## against this exact project) to fail every time with
## PERMISSION_DENIED. The only way to hand the server its own commit
## time from the REST API is `:commit` with an `updateTransforms` entry
## using `setToServerValue: "REQUEST_TIME"`, which substitutes the real
## server timestamp into `createdAt` before the rule evaluates it --
## confirmed working (200, and the doc later readable with a real
## `createdAt`) against the live project during implementation.
func submit_score(player_name: String, score: int, nuts: int, glands: int) -> void:
	if not network_enabled:
		submit_finished.emit(false)
		return
	var safe_name := player_name.strip_edges().substr(0, NAME_MAX_LEN)
	if safe_name.is_empty():
		safe_name = DEFAULT_NAME
	var doc_id := _generate_auto_id()
	var body := {
		"writes": [
			{
				"update": {
					"name": "projects/%s/databases/(default)/documents/%s/%s" % [PROJECT_ID, COLLECTION_ID, doc_id],
					"fields": {
						"name": { "stringValue": safe_name },
						"score": { "integerValue": str(score) },
						"nuts": { "integerValue": str(nuts) },
						"glands": { "integerValue": str(glands) },
					},
				},
				"updateTransforms": [
					{ "fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME" },
				],
				# Precondition guaranteeing this is a CREATE, never an
				# overwrite of another run's doc -- doc_id is a fresh
				# random id every call, so this should always hold; it's
				# a safety net, not something expected to ever trip.
				"currentDocument": { "exists": false },
			},
		],
	}
	var url := "%s:commit?key=%s" % [DOCUMENTS_URL, API_KEY]
	var headers := ["Content-Type: application/json"]
	var err := _submit_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_warning("Leaderboard: submit_score request() failed to start (err=%d)" % err)
		submit_finished.emit(false)

func _on_submit_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning("Leaderboard: score submission failed (result=%d, code=%d, body=%s)" % [result, response_code, body.get_string_from_utf8()])
		submit_finished.emit(false)
		return
	submit_finished.emit(true)


# ---------------------------------------------------------------------
# Network: fetch the top 10
# ---------------------------------------------------------------------

## Firestore REST "structured query": POST to `:runQuery` with a body
## describing the query (collection + orderBy + limit) instead of GET
## query params. The response is a JSON ARRAY, one entry per matched
## document (in order); entries with no "document" key are query-plan
## metadata only and are skipped.
func fetch_top_scores() -> void:
	if not network_enabled:
		top_scores_fetched.emit([], false)
		return
	var body := {
		"structuredQuery": {
			"from": [{ "collectionId": COLLECTION_ID }],
			"orderBy": [{ "field": { "fieldPath": "score" }, "direction": "DESCENDING" }],
			"limit": 10,
		},
	}
	var url := "%s:runQuery?key=%s" % [DOCUMENTS_URL, API_KEY]
	var headers := ["Content-Type: application/json"]
	var err := _query_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_warning("Leaderboard: fetch_top_scores request() failed to start (err=%d)" % err)
		top_scores_fetched.emit([], false)

func _on_query_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		push_warning("Leaderboard: fetch_top_scores failed (result=%d, code=%d, body=%s)" % [result, response_code, body.get_string_from_utf8()])
		top_scores_fetched.emit([], false)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Leaderboard: fetch_top_scores got a non-array response, ignoring")
		top_scores_fetched.emit([], false)
		return
	var entries: Array = []
	for row in parsed:
		if typeof(row) != TYPE_DICTIONARY or not row.has("document"):
			continue
		var document: Dictionary = row["document"]
		var fields: Dictionary = document.get("fields", {})
		var name_field: Dictionary = fields.get("name", {})
		var score_field: Dictionary = fields.get("score", {})
		var score_str: String = str(score_field.get("integerValue", "0"))
		entries.append({
			"name": str(name_field.get("stringValue", "?")),
			"score": score_str.to_int() if score_str.is_valid_int() else 0,
		})
	top_scores_fetched.emit(entries, true)


# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------

## Client-generated document id in the same alphabet Firestore's own
## auto-ids use (not cryptographically required to match exactly, just
## needs to be URL-safe and effectively collision-free at this project's
## scale).
func _generate_auto_id() -> String:
	var id := ""
	for i in AUTO_ID_LEN:
		id += AUTO_ID_CHARS[randi() % AUTO_ID_CHARS.length()]
	return id
