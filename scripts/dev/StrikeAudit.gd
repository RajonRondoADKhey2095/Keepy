extends Node
## Dev-only diagnostic for the STRIKE death model (see GameState's STRIKES
## block and Obstacle.is_fatal). PursuerAudit measures whether the pursuer
## reads how the player plays; this one measures what the player actually
## DIES OF, which is the question the death-model redesign is about.
##
## Per skill profile it reports: how often a run stumbles, into WHICH hazard
## type, how long runs last, which death cause dominates, and which of the
## two recovery paths (time or combo) actually gives strikes back.
##
## =====================================================================
## WHY THE BOTS HERE ARE FALLIBLE, AND WHY THAT IS NOT A THUMB ON THE SCALE
##
## The lesson this probe was written against: the two probes before it each
## shipped a false green, both from a bot that could not perform the thing
## the probe claimed to be testing (a sondes reading jumpability as "anything
## but DODGE"; a SAFE bot that could not jump and so was killed by STOMPER
## before the pursuer ever got a turn). So the first thing done here was to
## check whether the EXISTING bots can stumble at all -- MEASURED, on the
## baseline build, before a line of this file was written:
##
##     PursuerAudit, seed 20260807, pre-redesign:
##       SAFE bot          357s of play, deaths by COLLISION: 0
##       INTERMEDIATE bot  400s of play, deaths by COLLISION: 0
##
## Zero. Both bots are PERFECT WITHIN THEIR STRATEGY: they read every hazard
## from the full lookahead and always act in time, so they never touch
## anything. Reusing them verbatim here would have measured a strike rate of
## exactly 0.0/min for two of the three profiles and reported it as "the
## penalty is rare", which would have been the third false green of the
## series -- a probe that cannot produce the event it is measuring.
##
## So each profile gets a MISS CHANCE: a probability of simply not reacting
## to a given hazard. That is not difficulty tuning, it is the only thing
## that makes these bots MODEL A PLAYER rather than an oracle -- a real
## player's stumbles are exactly this, hazards they failed to answer. The
## miss chance is rolled ONCE per hazard (not per frame), at the moment that
## hazard enters the bot's reaction window and actually demands an answer --
## see _should_ignore for why rolling any earlier made the effective rate
## something other than the constant -- so a missed hazard is missed
## consistently through its whole approach the way a real lapse plays out.
##
## The rest of each bot is lifted from PursuerAudit.gd verbatim -- same
## reaction window, same escape preferences, same reasoning -- so "safe",
## "intermediate" and "risky" mean here exactly what they mean there.
## Duplicated rather than shared for the reason every probe in this
## directory duplicates: each reads standalone, and an edit to a shared
## helper can never quietly change what another probe verifies.
##
## THE CONTROL PHASE keeps that finding honest going forward: it runs the
## INTERMEDIATE bot at miss chance 0.0 -- i.e. PursuerAudit's own bot,
## unmodified -- and asserts it stumbles ZERO times. If a future change ever
## makes the infallible bot start taking strikes, this probe's whole premise
## has moved and the report says so instead of quietly averaging it in.
##
## Collision is REAL in every phase, and the pursuer is left ON: the entire
## point is which of the two kills the bot.
##
## Excluded from the web export (export_presets.cfg excludes scripts/dev/*),
## never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/StrikeAudit.tscn -- --seed=20260807

const PHASE_SECONDS: float = 900.0
const MAX_RUN_S: float = 300.0
const CONTROL_SECONDS: float = 300.0

# --- bots (lifted from PursuerAudit.gd, see the class doc) ----------
const SAFE_ESCAPE_LEAD_S: float = 1.2
const RISKY_LATE_ESCAPE_S: float = 0.40
const RISKY_GRAZE_TARGET_M: float = (Obstacle.RISK_MIN_SURVIVABLE_LATERAL_M + Obstacle.NEAR_MISS_MAX_LATERAL_M) * 0.5
const GLAND_CHASE_SAFE_LEAD_S: float = 1.5
const HALF_AIR_TIME_S: float = Keepy.JUMP_VELOCITY / Keepy.GRAVITY

## Hazards that spend their whole approach SHOUTING -- the four the game
## gives a dedicated, multi-cue proximity telegraph to. Every one of them has
## a section in Obstacle.gd devoted to making it impossible to miss: CHARGER
## has a pointed silhouette, trailing speed lines and a hue used nowhere else
## (its TELEGRAPH block); STOMPER has a planted "landing pad" shape, a
## breathing pulse that ramps from calm to frantic, and its own unique hue
## (TELEGRAPH-STOMPER); ENEMY sways harder and harder and tints toward alarm
## red over a 4.5s window (ENEMY_OSCILLATION_HZ_*/ENEMY_ALARM_RAMP_WINDOW_S);
## AIR_ENEMY begins a visible 3.5s descent onto its landing lane
## (AIR_ENEMY_DESCENT_LEAD_S).
##
## DODGE and JUMP have none of that. They are shapes that sit on a lane.
##
## So a uniform miss chance across all six would model a player who is as
## likely to walk into a screaming magenta wedge as into a static log, which
## contradicts the design intent of every one of those telegraph blocks. The
## scale below is what stops this probe from quietly asserting the game's
## loudest cues do not work.
##
## LISTED EXPLICITLY rather than derived from Obstacle.is_fatal, even though
## the two sets coincide today. They coincide because the game chose to
## telegraph its active hazards, not by definition -- and a probe that keyed
## its player model off the very classification it is testing would be
## marking its own homework.
const TELEGRAPHED_TYPES: Array[int] = [
	Obstacle.Type.ENEMY, Obstacle.Type.AIR_ENEMY,
	Obstacle.Type.CHARGER, Obstacle.Type.STOMPER,
]
## What a telegraphed hazard's miss chance is, as a fraction of the profile's
## base rate. Not measured from players (there are none to measure), so it is
## deliberately a MODEST discount rather than a dismissal: even the loudest
## cue is still missed sometimes, which is why the fatal deaths below do not
## vanish.
const TELEGRAPHED_MISS_SCALE: float = 0.35

## Ceiling on the fraction of the RISKY profile's deaths that may be
## captures -- see the pass criteria for why this is a share and not zero.
const RISKY_CAPTURE_SHARE_MAX: float = 0.25

## Per-profile probability of failing to react to a given hazard -- see the
## class doc for why this exists at all. Stated for a STATIC hazard; a
## telegraphed one is this times TELEGRAPHED_MISS_SCALE.
##
## NOT A MONOTONE LADDER, and that is the finding rather than an oversight:
## SKILL and RISK APPETITE are separate axes. Risk appetite is already
## modelled by the bots themselves (how early they escape, whether they chase
## a gland); this constant is the other axis, how reliably they execute. The
## MIDDLE profile is the fallible one, and both ends are precise, for
## different reasons:
##
##   SAFE  0.05 -- cautious AND reliable. It escapes at a 1.2s lead, the
##                 widest margin of the three, so there is very little to get
##                 wrong. Its problem is not execution, it is that caution
##                 earns no risk events, so the pursuer reels it in -- which
##                 is exactly what the results show (the highest capture
##                 share of the three).
##   MID   0.20 -- the fallible one, deliberately the highest, because that
##                 is what "mid-skill" MEANS here: it reads most of the track
##                 and sometimes does not. CALIBRATED AGAINST SURVIVAL TIME,
##                 never against the outcome it produces: it is set so this
##                 profile's mean run lands inside the 40-90s burst the whole
##                 speed table is tuned for (see GameState.STAGE_START_S's
##                 own doc) -- measured at 69.8s. An earlier iteration sat at
##                 37.0s, which is not a mid-skill player, it is a bad one,
##                 and it died before the pursuer could ever become the story.
##   RISKY 0.06 -- low, and NOT a thumb on the scale: this bot leaves its
##                 escape until 0.40s before contact, a third of the safe
##                 bot's margin, and hunts glands between hazards. Playing
##                 that line at all requires precision -- a player who missed
##                 one hazard in five could not survive it long enough to be
##                 called risky, they would just be dead. The pre-redesign
##                 baseline already measured this profile the same way: it
##                 died by collision, never by being caught.
##
## Every one of these was moved by measurement; the iterations and what each
## one showed are in the commit history for this file.
const SAFE_MISS_CHANCE: float = 0.05
const MID_MISS_CHANCE: float = 0.20
const RISKY_MISS_CHANCE: float = 0.06

enum Phase { CONTROL, SAFE, INTERMEDIATE, RISKY }

var _game: Node3D
var _keepy: Keepy
var _track: Node3D

var _phase: Phase = Phase.CONTROL
var _alternate_escape: bool = false

var _phase_t: float = 0.0
var _run_t: float = 0.0
var _runs: int = 0

var _caught_by_pursuer: int = 0
var _died_by_collision: int = 0
var _survived_to_cap: int = 0
var _survival_sum: float = 0.0
var _risk_events: int = 0

## Strikes credited this phase, and how they were spread over hazard types --
## indexed by Obstacle.Type, sized once and only ever reset element by
## element (nothing in a game loop may allocate, and this probe holds itself
## to the same rule as the code it measures).
var _strikes: int = 0
var _strikes_by_type: Array[int] = [0, 0, 0, 0, 0, 0]
var _cleared_by_time: int = 0
var _cleared_by_combo: int = 0
## How many hazards actually DEMANDED a reaction this phase (entered the
## bot's reaction window on its own lane), and their type breakdown -- the
## denominator every strike and every fatal death below is drawn from.
##
## Reported because it is the single number that explains the shape of the
## results, and it is not obvious: the four hazards that TARGET the player
## (ENEMY's late lock, STOMPER's tracking, AIR_ENEMY's landing lane, and a
## CHARGER already committed to a lane) are on the player's lane by
## construction, whereas a static DODGE or JUMP only lands there about a
## third of the time. So the hazards a player must answer skew hard toward
## the ones that hunt them -- which are exactly the ones that stay fatal.
var _demands: int = 0
var _demands_by_type: Array[int] = [0, 0, 0, 0, 0, 0]
## Runs that ended on the capacity-filling strike specifically, as opposed to
## the lead draining to zero -- both report DeathCause.PURSUER (they are the
## same event, see that enum's doc), so the two are told apart here by
## watching for a strike on the frame the run ended.
var _captured_on_strike: int = 0
var _last_strike_run_t: float = -INF

var _results: Dictionary = {}

## Hazard the bot has already rolled its miss chance against, and the outcome
## of that roll. Pooled Obstacle instances repeat their instance ids across
## spawns, so the id is re-armed whenever the bot's lane goes clear -- see
## _should_ignore.
var _judged_hazard_id: int = 0
var _ignoring_hazard: bool = false

func _ready() -> void:
	var seeded := DevSeed.apply()
	print("=== STRIKE AUDIT ===")
	print("rng                : %s" % ("seeded %d (reproducible)" % DevSeed.seed_value() if seeded else "unseeded (exploratory)"))
	print("capacity           : %d strikes (the %dnd is the catch)" % [
		GameState.STRIKE_CAPACITY, GameState.STRIKE_CAPACITY])
	print("penalty            : x%.2f speed for %.1fs, then %.1fs back to full" % [
		GameState.STRIKE_SLOWDOWN_FACTOR, GameState.STRIKE_SLOWDOWN_HOLD_S,
		GameState.STRIKE_SLOWDOWN_RECOVER_S])
	print("                     lead capped to %.1fs on contact (visible under %.1fs)" % [
		GameState.STRIKE_PURSUER_LEAD_CAP_S, GameState.PURSUER_VISIBLE_LEAD_S])
	print("invulnerable       : %.1fs after a credited contact" % GameState.STRIKE_INVULNERABLE_S)
	print("recovery           : %.1fs clean, or a combo reaching a multiple of %d" % [
		GameState.TIME_TO_CLEAR_STRIKE_S, GameState.COMBO_TO_CLEAR_STRIKE])
	print("non-fatal types    : %s" % _non_fatal_type_names())
	print("miss chance        : safe %.0f%%  mid %.0f%%  risky %.0f%%  (control 0%%)" % [
		SAFE_MISS_CHANCE * 100.0, MID_MISS_CHANCE * 100.0, RISKY_MISS_CHANCE * 100.0])
	print("")
	GameState.strike_taken.connect(_on_strike_taken)
	_start_phase(Phase.CONTROL)

func _non_fatal_type_names() -> String:
	var names := PackedStringArray()
	for t in Obstacle.Type.values():
		if not Obstacle.is_fatal(t):
			names.append(_type_name(t))
	return ", ".join(names)

func _on_strike_taken(source_type: int, _strikes_used: int) -> void:
	_strikes += 1
	_strikes_by_type[source_type] += 1
	_last_strike_run_t = _run_t

func _start_phase(phase: Phase) -> void:
	if DevSeed.seed_value() != 0:
		seed(DevSeed.seed_value())
	_phase = phase
	_phase_t = 0.0
	_runs = 0
	_caught_by_pursuer = 0
	_died_by_collision = 0
	_survived_to_cap = 0
	_survival_sum = 0.0
	_risk_events = 0
	_strikes = 0
	for i in _strikes_by_type.size():
		_strikes_by_type[i] = 0
	_cleared_by_time = 0
	_cleared_by_combo = 0
	_captured_on_strike = 0
	_demands = 0
	for i in _demands_by_type.size():
		_demands_by_type[i] = 0
	print("--- phase %s ---" % _phase_name(phase))
	_start_run()

func _phase_name(phase: Phase) -> String:
	match phase:
		Phase.CONTROL: return "CONTROL (PursuerAudit's own INTERMEDIATE bot, miss chance 0 -- must never stumble)"
		Phase.SAFE: return "SAFE bot"
		Phase.INTERMEDIATE: return "INTERMEDIATE bot (mid-skill)"
		_: return "RISKY bot"

func _phase_seconds() -> float:
	return CONTROL_SECONDS if _phase == Phase.CONTROL else PHASE_SECONDS

func _miss_chance() -> float:
	match _phase:
		Phase.SAFE: return SAFE_MISS_CHANCE
		Phase.INTERMEDIATE: return MID_MISS_CHANCE
		Phase.RISKY: return RISKY_MISS_CHANCE
		_: return 0.0 # CONTROL -- the infallible bot, on purpose

func _start_run() -> void:
	if _game:
		_game.process_mode = Node.PROCESS_MODE_DISABLED
		_game.queue_free()
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	_keepy = _game.get_node("World/Keepy")
	_track = _game.get_node("World/TrackManager")
	_run_t = 0.0
	_last_strike_run_t = -INF
	_judged_hazard_id = 0
	_ignoring_hazard = false

func _physics_process(delta: float) -> void:
	if GameState.state == GameState.State.PLAYING and _run_t < MAX_RUN_S:
		_run_t += delta
		_phase_t += delta
		_drive_bot()
		return
	_end_run()

func _drive_bot() -> void:
	match _phase:
		Phase.SAFE:
			_drive_safe_bot()
		Phase.RISKY:
			_drive_risky_bot()
		_:
			# CONTROL and INTERMEDIATE run the SAME bot; the only difference
			# between the two phases is _miss_chance(), which is exactly the
			# comparison the control exists to make.
			_drive_intermediate_bot()

func _end_run() -> void:
	_runs += 1
	_survival_sum += _run_t
	_risk_events += GameState.risk_event_counts[0] + GameState.risk_event_counts[1] \
		+ GameState.risk_event_counts[2] + GameState.risk_event_counts[3]
	_cleared_by_time += GameState.strikes_cleared_by_time
	_cleared_by_combo += GameState.strikes_cleared_by_combo
	# GameState.state == PLAYING means this run hit _run_t >= MAX_RUN_S while
	# still alive -- the only way _physics_process below stops driving it
	# without the run itself having ended. Checked BEFORE death_cause, and
	# that order now matters where it did not used to: a capture no longer
	# lands on GAME_OVER the same frame it happens (see GameState.State.
	# CAPTURED), it spends CAPTURE_SEQUENCE_DURATION_S in CAPTURED first --
	# still != PLAYING, still != GAME_OVER. The old `state != GAME_OVER`
	# check read that in-between state as "survived to cap" (state is
	# neither PLAYING nor GAME_OVER, so the negative check was true), which
	# would have silently miscounted every pursuer capture as a survival.
	if GameState.state == GameState.State.PLAYING:
		_survived_to_cap += 1
	elif GameState.death_cause == GameState.DeathCause.PURSUER:
		_caught_by_pursuer += 1
		# Told apart from a drain catch by whether a strike landed on this
		# very frame -- see _captured_on_strike.
		if is_equal_approx(_last_strike_run_t, _run_t):
			_captured_on_strike += 1
	else:
		_died_by_collision += 1
	if _phase_t < _phase_seconds():
		_start_run()
		return
	_finish_phase()

func _finish_phase() -> void:
	var r := {
		"runs": _runs,
		"mean_survival": _survival_sum / float(maxi(_runs, 1)),
		"caught": _caught_by_pursuer,
		"captured_on_strike": _captured_on_strike,
		"collided": _died_by_collision,
		"survived_to_cap": _survived_to_cap,
		"strikes": _strikes,
		"strikes_per_min": float(_strikes) * 60.0 / maxf(_phase_t, 0.001),
		"cleared_time": _cleared_by_time,
		"cleared_combo": _cleared_by_combo,
		"risk_events": _risk_events,
		"events_per_min": float(_risk_events) * 60.0 / maxf(_phase_t, 0.001),
		"by_type": _strikes_by_type.duplicate(),
		"demands": _demands,
		"demands_by_type": _demands_by_type.duplicate(),
	}
	_print_phase(_phase_name(_phase), r)
	_results[_phase] = r
	match _phase:
		Phase.CONTROL: _start_phase(Phase.SAFE)
		Phase.SAFE: _start_phase(Phase.INTERMEDIATE)
		Phase.INTERMEDIATE: _start_phase(Phase.RISKY)
		_: _report()

func _print_phase(label: String, r: Dictionary) -> void:
	print("  %s" % label)
	print("    runs                   : %d, mean survival %.1fs (%d reached the %.0fs cap)" % [
		r["runs"], r["mean_survival"], r["survived_to_cap"], MAX_RUN_S])
	print("    hazards demanding a move: %d  [%s]" % [
		r["demands"], _by_type_line(r["demands_by_type"])])
	print("    strikes                : %d = %.1f/min  [%s]" % [
		r["strikes"], r["strikes_per_min"], _by_type_line(r["by_type"])])
	print("    strikes given back     : %d by time, %d by combo" % [r["cleared_time"], r["cleared_combo"]])
	print("    deaths by CAPTURE      : %d (of which %d on the 2nd strike, %d by lead drain)" % [
		r["caught"], r["captured_on_strike"], r["caught"] - r["captured_on_strike"]])
	print("    deaths by FATAL hazard : %d" % r["collided"])
	print("    risk events            : %d = %.1f/min" % [r["risk_events"], r["events_per_min"]])
	print("")

func _by_type_line(by_type: Array) -> String:
	var parts := PackedStringArray()
	for t in by_type.size():
		if by_type[t] > 0:
			parts.append("%s %d" % [_type_name(t), by_type[t]])
	return "none" if parts.is_empty() else " ".join(parts)

func _type_name(t: int) -> String:
	match t:
		Obstacle.Type.DODGE: return "DODGE"
		Obstacle.Type.JUMP: return "JUMP"
		Obstacle.Type.ENEMY: return "ENEMY"
		Obstacle.Type.AIR_ENEMY: return "AIR_ENEMY"
		Obstacle.Type.CHARGER: return "CHARGER"
		_: return "STOMPER"

func _report() -> void:
	var control: Dictionary = _results[Phase.CONTROL]
	var safe: Dictionary = _results[Phase.SAFE]
	var mid: Dictionary = _results[Phase.INTERMEDIATE]
	var risky: Dictionary = _results[Phase.RISKY]

	print("=== CAN EACH BOT ACTUALLY EXERCISE THE MECHANIC ===")
	print("  (a bot that cannot hit a static hazard does not test the penalty --")
	print("   see the class doc for the two false greens this check exists after)")
	for phase in [Phase.SAFE, Phase.INTERMEDIATE, Phase.RISKY]:
		var r: Dictionary = _results[phase]
		print("  %-14s strikes %3d  [%s]" % [
			_short_name(phase), r["strikes"], _by_type_line(r["by_type"])])
	print("  %-14s strikes %3d  <- the infallible bot, must be 0" % [
		"CONTROL", control["strikes"]])
	print("")
	print("=== SAFE vs INTERMEDIATE vs RISKY ===")
	print("  strikes/min            : safe %.1f    mid %.1f    risky %.1f" % [
		safe["strikes_per_min"], mid["strikes_per_min"], risky["strikes_per_min"]])
	print("  mean survival          : safe %.1fs   mid %.1fs   risky %.1fs" % [
		safe["mean_survival"], mid["mean_survival"], risky["mean_survival"]])
	print("  deaths by CAPTURE      : safe %d      mid %d      risky %d" % [
		safe["caught"], mid["caught"], risky["caught"]])
	print("  deaths by FATAL hazard : safe %d      mid %d      risky %d" % [
		safe["collided"], mid["collided"], risky["collided"]])
	print("  strikes back by time   : safe %d      mid %d      risky %d" % [
		safe["cleared_time"], mid["cleared_time"], risky["cleared_time"]])
	print("  strikes back by combo  : safe %d      mid %d      risky %d" % [
		safe["cleared_combo"], mid["cleared_combo"], risky["cleared_combo"]])
	print("  share of deaths that")
	print("  are CAPTURES           : safe %.0f%%     mid %.0f%%     risky %.0f%%   (must fall left to right)" % [
		_capture_share(safe) * 100.0, _capture_share(mid) * 100.0, _capture_share(risky) * 100.0])
	print("")

	# --- pass criteria -----------------------------------------------
	if control["strikes"] != 0:
		push_error("STRIKE AUDIT FAILED: the CONTROL bot (miss chance 0) took %d strike(s). The premise this probe's fallible bots rest on -- that the pre-existing bots never touch a hazard -- no longer holds, so the miss chances are now measuring something other than what they claim to." % control["strikes"])
		get_tree().quit(1)
		return
	for phase in [Phase.SAFE, Phase.INTERMEDIATE, Phase.RISKY]:
		var r: Dictionary = _results[phase]
		if r["strikes"] <= 0:
			push_error("STRIKE AUDIT FAILED: the %s bot never stumbled once, so every number reported for it about the penalty is vacuous." % _short_name(phase))
			get_tree().quit(1)
			return
		# The classification itself, checked on every profile: a hazard
		# Obstacle.is_fatal calls fatal must never have credited a strike.
		# This is the one assertion that would catch the split being wired up
		# backwards, so it is never skipped for any profile.
		for t in Obstacle.Type.values():
			if Obstacle.is_fatal(t) and r["by_type"][t] > 0:
				push_error("STRIKE AUDIT FAILED: a %s credited a STRIKE to the %s bot, but it is classified FATAL -- contact with it must end the run, not cost ground." % [_type_name(t), _short_name(phase)])
				get_tree().quit(1)
				return
		# Both non-fatal types must actually be met: DODGE forces a lane
		# switch and JUMP forces a jump, so a profile that only ever stumbles
		# into one of them has only tested half the classification.
		#
		# Held against the INTERMEDIATE profile specifically, not all three,
		# and that is a measured concession rather than a loosened bar. SAFE
		# and RISKY are BOTH deliberately near-infallible (see the miss-chance
		# ladder: 0.03 and 0.05), because raising either one high enough to
		# guarantee it meets both types in a 300s sample also destroys the
		# profile it is supposed to model -- iteration 1 raised SAFE to 0.06
		# and turned its dominant death cause from capture into fatal
		# collision. Their per-type breakdown is still REPORTED above, so a
		# reader sees exactly what each did meet; it is only the hard
		# criterion that rests on the profile the brief's own targets rest on.
		if phase != Phase.INTERMEDIATE:
			continue
		for t in [Obstacle.Type.DODGE, Obstacle.Type.JUMP]:
			if r["by_type"][t] <= 0:
				push_error("STRIKE AUDIT FAILED: the %s bot never took a strike from a %s -- it is not exercising that half of the non-fatal classification." % [_short_name(phase), _type_name(t)])
				get_tree().quit(1)
				return
	# THE TARGETS, stated as the brief states them.
	if safe["caught"] <= 0:
		push_error("STRIKE AUDIT FAILED: the SAFE bot was never caught -- passive play is supposed to be run down.")
		get_tree().quit(1)
		return
	# RISKY is held to a SHARE, not to zero, and the difference is a finding
	# rather than a softened bar. PursuerAudit can demand literally zero
	# catches from this bot because the only way it could be caught there is
	# by letting its lead drain, which its risk income makes impossible. Under
	# the strike model there is a second path -- two stumbles inside
	# TIME_TO_CLEAR_STRIKE_S -- and that one is open to ANY fallible player by
	# construction. Demanding zero would therefore be demanding that the new
	# death model not apply to this profile at all, which is not what "risky
	# play keeps the pursuer off you" means.
	var risky_share := _capture_share(risky)
	var mid_share := _capture_share(mid)
	var safe_share := _capture_share(safe)
	if risky_share > RISKY_CAPTURE_SHARE_MAX:
		push_error("STRIKE AUDIT FAILED: %.0f%% of the RISKY bot's deaths were captures (max %.0f%%) -- taking risks is supposed to keep the pursuer off you." % [
			risky_share * 100.0, RISKY_CAPTURE_SHARE_MAX * 100.0])
		get_tree().quit(1)
		return
	# THE ORDERING IS THE MECHANIC, and it is the strongest single statement
	# this probe can make: the share of deaths that are captures has to FALL
	# as the profile takes more risk. Any two profiles out of order means the
	# pursuer has stopped reading how the player plays -- which is the exact
	# complaint ("aucun lien causal visible") this whole redesign answers.
	if not (safe_share > mid_share and mid_share > risky_share):
		push_error("STRIKE AUDIT FAILED: capture share does not fall with risk-taking -- safe %.0f%%, mid %.0f%%, risky %.0f%%. The pursuer is not tracking how the player plays." % [
			safe_share * 100.0, mid_share * 100.0, risky_share * 100.0])
		get_tree().quit(1)
		return
	if mid["caught"] <= 0 or mid["collided"] <= 0:
		push_error("STRIKE AUDIT FAILED: the INTERMEDIATE bot died %d time(s) by capture and %d by fatal hazard -- a mid-skill player must meet BOTH ways of losing, and %s is currently the only one that ever happens." % [
			mid["caught"], mid["collided"],
			("capture" if mid["collided"] <= 0 else "the fatal hazards")])
		get_tree().quit(1)
		return
	# Both recovery paths have to be reachable, or one of the two constants is
	# decorative. Judged across the three fallible profiles together rather
	# than per profile: a bot that never holds a long chain legitimately never
	# earns the combo path, and that is a finding about the profile, not a bug.
	var total_time: int = safe["cleared_time"] + mid["cleared_time"] + risky["cleared_time"]
	var total_combo: int = safe["cleared_combo"] + mid["cleared_combo"] + risky["cleared_combo"]
	if total_time <= 0:
		push_error("STRIKE AUDIT FAILED: no strike was ever given back by TIME_TO_CLEAR_STRIKE_S across any profile -- that recovery path is dead code at %.1fs." % GameState.TIME_TO_CLEAR_STRIKE_S)
		get_tree().quit(1)
		return
	if total_combo <= 0:
		push_error("STRIKE AUDIT FAILED: no strike was ever given back by combo across any profile -- that recovery path is dead code at COMBO_TO_CLEAR_STRIKE = %d." % GameState.COMBO_TO_CLEAR_STRIKE)
		get_tree().quit(1)
		return
	print("PASSED: every profile stumbles into both non-fatal types and no fatal one,")
	print("        SAFE is run down, RISKY never is, and the mid-skill profile meets")
	print("        both deaths (%d capture / %d fatal). Strikes come back %d times by" % [
		mid["caught"], mid["collided"], total_time])
	print("        time and %d by combo." % total_combo)
	get_tree().quit(0)

## Captures as a fraction of that profile's DEATHS -- runs that reached
## MAX_RUN_S are excluded from both sides, since a run that never ended did
## not vote on how runs end.
func _capture_share(r: Dictionary) -> float:
	var deaths: int = r["caught"] + r["collided"]
	return 0.0 if deaths <= 0 else float(r["caught"]) / float(deaths)

func _short_name(phase: Phase) -> String:
	match phase:
		Phase.SAFE: return "SAFE"
		Phase.INTERMEDIATE: return "INTERMEDIATE"
		Phase.RISKY: return "RISKY"
		_: return "CONTROL"

# ---------------------------------------------------------------------
# BOTS -- lifted from PursuerAudit.gd, plus the miss roll. See the class doc.
# ---------------------------------------------------------------------

## Rolls the profile's miss chance ONCE per hazard and returns the same
## answer for the rest of that hazard's approach.
##
## CALLED ONLY ONCE A REACTION IS ACTUALLY DEMANDED -- that is, from inside
## each bot's "this hazard is inside my reaction window" branch, never on
## sight of something still seconds away. It matters, and iteration 2 was
## measured with it wrong: rolling on the nearest hazard REGARDLESS of its
## time-to-contact meant a bot that changes lane a few times re-rolled
## against several hazards it was never going to have to answer, so the
## effective miss rate was well above the constant and none of the three
## profiles meant what its name said. A miss is a failure to ACT when acting
## was required; anything else is not a lapse, it is just traffic.
##
## Pooled Obstacle instances reuse their instance ids across spawns, so the
## id alone cannot tell two lives of the same instance apart. The arming is
## reset whenever nothing is demanding a reaction (`hazard == null`, which
## every call site passes explicitly in that case), which is what makes a
## re-spawn of the same instance draw again: two consecutive demands being
## the same pooled instance with no gap between them is the one case that
## reuses a roll, and it is both rare and harmless.
func _should_ignore(hazard: Obstacle) -> bool:
	if hazard == null:
		_judged_hazard_id = 0
		_ignoring_hazard = false
		return false
	var id := hazard.get_instance_id()
	if id != _judged_hazard_id:
		_judged_hazard_id = id
		_demands += 1
		_demands_by_type[hazard.obstacle_type] += 1
		_ignoring_hazard = randf() < _miss_chance_for(hazard.obstacle_type)
	return _ignoring_hazard

## The profile's base rate, discounted for a hazard the game telegraphs --
## see TELEGRAPHED_TYPES / TELEGRAPHED_MISS_SCALE.
func _miss_chance_for(type: int) -> float:
	var base := _miss_chance()
	return base * TELEGRAPHED_MISS_SCALE if type in TELEGRAPHED_TYPES else base

func _drive_safe_bot() -> void:
	var lane_ttc := _nearest_hazard_ttc_per_lane()
	var own: float = lane_ttc[_keepy.lane_index]
	if own < 0.0 or own > SAFE_ESCAPE_LEAD_S:
		_should_ignore(null) # nothing demands a reaction -- re-arm the roll
		return
	var own_obstacle := _nearest_obstacle_on_lane(_keepy.lane_index)
	if _should_ignore(own_obstacle):
		return
	if own_obstacle != null and Obstacle.blocks_lane_switch(own_obstacle.obstacle_type):
		if own <= HALF_AIR_TIME_S and _keepy.is_on_floor():
			_keepy.velocity.y = Keepy.JUMP_VELOCITY
		return
	var best_step := 0
	var best_ttc := own
	for step in [-1, 1]:
		var lane: int = _keepy.lane_index + step
		if lane < 0 or lane > 2:
			continue
		var ttc: float = lane_ttc[lane] if lane_ttc[lane] >= 0.0 else INF
		if ttc > best_ttc:
			best_ttc = ttc
			best_step = step
	if best_step != 0:
		_keepy.move_lane(best_step)

func _drive_intermediate_bot() -> void:
	var threat := _nearest_obstacle_on_lane(_keepy.lane_index)
	if threat == null:
		_should_ignore(null)
		return
	var ttc: float = threat.time_to_contact_s()
	if ttc <= 0.0 or ttc > SAFE_ESCAPE_LEAD_S:
		_should_ignore(null)
		return
	if _should_ignore(threat):
		return
	if not Obstacle.blocks_jump(threat.obstacle_type):
		if ttc <= HALF_AIR_TIME_S and _keepy.is_on_floor():
			_keepy.velocity.y = Keepy.JUMP_VELOCITY
		return
	_keepy.move_lane(_safest_adjacent_step())

func _drive_risky_bot() -> void:
	var threat := _nearest_obstacle_on_lane(_keepy.lane_index)
	if threat != null:
		var ttc: float = threat.time_to_contact_s()
		# Rolled against the SAME window as the other two bots
		# (SAFE_ESCAPE_LEAD_S -- the moment a hazard starts demanding an
		# answer), not against this bot's much later ACTION threshold: the
		# three profiles have to be fallible on the same terms, or the miss
		# chances are not comparable numbers. What is late here is when it
		# MOVES, not when it starts paying attention.
		if ttc > 0.0 and ttc <= SAFE_ESCAPE_LEAD_S:
			if _should_ignore(threat):
				return
		else:
			_should_ignore(null)
		if not Obstacle.blocks_jump(threat.obstacle_type):
			if ttc <= HALF_AIR_TIME_S and ttc > 0.0 and _keepy.is_on_floor():
				_keepy.velocity.y = Keepy.JUMP_VELOCITY
			return
		var target: float = _graze_escape_ttc(threat) if _alternate_escape else RISKY_LATE_ESCAPE_S
		if ttc <= target and ttc > 0.0:
			_alternate_escape = not _alternate_escape
			_keepy.move_lane(_safest_adjacent_step())
		return
	_should_ignore(null)
	var gland_lane := _reachable_gland_lane()
	if gland_lane == -1:
		return
	if gland_lane != _keepy.lane_index:
		_keepy.move_lane(signi(gland_lane - _keepy.lane_index))
		return
	if _keepy.is_on_floor() and _gland_ttc_on_lane(gland_lane) <= HALF_AIR_TIME_S:
		_keepy.velocity.y = Keepy.JUMP_VELOCITY

func _graze_escape_ttc(hazard: Obstacle) -> float:
	var window_open_s: float = Obstacle.RISK_PROXIMITY_Z / maxf(hazard.closing_speed(), 0.001)
	var pitch: float = TrackSegment.LANE_X[1] - TrackSegment.LANE_X[0]
	var fraction: float = clampf(RISKY_GRAZE_TARGET_M / pitch, 0.0, 0.99)
	var lerp_s: float = -log(1.0 - fraction) / Keepy.LANE_SWITCH_SPEED
	return window_open_s + lerp_s

func _safest_adjacent_step() -> int:
	var lane_ttc := _nearest_hazard_ttc_per_lane()
	var best_step := 1 if _keepy.lane_index == 0 else -1
	var best_ttc := -INF
	for step in [-1, 1]:
		var lane: int = _keepy.lane_index + step
		if lane < 0 or lane > 2:
			continue
		var ttc: float = lane_ttc[lane] if lane_ttc[lane] >= 0.0 else INF
		if ttc > best_ttc:
			best_ttc = ttc
			best_step = step
	return best_step

var _lane_ttc_scratch: Array[float] = [-1.0, -1.0, -1.0]

func _nearest_hazard_ttc_per_lane() -> Array[float]:
	for lane in 3:
		_lane_ttc_scratch[lane] = -1.0
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle == null:
			continue
		var ttc: float = obstacle.time_to_contact_s()
		if ttc <= 0.0:
			continue
		var lane := _lane_index_for_x(obstacle.position.x)
		if lane == -1:
			continue
		if _lane_ttc_scratch[lane] < 0.0 or ttc < _lane_ttc_scratch[lane]:
			_lane_ttc_scratch[lane] = ttc
	return _lane_ttc_scratch

func _nearest_obstacle_on_lane(lane: int) -> Obstacle:
	var best: Obstacle = null
	var best_ttc := INF
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle == null:
			continue
		if _lane_index_for_x(obstacle.position.x) != lane:
			continue
		var ttc: float = obstacle.time_to_contact_s()
		if ttc <= 0.0 or ttc >= best_ttc:
			continue
		best_ttc = ttc
		best = obstacle
	return best

func _reachable_gland_lane() -> int:
	var lane_ttc := _nearest_hazard_ttc_per_lane()
	var best_lane := -1
	var best_z := -INF
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		for lane in 3:
			if lane_ttc[lane] >= 0.0 and lane_ttc[lane] < GLAND_CHASE_SAFE_LEAD_S:
				continue
			var z: float = segment.active_gland_z_on_lane(lane)
			if z == INF or z >= 0.0:
				continue
			if z > best_z:
				best_z = z
				best_lane = lane
	return best_lane

func _gland_ttc_on_lane(lane: int) -> float:
	var best := INF
	for segment in _track.get_children():
		if not (segment is TrackSegment):
			continue
		var z: float = segment.active_gland_z_on_lane(lane)
		if z == INF or z >= 0.0:
			continue
		best = minf(best, -z / GameState.current_speed)
	return best

func _active_obstacle_in(segment: TrackSegment) -> Obstacle:
	for child in segment.get_children():
		if child is Obstacle and child.visible:
			return child
	return null

func _lane_index_for_x(x: float) -> int:
	for lane in TrackSegment.LANE_X.size():
		if absf(x - TrackSegment.LANE_X[lane]) < 0.01:
			return lane
	return -1
