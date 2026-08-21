extends Node
## Dev-only: gates the READABILITY contract of Keepy Battle -- the part of
## lot 2 that a device capture caught and that no existing probe could
## have caught.
##
## =====================================================================
## WHAT THIS ADDS THAT BattleContractProbe CANNOT
##
## That probe measures the FIGHT: phase order, durations, the resolution
## matrix, determinism. Every one of its assertions passed on lot 1, and
## lot 1 was unplayable on a phone -- because none of them is about
## whether a human can SEE what the FSM is doing. A combat system can be
## provably correct and still tell the player nothing.
##
## So this file measures the other half:
##
##   PHASE A  the geometry the whole telegraph rests on, read out of the
##            SHIPPED Battle.tscn rather than assumed
##   PHASE B  engine time cannot leak into the fight, exercised by
##            running the SAME fight with tweens actually stepping
##   PHASE C  an incoming attack is visible on the fighter, and GROWS
##   PHASE D  attack and dodge do not look alike
##   PHASE E  an interrupted animation is replaced, never stacked
##   PHASE F  the two HUD contradictions the captures showed
##   PHASE G  the CHARGE BAR (lot 7): full fill IS the instant of impact,
##            to the frame; legible against BOTH backgrounds; raised for
##            an attack and for nothing else
##
## PHASE B is the one that earns the file. Everything else here could be
## satisfied by an animation layer that also, quietly, changed the fight.

const TICK_S := 1.0 / 60.0
const FighterScene := preload("res://scenes/BattleFighter.tscn")
const HudScene := preload("res://scenes/BattleHUD.tscn")
const BattleScene := preload("res://scenes/Battle.tscn")
const KeepyProfile := preload("res://resources/battle/keepy.tres")
const DummyProfile := preload("res://resources/battle/dummy.tres")

## Sampling instants inside an attack windup, as fractions of its length.
## Far enough apart that an eased ramp has visibly moved between them --
## the point is to prove the telegraph GROWS, not that it merely exists.
const SAMPLE_EARLY := 0.27
const SAMPLE_LATE := 0.80

var _failures := 0
var _checks := 0

func _ready() -> void:
	ProbeWatchdog.arm(self, "BattleReadabilityProbe")
	print("=== BATTLE READABILITY PROBE ===")
	print("tick=%.6fs  profiles: %s vs %s" % [TICK_S, KeepyProfile.display_name, DummyProfile.display_name])
	_phase_a_facing()
	await _phase_b_no_leak()
	await _phase_c_telegraph()
	await _phase_d_silhouettes()
	await _phase_e_interrupt()
	_phase_f_hud()
	await _phase_g_charge_bar()
	print("--- %d check(s), %d failure(s) ---" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

# ---------------------------------------------------------------- PHASE A

## FighterView lunges along its fighter's LOCAL +Z and recoils along -Z,
## for both sides, from one sign convention. That only works because
## Battle.tscn happens to yaw the two fighters to face each other along
## that axis -- an authored fact, in a file nobody edits while thinking
## about animation code. Flip a rotation there and every attack in the
## game would lunge backwards, with nothing failing.
##
## So it is READ OUT of the shipped scene, not trusted: SceneState gives
## the authored transforms without instantiating the arena (which would
## drag in SafeArea, a HUD and a running round none of which this phase
## is measuring).
func _phase_a_facing() -> void:
	print("\n--- PHASE A: the fighters really do face each other along local +Z ---")
	var state := BattleScene.get_state()
	var marks := {}
	for i in state.get_node_count():
		var node_name := String(state.get_node_name(i))
		if node_name != "PlayerFighter" and node_name != "OpponentFighter":
			continue
		var placement := {"position": Vector3.ZERO, "rotation_degrees": Vector3.ZERO}
		for p in state.get_node_property_count(i):
			var key := String(state.get_node_property_name(i, p))
			if placement.has(key):
				placement[key] = state.get_node_property_value(i, p)
		marks[node_name] = placement

	_expect(marks.size() == 2, "Battle.tscn still carries both fighters")
	if marks.size() != 2:
		return

	for node_name in ["PlayerFighter", "OpponentFighter"]:
		var other: String = "OpponentFighter" if node_name == "PlayerFighter" else "PlayerFighter"
		var here: Vector3 = marks[node_name]["position"]
		var there: Vector3 = marks[other]["position"]
		var euler: Vector3 = marks[node_name]["rotation_degrees"]
		var basis := Basis.from_euler(Vector3(deg_to_rad(euler.x), deg_to_rad(euler.y), deg_to_rad(euler.z)))
		var local_forward := (basis * Vector3(0.0, 0.0, 1.0)).normalized()
		var toward := (there - here).normalized()
		var alignment := local_forward.dot(toward)
		print("  %-16s local +Z %s  toward opponent %s  dot=%.3f" % [node_name, local_forward, toward, alignment])
		_expect(alignment > 0.99, "%s's local +Z points at its opponent" % node_name)

	# The gap matters too: a lunge that reaches further than the space
	# between two fighters would put them inside each other.
	#
	# This used to subtract a hard-coded 0.45 -- the capsule radius
	# written in BattleFighter.tscn. That number stopped being the answer
	# the moment lot 6 installed real models: the squirrel is 2.04 deep
	# because of its tail, so its reach toward the opponent is more than
	# twice the capsule's. Measuring it instead means this assertion keeps
	# meaning what it says for whatever .glb a future profile carries,
	# which is the whole point of the one-.tres-one-.glb contract.
	var gap: float = (marks["OpponentFighter"]["position"] as Vector3).distance_to(marks["PlayerFighter"]["position"] as Vector3)
	var reach_player := _forward_reach(KeepyProfile)
	var reach_opponent := _forward_reach(DummyProfile)
	var surface_gap := gap - reach_player - reach_opponent
	var both_lunge := 2.0 * FighterView.LUNGE_REACH
	print("  forward reach: player %.3f, opponent %.3f (from each slot's measured visual AABB)" % [reach_player, reach_opponent])
	print("  centres %.2f apart, %.2f between surfaces, both lunging closes %.2f" % [gap, surface_gap, both_lunge])
	_expect(both_lunge < surface_gap, "two simultaneous lunges cannot interpenetrate")

# ---------------------------------------------------------------- PHASE B

## The claim FighterView's header makes, turned into a measurement: the
## animation layer cannot change the fight.
##
## Both runs are the SAME fight at the SAME seed with views attached (they
## always are -- there is no headless bypass). The difference is that the
## second one yields a real frame between every tick, so every tween
## created by every state change genuinely steps, dozens of times, while
## the FSM advances. If any engine-time value were reachable from the FSM,
## the two traces would part.
func _phase_b_no_leak() -> void:
	print("\n--- PHASE B: stepping the tweens does not change the fight ---")
	var quiet := await _run_fight(20260820, 4000, false)
	var animated := await _run_fight(20260820, 4000, true)
	print("  no frames between ticks : %d ticks, winner=%s" % [quiet.ticks, quiet.winner])
	print("  a frame between ticks   : %d ticks, winner=%s" % [animated.ticks, animated.winner])
	_expect(quiet.trace.length() > 0, "the trace is not empty")
	_expect(quiet.trace == animated.trace, "byte-identical trace with tweens live (%d chars)" % quiet.trace.length())
	_expect(quiet.ticks == animated.ticks, "same tick count")

# ---------------------------------------------------------------- PHASE C

## The defect lot 2 exists to fix: during an opponent's attack windup,
## something on the FIGHTER has to move, and it has to keep moving, so
## that "how far it has wound up" reads as "how long is left".
##
## Measured on the OPPONENT's profile since lot 8, and that is the whole
## point of the phase rather than a detail: a telegraph is a thing the
## DEFENDER reads, so it only ever exists on the fighter opposite. The
## player's attack is instant and has no wind-up to animate -- running
## this against it would sample a phase of length zero and assert that
## nothing had moved yet, which is true and meaningless.
func _phase_c_telegraph() -> void:
	print("\n--- PHASE C: the attack telegraph is visible and grows ---")
	var fighter := _make(DummyProfile)
	var slot := fighter.get_node("Body") as ModelSlot
	var rest := slot.position
	var windup: float = DummyProfile.attack_windup_s

	fighter.request_action(BattleTypes.Action.ATTACK)
	_expect(fighter.state == BattleTypes.State.WINDUP, "precondition: the fighter is winding up")

	await _wait(windup * SAMPLE_EARLY)
	var early_recoil := _recoil(slot, rest)
	var early_tint := _tint(slot)
	await _wait(windup * (SAMPLE_LATE - SAMPLE_EARLY))
	var late_recoil := _recoil(slot, rest)
	var late_tint := _tint(slot)

	print("  recoil away from opponent : %.4f at %d%% -> %.4f at %d%%" % [
		early_recoil, int(SAMPLE_EARLY * 100.0), late_recoil, int(SAMPLE_LATE * 100.0)])
	_expect(early_recoil > 0.001, "the fighter has already moved early in the windup")
	_expect(late_recoil > early_recoil, "and keeps moving: the anticipation GROWS, it does not just snap")
	_expect(late_recoil <= FighterView.WINDUP_RECOIL + 0.001, "the recoil stays inside its authored bound")

	print("  tint toward alert (green) : %.3f -> %.3f  (base %.3f, alert %.3f)" % [
		early_tint.g, late_tint.g, DummyProfile.placeholder_color.g, FighterView.ALERT_COLOR.g])
	_expect(early_tint != Color.WHITE, "the view took ownership of a material to tint")
	_expect(late_tint.g < early_tint.g, "the danger colour ramps progressively, not as a flash")
	fighter.free()

# ---------------------------------------------------------------- PHASE D

## Two actions, two silhouettes. A dodge that looked like an attack would
## be worse than no animation at all: it would actively mislead.
func _phase_d_silhouettes() -> void:
	print("\n--- PHASE D: attack and dodge do not look alike ---")
	var poses := {}
	for entry in [
		["ATTACK", BattleTypes.Action.ATTACK],
		["DODGE", BattleTypes.Action.DODGE],
	]:
		var label: String = entry[0]
		var action: BattleTypes.Action = entry[1]
		var fighter := _make(KeepyProfile)
		var slot := fighter.get_node("Body") as ModelSlot
		var rest := slot.position
		fighter.request_action(action)
		# Straight through the windup, synchronously: this phase is about
		# the ACTIVE pose, and the windup tween is meant to be replaced.
		var guard_ticks := 0
		while fighter.state != BattleTypes.State.ACTIVE and guard_ticks < 600:
			fighter.advance(TICK_S)
			guard_ticks += 1
		_expect(fighter.state == BattleTypes.State.ACTIVE, "%s reached its ACTIVE window" % label)
		await _wait(0.14)
		poses[label] = {
			"forward": -_recoil(slot, rest),
			"height": slot.scale.y,
		}
		print("  %-6s forward %+.3f   height x%.3f" % [label, poses[label]["forward"], poses[label]["height"]])
		fighter.free()

	_expect(poses["ATTACK"]["forward"] > 0.1, "ATTACK lunges TOWARD the opponent")
	_expect(poses["DODGE"]["forward"] < -0.1, "DODGE slips AWAY from the opponent")
	# Opposite SIGNS, not merely different numbers: the two poses have to
	# be distinguishable at a glance on a phone, and "one is a bit further
	# forward than the other" is not that.
	_expect(poses["ATTACK"]["forward"] > poses["DODGE"]["forward"] + 0.3,
		"ATTACK and DODGE move in opposite directions, not just by different amounts")

# ---------------------------------------------------------------- PHASE E

## A fight interrupts itself constantly -- a KO lands mid-lunge, a stagger
## cancels a windup. Every one of those has to REPLACE the animation in
## flight. Tweens that stacked instead would fight each other for the same
## node and the fighter would jitter between two targets.
func _phase_e_interrupt() -> void:
	print("\n--- PHASE E: an interrupted animation is replaced, not stacked ---")
	var fighter := _make(KeepyProfile)
	var slot := fighter.get_node("Body") as ModelSlot

	# 50 transitions, back to back, faster than any of them can finish.
	for i in 25:
		fighter.request_action(BattleTypes.Action.ATTACK)
		fighter.advance(TICK_S)
		fighter.reset()
	await _wait(0.05)
	var live := get_tree().get_processed_tweens().size()
	print("  live tweens after 25 aborted actions : %d" % live)
	_expect(live <= 4, "tweens are killed and replaced, never accumulated (%d live)" % live)

	# A KO landing mid-lunge must topple the fighter, not leave it frozen
	# in the pose it was in when the fight stopped.
	fighter.reset()
	fighter.request_action(BattleTypes.Action.ATTACK)
	var ticks := 0
	while fighter.state != BattleTypes.State.ACTIVE and ticks < 600:
		fighter.advance(TICK_S)
		ticks += 1
	await _wait(0.05)
	fighter.receive_strike(KeepyProfile.max_hp, true)
	_expect(fighter.state == BattleTypes.State.KO, "precondition: the fighter is KO mid-lunge")
	await _wait(FighterView.KO_S + 0.12)
	print("  toppled to pitch %.1f deg, centre y %.3f" % [slot.rotation_degrees.x, slot.position.y])
	_expect(absf(slot.rotation_degrees.x - FighterView.KO_FALL_DEG) < 1.0, "the KO topple wins over the lunge in flight")
	_expect(absf(slot.position.y - FighterView.KO_CENTRE_Y) < 0.01, "and lands the body on the ground rather than mid-air")
	fighter.free()

# ---------------------------------------------------------------- PHASE F

## The two contradictions the device captures showed, both now measurable.
func _phase_f_hud() -> void:
	print("\n--- PHASE F: the HUD cannot contradict itself ---")

	# (1) A verdict that outlives the action that produced it. The
	# attacker stays committed for active + recovery after its strike
	# resolves; a longer FLASH_S leaves "TOUCHE" on screen while the same
	# fighter's state line already reads "Pret".
	var shortest := 1000.0
	for entry in [["Keepy", KeepyProfile], ["Sparring", DummyProfile]]:
		var label: String = entry[0]
		var p: FighterProfile = entry[1]
		var committed: float = p.attack_active_s + p.attack_recovery_s
		shortest = minf(shortest, committed)
		print("  %-9s stays committed after its strike : %.0f ms" % [label, committed * 1000.0])
	print("  FLASH_S                                    : %.0f ms" % (BattleHUD.FLASH_S * 1000.0))
	_expect(BattleHUD.FLASH_S < shortest, "a strike verdict cannot outlive the action that caused it")

	# (2) A frozen phase presented as the current one. The round stops on
	# the KO tick, so the winner's FSM is genuinely stuck in ACTIVE -- the
	# HUD must stop reporting phases once there is no fight left to report.
	var player := _make(KeepyProfile)
	var opponent := _make(DummyProfile)
	var hud := HudScene.instantiate() as BattleHUD
	add_child(hud)
	hud.bind(player, opponent)
	opponent.request_action(BattleTypes.Action.ATTACK)
	var ticks := 0
	while opponent.state != BattleTypes.State.ACTIVE and ticks < 600:
		opponent.advance(TICK_S)
		ticks += 1
	print("  winner's live label at the KO tick : '%s'" % hud.opponent_state_label.text)
	_expect(hud.opponent_state_label.text == "Attaque - Actif", "precondition: the frozen phase is what the label held")
	hud.show_result(false)
	print("  after show_result()                : '%s' / '%s'" % [
		hud.player_state_label.text, hud.opponent_state_label.text])
	_expect(hud.opponent_state_label.text != "Attaque - Actif", "the frozen phase is no longer presented as current")
	_expect(hud.player_state_label.text == "K.O." and hud.opponent_state_label.text == "Vainqueur",
		"both lines report how the round ended instead")
	hud.free()
	player.free()
	opponent.free()

# ---------------------------------------------------------------- helpers

class FightResult:
	var ticks: int = 0
	var winner: String = "none"
	var trace: String = ""

## The arena's tick order exactly, optionally yielding a real frame
## between ticks so the view layer's tweens actually run.
func _run_fight(fight_seed: int, tick_cap: int, animate: bool) -> FightResult:
	var result := FightResult.new()
	var left := _make(KeepyProfile)
	var right := _make(DummyProfile)
	var rng := RandomNumberGenerator.new()
	rng.seed = fight_seed
	var brain := FighterBrain.new()
	brain.setup(right, left, right.profile, rng)
	left.strike_activated.connect(func() -> void:
		var rip := left.attack_is_riposte()
		right.receive_strike(left.profile.damage_for(rip), rip))
	right.strike_activated.connect(func() -> void:
		var rip := right.attack_is_riposte()
		left.receive_strike(right.profile.damage_for(rip), rip))

	var parts := PackedStringArray()
	while result.ticks < tick_cap and left.is_alive() and right.is_alive():
		left.advance(TICK_S)
		right.advance(TICK_S)
		brain.advance(TICK_S)
		result.ticks += 1
		parts.append("%d:%d:%d:%d:%d:%d" % [left.hp, left.state, left.current_action, right.hp, right.state, right.current_action])
		if animate:
			await get_tree().process_frame
	result.trace = "|".join(parts)
	if not right.is_alive():
		result.winner = "player"
	elif not left.is_alive():
		result.winner = "opponent"
	left.free()
	right.free()
	return result

# ---------------------------------------------------------------- PHASE G

## THE CHARGE BAR -- the whole of lot 7, in one phase.
##
## Lots 3, 4, 5 and 6 each closed a different, measured cause of the same
## device report and none of them shifted it. The cause finally retained
## is that the player knew an attack was COMING and never knew WHEN it
## lands, so defending was a guess -- and a guess that fails is
## indistinguishable from a button that does nothing.
##
## The bar states the instant. What this phase gates is that the
## statement is TRUE, and it checks it on both halves separately, because
## they can fail independently:
##
##   1. the FSM number, tick by tick: charge_progress() is elapsed/total
##      through the wind-up and reaches 1.0 on the tick the strike
##      leaves. That is arithmetic and it is checked as arithmetic.
##   2. the DRAWN bar: the Fill mesh actually carries that fraction on
##      the frame the blow is thrown. A correct number rendered a frame
##      late would teach the wrong timing, which is why lot 7 reads it in
##      _process() instead of animating it with a tween.
##
## It also carries forward the two things lot 6's marker phase gated, on
## the geometry that replaced it: legibility against BOTH backdrops (the
## bar is engine-side, so no future .glb can weaken it), and the lot-2
## rule that this channel means an incoming attack and nothing else.
const CONTRAST_FLOOR := 3.0

func _phase_g_charge_bar() -> void:
	print("\n--- PHASE G: the charge bar completes exactly at impact ---")

	# --- 1. the number, on a bare fighter, tick by tick -----------------
	var solo := _make(DummyProfile)
	var struck := [-1]
	var ticks := [0]
	solo.strike_activated.connect(func() -> void: struck[0] = ticks[0])
	solo.request_action(BattleTypes.Action.ATTACK)
	_expect(solo.is_charging(), "an ATTACK wind-up reports itself as charging")
	_expect(is_equal_approx(solo.charge_progress(), 0.0), "and starts at an empty bar")

	var last_progress := 0.0
	var monotone := true
	var worst_error := 0.0
	var total: float = DummyProfile.attack_windup_s
	while struck[0] < 0 and ticks[0] < 600:
		# Counted BEFORE the step, so `ticks[0]` is the index of the tick
		# being executed and `struck[0]` is the tick the blow left on --
		# not the one before it. The strike fires from inside advance().
		ticks[0] += 1
		solo.advance(TICK_S)
		if not solo.is_charging():
			break
		var elapsed := float(ticks[0]) * TICK_S
		var progress := solo.charge_progress()
		worst_error = maxf(worst_error, absf(progress - elapsed / total))
		if progress < last_progress - 1e-6:
			monotone = false
		last_progress = progress
	print("  wind-up %.3fs = %d ticks; strike left on tick %d" % [total, int(round(total / TICK_S)), struck[0]])
	print("  worst |progress - elapsed/total| over the whole fill : %.6f" % worst_error)
	_expect(struck[0] > 0, "the strike really did leave")
	_expect(monotone, "the fill never goes backwards")
	_expect(worst_error < 1e-4, "the fill fraction IS elapsed/total, not an approximation of it")
	# The bar's promise, as a tick index. The strike leaves on the FIRST
	# tick of ACTIVE, i.e. the tick after the last charging one, so the
	# fill was within one tick of full when the blow was thrown -- which
	# is the tightest a 60 Hz clock can be.
	var last_charging_tick: int = struck[0] - 1
	var progress_at_release := float(last_charging_tick) * TICK_S / total
	print("  fill at the last charging tick : %.4f (one tick = %.4f of the bar)" % [
		progress_at_release, TICK_S / total])
	_expect(1.0 - progress_at_release <= TICK_S / total + 1e-6,
		"the bar is full to within ONE TICK when the strike leaves")
	_expect(not solo.is_charging(), "and stops charging the instant it does")
	_expect(is_equal_approx(solo.charge_progress(), 0.0), "charge_progress() is 0 outside a wind-up")
	# A dodge raises nothing: the bar is the attack channel and only that.
	solo.reset()
	solo.request_action(BattleTypes.Action.DODGE)
	_expect(not solo.is_charging(), "a DODGE wind-up is NOT a charge")
	solo.free()

	# --- 2. the drawn bar, in the shipped scene -------------------------
	var arena := BattleScene.instantiate()
	add_child(arena)
	await get_tree().process_frame
	# The arena starts a real round the moment it enters the tree, and its
	# brain drives the opponent every frame. Leaving it running would mean
	# this phase measured a fighter it does not control -- lot 6's version
	# of it did, and read a bar raised by the AI's own attack as one
	# raised by the action this loop had just asked for.
	arena.set_process(false)
	arena.set_physics_process(false)
	var world := arena.get_node("World") as Node3D
	var env := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var ground_material := (world.get_node("Ground") as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
	var sky: Color = env.background_color
	var ground: Color = ground_material.albedo_color

	var fighter := world.get_node("OpponentFighter") as Fighter
	var slot := fighter.get_node("Body") as ModelSlot
	var bar := slot.get_node_or_null("Charge") as Node3D
	_expect(bar != null, "the fighter scene carries a Body/Charge bar")
	if bar == null:
		arena.queue_free()
		return
	var fill := bar.get_node_or_null("Fill") as MeshInstance3D
	var track := bar.get_node_or_null("Track") as MeshInstance3D
	var cue := bar.get_node_or_null("Cue") as MeshInstance3D
	_expect(fill != null and track != null and cue != null, "with a Track, a Fill and an evade Cue")
	if fill == null or track == null or cue == null:
		arena.queue_free()
		return

	# Raise it once so FighterView resolves the bar and paints it. The
	# colours are FighterView constants and not authored in the .tscn, so
	# what is gated below is what gets drawn.
	fighter.request_action(BattleTypes.Action.ATTACK)
	fighter.advance(TICK_S)
	await _wait(0.05)
	var fill_colour := _bar_colour(fill)
	var track_colour := _bar_colour(track)
	var cue_colour := _bar_colour(cue)
	print("  fill %s, track %s, cue %s" % [fill_colour, track_colour, cue_colour])
	_expect(fill_colour.is_equal_approx(FighterView.CHARGE_FILL_COLOR),
		"the drawn fill carries FighterView.CHARGE_FILL_COLOR")
	_expect(track_colour.is_equal_approx(FighterView.CHARGE_TRACK_COLOR),
		"the drawn track carries FighterView.CHARGE_TRACK_COLOR")
	_expect(cue_colour.is_equal_approx(FighterView.CHARGE_CUE_COLOR),
		"the drawn evade band carries FighterView.CHARGE_CUE_COLOR")
	print("  drawn over sky %s and ground %s" % [sky, ground])
	for backdrop in [["sky", sky], ["ground", ground]]:
		var backdrop_name: String = backdrop[0]
		var behind: Color = backdrop[1]
		var best := maxf(_contrast(fill_colour, behind), _contrast(track_colour, behind))
		print("    vs %-6s : fill %.2f:1, track %.2f:1, best %.2f:1" % [
			backdrop_name, _contrast(fill_colour, behind), _contrast(track_colour, behind), best])
		_expect(best >= CONTRAST_FLOOR, "the bar clears %.1f:1 against the %s" % [CONTRAST_FLOOR, backdrop_name])
		# The evade band stands PROUD of the track, so unlike the fill it
		# is never seen against the bar -- it is always against one of
		# these two, and it has to clear on its OWN rather than being
		# carried by a neighbour.
		print("    vs %-6s : cue  %.2f:1" % [backdrop_name, _contrast(cue_colour, behind)])
		_expect(_contrast(cue_colour, behind) >= CONTRAST_FLOOR,
			"the evade band clears %.1f:1 against the %s on its own" % [CONTRAST_FLOOR, backdrop_name])
	# And the two halves have to be told apart from EACH OTHER, or the
	# bar is one solid block whose fill nobody can locate.
	print("    fill vs track : %.2f:1" % _contrast(fill_colour, track_colour))
	_expect(_contrast(fill_colour, track_colour) >= CONTRAST_FLOOR,
		"the fill is legible against its own track")

	# =================================================================
	# LOT 8: THE PLAYER HAS NO BAR AT ALL, AND THAT IS A GATE
	#
	# The bar was put on both fighters at lot 7 in the belief it helped
	# the player. It did the opposite: it imposed a timing on the
	# player's OWN attack, which is a thing they decide rather than a
	# thing they read. Lot 8 makes the player's attack instant, so there
	# is no wind-up to depict -- and the absence has to be checked, not
	# assumed, because a one-frame flash of a full bar is exactly what a
	# zero-length WINDUP would produce if FighterView keyed off the state
	# instead of the phase having a length.
	var player_fighter := world.get_node("PlayerFighter") as Fighter
	var player_slot := player_fighter.get_node("Body") as ModelSlot
	var player_bar := player_slot.get_node_or_null("Charge") as Node3D
	_expect(player_bar != null, "the player's fighter still carries the same scene geometry")
	if player_bar != null:
		player_fighter.reset()
		await _wait(FighterView.CHARGE_OFF_S + 0.06)
		var ever_shown := false
		player_fighter.request_action(BattleTypes.Action.ATTACK)
		for i in 8:
			player_fighter.advance(TICK_S)
			await get_tree().process_frame
			if player_bar.visible:
				ever_shown = true
		print("    player's bar during a full instant attack : %s" % [
			"SHOWN" if ever_shown else "never raised"])
		_expect(not ever_shown,
			"an instant attack never raises a bar, not even for one frame")
		# is_visible_in_tree(), not the local flag: the band is a child of
		# the bar, so what decides whether a pixel is drawn is the whole
		# chain. Asserting the local flag would fail on a band that is
		# hidden along with its parent -- correct behaviour reported as a
		# defect.
		var player_cue := player_bar.get_node_or_null("Cue") as MeshInstance3D
		_expect(player_cue == null or not player_cue.is_visible_in_tree(),
			"and no evade band is drawn on a fighter that never telegraphs")

	# The authored mesh width and the constant FighterView re-centres with
	# must agree, or the fill grows from the wrong place -- silently, and
	# only visibly at fractions nobody screenshots.
	var authored_width: float = (fill.mesh as BoxMesh).size.x
	print("    Fill mesh width %.3f, FighterView.CHARGE_WIDTH %.3f" % [authored_width, FighterView.CHARGE_WIDTH])
	_expect(is_equal_approx(authored_width, FighterView.CHARGE_WIDTH),
		"the scene's Fill width and the constant used to re-centre it are the same number")

	# Attack-only, driven through the real FSM rather than by calling the
	# view's helpers: the question is what a PLAYER sees during each
	# action, and only the state machine decides that.
	for entry in [["ATTACK", BattleTypes.Action.ATTACK, true], ["DODGE", BattleTypes.Action.DODGE, false]]:
		var tag: String = entry[0]
		var action: BattleTypes.Action = entry[1]
		var want: bool = entry[2]
		fighter.reset()
		await _wait(FighterView.CHARGE_OFF_S + 0.06)
		_expect(not bar.visible, "%s: precondition, the bar is down before the action" % tag)
		fighter.request_action(action)
		fighter.advance(TICK_S)
		await _wait(0.05)
		print("    %-6s wind-up -> bar %s (want %s)" % [
			tag, "SHOWN" if bar.visible else "hidden", "SHOWN" if want else "hidden"])
		_expect(bar.visible == want, "%s %s the bar" % [tag, "raises" if want else "does not raise"])

	# The drawn fill FOLLOWS the FSM, and is full on the frame the strike
	# leaves. This is half 2 of the contract, and it is the half a tween
	# would fail: the loop below yields a real frame per tick, so a
	# tween-driven bar would be running on engine time against an FSM on
	# fixed steps.
	fighter.reset()
	await _wait(FighterView.CHARGE_OFF_S + 0.06)
	var release_fill := [-1.0]
	var mid_fill := -1.0
	fighter.strike_activated.connect(func() -> void: release_fill[0] = -2.0)
	fighter.request_action(BattleTypes.Action.ATTACK)
	var frames := 0
	while fighter.state == BattleTypes.State.WINDUP and frames < 600:
		fighter.advance(TICK_S)
		frames += 1
		await get_tree().process_frame
		if release_fill[0] == -2.0:
			release_fill[0] = fill.scale.x
		elif absf(fighter.charge_progress() - 0.5) < 0.02:
			mid_fill = fill.scale.x
	print("    drawn fill at ~50%% of the wind-up : %.4f" % mid_fill)
	print("    drawn fill on the strike frame    : %.4f" % release_fill[0])
	_expect(mid_fill > 0.4 and mid_fill < 0.6, "the drawn fill tracks the wind-up rather than jumping")
	_expect(is_equal_approx(release_fill[0], 1.0), "and is exactly FULL on the frame the strike leaves")
	# Left-aligned: a fill at fraction f must have its left edge where an
	# empty one did, or the bar reads as a block growing outward from the
	# middle instead of as a bar filling up.
	var left_edge_full: float = fill.position.x - FighterView.CHARGE_WIDTH * 0.5 * fill.scale.x
	print("    left edge at full : %.4f (half-width %.3f)" % [left_edge_full, FighterView.CHARGE_WIDTH * 0.5])
	_expect(is_equal_approx(left_edge_full, -FighterView.CHARGE_WIDTH * 0.5),
		"the fill grows from the left edge of the track, not from its centre")

	# --- 3. the evade band marks the taps that actually work -----------
	#
	# The band is drawn from arithmetic in BattleArena. This checks it
	# against the MECHANIC instead: it taps a dodge at the band's two
	# edges and at its centre and asserts the blow is really evaded, and
	# taps outside both edges and asserts it is not. A band that merely
	# looked plausible would pass every assertion above this one.
	var lo: float = arena._evade_lo(fighter, arena.player)
	var hi: float = arena._evade_hi(fighter, arena.player)
	print("    evade band on the opponent's bar : %.3f .. %.3f of the fill" % [lo, hi])
	_expect(lo > 0.0 and hi > lo and hi < 1.0,
		"the band is a real span inside the bar, not the whole of it")
	print("    drawn band centre %.3f, span %.3f" % [
		cue.position.x / FighterView.CHARGE_WIDTH + 0.5, cue.scale.x])
	_expect(absf(cue.scale.x - (hi - lo)) < 1e-4, "the drawn band is exactly that span wide")
	_expect(absf((cue.position.x / FighterView.CHARGE_WIDTH + 0.5) - (lo + hi) * 0.5) < 1e-4,
		"and sits exactly where the span is")
	var w: float = DummyProfile.attack_windup_s
	# One tick inside each edge, because the FSM is quantised and the
	# arithmetic is not: the band's own boundary tick can fall either
	# side of a tick line.
	var margin := TICK_S / w
	for probe in [["just inside lo", lo + margin, true], ["centre", (lo + hi) * 0.5, true],
			["just inside hi", hi - margin, true],
			["well before lo", lo - 4.0 * margin, false],
			["after hi", hi + 3.0 * margin, false]]:
		var tag: String = probe[0]
		var at: float = probe[1]
		var want: bool = probe[2]
		var evaded := _dodge_at(at)
		print("    tap at %.3f of the bar (%-15s) -> %s (want %s)" % [
			at, tag, "EVADED" if evaded else "hit", "EVADED" if want else "hit"])
		_expect(evaded == want, "a dodge tapped %s %s" % [tag, "evades" if want else "does not evade"])

	# Placed from what the slot really draws, not from a per-profile
	# number -- so it is above the head of a 1.70 m owl and of a 1.35 m
	# squirrel with nothing in either .tres saying so.
	var head: float = slot.visual_aabb().end.y
	print("    slot head at local y %.3f, bar at %.3f" % [head, bar.position.y])
	_expect(bar.position.y > head, "the bar sits clear of the fighter it belongs to")
	var view := fighter.get_node("View") as FighterView
	if view != null:
		view.settle()
	arena.queue_free()
	await get_tree().process_frame

## Does a dodge tapped at `fraction` of the attacker's charge bar evade
## the blow? Run on real Fighters through the real resolution path, on
## bare instances rather than the arena's, so nothing the arena is doing
## can contribute.
func _dodge_at(fraction: float) -> bool:
	var attacker := _make(DummyProfile)
	var defender := _make(KeepyProfile)
	var outcome := [BattleTypes.Outcome.MISSED]
	attacker.strike_activated.connect(func() -> void:
		var rip := attacker.attack_is_riposte()
		outcome[0] = defender.receive_strike(attacker.profile.damage_for(rip), rip))
	attacker.request_action(BattleTypes.Action.ATTACK)
	var tapped := false
	var ticks := 0
	while attacker.state == BattleTypes.State.WINDUP and ticks < 400:
		if not tapped and attacker.charge_progress() >= fraction:
			tapped = true
			defender.request_action(BattleTypes.Action.DODGE)
		attacker.advance(TICK_S)
		defender.advance(TICK_S)
		ticks += 1
	if not tapped:
		defender.request_action(BattleTypes.Action.DODGE)
	attacker.advance(TICK_S)
	defender.advance(TICK_S)
	var evaded: bool = outcome[0] == BattleTypes.Outcome.DODGED
	attacker.free()
	defender.free()
	return evaded

func _bar_colour(mesh: MeshInstance3D) -> Color:
	var material := mesh.get_surface_override_material(0) as StandardMaterial3D
	return material.albedo_color if material else Color.MAGENTA

## WCAG relative luminance, the same maths every contrast probe in this
## project uses -- so a number printed here is comparable to one printed
## by DarkPaletteAudit rather than merely similar-looking.
func _relative_luminance(colour: Color) -> float:
	var channels := [colour.r, colour.g, colour.b]
	var linear: Array[float] = []
	for c in channels:
		var v: float = c
		linear.append(v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]

func _contrast(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

## The distance a fighter's drawn silhouette reaches toward its opponent,
## measured off a real instance of its own profile rather than assumed
## from the placeholder.
func _forward_reach(profile: FighterProfile) -> float:
	var fighter := _make(profile)
	var slot := fighter.get_node("Body") as ModelSlot
	var box := slot.visual_aabb()
	var reach := -INF
	for corner in 8:
		reach = maxf(reach, box.get_endpoint(corner).z)
	fighter.free()
	return reach

func _make(profile: FighterProfile) -> Fighter:
	var fighter := FighterScene.instantiate() as Fighter
	fighter.profile = profile
	add_child(fighter)
	return fighter

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

## How far the slot has moved AWAY from its opponent, in its own local
## space. Positive is backwards, which is the direction a windup coils in.
func _recoil(slot: ModelSlot, rest: Vector3) -> float:
	return rest.z - slot.position.z

func _tint(slot: ModelSlot) -> Color:
	var material := slot.slot_material() as StandardMaterial3D
	return material.albedo_color if material else Color.WHITE

func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("    OK    %s" % label)
		return
	_failures += 1
	printerr("    FAIL  %s" % label)
	print("    FAIL  %s" % label)
