extends RefCounted
class_name ProbeCoverage
## Dev-only: the ledger of WHICH MECHANICS A PROBE'S BOTS ACTUALLY MET.
##
## =====================================================================
## WHY THIS EXISTS
##
## Five false greens have now been found in this folder, and they are all
## the same bug wearing different clothes:
##
##   1. probes reading jumpability as "anything except DODGE" -- so CHARGER,
##      added later and also unjumpable, was silently treated as jumpable;
##   2. a SAFE bot that could not jump, killed by STOMPER before the
##      pursuer it was measuring ever got a turn;
##   3. AntiFrustrationAudit counting a CLOSED lane as an escape, because
##      a closed lane is empty and empty looked safe;
##   4. bots choosing the escape with the longest time-to-contact, and so
##      parking themselves in front of a shut lane;
##   5. ComboAudit's SAFE bot, which never received fix 2 and dies to
##      STOMPER at 28s, so its "risky pays better" conclusion was measured
##      against a bot that was not playing safe but dying.
##
## Every one of them is a probe REPORTING GREEN ON A MECHANIC IT NEVER
## EXERCISED. Every one was found by a human reading the code months after
## the fact. None was found by a probe, because no probe was asking the
## question.
##
## =====================================================================
## WHY THIS IS A LEDGER INSIDE EACH PROBE, AND NOT A META PROBE OF ITS OWN
##
## The obvious shape -- one new MetaAudit.tscn that drives bots and checks
## they meet everything -- does not work, and it is worth writing down why
## so it is not proposed again.
##
## A meta probe drives ITS OWN bots. Passing would prove that the META
## probe's bots meet every mechanic. It would prove exactly nothing about
## whether PursuerAudit's SAFE bot meets STOMPER, which is the actual
## question, because that is a property of PursuerAudit's own bot code. The
## defect is per-probe and per-bot; a check that does not run on that
## probe's bots cannot see it. ComboAudit is the proof: PursuerAudit,
## StrikeAudit and PursuerFramingAudit all carry the STOMPER fix and would
## have passed any meta probe, while ComboAudit -- same function name, same
## lineage -- did not, and was green throughout.
##
## So the ledger rides inside each probe, observes THAT probe's bots on
## THAT probe's run, and gates THAT probe's verdict. The cost is three
## lines per probe; the benefit is that the check cannot drift away from
## the thing it checks.
##
## =====================================================================
## WHAT COUNTS AS "MET"
##
## Not "spawned somewhere on the track" -- a hazard that despawned forty
## metres ahead never tested anything. The ledger counts an obstacle when
## it REACHES THE PLAYER, which is where collision is really tested (see
## Obstacle.time_to_contact_s). Crossing detection is lifted from
## StomperConflictAudit._scan, including its respawn guard: pooled
## instances reuse their ids, so a segment recycling under the same key
## must not read as a crossing.
##
## THE THRESHOLD IS AHEAD OF THE Z=0 PLANE (see ARRIVAL_Z), NOT ON IT, AND
## THAT IS NOT A DETAIL. Written the obvious way -- crossing Z=0 -- this ledger
## has a blind spot in exactly the place it exists to watch: a hazard that
## KILLS the bot ends the run at the instant of contact, so the frame that
## would have recorded the crossing never runs, and the most consequential
## encounter a bot can have becomes the one encounter the ledger cannot
## see. It was caught by the ledger reporting "SAFE never met STOMPER" for
## a bot that in fact met one repeatedly and died to it every time -- the
## exact shape of false green this whole file exists to make impossible,
## reproduced inside the guard against it.
##
## Counting from ARRIVAL_Z instead means the arrival is recorded on a frame
## that runs whether or not the run survives it.
##
## Two counters per type, because they answer different questions:
##
##   PRESENTED    -- it reached the player at all. If this is 0, the RUN
##                   never produced the mechanic, and any claim the probe
##                   makes about it is vacuous.
##   ON PLAYER LANE -- it reached the player ON THE LANE THE PLAYER WAS
##                   STANDING ON, i.e. the bot actually had to answer it.
##                   If PRESENTED is high and this is 0, the bot is
##                   dodging the mechanic rather than exercising it --
##                   which is what a bot with a blind spot looks like from
##                   the outside.
##
## The non-obstacle mechanics are counted from their own state rather than
## from the track: pursuer visibility, strikes taken, shrink windows
## opened, rush windows entered.

## The mechanics a probe can require. Obstacle types are mirrored from
## Obstacle.Type deliberately rather than aliased, so that ADDING A TYPE
## THERE AND FORGETTING IT HERE is a compile-time-visible omission in one
## known place instead of a silent gap spread across ten probes.
enum Mechanic {
	DODGE, JUMP, ENEMY, AIR_ENEMY, CHARGER, STOMPER,
	PURSUER_VISIBLE, STRIKE, SHRINK, RUSH,
}

const OBSTACLE_MECHANICS: Array[int] = [
	Mechanic.DODGE, Mechanic.JUMP, Mechanic.ENEMY,
	Mechanic.AIR_ENEMY, Mechanic.CHARGER, Mechanic.STOMPER,
]

## Every hazard that reaches the player, and nothing else. The default
## requirement for any probe whose bots play a real run: if one of these
## never arrived, the run did not contain the game.
const ALL_HAZARDS: Array[int] = OBSTACLE_MECHANICS

## The Z at which a hazard counts as having reached the player -- see the
## class doc for why this is ahead of the Z=0 plane rather than on it.
##
## Derived, not picked: contact becomes geometrically possible at about
## Z = -1.0 (every hazard hitbox is 1.0m deep, Obstacle.RISK_PROXIMITY_Z,
## plus Keepy's 0.5m capsule radius, minus the half-depth) and the world
## moves up to 26 m/s (GameState.STAGE_SPEEDS), i.e. 0.43m per physics
## frame, more for a CHARGER at 2.35x. Counting from 2.0m out therefore
## guarantees at least one observed frame BEFORE the earliest possible
## contact, at any speed, for any type -- which is what makes a fatal
## encounter countable at all.
const ARRIVAL_Z: float = -2.0

static func mechanic_name(m: int) -> String:
	match m:
		Mechanic.DODGE: return "DODGE"
		Mechanic.JUMP: return "JUMP"
		Mechanic.ENEMY: return "ENEMY"
		Mechanic.AIR_ENEMY: return "AIR_ENEMY"
		Mechanic.CHARGER: return "CHARGER"
		Mechanic.STOMPER: return "STOMPER"
		Mechanic.PURSUER_VISIBLE: return "PURSUER_VISIBLE"
		Mechanic.STRIKE: return "STRIKE"
		Mechanic.SHRINK: return "SHRINK"
		Mechanic.RUSH: return "RUSH"
		_: return "?"

## Obstacle.Type -> Mechanic. Explicit rather than an int cast: the two
## enums agree today by construction, and this is where that stops being
## load-bearing if either ever gains a member.
static func mechanic_for_type(type: int) -> int:
	match type:
		Obstacle.Type.DODGE: return Mechanic.DODGE
		Obstacle.Type.JUMP: return Mechanic.JUMP
		Obstacle.Type.ENEMY: return Mechanic.ENEMY
		Obstacle.Type.AIR_ENEMY: return Mechanic.AIR_ENEMY
		Obstacle.Type.CHARGER: return Mechanic.CHARGER
		Obstacle.Type.STOMPER: return Mechanic.STOMPER
		_: return -1

# phase name -> { mechanic -> {"presented": int, "answered": int} }
var _phases: Dictionary = {}
var _phase: String = ""
## Phases reported but not gated -- see exempt_phase().
var _exempt: Array[String] = []

# Crossing detection, keyed by SEGMENT instance id -- see the class doc.
var _prev_z: Dictionary = {}
var _was_visible: Dictionary = {}

# Baselines for the counters that are cumulative on GameState, so a phase
# reports its own deltas rather than the run's running totals.
var _strikes_base: int = 0
var _shrink_base: int = 0
var _was_pursuer_visible: bool = false
var _was_rush: bool = false

## Starts (or resumes) accounting under a phase label. Safe to call again
## with a label already seen -- counts accumulate, which is what a probe
## that restarts runs inside one phase needs.
func begin_phase(label: String) -> void:
	_phase = label
	if not _phases.has(label):
		_phases[label] = {}
	_prev_z.clear()
	_was_visible.clear()
	_strikes_base = GameState.strikes_taken_total
	_shrink_base = GameState.shrink_windows_opened
	_was_pursuer_visible = GameState.pursuer_visible
	_was_rush = false

## Call once per physics frame, from the probe's own _physics_process,
## AFTER its bot has been driven. `track` is the TrackManager, `player` the
## Keepy instance.
func observe(track: Node, player: Node) -> void:
	if _phase == "":
		return
	_observe_obstacles(track, player)
	_observe_state(track)

## Marks a phase as REPORTED BUT NOT GATED. Its counts still print;
## verify() skips it.
##
## For phases whose claim genuinely does not depend on which hazards
## turned up, and only those. The case it exists for is PursuerAudit's
## HOSTILE phase: it disables the player's collision layer outright and
## measures how long the pursuer's lead takes to drain with zero risk
## income, over a single ~53s run. Hazards cannot touch that number --
## they cannot touch the bot at all -- so requiring the run to have
## produced all six would fail the probe for a reason that is not a
## defect, which is the mirror image of the bug this whole file exists
## to prevent and just as dishonest.
##
## The bar for using this is that the phase's conclusion is INDEPENDENT of
## the mechanic, not that the phase is short or that coverage is
## inconvenient. A phase with collision ON stays gated.
func exempt_phase(label: String) -> void:
	if not _exempt.has(label):
		_exempt.append(label)

## The run restarted under the same phase -- drop the per-instance crossing
## state so a recycled segment cannot read as a crossing, and re-baseline
## the cumulative counters GameState resets with the run.
func run_restarted() -> void:
	_prev_z.clear()
	_was_visible.clear()
	_strikes_base = 0
	_shrink_base = 0
	_was_pursuer_visible = false
	_was_rush = false

func _observe_obstacles(track: Node, player: Node) -> void:
	var player_lane: int = player.lane_index
	for segment in track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle: Obstacle = null
		for child in segment.get_children():
			if child is Obstacle:
				obstacle = child
				break
		if obstacle == null:
			continue
		var key := segment.get_instance_id()
		var now_visible: bool = obstacle.visible
		var was_visible: bool = _was_visible.get(key, false)
		_was_visible[key] = now_visible
		if not now_visible:
			_prev_z.erase(key)
			continue
		var z: float = obstacle.global_position.z
		# Same respawn guard as StomperConflictAudit._scan: a pooled
		# segment reused under the same key jumps backwards in Z, and
		# that is not a crossing.
		var respawned := not was_visible or (_prev_z.has(key) and z < float(_prev_z[key]))
		if not respawned and _prev_z.has(key) \
				and float(_prev_z[key]) < ARRIVAL_Z and z >= ARRIVAL_Z:
			_on_crossed(obstacle, player_lane)
		_prev_z[key] = z

func _on_crossed(obstacle: Obstacle, player_lane: int) -> void:
	var mech := mechanic_for_type(obstacle.obstacle_type)
	if mech == -1:
		return
	_bump(mech, "presented")
	if _lane_index_for_x(obstacle.global_position.x) == player_lane:
		_bump(mech, "answered")

## Nearest lane, not exact equality: a mid-sway ENEMY or a CHARGER crossing
## between two lane centres still arrived somewhere, and "somewhere" is
## what decides whether the player had to deal with it.
func _lane_index_for_x(x: float) -> int:
	var best := 0
	var best_d := INF
	for lane in TrackSegment.LANE_X.size():
		var d: float = absf(x - TrackSegment.LANE_X[lane])
		if d < best_d:
			best_d = d
			best = lane
	return best

func _observe_state(track: Node) -> void:
	# Edge-triggered, not level-triggered: the question is "did this happen
	# to the bot", and a mechanic that is continuously true for 40s is one
	# occurrence, not 2400 of them.
	var vis: bool = GameState.pursuer_visible
	if vis and not _was_pursuer_visible:
		_bump(Mechanic.PURSUER_VISIBLE, "presented")
		_bump(Mechanic.PURSUER_VISIBLE, "answered")
	_was_pursuer_visible = vis

	var rush: bool = track.is_rush_active()
	if rush and not _was_rush:
		_bump(Mechanic.RUSH, "presented")
		_bump(Mechanic.RUSH, "answered")
	_was_rush = rush

	# These two are cumulative counters on GameState, so a delta against the
	# phase baseline is the phase's own count. Guarded against going
	# negative, which is what a run reset looks like from here.
	var strikes: int = GameState.strikes_taken_total - _strikes_base
	if strikes > 0:
		_strikes_base = GameState.strikes_taken_total
		_bump(Mechanic.STRIKE, "presented", strikes)
		_bump(Mechanic.STRIKE, "answered", strikes)
	elif strikes < 0:
		_strikes_base = GameState.strikes_taken_total

	var shrinks: int = GameState.shrink_windows_opened - _shrink_base
	if shrinks > 0:
		_shrink_base = GameState.shrink_windows_opened
		_bump(Mechanic.SHRINK, "presented", shrinks)
		_bump(Mechanic.SHRINK, "answered", shrinks)
	elif shrinks < 0:
		_shrink_base = GameState.shrink_windows_opened

func _bump(mech: int, field: String, amount: int = 1) -> void:
	var phase: Dictionary = _phases[_phase]
	if not phase.has(mech):
		phase[mech] = {"presented": 0, "answered": 0}
	phase[mech][field] += amount

func count(phase_label: String, mech: int, field: String = "presented") -> int:
	if not _phases.has(phase_label):
		return 0
	var phase: Dictionary = _phases[phase_label]
	if not phase.has(mech):
		return 0
	return int(phase[mech][field])

func phases() -> Array:
	return _phases.keys()

## Prints the ledger. Always call this, including on a pass: the point is
## that a reader can see WHAT WAS EXERCISED, not just that something was.
func report(required: Array[int]) -> void:
	print("=== MECHANIC COVERAGE (what each bot actually met) ===")
	print("  presented = reached the player plane;  answered = reached it on the player's own lane")
	for label in _phases.keys():
		var line := ""
		for mech in required:
			line += "  %s %d/%d" % [
				mechanic_name(mech), count(label, mech, "presented"), count(label, mech, "answered")]
		print("  %-14s%s%s" % [label, line, "   (reported, not gated)" if label in _exempt else ""])
	print("")

## The gate. Returns a list of human-readable failures, empty when every
## required mechanic was met at least `min_presented` times in every phase.
##
## `min_answered` defaults to 0 -- REQUIRING a hazard to land on the
## player's own lane is a stronger claim than most probes can honestly
## make (a good bot legitimately avoids being there), so it is opt-in per
## probe rather than assumed here.
func verify(required: Array[int], min_presented: int = 1, min_answered: int = 0) -> Array[String]:
	var failures: Array[String] = []
	if _phases.is_empty():
		failures.append("the coverage ledger recorded no phases at all -- observe() was never called, so this run proves nothing about what it exercised")
		return failures
	for label in _phases.keys():
		if label in _exempt:
			continue
		for mech in required:
			var presented := count(label, mech, "presented")
			var answered := count(label, mech, "answered")
			if presented < min_presented:
				failures.append("%s never met %s (%d reached the player, need %d) -- every claim this run makes about %s is vacuous, it was not exercised" % [
					label, mechanic_name(mech), presented, min_presented, mechanic_name(mech)])
			elif answered < min_answered:
				failures.append("%s met %s %d time(s) but never on its own lane (%d, need %d) -- it was present, the bot never had to answer it" % [
					label, mechanic_name(mech), presented, answered, min_answered])
	return failures
