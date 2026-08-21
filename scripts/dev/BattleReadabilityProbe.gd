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
##   PHASE D  attack, guard and dodge do not look alike
##   PHASE E  an interrupted animation is replaced, never stacked
##   PHASE F  the two HUD contradictions the captures showed
##   PHASE G  the attack marker: legible against BOTH backgrounds, and
##            shown for attacks and nothing else (lot 6)
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
	await _phase_g_marker()
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
func _phase_c_telegraph() -> void:
	print("\n--- PHASE C: the attack telegraph is visible and grows ---")
	var fighter := _make(KeepyProfile)
	var slot := fighter.get_node("Body") as ModelSlot
	var rest := slot.position
	var windup: float = KeepyProfile.attack_windup_s

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
		early_tint.g, late_tint.g, KeepyProfile.placeholder_color.g, FighterView.ALERT_COLOR.g])
	_expect(early_tint != Color.WHITE, "the view took ownership of a material to tint")
	_expect(late_tint.g < early_tint.g, "the danger colour ramps progressively, not as a flash")
	fighter.free()

# ---------------------------------------------------------------- PHASE D

## Three actions, three silhouettes. A guard that looked like an attack
## would be worse than no animation at all: it would actively mislead.
func _phase_d_silhouettes() -> void:
	print("\n--- PHASE D: attack, guard and dodge do not look alike ---")
	var poses := {}
	for entry in [
		["ATTACK", BattleTypes.Action.ATTACK],
		["GUARD", BattleTypes.Action.GUARD],
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
	_expect(poses["GUARD"]["height"] < 0.98, "GUARD braces low instead of moving in")
	_expect(poses["ATTACK"]["forward"] > poses["GUARD"]["forward"], "ATTACK and GUARD are not the same pose")
	_expect(poses["GUARD"]["forward"] > poses["DODGE"]["forward"], "GUARD and DODGE are not the same pose")

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
	fighter.receive_strike(KeepyProfile.max_hp)
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
	left.strike_activated.connect(func() -> void: right.receive_strike(left.profile.attack_damage))
	right.strike_activated.connect(func() -> void: left.receive_strike(right.profile.attack_damage))

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

## The engine-side attack marker, added at lot 6 because the tint alone
## stopped being able to carry the telegraph once real .glb art landed.
## Measured on the shipped Battle scene, rest vs fully-alarmed, averaged
## over the fighter's own pixels: the player's squirrel is BETTER off than
## the capsule it replaced (2.21:1 against 1.63:1 in luminance), but the
## opponent's owl loses the channel that carried most of the old cue --
## its hue swing falls from 159.6 degrees to 10.2, because a blue capsule
## turning red is a near-complementary flip and a brown owl turning red is
## barely a hue change at all. The opponent is the fighter a player
## actually reads. Full table in FighterView's header.
##
## What this phase gates is the property that makes the marker worth
## having: its legibility is a fact about GEOMETRY AND COLOURS THIS
## PROJECT OWNS, so it cannot be weakened by a future asset the way the
## tint was. Two prisms, bright core inside a near-black outline, and the
## assertion is that at least one of the two clears 3.0:1 against each of
## the two things it can be drawn over -- the dark sky above the arena and
## the lit ground below it. Neither colour has to beat both; between them
## they must leave no background that swallows the marker.
##
## And it gates the lot-2 rule the marker could most easily have broken:
## it is shown for an attack telegraph and for nothing else. A marker over
## a guard would make the colour channel mean two things again.
const CONTRAST_FLOOR := 3.0

func _phase_g_marker() -> void:
	print("\n--- PHASE G: the attack marker is asset-independent and attack-only ---")
	var arena := BattleScene.instantiate()
	add_child(arena)
	await get_tree().process_frame
	# The arena starts a real round the moment it enters the tree, and its
	# brain drives the opponent every frame. Leaving it running would mean
	# this phase measured a fighter it does not control -- the first
	# version of it did, and read a marker raised by the AI's own attack
	# as one raised by the guard this loop had just asked for.
	arena.set_process(false)
	arena.set_physics_process(false)
	var world := arena.get_node("World") as Node3D
	var env := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var ground_material := (world.get_node("Ground") as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
	var sky: Color = env.background_color
	var ground: Color = ground_material.albedo_color

	var fighter := world.get_node("OpponentFighter") as Fighter
	var slot := fighter.get_node("Body") as ModelSlot
	var alert := slot.get_node_or_null("Alert") as Node3D
	_expect(alert != null, "the fighter scene carries a Body/Alert marker")
	if alert == null:
		arena.queue_free()
		return

	var core := _marker_colour(alert, "Core")
	var outline := _marker_colour(alert, "Outline")
	print("  marker core %s, outline %s" % [core, outline])
	print("  drawn over sky %s and ground %s" % [sky, ground])
	for backdrop in [["sky", sky], ["ground", ground]]:
		var name: String = backdrop[0]
		var behind: Color = backdrop[1]
		var best := maxf(_contrast(core, behind), _contrast(outline, behind))
		print("    vs %-6s : core %.2f:1, outline %.2f:1, best %.2f:1" % [
			name, _contrast(core, behind), _contrast(outline, behind), best])
		_expect(best >= CONTRAST_FLOOR, "the marker clears %.1f:1 against the %s" % [CONTRAST_FLOOR, name])

	# Attack-only, driven through the real FSM rather than by calling the
	# view's helpers: the question is what a PLAYER sees during each
	# action, and only the state machine decides that.
	var view := fighter.get_node("View") as FighterView
	var cases := {"ATTACK": BattleTypes.Action.ATTACK, "FEINT": BattleTypes.Action.FEINT,
		"GUARD": BattleTypes.Action.GUARD, "DODGE": BattleTypes.Action.DODGE}
	for tag in cases:
		var action: BattleTypes.Action = cases[tag]
		# Back to a PROVEN-clean marker first. Without this the loop would
		# be reading the previous case's marker still retracting -- the
		# fade is deliberately not instant -- and a guard would look like
		# it had raised one. Asserting the clean state instead of merely
		# waiting for it also gates the other half of the contract: the
		# marker really does come back down.
		fighter.reset()
		await _wait(FighterView.ALERT_OFF_S + 0.06)
		_expect(not alert.visible, "%s: precondition, the marker is down before the action" % tag)
		fighter.request_action(action)
		fighter.advance(TICK_S)
		await _wait(0.05)
		var shown: bool = alert.visible and alert.scale.x > 0.01
		var want := BattleTypes.is_attack_like(action)
		print("    %-6s windup -> marker %s (want %s)" % [
			tag, "SHOWN" if shown else "hidden", "SHOWN" if want else "hidden"])
		_expect(shown == want, "%s %s the marker" % [tag, "raises" if want else "does not raise"])

	# It has to grow, for the same reason the tint ramps: the size IS the
	# clock. A marker that appears at full size says "an attack" and not
	# "an attack, this soon".
	fighter.reset()
	await _wait(0.05)
	fighter.request_action(BattleTypes.Action.ATTACK)
	fighter.advance(TICK_S)
	await _wait(0.02)
	var early: float = alert.scale.x
	await _wait(fighter.telegraph_duration() * 0.7)
	var late: float = alert.scale.x
	print("    marker scale %.3f early -> %.3f late" % [early, late])
	_expect(late > early + 0.1, "the marker GROWS over the telegraph rather than popping")

	# Placed from what the slot really draws, not from a per-profile
	# number -- so it is above the head of a 1.70 m owl and of a 1.35 m
	# squirrel with nothing in either .tres saying so.
	var head: float = slot.visual_aabb().end.y
	print("    slot head at local y %.3f, marker at %.3f" % [head, alert.position.y])
	_expect(alert.position.y > head, "the marker sits clear of the fighter it belongs to")
	if view != null:
		view.settle()
	arena.queue_free()
	await get_tree().process_frame

func _marker_colour(alert: Node3D, child: String) -> Color:
	var mesh := alert.get_node_or_null(child) as MeshInstance3D
	if mesh == null:
		return Color.MAGENTA
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
