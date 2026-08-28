extends Node
## Autoloaded as "BattleStats". Keepy Battle's FIRST and ONLY write to
## Firestore: one cumulative, anonymous counter document, incremented
## once at the end of each finished fight.
##
##   battleStats/global
##     gamesPlayed, wins, losses : int
##     attacks / dodges / blocks : { attempted, hit, missed } : int
##     updatedAt                 : server timestamp
##
## Same "never block, never crash the game" contract as Leaderboard.gd
## and Quizz.gd: every entry point ends in a signal, off-web and headless
## degrade to a defined failure, and a refused or lost write costs the
## player nothing -- the fight is already over and the result panel is
## already up when this runs.
##
## =====================================================================
## ANONYMOUS ON PURPOSE -- NO uid, NO PER-FIGHT DOCUMENT
##
## The schema is a single shared document with no owner field. That is
## the whole design, decided by Mathieu, not a stage on the way to
## per-user stats:
##   - no `uid` is written, so nothing here can be traced to a player;
##   - no per-fight history is kept, so the collection cannot grow.
##
## The cost is stated plainly rather than papered over: a single shared
## document incremented client-side CANNOT be made watertight by rules.
## A determined client holding the (public, shipped) API key and a valid
## Google token can send whatever increments it likes. The rules narrow
## the surface as far as rules can -- signed-in only, exact key set,
## non-negative ints, server-set updatedAt, no delete, and a monotonic
## check that refuses any write which would LOWER a counter -- and that
## is the accepted limit for display-only numbers.
##
## That monotonic rule earns its place twice over, and the second reason
## is the one worth remembering: it is also the safety net under the
## write shape below. If `updateMask` were ever ignored, the transforms
## would land on a blanked document and the resulting values would be
## this fight's deltas alone -- far LOWER than what is stored -- so the
## rule refuses the write instead of letting the totals be silently
## reset. The failure mode of a bad mask is a denied write, not lost data.
##
## =====================================================================
## THE WRITE SHAPE, AND THE ONE THING TO GET RIGHT
##
## A `:commit` with a single write carrying:
##   update           : the document NAME only, with no `fields`
##   updateMask       : present, with an EMPTY fieldPaths list
##   updateTransforms : one `increment` per counter, plus REQUEST_TIME
##
## This is the shape the official SDKs emit for
## `set({counter: increment(1)}, {merge: true})`, and each part matters:
##
##   - the mask being PRESENT is what makes this a merge. Firestore's
##     contract is "if the mask is not set for an update and the document
##     exists, any existing data will be overwritten" -- so an absent
##     mask with empty fields would WIPE the counters before the
##     transforms ran. `updateMask` is a message field, so proto3 JSON
##     tracks its presence explicitly: `{"fieldPaths": []}` is a mask
##     that is set and lists nothing, not an absent mask.
##   - the mask being EMPTY is what makes it delete nothing: "fields
##     referenced in the mask, but not present in the input document, are
##     deleted". Nothing is referenced, so nothing is deleted.
##   - `increment` on a field that does not exist yet treats it as 0 and
##     creates it, which is why this same body both CREATES the document
##     on the first fight ever and updates it on every fight after. There
##     is no create-or-update branch here, and there must not be one --
##     a read-then-write would race with every other player.
##
## ONE write per finished fight, never one per action: the numbers are
## cumulative, so a per-action write would buy nothing and cost a request
## in the middle of a fight.

## Always emitted, exactly once per record() call. `error` is "" on
## success and a machine-readable code otherwise. `success` comes FIRST,
## matching Quizz.gd (and diverging from Leaderboard.gd, which predates
## that convention).
signal record_finished(success: bool, error: String)

## Project id and API key are READ FROM Leaderboard.gd rather than copied,
## for the reason Quizz.gd gives: two literal copies of an API key is a
## rotation hazard whose failure mode is a silent 403 in whichever file
## was forgotten. Leaderboard is registered before this autoload in
## project.godot.
const COLLECTION_ID := "battleStats"
## The one and only document. A constant, not a parameter: "one shared
## cumulative document" is the schema, so an argument here would suggest
## a choice that does not exist.
const DOCUMENT_ID := "global"

## Failure reasons produced locally, before any request goes out. Same
## vocabulary as Quizz.gd so a reader of either file recognises them.
const ERR_NETWORK_DISABLED := "network-disabled"
const ERR_AUTH_REQUIRED := "auth-required"
const ERR_REQUEST_START := "request-start-failed"
const ERR_NOT_FINISHED := "fight-not-finished"
const ERR_QUEUE_FULL := "queue-full"
const ERR_HTTP := "http-error"

## A fight ends at most every few seconds and each one enqueues exactly
## once, so this depth is already far past anything reachable; it exists
## so a hung socket cannot grow an unbounded array.
const QUEUE_MAX := 4
## Frees the single in-flight slot when a request never answers. Godot's
## default is 0 (wait for ever), which on a flaky mobile connection would
## mean the first stuck write silently swallows every later one.
const REQUEST_TIMEOUT_S := 15.0

## Same meaning and same detection as Leaderboard.network_enabled and
## Quizz.network_enabled: false under the headless DisplayServer (every
## scripts/dev probe), true in a browser or a desktop editor. Flipped in
## _ready() below.
var network_enabled: bool = true

var _http: HTTPRequest
var _queue: Array[String] = []
var _in_flight: bool = false

func _ready() -> void:
	# Identical detection to Leaderboard._ready(), for the identical
	# reason: every probe boots with `--headless`, so every probe -- and
	# every future one, with nothing to remember -- is covered here once.
	if DisplayServer.get_name() == "headless":
		network_enabled = false

	_http = HTTPRequest.new()
	# Firestore answers `Content-Encoding: gzip` while the Web export's
	# fetch/XHR has already decoded the bytes, so Godot's own
	# decompression pass runs on plaintext JSON and fails outright
	# (result=8 with code=200). Same fix, same reason, as Leaderboard.gd
	# and Quizz.gd -- confirmed on device for the leaderboard.
	_http.accept_gzip = false
	_http.timeout = REQUEST_TIMEOUT_S
	add_child(_http)
	_http.request_completed.connect(_on_completed)

## Records ONE finished fight. `tally` must already have been closed with
## BattleTally.finish() -- a fight that did not end (the player quit to
## the hub mid-round) is not a game played and must not be recorded.
##
## Never raises, never blocks, and never keeps the caller waiting: the
## arena calls this and carries straight on to the result panel.
func record(tally: BattleTally) -> void:
	if tally == null or not tally.is_finished():
		record_finished.emit(false, ERR_NOT_FINISHED)
		return

	# The invariant is enforced HERE, on the numbers actually collected,
	# and not left to the combat FSM's good behaviour -- see BattleTally.
	# repair()'s doc for why raising `attempted` is the honest direction.
	# A repair is a defect in the counting path, so it is loud.
	var repairs := tally.repair()
	for line in repairs:
		push_warning("BattleStats: incoherent tally repaired -- %s" % line)

	var increments := tally.to_increments()

	# Network first, then auth: a probe must never reach into Auth at all.
	if not network_enabled:
		record_finished.emit(false, ERR_NETWORK_DISABLED)
		return
	var headers := _auth_headers()
	if headers.is_empty():
		record_finished.emit(false, ERR_AUTH_REQUIRED)
		return

	if _queue.size() >= QUEUE_MAX:
		push_warning("BattleStats: queue full, dropping one fight's counters")
		record_finished.emit(false, ERR_QUEUE_FULL)
		return
	_queue.append(JSON.stringify(build_body(increments)))
	_pump()

## The REST body for a set of {field path: delta} increments, split out
## from record() so a probe can read the exact bytes this file would send
## without a socket, a token or a Firestore project in the way.
##
## An instance method and not a static one, deliberately: it resolves the
## project id through the Leaderboard autoload, and autoload lookups from
## a static context are a Godot detail this file has no reason to bet on.
##
## Deltas of zero ARE included: see BattleTally.to_increments() -- they
## are what makes the first write of the document's life produce the full
## key set the rules demand.
func build_body(increments: Dictionary) -> Dictionary:
	var transforms: Array = []
	# Sorted so the body is byte-stable for a given set of counters --
	# a probe can compare it literally instead of parsing it back.
	var paths := increments.keys()
	paths.sort()
	for path in paths:
		transforms.append({
			"fieldPath": path,
			# int64 travels as a JSON STRING in the Firestore REST
			# mapping, exactly as Leaderboard.gd sends `score`.
			"increment": { "integerValue": str(int(increments[path])) },
		})
	# The rules require `updatedAt == request.time`, which only a server
	# transform can satisfy -- a client clock never can, and that is the
	# point of requiring it.
	transforms.append({ "fieldPath": "updatedAt", "setToServerValue": "REQUEST_TIME" })
	return {
		"writes": [
			{
				"update": { "name": document_path() },
				# PRESENT and EMPTY. Read the header before touching this
				# line: dropping it turns a merge into a full overwrite.
				"updateMask": { "fieldPaths": [] },
				"updateTransforms": transforms,
			},
		],
	}

func document_path() -> String:
	return "projects/%s/databases/(default)/documents/%s/%s" % [
		Leaderboard.PROJECT_ID, COLLECTION_ID, DOCUMENT_ID,
	]

func commit_url() -> String:
	return "%s:commit?key=%s" % [Leaderboard.DOCUMENTS_URL, Leaderboard.API_KEY]

func _pump() -> void:
	if _in_flight or _queue.is_empty():
		return
	var body: String = _queue.pop_front()
	var err := _http.request(commit_url(), _auth_headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("BattleStats: request() failed to start (err=%d)" % err)
		record_finished.emit(false, ERR_REQUEST_START)
		# Not re-queued: a request that cannot even start will not start
		# on the next fight either, and retrying here would turn one bad
		# state into a growing backlog.
		_pump()
		return
	_in_flight = true

func _on_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		# Discreet by design: the fight is over, the player is looking at
		# the result panel, and a stats write is not something they asked
		# for. A warning in the console, nothing on screen, nothing
		# blocked.
		push_warning("BattleStats: record failed (result=%d, code=%d, body=%s)" % [
			result, response_code, body.get_string_from_utf8(),
		])
		record_finished.emit(false, ERR_HTTP)
		_pump()
		return
	record_finished.emit(true, "")
	_pump()

## Empty array means "no usable bearer" -- and here that is a refusal,
## not a reason to send the request bare: the battleStats rules gate
## every write on `request.auth != null`, so an unauthenticated call is a
## guaranteed 403. Both halves are checked because Auth publishes the uid
## before the token (see Auth.get_id_token's doc).
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
