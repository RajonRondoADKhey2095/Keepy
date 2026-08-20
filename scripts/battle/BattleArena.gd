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
## ONE moment only -- the end of a round, below -- and never during a
## tick, so nothing here can make an animation an input to the fight.
@onready var player_view: FighterView = $World/PlayerFighter/View
@onready var opponent_view: FighterView = $World/OpponentFighter/View
@onready var hud: BattleHUD = $BattleHUD

var _rng := RandomNumberGenerator.new()
var _brain := FighterBrain.new()
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
	_brain.setup(opponent, player, opponent.profile, _rng)
	_accumulator = 0.0
	_running = true
	hud.show_fight()

func _on_player_action(action: BattleTypes.Action) -> void:
	if not _running:
		return
	player.request_action(action)

func _on_player_strike() -> void:
	var outcome := opponent.receive_strike(_damage_of(player))
	hud.report_strike(true, outcome)

func _on_opponent_strike() -> void:
	var outcome := player.receive_strike(_damage_of(opponent))
	hud.report_strike(false, outcome)

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
	hud.show_result(player_won)

func _on_quit() -> void:
	get_tree().change_scene_to_file(HUB_SCENE)

func _damage_of(fighter: Fighter) -> int:
	return fighter.profile.attack_damage if fighter.profile else 0

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
