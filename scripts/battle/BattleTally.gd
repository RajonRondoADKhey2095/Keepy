extends RefCounted
class_name BattleTally
## One fight's worth of counters for the PLAYER side, and nothing else.
##
## =====================================================================
## WHY THIS IS A SEPARATE FILE AND NOT A HANDFUL OF ints IN BattleArena
##
## Two reasons, both structural:
##
##   1. It has ZERO network in it, so the counting rules can be gated by
##      a probe without a socket, a token or a Firestore project. What
##      BattleStats.gd does with the result is a different question with
##      a different failure mode.
##   2. The invariant below has to hold BEFORE anything is sent, and an
##      invariant that lives in the same file as the emitter is one that
##      gets "temporarily" bypassed the day a counter looks wrong.
##
## =====================================================================
## THE INVARIANT: hit + missed <= attempted, PER GROUP
##
## `attempted` counts COMMITMENTS (the action began), `hit` and `missed`
## count RESOLUTIONS (a strike was resolved for or against it). Those are
## not the same population and the gap is meaningful, not slack:
##
##   attacks : an attack interrupted before its ACTIVE window never
##             resolves, so it is attempted-but-neither.
##   dodges  : most dodges face no incoming strike at all -- pressing
##             dodge into empty air is attempted-but-neither.
##   blocks  : same.
##
## So the relation is `<=`, never `==`, and `attempted - (hit + missed)`
## is a real number a dashboard can read as "commitments that never got
## tested".
##
## The combat FSM as written today cannot break it -- every resolution
## path requires a `current_action` that was necessarily begun, and
## Fighter._strike_spent makes one action resolve at most once. That is
## an argument, not a guarantee: it is a property of code this file does
## not own and that a future lot may change. `repair()` therefore checks
## it on real numbers, out loud, rather than trusting it.
##
## =====================================================================
## PLAYER SIDE ONLY
##
## Every counter here is about the human. `wins`/`losses` are the human's
## result, and the three groups are the human's own commitments. The
## opponent's play is not recorded: the shared document is a picture of
## how PEOPLE play Keepy Battle, and mixing an AI's actions into it would
## make every ratio meaningless without a way to separate them again.

## Firestore field paths, verbatim, used as the keys of to_increments().
## Same discipline as Quizz.gd's payloads: what is written is spelled
## exactly like the field it lands in, so there is no translation table
## between this file and the REST body to get wrong.
const FIELD_GAMES := "gamesPlayed"
const FIELD_WINS := "wins"
const FIELD_LOSSES := "losses"
const GROUP_ATTACKS := "attacks"
const GROUP_DODGES := "dodges"
const GROUP_BLOCKS := "blocks"
const GROUPS := [GROUP_ATTACKS, GROUP_DODGES, GROUP_BLOCKS]
const SUB_ATTEMPTED := "attempted"
const SUB_HIT := "hit"
const SUB_MISSED := "missed"
const SUBS := [SUB_ATTEMPTED, SUB_HIT, SUB_MISSED]

var _groups := {}
var _finished := false
var _won := false

func _init() -> void:
	reset()

## Back to an unstarted fight. Called by BattleArena on every round start,
## including a rematch -- a rematch is a NEW fight and must not inherit
## the previous one's tally.
func reset() -> void:
	_groups = {}
	for group in GROUPS:
		_groups[group] = { SUB_ATTEMPTED: 0, SUB_HIT: 0, SUB_MISSED: 0 }
	_finished = false
	_won = false

## A commitment. Called from Fighter.action_started on the PLAYER only.
## GUARD and DODGE map to their own groups; ATTACK to attacks; anything
## else (NONE, and FEINT which is opponent-only and can never reach here)
## is ignored rather than silently folded into a group it does not belong
## to.
func note_action_started(action: BattleTypes.Action) -> void:
	var group := _group_of(action)
	if group.is_empty():
		return
	_groups[group][SUB_ATTEMPTED] += 1

## The player attacked and the strike has been resolved against the
## opponent.
##
## HIT is the only outcome counted as a hit. BLOCKED deals chip damage
## and is deliberately counted as MISSED: the question this counter
## answers is "did the attack land cleanly", and an attack the opponent
## guarded did not. MISSED (opponent already KO) is a no-op resolution
## and counts as missed too, which is what it is.
func note_attack_resolved(outcome: BattleTypes.Outcome) -> void:
	if outcome == BattleTypes.Outcome.HIT:
		_groups[GROUP_ATTACKS][SUB_HIT] += 1
	else:
		_groups[GROUP_ATTACKS][SUB_MISSED] += 1

## The opponent attacked and the strike has been resolved against the
## PLAYER. `attempted` is what the player was committed to at that
## instant (Fighter.last_defence(), read by the arena BEFORE the strike
## resolves -- resolving is what clears it).
##
## The pairing is exactly the one BattleTypes.strike_label() shows the
## player on screen, and that is the point: a counter that disagreed with
## the word the player just read would be a second, invisible truth.
##
##   DODGED  -> dodges.hit      the evade worked
##   BLOCKED -> blocks.hit      the guard held
##   HIT     -> .missed of whichever defence was committed
##              ("ESQUIVE RATEE" / "GARDE BRISEE"); nothing at all when
##              the player had committed to no defence, because being
##              caught mid-attack or standing still is not a failed
##              defence and counting it as one would poison the ratio.
func note_defence_resolved(attempted: BattleTypes.Action, outcome: BattleTypes.Outcome) -> void:
	if outcome == BattleTypes.Outcome.DODGED:
		_groups[GROUP_DODGES][SUB_HIT] += 1
		return
	if outcome == BattleTypes.Outcome.BLOCKED:
		_groups[GROUP_BLOCKS][SUB_HIT] += 1
		return
	if outcome != BattleTypes.Outcome.HIT:
		return
	var group := _group_of(attempted)
	if group.is_empty() or group == GROUP_ATTACKS:
		return
	_groups[group][SUB_MISSED] += 1

## Closes the fight. Exactly one of wins/losses becomes 1; gamesPlayed
## becomes 1. Idempotent on purpose -- BattleArena._end_round() is driven
## by a KO signal, and a second call must not double-count a fight.
func finish(player_won: bool) -> bool:
	if _finished:
		return false
	_finished = true
	_won = player_won
	return true

func is_finished() -> bool:
	return _finished

## Enforces the invariant on the numbers actually collected, and returns
## a human-readable list of what it had to change (empty when clean).
##
## It RAISES `attempted` to `hit + missed` rather than lowering the
## resolutions. A resolution is a thing that demonstrably happened -- a
## strike was resolved -- while a missing commitment can only be a
## bookkeeping gap here. Dropping observed events to make the arithmetic
## fit would hide the very defect this check exists to surface.
##
## Called by BattleStats.gd immediately before encoding, never by the
## counting path: repairing as you count would erase the evidence.
func repair() -> PackedStringArray:
	var repairs := PackedStringArray()
	for group in GROUPS:
		var g: Dictionary = _groups[group]
		var resolved: int = g[SUB_HIT] + g[SUB_MISSED]
		if resolved > g[SUB_ATTEMPTED]:
			repairs.append("%s.attempted %d -> %d (hit %d + missed %d)" % [
				group, g[SUB_ATTEMPTED], resolved, g[SUB_HIT], g[SUB_MISSED],
			])
			g[SUB_ATTEMPTED] = resolved
	return repairs

## The write, as {firestore field path: delta}. Every key of the schema
## is present on EVERY call, including the ones whose delta is zero.
##
## That is not padding, it is what makes the very first write of the
## document's life produce the full shape: an `increment` transform on a
## field that does not exist yet creates it, so sending `losses: 0` after
## a win is what stops `losses` from being absent until somebody finally
## loses -- and an absent key is what the rules' hasAll() would refuse.
func to_increments() -> Dictionary:
	var out := {
		FIELD_GAMES: 1 if _finished else 0,
		FIELD_WINS: 1 if _finished and _won else 0,
		FIELD_LOSSES: 1 if _finished and not _won else 0,
	}
	for group in GROUPS:
		for sub in SUBS:
			out["%s.%s" % [group, sub]] = _groups[group][sub]
	return out

## Read-only view for probes and for the log line, in the same shape the
## document has. Never used to write.
func snapshot() -> Dictionary:
	var out := {
		FIELD_GAMES: 1 if _finished else 0,
		FIELD_WINS: 1 if _finished and _won else 0,
		FIELD_LOSSES: 1 if _finished and not _won else 0,
	}
	for group in GROUPS:
		out[group] = _groups[group].duplicate()
	return out

func _group_of(action: BattleTypes.Action) -> String:
	match action:
		BattleTypes.Action.ATTACK: return GROUP_ATTACKS
		BattleTypes.Action.DODGE: return GROUP_DODGES
		BattleTypes.Action.GUARD: return GROUP_BLOCKS
	return ""
