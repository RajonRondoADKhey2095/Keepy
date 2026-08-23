extends Node3D
class_name BattleArena
## Root of Keepy Battle (scenes/Battle.tscn). Owns three things and no
## more: the fixed-step clock, the ONE place a strike is resolved, and
## the wiring between "who taps" and "which Fighter".
##
## =====================================================================
## FIXED-STEP CLOCK -- WHY NOT JUST USE delta
##
## Both fighters and the AI brain are advanced by whole TICK_S steps out
## of an accumulator, never by the frame's raw delta. On a phone the
## frame time is whatever the browser felt like giving us, and a FSM
## stepped by that has phase boundaries that land on different frames run
## to run: two identical fights diverge, and "is this combo actually
## unblockable or did I just get a long frame" becomes unanswerable.
## Stepping in fixed ticks makes a fight a pure function of (seed, tap
## timings in ticks), which is the property this whole lot depends on --
## it is what lets a balance change be MEASURED rather than felt.
##
## The engine's own _physics_process would give a fixed step too, and was
## rejected for one reason: it ties combat pacing to a project-wide
## physics setting that belongs to Keepy Chased, so a future change there
## would silently retune this game. The accumulator is explicit and local.
##
## =====================================================================
## STRIKE RESOLUTION LIVES HERE, ONCE
##
## A Fighter announces `strike_activated` and knows nothing about who is
## in front of it; the arena calls `receive_strike()` on the other one,
## which answers from its own state. Neither fighter holds a reference to
## the other, so there is exactly one rule and no chance of two
## half-rules disagreeing.
##
## =====================================================================
## CUMULATIVE STATS -- THE ONE FIRESTORE WRITE IN THIS GAME
##
## Because this file is already "the ONE place a strike is resolved", it
## is also the only place that sees both halves of every exchange: what
## the player committed to, and what came of it. So the per-fight tally
## is counted here and nowhere else -- a Fighter counting its own strikes
## would be a second bookkeeper on the same facts.
##
## The tally is pure counting (BattleTally, no network). It is handed to
## BattleStats ONCE, in _end_round(), and never during a tick: nothing
## about recording can reach into the fight, and a fight abandoned to the
## hub mid-round records nothing because it never ended.
##
## =====================================================================
## SEEDING
##
## One RandomNumberGenerator, seeded explicitly, handed to the brain --
## the global RNG is never touched anywhere in scripts/battle/. Rounds
## re-seed as base_seed + round index, so round 2 is not a replay of
## round 1 yet the whole session is still reproducible from one number.

const TICK_S := 1.0 / 60.0
## Guard against a spiral of death after a long stall (tab restored, GC
## pause): drop the excess rather than trying to catch up in one frame.
const MAX_TICKS_PER_FRAME := 8
const HUB_SCENE := "res://scenes/Hub.tscn"

## Base seed for the fight. Overridable from the command line with
## `-- --seed=<int>`, the same convention every probe in scripts/dev/
## uses, so a future BattleBalanceAudit can replay a specific fight
## without this file growing a debug-only branch.
##
## The parse is INLINE below and not a call to DevSeed.seed_value(),
## which does exactly this and would have been the obvious reuse:
## export_presets.cfg carries `scripts/dev/*` in its exclude_filter, so
## DevSeed is NOT in the shipped pack. A `class_name` reference to it
## from a shipped script resolves in the editor and in a headless run and
## then fails in the web build only -- the one place nobody can check.
@export var base_seed: int = 20260820

@onready var player: Fighter = $World/PlayerFighter
@onready var opponent: Fighter = $World/OpponentFighter
## The two view layers, addressed by path exactly like the fighters above
## and for the same reason: the scene IS the wiring. They are touched at
## TWO moments only -- the start and the end of a round, below -- and
## never during a tick, so nothing here can make an animation an input to
## the fight.
@onready var player_view: FighterView = $World/PlayerFighter/View
@onready var opponent_view: FighterView = $World/OpponentFighter/View
@onready var hud: BattleHUD = $BattleHUD

var _rng := RandomNumberGenerator.new()
var _brain := FighterBrain.new()
## Counters for the fight in progress, player side only. Reset at every
## round start, closed and handed to BattleStats at every round end.
var _tally := BattleTally.new()
var _accumulator: float = 0.0
var _round: int = 0
var _running: bool = false

func _ready() -> void:
	# Swamp default: this arena keeps Keepy's palette, so the safe-area
	# strip stays the shell's baseline colour.
	SafeArea.set_default()
	# Canvas fills the screen. Unlike Game.tscn -- which asks for KEEP
	# because Chased's reaction budget is tuned to a 9:16 framing (see
	# SafeArea.gd) -- Battle has no scrolling world and no distance-based
	# budget: the two fighters are at fixed marks, so a taller viewport
	# shows more empty sky and changes nothing that can be played.
	SafeArea.fill_screen()

	hud.bind(player, opponent)
	hud.action_requested.connect(_on_player_action)
	hud.rematch_requested.connect(_start_round)
	hud.quit_requested.connect(_on_quit)

	# The player's commitments -- the `attempted` half of the stats. Read
	# from the fighter's own signal rather than from the HUD's taps: a
	# tap that arrives mid-lockout is BUFFERED and may never become an
	# action at all, and counting a commitment that never happened would
	# quietly inflate every ratio.
	player.action_started.connect(_on_player_action_started)
	player.strike_activated.connect(_on_player_strike)
	opponent.strike_activated.connect(_on_opponent_strike)
	player.knocked_out.connect(_on_player_ko)
	opponent.knocked_out.connect(_on_opponent_ko)

	_start_round()

func _exit_tree() -> void:
	# Explicit teardown even though a scene change frees all of it: these
	# connections cross node boundaries, and leaving them implicit is how
	# a future refactor that keeps the HUD alive across rounds ends up
	# with two handlers on one signal.
	if is_instance_valid(hud):
		_disconnect(hud.action_requested, _on_player_action)
		_disconnect(hud.rematch_requested, _start_round)
		_disconnect(hud.quit_requested, _on_quit)
	if is_instance_valid(player):
		_disconnect(player.action_started, _on_player_action_started)
		_disconnect(player.strike_activated, _on_player_strike)
		_disconnect(player.knocked_out, _on_player_ko)
	if is_instance_valid(opponent):
		_disconnect(opponent.strike_activated, _on_opponent_strike)
		_disconnect(opponent.knocked_out, _on_opponent_ko)

func _process(delta: float) -> void:
	if not _running:
		return
	_accumulator += delta
	var ticks := 0
	while _accumulator >= TICK_S and ticks < MAX_TICKS_PER_FRAME:
		_accumulator -= TICK_S
		_tick(TICK_S)
		ticks += 1
		if not _running:
			break
	if ticks >= MAX_TICKS_PER_FRAME:
		_accumulator = 0.0

## One tick, in a FIXED order: both fighters advance, then the brain
## decides. The order is part of the determinism contract -- deciding
## before advancing would let the AI act on a state that is about to
## change in the same tick, and reversing the two fighters would change
## which side wins a simultaneous trade.
func _tick(dt: float) -> void:
	player.advance(dt)
	opponent.advance(dt)
	_brain.advance(dt)

func _start_round() -> void:
	_round += 1
	# Same base seed, different round: a session is reproducible from one
	# number, without round 2 replaying round 1's draws.
	_rng.seed = _effective_seed() + _round
	player.reset()
	opponent.reset()
	# A rematch is a NEW fight: it must not inherit the previous tally.
	_tally.reset()
	_brain.setup(opponent, player, opponent.profile, _rng)
	# Each fighter's charge bar shows the window in which its OPPONENT
	# should tap a dodge. That span mixes the ATTACKER's wind-up with the
	# DEFENDER's dodge timings, so this is the only object that can work
	# it out -- a view deriving it from its own profile would be drawing a
	# guess about the fighter opposite.
	player_view.set_dodge_window(_evade_lo(player, opponent), _evade_hi(player, opponent))
	opponent_view.set_dodge_window(_evade_lo(opponent, player), _evade_hi(opponent, player))
	_accumulator = 0.0
	_running = true
	hud.show_fight()

func _on_player_action(action: BattleTypes.Action) -> void:
	if not _running:
		return
	player.request_action(action)

## `last_defence()` is read BEFORE the strike resolves, because resolving
## it is what clears the action: a mistimed dodge has already become a
## stagger with no action at all by the time receive_strike() returns.
## Same fact the defender's own view gets on `hit_taken`, taken from the
## same place one line earlier.
func _on_player_strike() -> void:
	var attempted := opponent.last_defence()
	var riposte := player.attack_is_riposte()
	var outcome := opponent.receive_strike(_damage_of(player, riposte), riposte)
	_tally.note_attack_resolved(outcome)
	hud.report_strike(true, outcome, attempted)

func _on_opponent_strike() -> void:
	var attempted := player.last_defence()
	var riposte := opponent.attack_is_riposte()
	var outcome := player.receive_strike(_damage_of(opponent, riposte), riposte)
	# Same (attempted, outcome) pair the HUD is about to turn into
	# "ESQUIVE RATEE" on the next line, taken from the same read: the
	# counter and the word the player sees cannot drift.
	_tally.note_defence_resolved(attempted, outcome)
	hud.report_strike(false, outcome, attempted)

## The player committed to something. NOT called for the opponent: the
## shared stats document describes how PEOPLE play, and folding an AI's
## actions into it would make every ratio unreadable.
func _on_player_action_started(action: BattleTypes.Action) -> void:
	_tally.note_action_started(action)

func _on_player_ko() -> void:
	_end_round(false)

func _on_opponent_ko() -> void:
	_end_round(true)

## Stops the clock and hands the round to the HUD.
##
## The two settle() calls are the visual consequence of that first line.
## `_running = false` happens on the KO TICK, which is the tick the winner
## entered its ACTIVE window -- its FSM never emits another transition, so
## without this its view would hold the winning lunge for as long as the
## result panel is up (600x440 on a 1080x1920 screen: it covers neither
## fighter). settle() returns a fighter that is still standing to rest and
## deliberately leaves a KO'd one lying down, since the topple IS the
## result being shown.
func _end_round(player_won: bool) -> void:
	_running = false
	player_view.settle()
	opponent_view.settle()
	# One write per FINISHED fight, fired and forgotten. BattleStats
	# never blocks and never raises, so nothing below depends on it and
	# the result panel goes up regardless of network, auth or rules --
	# and `finish()` is idempotent, so a second KO signal cannot
	# double-count this fight.
	if _tally.finish(player_won):
		BattleStats.record(_tally)
	hud.show_result(player_won)

## Read-only view of the fight in progress, for BattleStatsProbe.
##
## Nothing in the GAME reads this -- the tally has exactly one consumer,
## _end_round() above. It exists so the probe can check the counters an
## actual, shipped fight produced instead of re-deriving them from a
## copy of the wiring, which is the "fixture that diverges from the real
## thing" trap this repo has already paid for once (AlarmRampAudit).
func fight_tally() -> BattleTally:
	return _tally

func _on_quit() -> void:
	get_tree().change_scene_to_file(HUB_SCENE)

## The evade window on `attacker`'s bar, as fractions of its fill.
##
## A dodge tapped `t` seconds into a wind-up of length W becomes active at
## t + dw and drops at t + dw + da, so it covers a blow landing at W iff
##
##     W - dw - da  <=  t  <=  W - dw
##
## which is a span of exactly the defender's dodge_active_s, ending
## dodge_windup_s short of a full bar.
##
## =====================================================================
## THE BAND IS DELIBERATELY A SUBSET OF WHAT REALLY WORKS
##
## That inequality is continuous and the FSM is not: everything is
## quantised to TICK_S, and inside a tick the ATTACKER advances before
## the defender (see _tick()), so a strike can resolve on a tick the
## defender has not stepped yet. Measured on the shipped profiles, the
## taps that really evade are ticks 26..49 of 54, i.e. 0.481..0.907 of
## the bar, while the plain arithmetic gives 0.500..0.944.
##
## The low end is therefore already conservative and is left alone. The
## HIGH end is not -- it over-promises by two ticks -- so it carries a
## two-tick allowance. A band that claims a tap works and then does not
## is worse than no band: it teaches the wrong timing, with the game's
## own authority behind it. BattleReadabilityProbe taps at both edges and
## at the centre and asserts the blow is really evaded, so the band is
## checked against the MECHANIC and not against this comment.
##
## Both ends are clamped by FighterView; a wind-up shorter than the
## dodge's own startup would put the whole window before the bar even
## appears, and drawing a negative span is not a thing this arena should
## invent a meaning for.
const EVADE_EDGE_ALLOWANCE_TICKS := 2.0
func _evade_lo(attacker: Fighter, defender: Fighter) -> float:
	var w := _windup_of(attacker)
	if w <= 0.0:
		return -1.0
	return (w - defender.profile.dodge_windup_s - defender.profile.dodge_active_s) / w

func _evade_hi(attacker: Fighter, defender: Fighter) -> float:
	var w := _windup_of(attacker)
	if w <= 0.0:
		return -1.0
	return (w - defender.profile.dodge_windup_s - EVADE_EDGE_ALLOWANCE_TICKS * TICK_S) / w

func _windup_of(fighter: Fighter) -> float:
	return fighter.profile.attack_windup_s if fighter.profile else 0.0

## What one strike costs, and whether it cancels what the target was
## doing. BOTH answers come from the same fact -- was this attack thrown
## off a successful dodge -- so they cannot drift apart into a heavy blow
## that does not stagger or a chip that does.
##
## Priced HERE rather than inside Fighter for the reason the whole
## resolution lives here: a fighter must not have to know anything about
## the one in front of it, and pricing is half of resolving.
func _damage_of(fighter: Fighter, riposte: bool) -> int:
	if fighter.profile == null:
		return 0
	return fighter.profile.damage_for(riposte)

## `--seed=<int>` passed after a bare `--`, or base_seed. Deliberately a
## copy of DevSeed.seed_value()'s six lines rather than a call to it --
## see base_seed's comment for why that reuse is not available here.
func _effective_seed() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			var value := int(arg.substr("--seed=".length()))
			if value != 0:
				return value
	return base_seed

func _disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)
