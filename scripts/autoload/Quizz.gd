extends Node
## Autoloaded as "Quizz". Authoring CRUD for Keepy Quizz against the
## `quizzes/{quizId}` collection, its `questions/{questionId}`
## sub-collection, and the top-level `categories/{categoryId}` collection
## of the Firebase project keepy-8df91, over the Firestore REST API
## directly (no Firebase SDK), exactly like Leaderboard.gd.
##
## FIRST REAL CLIENT of the Quizz rules deployed to production on
## 18 aout 2026 (run #3 of firestore-rules.yml). Until this file existed
## the rules described a contract nothing exercised. The shapes below are
## written against the deployed `firestore.rules`, read field by field --
## not against the draft in docs/QUIZZ_SPEC.md section 4, which the
## deployed file supersedes.
##
## =====================================================================
## SCOPE -- what this file is NOT
##
## Authoring only: create / read / update / delete the SIGNED-IN USER'S
## OWN quizzes, questions and categories -- the last of these has no
## update at all, by rule (see delete_category). There is no play loop here, no scoring, no
## screen, and nothing in scenes/. The Quizz button of scenes/Hub.tscn is
## still `disabled = true` and still connected to nothing -- Hub.tscn and
## Hub.gd are untouched by the batch that added this file. See CLAUDE.md
## for where a future session picks this up.
##
## =====================================================================
## ROBUSTNESS CONTRACT -- identical to Leaderboard.gd
##
##   1. Headless short-circuit FIRST, in _ready(): every scripts/dev
##      probe boots with `--headless`, so `network_enabled` goes false
##      there and every entry point degrades to its failure signal
##      without ever constructing a request. That covers every probe
##      automatically, including future ones -- no probe has to opt out.
##   2. No entry point can crash or block. Every public call emits its
##      signal EXACTLY ONCE, success or failure, so callers never need a
##      timeout of their own and never have to special-case "offline".
##   3. A rejected argument fails locally, before any socket is opened.
##
## =====================================================================
## AUTH IS MANDATORY HERE, UNLIKE Leaderboard.gd
##
## Leaderboard.gd attaches `Authorization: Bearer <idToken>` "when
## available, never required", because the /scores rules used to accept
## anonymous writes. The Quizz rules do not: `signedIn()` gates read,
## create, update AND delete on both collections. A request without a
## bearer is a GUARANTEED 403.
##
## So this file refuses to spend a round trip on a certain refusal: every
## entry point checks for BOTH a signed-in user and a non-empty token,
## and emits `error = "auth-required"` immediately when either is
## missing. The two are checked separately on purpose -- Auth publishes
## the uid BEFORE the token (see Auth.get_id_token's doc), so a
## signed-in check alone would let an empty bearer through, which Google
## answers with 401 rather than a rule refusal.
##
## The token is read at the moment each request leaves _pump(), never
## cached: a Firebase ID token lasts one hour and the shell republishes a
## renewed one through onIdTokenChanged. An authoring session is far more
## exposed to that than a run of Keepy Chased, which writes once at the
## game over screen.
##
## =====================================================================
## FIRESTORE REST SHAPES USED (docs/QUIZZ_SPEC.md section 8)
##
##  - CREATE: `:commit` with `currentDocument: {exists: false}` and TWO
##    `updateTransforms` (`createdAt` and `updatedAt`, both
##    `setToServerValue: REQUEST_TIME`). The rules demand
##    `createdAt == request.time`, which only the server can produce -- a
##    client-supplied literal never satisfies that equality.
##  - UPDATE: `:commit` with `currentDocument: {exists: true}`, an
##    explicit `updateMask.fieldPaths` listing EXACTLY the fields sent,
##    and a transform on `updatedAt`. `uid` and `createdAt` are never in
##    the mask and never sent: the immutability rules compare the
##    RESULTING document to the stored one, and a field outside the mask
##    is preserved untouched, so omitting them satisfies the comparison.
##    (A mask referencing a field absent from `fields` DELETES it, hence
##    "exactly the fields sent" and not "everything the schema allows".)
##  - DELETE: `:commit` with a `delete` write and
##    `currentDocument: {exists: true}`.
##  - LIST: `:runQuery` with a structured query that MUST carry a
##    `fieldFilter uid EQUAL <my uid>`. Firestore only runs queries it
##    can prove conform to an owner-only read rule -- an unfiltered list
##    is REFUSED, not empty.
##
## =====================================================================
## ONE HTTPRequest, ONE FIFO QUEUE
##
## An HTTPRequest node serves one request at a time (ERR_BUSY otherwise).
## Leaderboard.gd gets away with one node per endpoint because it has
## exactly two; this file has eleven operations across three collections,
## so a node per entry point would be eleven idle nodes and would still not
## serialise two creates in a row. Instead: a single node, a FIFO queue,
## and a single in-flight slot. Nothing is ever dropped silently -- a
## call made while another is in flight is queued and dispatched when the
## slot frees, and a queued call whose auth has since disappeared fails
## with its own signal rather than being discarded.

## Every signal follows the same argument order: `success` first, then the
## identifiers/payload, then `error` last. `error` is "" on success and a
## machine-or-human readable reason otherwise (see the ERR_* constants,
## plus verbatim Firestore messages for server refusals -- those carry the
## console URL when an index is missing, so they are NOT truncated).
##
## NOTE the divergence from Leaderboard.gd, which puts `success` last
## (`top_scores_fetched(entries, success)`). That file predates this one
## and is not touched here; consistency INSIDE this file was preferred to
## consistency with a two-signal neighbour.
signal quiz_created(success: bool, quiz_id: String, error: String)
signal quiz_updated(success: bool, quiz_id: String, error: String)
signal quiz_deleted(success: bool, quiz_id: String, error: String)
## `quizzes` is an Array of Dictionaries, newest-modified first, shaped
## exactly like the payload accepted by create_quiz/update_quiz plus an
## "id" key -- see _decode_quiz(). Always emitted, empty on failure.
signal quizzes_fetched(success: bool, quizzes: Array, error: String)

signal question_created(success: bool, quiz_id: String, question_id: String, error: String)
signal question_updated(success: bool, quiz_id: String, question_id: String, error: String)
signal question_deleted(success: bool, quiz_id: String, question_id: String, error: String)
## `questions` is an Array of Dictionaries sorted by (order, id) -- see
## the sort note on QUESTION_ORDER_MAX. Always emitted, empty on failure.
signal questions_fetched(success: bool, quiz_id: String, questions: Array, error: String)

## Categories (19 aout 2026). Same argument order as everything above.
## There is deliberately NO `category_updated`: the deployed rules answer
## `allow update: if false` on this collection, so a rename is a refusal,
## not a feature waiting for a client. See the comment on delete_category.
signal category_created(success: bool, category_id: String, error: String)
signal category_deleted(success: bool, category_id: String, error: String)
## `categories` is an Array of Dictionaries sorted by (lowercased name, id)
## -- see the sort note on list_own_categories(). Always emitted, empty on
## failure.
signal categories_fetched(success: bool, categories: Array, error: String)

## Project id and API key are READ FROM Leaderboard.gd rather than copied.
## They identify the same Firebase project, and two literal copies of an
## API key is a rotation hazard whose failure mode is a silent 403 in
## whichever file was forgotten. Leaderboard is registered before this
## autoload (see project.godot), and constants resolve through the
## singleton at call time.
const QUIZZES_COLLECTION := "quizzes"
const QUESTIONS_COLLECTION := "questions"
## TOP-LEVEL, sibling of `quizzes`, not a sub-collection of it -- a
## category belongs to the USER and is shared by several quizzes. See the
## header comment of its `match` block in firestore.rules.
const CATEGORIES_COLLECTION := "categories"

## Client-side mirrors of the deployed rules. Checking them here does not
## make the server checks redundant -- the server remains the authority --
## it only turns a guaranteed 403 into an instant local failure with a
## reason a UI can actually show.
const TITLE_MIN_LEN := 1
const TITLE_MAX_LEN := 60
const CATEGORY_NAME_MIN_LEN := 1
const CATEGORY_NAME_MAX_LEN := 30
## Mirrors the rules' own bound on `quizzes.categoryId`, which is 64 and
## not 20 on purpose: neither side should encode the current auto-id
## length, or changing the generator would need a rules deploy.
const CATEGORY_ID_MAX_LEN := 64
const PROMPT_MIN_LEN := 1
const PROMPT_MAX_LEN := 200
const CHOICE_MIN_LEN := 1
const CHOICE_MAX_LEN := 120
const ANSWER_TEXT_MIN_LEN := 1
const ANSWER_TEXT_MAX_LEN := 120
const QUESTION_ORDER_MAX := 199
const QUESTION_COUNT_MAX := 50
const MCQ4_CHOICE_COUNT := 4

const TYPE_MCQ4 := "mcq4"
const TYPE_TRUEFALSE := "truefalse"
const TYPE_FREE := "free"
const QUESTION_TYPES := [TYPE_MCQ4, TYPE_TRUEFALSE, TYPE_FREE]

## The only `visibility` value the deployed rules accept. Not a default
## that a caller may override -- an argument would suggest otherwise, so
## there is none. Widening sharing is a decision that reopens
## docs/QUIZZ_SPEC.md section 2.3, not a parameter.
const VISIBILITY_PRIVATE := "private"

const AUTO_ID_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
const AUTO_ID_LEN := 20

## Failure reasons produced locally, before any request goes out.
const ERR_NETWORK_DISABLED := "network-disabled"
const ERR_AUTH_REQUIRED := "auth-required"
const ERR_REQUEST_START := "request-start-failed"
const ERR_BAD_RESPONSE := "bad-response"

## Same meaning and same detection as Leaderboard.network_enabled: false
## under the headless DisplayServer (every scripts/dev probe), true in a
## browser or a desktop editor. Flipped in _ready() below.
var network_enabled: bool = true

var _http: HTTPRequest
var _queue: Array[Dictionary] = []
## The operation currently owning _http. Empty dictionary means idle.
var _in_flight: Dictionary = {}
## Re-entry guard for _pump() -- see its doc comment.
var _pumping: bool = false

func _ready() -> void:
	# Identical detection to Leaderboard._ready(), for the identical
	# reason -- see the contract note at the top of this file.
	if DisplayServer.get_name() == "headless":
		network_enabled = false

	_http = HTTPRequest.new()
	# Firestore answers with `Content-Encoding: gzip`, and on the Web
	# export fetch/XHR has ALREADY decoded the body before Godot sees it.
	# Leaving accept_gzip on makes HTTPRequest try to gunzip plaintext
	# JSON and throw away a successful response: measured on device as
	# result=8 (RESULT_BODY_DECOMPRESS_FAILED) with code=200, on both the
	# installed PWA and a plain Chrome tab. Same fix as Leaderboard.gd.
	_http.accept_gzip = false
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


# ---------------------------------------------------------------------
# Public API -- quizzes
# ---------------------------------------------------------------------

## Creates a quiz owned by the signed-in user and emits `quiz_created`
## exactly once. The document id is generated client-side (same alphabet
## and length as Firestore's own auto-ids) and handed back on the signal
## so the caller can immediately add questions to it without a list
## round trip.
##
## `questionCount` is written explicitly as 0 rather than omitted, even
## though the rules make it optional: a counter that exists from the
## start makes update_quiz a plain field write instead of a
## create-or-update branch. It stays a DISPLAY value -- the rules cannot
## count sub-collection documents, so nothing ever reconciles it with
## reality (docs/QUIZZ_SPEC.md section 5).
##
## `category_id` is OPTIONAL and defaults to "" -- every call written
## before 19 aout 2026 keeps compiling and keeps producing exactly the
## same document, with no `categoryId` field at all.
##
## Only its SHAPE is checked here. That the category exists and belongs
## to the same user is NOT verified, by neither this file nor the rules:
## the rules could do it with a get(), and that is deliberately declined
## for the three reasons spelled out on validCategoryId() in
## firestore.rules (billed read on the hot path, a deleted category
## silently freezing every quiz that cited it, and get()-of-absent being
## an evaluation error rather than a clean false). The real integrity
## gate is the UI, which can only ever pass an id it just listed. A
## dangling id is not a security hole -- `categoryId` is never a read key,
## the quiz list is filtered on `uid` and nothing else -- it just files a
## quiz in a drawer of its own owner that no longer exists, and the
## screen shows those as uncategorised (docs/QUIZZ_SPEC.md section 5).
func create_quiz(title: String, category_id: String = "") -> void:
	var safe_title := title.strip_edges()
	var invalid := _validate_title(safe_title)
	if not invalid.is_empty():
		quiz_created.emit(false, "", invalid)
		return
	var safe_category := category_id.strip_edges()
	var invalid_category := _validate_category_id(safe_category)
	if not invalid_category.is_empty():
		quiz_created.emit(false, "", invalid_category)
		return
	var gate := _gate()
	if not gate.is_empty():
		quiz_created.emit(false, "", gate)
		return
	var quiz_id := _generate_auto_id()
	var fields := {
		"uid": { "stringValue": _uid() },
		"title": { "stringValue": safe_title },
		"visibility": { "stringValue": VISIBILITY_PRIVATE },
		"questionCount": { "integerValue": "0" },
	}
	# OMITTED, not written as "" -- the rules bound categoryId at 1..64
	# when present, so an empty string would be a refusal, and a field
	# that exists-but-means-nothing is worse than an absent one anyway.
	if not safe_category.is_empty():
		fields["categoryId"] = { "stringValue": safe_category }
	var body := {
		"writes": [
			{
				"update": {
					"name": _quiz_path(quiz_id),
					"fields": fields,
				},
				"updateTransforms": [
					{ "fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME" },
					{ "fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME" },
				],
				"currentDocument": { "exists": false },
			},
		],
	}
	_enqueue({
		"kind": "quiz_create",
		"url": _commit_url(),
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body),
		"quiz_id": quiz_id,
		"question_id": "",
	})

## Renames a quiz, and optionally refreshes its display counter. Pass
## `question_count = -1` (the default) to leave the counter alone.
##
## `visibility` IS sent even though it never changes: the rules require
## the resulting document to carry it, and sending it makes this write
## self-sufficient instead of dependent on what happens to be stored.
## `uid` and `createdAt` are NOT sent -- see the UPDATE shape note at the
## top of this file.
func update_quiz(quiz_id: String, title: String, question_count: int = -1) -> void:
	if quiz_id.is_empty():
		quiz_updated.emit(false, quiz_id, "invalid-quiz-id")
		return
	var safe_title := title.strip_edges()
	var invalid := _validate_title(safe_title)
	if not invalid.is_empty():
		quiz_updated.emit(false, quiz_id, invalid)
		return
	if question_count > QUESTION_COUNT_MAX:
		quiz_updated.emit(false, quiz_id, "invalid-question-count")
		return
	var gate := _gate()
	if not gate.is_empty():
		quiz_updated.emit(false, quiz_id, gate)
		return
	var fields := {
		"title": { "stringValue": safe_title },
		"visibility": { "stringValue": VISIBILITY_PRIVATE },
	}
	var mask := ["title", "visibility"]
	if question_count >= 0:
		fields["questionCount"] = { "integerValue": str(question_count) }
		mask.append("questionCount")
	var body := {
		"writes": [
			{
				"update": {
					"name": _quiz_path(quiz_id),
					"fields": fields,
				},
				"updateMask": { "fieldPaths": mask },
				"updateTransforms": [
					{ "fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME" },
				],
				"currentDocument": { "exists": true },
			},
		],
	}
	_enqueue({
		"kind": "quiz_update",
		"url": _commit_url(),
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body),
		"quiz_id": quiz_id,
		"question_id": "",
	})

## Deletes a quiz. NOT a cascade: its questions survive as orphans,
## readable by their owner and nobody else. That is a deployed-rules
## limitation, not an oversight here -- a rule cannot delete other
## documents, and doing it client-side would need a list + N deletes that
## can fail halfway. A caller that wants the sub-collection gone must
## list_questions() and delete_question() each one FIRST, while the
## parent still exists.
func delete_quiz(quiz_id: String) -> void:
	if quiz_id.is_empty():
		quiz_deleted.emit(false, quiz_id, "invalid-quiz-id")
		return
	var gate := _gate()
	if not gate.is_empty():
		quiz_deleted.emit(false, quiz_id, gate)
		return
	var body := {
		"writes": [
			{
				"delete": _quiz_path(quiz_id),
				"currentDocument": { "exists": true },
			},
		],
	}
	_enqueue({
		"kind": "quiz_delete",
		"url": _commit_url(),
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body),
		"quiz_id": quiz_id,
		"question_id": "",
	})

## Lists the signed-in user's own quizzes, most recently modified first.
##
## The `uid EQUAL` filter is NOT an optimisation and must never be
## dropped: the read rule is owner-only, and Firestore refuses a query it
## cannot prove conforming rather than returning a filtered subset.
##
## WARNING -- COMPOSITE INDEX REQUIRED, and it is a MANUAL action.
## An equality filter combined with an orderBy on a DIFFERENT field is
## not served by single-field indexes: this query needs `uid ASC` +
## `updatedAt DESC` on `quizzes`. Until it exists, Firestore answers 400
## FAILED_PRECONDITION with a message containing a ready-made console URL
## -- that message is forwarded VERBATIM on the `error` argument of
## `quizzes_fetched`, so the URL survives to the caller instead of being
## swallowed. Nothing here retries or silently falls back to an unsorted
## query: that would hide a missing index behind a different result set.
func list_own_quizzes() -> void:
	var gate := _gate()
	if not gate.is_empty():
		quizzes_fetched.emit(false, [], gate)
		return
	var body := {
		"structuredQuery": {
			"from": [{ "collectionId": QUIZZES_COLLECTION }],
			"where": _own_uid_filter(),
			"orderBy": [{ "field": { "fieldPath": "updatedAt" }, "direction": "DESCENDING" }],
		},
	}
	_enqueue({
		"kind": "quizzes_list",
		"url": _run_query_url(""),
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body),
		"quiz_id": "",
		"question_id": "",
	})


# ---------------------------------------------------------------------
# Public API -- categories
# ---------------------------------------------------------------------

## Creates a category owned by the signed-in user and emits
## `category_created` exactly once, handing back the client-generated id
## so the caller can select it immediately without a list round trip --
## same shape as create_quiz.
##
## No `updatedAt`: nothing can modify a category (the rules answer
## `allow update: if false`), so a "last modified" field could never hold
## anything but `createdAt`.
func create_category(name: String) -> void:
	var safe_name := name.strip_edges()
	var invalid := _validate_category_name(safe_name)
	if not invalid.is_empty():
		category_created.emit(false, "", invalid)
		return
	var gate := _gate()
	if not gate.is_empty():
		category_created.emit(false, "", gate)
		return
	var category_id := _generate_auto_id()
	var body := {
		"writes": [
			{
				"update": {
					"name": _category_path(category_id),
					"fields": {
						"uid": { "stringValue": _uid() },
						"name": { "stringValue": safe_name },
					},
				},
				"updateTransforms": [
					{ "fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME" },
				],
				"currentDocument": { "exists": false },
			},
		],
	}
	_enqueue({
		"kind": "category_create",
		"url": _commit_url(),
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body),
		"quiz_id": "",
		"question_id": "",
		"category_id": category_id,
	})

## Deletes a category. NOT a cascade, and there is nothing to cascade
## INTO: quizzes are not children of a category, they merely name one.
## Every quiz whose `categoryId` was this one keeps that id and becomes a
## dangling reference -- deliberately, because the alternative (list every
## quiz, rewrite each one) is an N-write best-effort loop that can fail
## halfway and leave the collection in a worse state than one stale id.
## A dangling id is harmless by construction: it is never a read key, and
## a screen resolves it against the categories it actually fetched, so an
## unresolvable one reads as "no category" rather than as an error.
##
## There is no `update_category()`, and that is a rules-level fact, not an
## omission here: the deployed `allow update: if false` would refuse the
## write. Renaming therefore means delete + create, which mints a NEW id
## and dangles every quiz that cited the old one. Re-opening it takes both
## halves at once -- the rule and the method -- see firestore.rules.
func delete_category(category_id: String) -> void:
	if category_id.is_empty():
		category_deleted.emit(false, category_id, "invalid-category-id")
		return
	var gate := _gate()
	if not gate.is_empty():
		category_deleted.emit(false, category_id, gate)
		return
	var body := {
		"writes": [
			{
				"delete": _category_path(category_id),
				"currentDocument": { "exists": true },
			},
		],
	}
	_enqueue({
		"kind": "category_delete",
		"url": _commit_url(),
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body),
		"quiz_id": "",
		"question_id": "",
		"category_id": category_id,
	})

## Lists the signed-in user's own categories.
##
## The `uid EQUAL` filter is mandatory for the same reason as in
## list_own_quizzes(): the read rule is owner-only, and Firestore refuses
## a query it cannot prove conforming rather than returning a subset.
##
## NO `orderBy`, and that is the whole point -- it is what keeps this
## query servable by the AUTOMATIC single-field index on `uid` and out of
## the composite-index Console dance list_own_quizzes() has to warn about.
## An equality filter combined with an orderBy on a DIFFERENT field is
## what needs a composite index; an equality filter alone does not. So
## this call cannot answer 400 FAILED_PRECONDITION, and adding a sort
## here later is not a free change -- it is a manual index creation.
##
## Ordering is therefore done in _dispatch, on (lowercased name, id):
## alphabetical because a drawer list is scanned by eye and not by
## recency, case-insensitive so "Histoire" and "histoire" sit together,
## and tie-broken on the document id so two categories of the same name
## keep a stable order between two fetches.
func list_own_categories() -> void:
	var gate := _gate()
	if not gate.is_empty():
		categories_fetched.emit(false, [], gate)
		return
	var body := {
		"structuredQuery": {
			"from": [{ "collectionId": CATEGORIES_COLLECTION }],
			"where": _own_uid_filter(),
		},
	}
	_enqueue({
		"kind": "categories_list",
		"url": _run_query_url(""),
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body),
		"quiz_id": "",
		"question_id": "",
		"category_id": "",
	})


# ---------------------------------------------------------------------
# Public API -- questions
# ---------------------------------------------------------------------

## Creates a question inside `quiz_id`. `type` is one of QUESTION_TYPES,
## and `payload` carries the fields under their EXACT Firestore names --
## the same names _decode_question() hands back, so what you read is what
## you write, with no translation table to get wrong:
##
##   common      : "prompt" (String), "order" (int)
##   mcq4        : "choice0".."choice3" (String), "answerIndex" (int 0..3)
##   truefalse   : "answerBool" (bool)
##   free        : "answerText" (String)
##
## `uid` is filled in from Auth and must NOT be in `payload`; the two
## timestamps come from server transforms. Anything else in `payload` is
## ignored here and would be refused by the rules' per-type `hasOnly`.
##
## The 50-questions-per-quiz cap of docs/QUIZZ_SPEC.md is NOT enforced
## here and cannot be: neither this file nor a rule can count the
## sub-collection without a list, and a count read at create time races
## with itself. A caller that cares must count what list_questions()
## returned and refuse locally.
func create_question(quiz_id: String, type: String, payload: Dictionary) -> void:
	if quiz_id.is_empty():
		question_created.emit(false, quiz_id, "", "invalid-quiz-id")
		return
	var encoded := _encode_question(type, payload)
	if not encoded["ok"]:
		question_created.emit(false, quiz_id, "", encoded["error"])
		return
	var gate := _gate()
	if not gate.is_empty():
		question_created.emit(false, quiz_id, "", gate)
		return
	var fields: Dictionary = encoded["fields"]
	fields["uid"] = { "stringValue": _uid() }
	fields["type"] = { "stringValue": type }
	var question_id := _generate_auto_id()
	var body := {
		"writes": [
			{
				"update": {
					"name": _question_path(quiz_id, question_id),
					"fields": fields,
				},
				"updateTransforms": [
					{ "fieldPath": "createdAt", "setToServerValue": "REQUEST_TIME" },
					{ "fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME" },
				],
				"currentDocument": { "exists": false },
			},
		],
	}
	_enqueue({
		"kind": "question_create",
		"url": _commit_url(),
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body),
		"quiz_id": quiz_id,
		"question_id": question_id,
	})

## Rewrites a question's prompt, order and type-specific answer fields.
##
## `type` must be the type the document ALREADY has -- it is immutable in
## the rules, and a question cannot change format in place. It is sent in
## the mask anyway, deliberately: an equal value satisfies the
## immutability check, and a MISMATCHED one is then refused on that exact
## rule instead of producing a confusing `hasOnly` failure caused by the
## old type's fields surviving outside the mask alongside the new type's.
func update_question(quiz_id: String, question_id: String, type: String, payload: Dictionary) -> void:
	if quiz_id.is_empty():
		question_updated.emit(false, quiz_id, question_id, "invalid-quiz-id")
		return
	if question_id.is_empty():
		question_updated.emit(false, quiz_id, question_id, "invalid-question-id")
		return
	var encoded := _encode_question(type, payload)
	if not encoded["ok"]:
		question_updated.emit(false, quiz_id, question_id, encoded["error"])
		return
	var gate := _gate()
	if not gate.is_empty():
		question_updated.emit(false, quiz_id, question_id, gate)
		return
	var fields: Dictionary = encoded["fields"]
	fields["type"] = { "stringValue": type }
	var body := {
		"writes": [
			{
				"update": {
					"name": _question_path(quiz_id, question_id),
					"fields": fields,
				},
				# Exactly the keys of `fields`, so nothing is deleted by
				# omission and nothing outside this write is touched.
				"updateMask": { "fieldPaths": fields.keys() },
				"updateTransforms": [
					{ "fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME" },
				],
				"currentDocument": { "exists": true },
			},
		],
	}
	_enqueue({
		"kind": "question_update",
		"url": _commit_url(),
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body),
		"quiz_id": quiz_id,
		"question_id": question_id,
	})

func delete_question(quiz_id: String, question_id: String) -> void:
	if quiz_id.is_empty():
		question_deleted.emit(false, quiz_id, question_id, "invalid-quiz-id")
		return
	if question_id.is_empty():
		question_deleted.emit(false, quiz_id, question_id, "invalid-question-id")
		return
	var gate := _gate()
	if not gate.is_empty():
		question_deleted.emit(false, quiz_id, question_id, gate)
		return
	var body := {
		"writes": [
			{
				"delete": _question_path(quiz_id, question_id),
				"currentDocument": { "exists": true },
			},
		],
	}
	_enqueue({
		"kind": "question_delete",
		"url": _commit_url(),
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body),
		"quiz_id": quiz_id,
		"question_id": question_id,
	})

## Lists the questions of one quiz. The `:runQuery` is issued against the
## PARENT document, which is what scopes `from: questions` to this quiz
## rather than to every quiz in the project.
##
## The `uid EQUAL` filter is required here for the same reason as on the
## quiz list -- the read rule reads the QUESTION's own denormalised `uid`,
## so an unfiltered query is refused even though every document in the
## sub-collection happens to share one owner.
##
## NO server-side orderBy, ON PURPOSE, and this is not the same call as
## list_own_quizzes(). Two reasons, both in the deployed rules' own
## comments: `order` is neither unique nor contiguous, so the display sort
## has to be (order, id) -- a tie-break a Firestore orderBy on `order`
## alone cannot express -- and dropping the orderBy keeps this query on
## the single-field `uid` index, so it needs NO composite index and works
## the day it first runs. The set is capped at a few dozen documents, so
## sorting it here costs nothing.
func list_questions(quiz_id: String) -> void:
	if quiz_id.is_empty():
		questions_fetched.emit(false, quiz_id, [], "invalid-quiz-id")
		return
	var gate := _gate()
	if not gate.is_empty():
		questions_fetched.emit(false, quiz_id, [], gate)
		return
	var body := {
		"structuredQuery": {
			"from": [{ "collectionId": QUESTIONS_COLLECTION }],
			"where": _own_uid_filter(),
		},
	}
	_enqueue({
		"kind": "questions_list",
		"url": _run_query_url("/%s/%s" % [QUIZZES_COLLECTION, quiz_id]),
		"method": HTTPClient.METHOD_POST,
		"body": JSON.stringify(body),
		"quiz_id": quiz_id,
		"question_id": "",
	})


# ---------------------------------------------------------------------
# Queue
# ---------------------------------------------------------------------

func _enqueue(op: Dictionary) -> void:
	_queue.append(op)
	_pump()

## Dispatches the next queued operation if the single HTTPRequest is
## idle. Written as a LOOP and not as a recursive retry on purpose: a
## queue of N operations that all fail to start would otherwise recurse N
## frames deep inside one call.
##
## `_pumping` guards RE-ENTRY, which is not hypothetical: _fail() below
## emits a signal from INSIDE this loop, and the obvious caller shape
## ("on failure, retry / queue the next thing") calls straight back into
## an entry point, hence into _enqueue(), hence into here. Without the
## guard that nested call would dispatch and fill the in-flight slot, and
## the OUTER loop would then hand a second request to a busy HTTPRequest
## -- ERR_BUSY, reported to the caller as a start failure that has
## nothing to do with its operation. A re-entrant call returns
## immediately instead; whatever it queued is picked up by the loop
## already running, whose condition is re-tested every iteration.
func _pump() -> void:
	if _pumping:
		return
	_pumping = true
	while _in_flight.is_empty() and not _queue.is_empty():
		var op: Dictionary = _queue.pop_front()
		# Auth is re-checked HERE, not only at call time: the token is
		# read fresh for every request (it is renewed hourly), and a
		# session can end while an operation waits its turn. Failing the
		# op is the contract -- dropping it silently is not.
		var headers := _auth_headers()
		if headers.is_empty():
			# NOT dropped -- it fails with its own signal, which is the
			# whole point of re-checking here rather than at call time.
			push_warning("Quizz: %s failed at dispatch, no bearer available" % op["kind"])
			_fail(op, ERR_AUTH_REQUIRED)
			continue
		var err := _http.request(op["url"], headers, op["method"], op["body"])
		if err == OK:
			_in_flight = op
			continue
		push_warning("Quizz: %s could not start (err=%d)" % [op["kind"], err])
		_fail(op, "%s: err=%d" % [ERR_REQUEST_START, err])
	_pumping = false

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var op := _in_flight
	_in_flight = {}
	if op.is_empty():
		# Cannot happen through the queue, but an unsolicited callback
		# must not be able to emit a signal attributed to nothing.
		push_warning("Quizz: response with no in-flight operation, ignored")
		_pump()
		return
	_dispatch(op, result, response_code, body)
	_pump()

func _dispatch(op: Dictionary, result: int, response_code: int, body: PackedByteArray) -> void:
	var kind: String = op["kind"]
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var reason := _error_text(result, response_code, body)
		push_warning("Quizz: %s failed (%s)" % [kind, reason])
		_fail(op, reason)
		return
	match kind:
		"quiz_create":
			quiz_created.emit(true, op["quiz_id"], "")
		"quiz_update":
			quiz_updated.emit(true, op["quiz_id"], "")
		"quiz_delete":
			quiz_deleted.emit(true, op["quiz_id"], "")
		"question_create":
			question_created.emit(true, op["quiz_id"], op["question_id"], "")
		"question_update":
			question_updated.emit(true, op["quiz_id"], op["question_id"], "")
		"question_delete":
			question_deleted.emit(true, op["quiz_id"], op["question_id"], "")
		"category_create":
			category_created.emit(true, op["category_id"], "")
		"category_delete":
			category_deleted.emit(true, op["category_id"], "")
		"categories_list":
			var category_rows = _parse_query_rows(body)
			if category_rows == null:
				_fail(op, ERR_BAD_RESPONSE)
				return
			var categories: Array = []
			for document in category_rows:
				categories.append(_decode_category(document))
			# Sorted HERE and not by the query -- see list_own_categories().
			categories.sort_custom(_compare_categories)
			categories_fetched.emit(true, categories, "")
		"quizzes_list":
			var quiz_rows = _parse_query_rows(body)
			if quiz_rows == null:
				_fail(op, ERR_BAD_RESPONSE)
				return
			var quizzes: Array = []
			for document in quiz_rows:
				quizzes.append(_decode_quiz(document))
			quizzes_fetched.emit(true, quizzes, "")
		"questions_list":
			var question_rows = _parse_query_rows(body)
			if question_rows == null:
				_fail(op, ERR_BAD_RESPONSE)
				return
			var questions: Array = []
			for document in question_rows:
				questions.append(_decode_question(document))
			questions.sort_custom(_compare_questions)
			questions_fetched.emit(true, op["quiz_id"], questions, "")
		_:
			push_warning("Quizz: unknown operation kind '%s'" % kind)

## Display order is (order, id) -- `order` is neither unique nor
## contiguous (the rules cannot see sibling documents, and say so), so the
## document id is what makes the order stable between two fetches of the
## same quiz. A named function rather than an inline lambda: this is the
## sort the deployed rules explicitly prescribe, and it deserves to be
## findable by name.
func _compare_questions(a: Dictionary, b: Dictionary) -> bool:
	if a["order"] != b["order"]:
		return a["order"] < b["order"]
	return String(a["id"]) < String(b["id"])

## (lowercased name, id). The id tie-break is not decoration: two
## categories may legitimately carry the same name -- the rules cannot see
## sibling documents, exactly as for `order` on questions -- and without
## it two fetches could hand back two different orders for the same data.
func _compare_categories(a: Dictionary, b: Dictionary) -> bool:
	var name_a := String(a["name"]).to_lower()
	var name_b := String(b["name"]).to_lower()
	if name_a != name_b:
		return name_a < name_b
	return String(a["id"]) < String(b["id"])

## Single place where a failed operation turns into its signal, so every
## entry point is guaranteed to emit exactly once whatever went wrong and
## wherever it went wrong.
func _fail(op: Dictionary, error: String) -> void:
	match op["kind"]:
		"quiz_create":
			quiz_created.emit(false, op["quiz_id"], error)
		"quiz_update":
			quiz_updated.emit(false, op["quiz_id"], error)
		"quiz_delete":
			quiz_deleted.emit(false, op["quiz_id"], error)
		"quizzes_list":
			quizzes_fetched.emit(false, [], error)
		"question_create":
			question_created.emit(false, op["quiz_id"], op["question_id"], error)
		"question_update":
			question_updated.emit(false, op["quiz_id"], op["question_id"], error)
		"question_delete":
			question_deleted.emit(false, op["quiz_id"], op["question_id"], error)
		"questions_list":
			questions_fetched.emit(false, op["quiz_id"], [], error)
		"category_create":
			category_created.emit(false, op["category_id"], error)
		"category_delete":
			category_deleted.emit(false, op["category_id"], error)
		"categories_list":
			categories_fetched.emit(false, [], error)
		_:
			push_warning("Quizz: cannot report failure of unknown kind '%s'" % op["kind"])


# ---------------------------------------------------------------------
# Validation and encoding
# ---------------------------------------------------------------------

## "" when the call may proceed, otherwise the reason it may not. Ordered
## deliberately: network first (a probe must never look at Auth at all),
## then the two auth halves.
func _gate() -> String:
	if not network_enabled:
		return ERR_NETWORK_DISABLED
	if _auth_headers().is_empty():
		return ERR_AUTH_REQUIRED
	return ""

## Empty array means "no usable bearer" -- callers must treat that as a
## refusal, never as "send it without the header". Both halves are
## checked because Auth publishes the uid before the token.
func _auth_headers() -> PackedStringArray:
	if not Auth.is_signed_in():
		return PackedStringArray()
	var token := Auth.get_id_token()
	if token.is_empty():
		return PackedStringArray()
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token,
	])

func _uid() -> String:
	return Auth.get_current_uid()

func _validate_title(title: String) -> String:
	if title.length() < TITLE_MIN_LEN or title.length() > TITLE_MAX_LEN:
		return "invalid-title"
	return ""

func _validate_category_name(name: String) -> String:
	if name.length() < CATEGORY_NAME_MIN_LEN or name.length() > CATEGORY_NAME_MAX_LEN:
		return "invalid-category-name"
	return ""

## "" is VALID and means "no category" -- the field is then omitted from
## the document entirely (see create_quiz). Only a non-empty id that could
## never satisfy the rules is refused, so a caller never spends a round
## trip on a guaranteed 403.
func _validate_category_id(category_id: String) -> String:
	if category_id.length() > CATEGORY_ID_MAX_LEN:
		return "invalid-category-id"
	return ""

## Returns {"ok": bool, "error": String, "fields": Dictionary}. `fields`
## holds the Firestore-encoded common fields plus the ones this `type`
## requires, and NOTHING else -- the rules close each type's key set, so
## a stray field from another format is a refusal, not a no-op.
func _encode_question(type: String, payload: Dictionary) -> Dictionary:
	if not QUESTION_TYPES.has(type):
		return { "ok": false, "error": "invalid-type", "fields": {} }
	var prompt := String(payload.get("prompt", "")).strip_edges()
	if prompt.length() < PROMPT_MIN_LEN or prompt.length() > PROMPT_MAX_LEN:
		return { "ok": false, "error": "invalid-prompt", "fields": {} }
	var order_value = payload.get("order", 0)
	if typeof(order_value) != TYPE_INT and typeof(order_value) != TYPE_FLOAT:
		return { "ok": false, "error": "invalid-order", "fields": {} }
	var order := int(order_value)
	if order < 0 or order > QUESTION_ORDER_MAX:
		return { "ok": false, "error": "invalid-order", "fields": {} }
	var fields := {
		"prompt": { "stringValue": prompt },
		"order": { "integerValue": str(order) },
	}
	match type:
		TYPE_MCQ4:
			for i in MCQ4_CHOICE_COUNT:
				var key := "choice%d" % i
				var choice := String(payload.get(key, "")).strip_edges()
				if choice.length() < CHOICE_MIN_LEN or choice.length() > CHOICE_MAX_LEN:
					return { "ok": false, "error": "invalid-%s" % key, "fields": {} }
				fields[key] = { "stringValue": choice }
			var index_value = payload.get("answerIndex", -1)
			if typeof(index_value) != TYPE_INT and typeof(index_value) != TYPE_FLOAT:
				return { "ok": false, "error": "invalid-answer-index", "fields": {} }
			var answer_index := int(index_value)
			if answer_index < 0 or answer_index >= MCQ4_CHOICE_COUNT:
				return { "ok": false, "error": "invalid-answer-index", "fields": {} }
			fields["answerIndex"] = { "integerValue": str(answer_index) }
		TYPE_TRUEFALSE:
			var bool_value = payload.get("answerBool", null)
			if typeof(bool_value) != TYPE_BOOL:
				return { "ok": false, "error": "invalid-answer-bool", "fields": {} }
			fields["answerBool"] = { "booleanValue": bool_value }
		TYPE_FREE:
			var answer_text := String(payload.get("answerText", "")).strip_edges()
			if answer_text.length() < ANSWER_TEXT_MIN_LEN or answer_text.length() > ANSWER_TEXT_MAX_LEN:
				return { "ok": false, "error": "invalid-answer-text", "fields": {} }
			fields["answerText"] = { "stringValue": answer_text }
	return { "ok": true, "error": "", "fields": fields }


# ---------------------------------------------------------------------
# REST plumbing
# ---------------------------------------------------------------------

func _documents_url() -> String:
	return Leaderboard.DOCUMENTS_URL

func _commit_url() -> String:
	return "%s:commit?key=%s" % [_documents_url(), Leaderboard.API_KEY]

## `parent_suffix` is "" for a root-collection query, or
## "/quizzes/<id>" to scope a sub-collection query to one parent.
func _run_query_url(parent_suffix: String) -> String:
	return "%s%s:runQuery?key=%s" % [_documents_url(), parent_suffix, Leaderboard.API_KEY]

func _quiz_path(quiz_id: String) -> String:
	return "projects/%s/databases/(default)/documents/%s/%s" % [Leaderboard.PROJECT_ID, QUIZZES_COLLECTION, quiz_id]

func _question_path(quiz_id: String, question_id: String) -> String:
	return "%s/%s/%s" % [_quiz_path(quiz_id), QUESTIONS_COLLECTION, question_id]

func _category_path(category_id: String) -> String:
	return "projects/%s/databases/(default)/documents/%s/%s" % [Leaderboard.PROJECT_ID, CATEGORIES_COLLECTION, category_id]

## The owner filter every list query must carry -- see list_own_quizzes.
func _own_uid_filter() -> Dictionary:
	return {
		"fieldFilter": {
			"field": { "fieldPath": "uid" },
			"op": "EQUAL",
			"value": { "stringValue": _uid() },
		},
	}

## Returns the "document" objects of a `:runQuery` response, or null when
## the body is not the JSON ARRAY the REST API is documented to return.
## Rows without a "document" key are query-plan metadata and are skipped,
## exactly as Leaderboard._on_query_completed does.
func _parse_query_rows(body: PackedByteArray):
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("Quizz: query response was not an array, ignoring")
		return null
	var documents: Array = []
	for row in parsed:
		if typeof(row) != TYPE_DICTIONARY or not row.has("document"):
			continue
		documents.append(row["document"])
	return documents

## Firestore's own message is kept VERBATIM rather than mapped to a short
## code: on a missing composite index it contains the ready-made console
## URL, which is the single most useful string this file can hand back.
func _error_text(result: int, response_code: int, body: PackedByteArray) -> String:
	var text := body.get_string_from_utf8()
	# Only hand JSON.parse_string something that can plausibly BE json.
	# A transport failure (offline, DNS, connection refused) carries an
	# EMPTY body, and parsing "" makes the engine print its own
	# `Parse JSON failed` ERROR line -- an alarming stderr entry for the
	# most ordinary failure this file has. Measured, not guessed: it
	# showed up on the RESULT_CANT_CONNECT case while validating this
	# file.
	var parsed = JSON.parse_string(text) if text.begins_with("{") else null
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
		var error_object = parsed["error"]
		if typeof(error_object) == TYPE_DICTIONARY:
			return "result=%d code=%d %s: %s" % [
				result,
				response_code,
				str(error_object.get("status", "")),
				str(error_object.get("message", "")),
			]
	return "result=%d code=%d %s" % [result, response_code, text]


# ---------------------------------------------------------------------
# Decoding
# ---------------------------------------------------------------------

## Keys are the Firestore field names VERBATIM, plus "id" for the
## document id -- the same names create_quiz/update_quiz write, so a
## round trip needs no renaming.
func _decode_quiz(document: Dictionary) -> Dictionary:
	var fields: Dictionary = document.get("fields", {})
	return {
		"id": _document_id(document),
		"title": _decode_string(fields, "title"),
		"visibility": _decode_string(fields, "visibility"),
		"questionCount": _decode_int(fields, "questionCount"),
		# "" when the field is absent, which is what an uncategorised quiz
		# looks like on the wire -- the same value create_quiz() accepts to
		# mean "no category", so a round trip needs no special case.
		"categoryId": _decode_string(fields, "categoryId"),
		"createdAt": _decode_string(fields, "createdAt", "timestampValue"),
		"updatedAt": _decode_string(fields, "updatedAt", "timestampValue"),
	}

## Same convention as _decode_quiz. `createdAt` is decoded even though no
## screen sorts on it today -- it is a real field of the document, and a
## decoder that silently drops one is how a future caller learns it does
## not exist.
func _decode_category(document: Dictionary) -> Dictionary:
	var fields: Dictionary = document.get("fields", {})
	return {
		"id": _document_id(document),
		"name": _decode_string(fields, "name"),
		"createdAt": _decode_string(fields, "createdAt", "timestampValue"),
	}

## Same convention as _decode_quiz. Only the keys the document's own
## `type` defines are present -- a caller reads `type` first, exactly as
## the rules do.
func _decode_question(document: Dictionary) -> Dictionary:
	var fields: Dictionary = document.get("fields", {})
	var type := _decode_string(fields, "type")
	var out := {
		"id": _document_id(document),
		"type": type,
		"prompt": _decode_string(fields, "prompt"),
		"order": _decode_int(fields, "order"),
		"createdAt": _decode_string(fields, "createdAt", "timestampValue"),
		"updatedAt": _decode_string(fields, "updatedAt", "timestampValue"),
	}
	match type:
		TYPE_MCQ4:
			for i in MCQ4_CHOICE_COUNT:
				var key := "choice%d" % i
				out[key] = _decode_string(fields, key)
			out["answerIndex"] = _decode_int(fields, "answerIndex")
		TYPE_TRUEFALSE:
			var field: Dictionary = fields.get("answerBool", {})
			out["answerBool"] = bool(field.get("booleanValue", false))
		TYPE_FREE:
			out["answerText"] = _decode_string(fields, "answerText")
	return out

## Firestore returns the full resource path; the id is its last segment.
func _document_id(document: Dictionary) -> String:
	var full_name := str(document.get("name", ""))
	if full_name.is_empty():
		return ""
	return full_name.get_slice("/", full_name.get_slice_count("/") - 1)

func _decode_string(fields: Dictionary, key: String, value_type: String = "stringValue") -> String:
	var field: Dictionary = fields.get(key, {})
	return str(field.get(value_type, ""))

## REST encodes int64 as a JSON STRING to avoid precision loss, so this
## always goes through str() before to_int().
func _decode_int(fields: Dictionary, key: String) -> int:
	var field: Dictionary = fields.get(key, {})
	var raw := str(field.get("integerValue", "0"))
	return raw.to_int() if raw.is_valid_int() else 0

## Deliberately a local copy of Leaderboard's generator rather than a
## call into its private API: six lines, same alphabet and length as
## Firestore's own auto-ids. If one ever changes, the other must follow.
func _generate_auto_id() -> String:
	var id := ""
	for i in AUTO_ID_LEN:
		id += AUTO_ID_CHARS[randi() % AUTO_ID_CHARS.length()]
	return id
