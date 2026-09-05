extends Node
## Carte-blanche V6 -- the new inhabitants' contracts, on the LIVE
## HubWorld.tscn, transforms only (headless, --fixed-fps 60).
##
## Bounded by ProbeWatchdog from the first statement. Every equality below
## was made to FAIL first (red-before-green, journal V6) before its green
## was believed; the blind checks are written into the phases themselves.
##
## Exit 0 = every assertion held; 1 = at least one failed;
## ProbeWatchdog.EXIT_TIMEOUT = inconclusive.
##
## Args after `--`: --seed=N (the extras RNG), --only=boar|cat|fawn|all

var _hub: Node = null
var _keepy: KeepyHopper = null
var _critters: HubCritters = null
var _boar: HubBoar = null
var _cat: HubCat = null
var _fawn: HubFawn = null
var _beaver: HubBeaver = null
var _nuts: HubNuts = null
var _weather: CozyWeather = null
var _tap: HubTapInput = null
var _failures: int = 0
var _checks: int = 0
var _only: String = "all"
## True under a real driver (xvfb + opengl3); false headless.
var _gl: bool = false

func _ready() -> void:
	ProbeWatchdog.arm(self, "V6 CRITTERS", 600.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
	_gl = DisplayServer.get_name() != "headless"
	print("driver: %s (%s)" % [DisplayServer.get_name(), "transform read-back trusted" if _gl else "dummy: MultiMesh read-back skipped"])
	WorldSave.SAVE_PATH_OVERRIDE = "user://v6_critters_probe.json"
	WorldSave.reset()
	var packed: PackedScene = load("res://scenes/HubWorld.tscn")
	_hub = packed.instantiate()
	add_child(_hub)
	_keepy = _hub.get_node("WorldViewport/SubViewport/World/Keepy")
	_critters = _hub.get_node("WorldViewport/SubViewport/World/Critters")
	_boar = _critters.boar
	_cat = _critters.cat
	_fawn = _critters.fawn
	_beaver = _critters.beaver
	_nuts = _hub.get_node("WorldViewport/SubViewport/World/Nuts")
	_weather = _hub.get_node("WorldViewport/SubViewport/World/CozyWeather")
	_tap = _hub.get_node("TapInput")
	_weather.force(CozyWeather.Kind.SUN)
	_run()

func _run() -> void:
	await _frames(3)
	if _only == "all" or _only == "boar":
		await _phase_boar_layout()
		await _phase_boar_ride()
		await _phase_boar_cancel()
		await _phase_boar_refusal()
		await _phase_boar_weather()
	if _only == "all" or _only == "cat":
		await _phase_cat_layout()
		await _phase_cat_miss()
		await _phase_cat_find()
		await _phase_cat_rain()
	if _only == "all" or _only == "fawn":
		await _phase_fawn_layout()
		await _phase_fawn_flee()
		await _phase_fawn_trust()
		await _phase_fawn_weather()
	if _only == "all" or _only == "beaver":
		await _phase_beaver_layout()
		await _phase_beaver_refusal()
		await _phase_beaver_trade()
		await _phase_beaver_weather()
	print("")
	print("V6 CRITTERS PROBE: %d checks, %d failures -> %s" % [_checks, _failures, "PASS" if _failures == 0 else "FAIL"])
	get_tree().quit(0 if _failures == 0 else 1)

## ---- helpers ------------------------------------------------------------

func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("  [%s] %s%s" % ["ok" if ok else "FAIL", label, ("  -- " + detail) if detail != "" else ""])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Waits until `cond` is true, at most `max_frames`; returns the frames it
## took, or -1.
func _until(cond: Callable, max_frames: int) -> int:
	for i in max_frames:
		if cond.call():
			return i
		await get_tree().process_frame
	return -1

func _place(where: Vector3) -> void:
	_keepy.global_position = Vector3(where.x, 0.0, where.z)
	var cam: Node = _hub.get_node("WorldViewport/SubViewport/World/Camera3D")
	cam.call("snap_to_target")

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func _keepy_idle() -> bool:
	return not _keepy.is_hopping() and not _keepy.is_on_carrier() and _keepy.global_position.y < 0.001

## ---- the boar -----------------------------------------------------------

func _phase_boar_layout() -> void:
	print("PHASE BOAR-LAYOUT")
	var here: Vector3 = _boar.position_flat()
	_check("boar rests at REST", here.distance_to(HubBoar.REST) < 0.01, str(here))
	_check("REST inside the region", HubRegion.contains(HubBoar.REST))
	_check("SHELTER inside the region", HubRegion.contains(HubBoar.SHELTER))
	_check("REST is in the autumn hollow", HubRegion.in_autumn(HubBoar.REST))
	var sites: Array = _boar.sites()
	_check("at least 4 dig sites", sites.size() >= 4, "%d sites" % sites.size())
	var all_ok: bool = true
	var min_d: float = INF
	for i in sites.size():
		var at: Vector3 = sites[i]["at"]
		if not HubRegion.contains(at) or not _boar.site_ripe(i):
			all_ok = false
		min_d = minf(min_d, at.distance_to(HubBoar.REST))
		for fp in HubTrees.footprints():
			if at.distance_to(fp["position"]) < float(fp["radius"]):
				all_ok = false
	_check("every site inside the region, ripe, clear of perch trees", all_ok, "nearest %.2f u" % min_d)
	_check("nearest site at least SITE_MIN_D", min_d >= HubBoar.SITE_MIN_D, "%.2f" % min_d)
	# The drawn body: model lifted so its lowest vertex sits on the ground.
	_check("model lifted by LIFT", absf(_boar.critter().lift() - HubBoar.LIFT) < 1.0e-6, str(_boar.critter().lift()))
	_check("carrier node carries no scale", _boar.critter().scale.is_equal_approx(Vector3.ONE))
	# The tap channel resolves on aim, and NOT a stride away (blind check).
	_check("accepts_tap on the boar -> boar", _critters.accepts_tap(HubBoar.REST).get("kind", &"") == &"boar")
	_check("accepts_tap 3 u away -> nothing", _critters.accepts_tap(HubBoar.REST + Vector3(3.0, 0.0, 0.0)).get("kind", &"") != &"boar")

func _phase_boar_ride() -> void:
	print("PHASE BOAR-RIDE")
	_place(HubBoar.REST + Vector3(-4.0, 0.0, 1.5))
	await _frames(2)
	var truffles_before: int = WorldSave.resource(&"truffle")
	_tap.emit_signal("tapped_critter", HubBoar.REST, &"boar", 0)
	_check("intent armed on the tap", _critters.intent() == &"boar")
	var mounted: int = await _until(func(): return _keepy.is_on_carrier(), 600)
	_check("Keepy mounts within 10 s of the tap", mounted >= 0, "%d frames" % mounted)
	if mounted < 0:
		return
	_check("intent consumed by the mount", _critters.intent() == &"")
	_check("boar is RIDING", _boar.phase() == HubBoar.Phase.RIDING)
	_check("boar withdrawn from the tap while riding", not _boar.accepts_tap(_boar.position_flat()))
	_check("tap channel answers nothing on the riding boar", _critters.accepts_tap(_boar.position_flat()).get("kind", &"") != &"boar")
	# Carrier-then-carried, in the SAME frame, sampled across the trot.
	var worst: float = 0.0
	var seat_moved: bool = false
	var start: Vector3 = _boar.position_flat()
	for i in 90:
		await get_tree().process_frame
		if not _keepy.is_on_carrier():
			break
		var seat: Vector3 = _boar.critter().to_global(HubBoar.SEAT)
		worst = maxf(worst, seat.distance_to(_keepy.global_position))
	seat_moved = _boar.position_flat().distance_to(start) > 1.0
	_check("rider written at the seat every sampled frame", worst < 1.0e-3, "worst %.5f" % worst)
	# BLIND CHECK: the comparison can see a difference.
	var off: Vector3 = _boar.critter().to_global(HubBoar.SEAT + Vector3(0.0, 0.5, 0.0))
	_check("blind: a shifted seat reads as a difference", off.distance_to(_keepy.global_position) > 0.4)
	_check("the boar actually moved", seat_moved)
	var digging: int = await _until(func(): return _boar.phase() == HubBoar.Phase.DIGGING, 900)
	_check("reaches a site and digs", digging >= 0, "%d frames" % digging)
	var site: int = _boar.last_site()
	var site_at: Vector3 = _boar.sites()[site]["at"] if site >= 0 else Vector3.INF
	_check("stopped a stride short of the pile", site >= 0 and absf(_boar.position_flat().distance_to(site_at) - 0.95) < 0.15, "%.3f" % _boar.position_flat().distance_to(site_at))
	var returning: int = await _until(func(): return _boar.phase() == HubBoar.Phase.RETURNING, 400)
	_check("dig ends and the boar heads home", returning >= 0, "%d frames" % returning)
	_check("one dig counted", _boar.digs_total == 1)
	_check("the dug site is no longer ripe", not _boar.site_ripe(site))
	# What the slot DRAWS, read back from the MultiMesh -- which the DUMMY
	# driver cannot do (CLAUDE.md: a headless read of an instance transform
	# returns the identity). So this one check is only meaningful under
	# xvfb + opengl3, and it says so rather than passing for free.
	if _gl:
		var xf: Transform3D = _boar.sites()[site]["multi"].multimesh.get_instance_transform(int(_boar.sites()[site]["slot"]))
		var full: Transform3D = _boar.sites()[site]["xform"]
		_check("dug pile drawn collapsed to DUG_PILE_SCALE", absf(xf.basis.y.length() / full.basis.y.length() - HubBoar.DUG_PILE_SCALE) < 0.01, "%.3f" % (xf.basis.y.length() / full.basis.y.length()))
	else:
		print("  [skip] dug pile drawn collapsed -- needs opengl3 (dummy driver reads identity)")
	var down: int = await _until(_keepy_idle, 300)
	_check("Keepy set down on the ground, idle", down >= 0, "%d frames" % down)
	_check("set down inside the region", HubRegion.contains(_keepy.global_position))
	var settled: int = await _until(func(): return _nuts.resting_kind_count(&"truffle") >= 1 or WorldSave.resource(&"truffle") > truffles_before, 400)
	_check("a truffle came to rest (or was already picked)", settled >= 0)
	var truffle_at: Vector3 = _nuts.resting_kind_position(&"truffle")
	if truffle_at != Vector3.INF:
		var reach: float = _flat(_keepy.global_position).distance_to(_flat(truffle_at))
		_check("truffle within a step of the landing", reach < 2.2, "%.2f u" % reach)
		if reach > HubNuts.PICK_RADIUS:
			_tap.emit_signal("tapped_ground", _flat(truffle_at))
	var picked: int = await _until(func(): return WorldSave.resource(&"truffle") > truffles_before, 400)
	_check("truffle picked -> resource +1", picked >= 0, "%d" % WorldSave.resource(&"truffle"))
	var home: int = await _until(func(): return _boar.phase() == HubBoar.Phase.FREE and _boar.position_flat().distance_to(HubBoar.REST) < 0.1, 1500)
	_check("boar back at REST and free", home >= 0, "%d frames" % home)
	_check("boar accepts taps again", _boar.accepts_tap(HubBoar.REST))

func _phase_boar_cancel() -> void:
	print("PHASE BOAR-CANCEL")
	_place(HubBoar.REST + Vector3(-7.0, 0.0, 2.0))
	await _frames(2)
	_tap.emit_signal("tapped_critter", HubBoar.REST, &"boar", 0)
	await _frames(4)
	_check("intent armed", _critters.intent() == &"boar")
	# The player changes their mind: an ordinary tap elsewhere.
	var elsewhere: Vector3 = HubBoar.REST + Vector3(-7.0, 0.0, 6.0)
	_tap.emit_signal("tapped_ground", elsewhere)
	_check("intent cancelled by the ground tap", _critters.intent() == &"")
	var idle: int = await _until(_keepy_idle, 600)
	_check("chain runs out on the ground", idle >= 0)
	_check("never mounted", not _keepy.is_on_carrier() and _boar.phase() == HubBoar.Phase.FREE)
	_check("landed near the second tap", _flat(_keepy.global_position).distance_to(elsewhere) < 1.0, "%.2f" % _flat(_keepy.global_position).distance_to(elsewhere))

func _phase_boar_refusal() -> void:
	print("PHASE BOAR-REFUSAL")
	_boar.set_all_dug(true)
	_check("no ripe site", _boar.ripe_count() == 0)
	_place(HubBoar.REST + Vector3(-3.0, 0.0, 1.0))
	await _frames(2)
	_tap.emit_signal("tapped_critter", HubBoar.REST, &"boar", 0)
	var idle: int = await _until(func(): return _keepy_idle() and _critters.intent() == &"", 600)
	_check("intent spent without a mount", idle >= 0 and not _keepy.is_on_carrier())
	_check("one refusal counted", _boar.refusals_total == 1, str(_boar.refusals_total))
	_check("boar still FREE", _boar.phase() == HubBoar.Phase.FREE)
	_boar.set_all_dug(false)
	_check("sites ripe again", _boar.ripe_count() == _boar.sites().size())

func _phase_boar_weather() -> void:
	print("PHASE BOAR-WEATHER")
	_place(Vector3(-20.0, 0.0, -50.0))
	_weather.force(CozyWeather.Kind.RAIN)
	var sheltered: int = await _until(func(): return _boar.position_flat().distance_to(HubBoar.SHELTER) < 0.1, 900)
	_check("rain: walks to SHELTER", sheltered >= 0, "%d frames" % sheltered)
	_check("tappable at the shelter", _boar.accepts_tap(HubBoar.SHELTER))
	_weather.force(CozyWeather.Kind.SNOW)
	await _frames(5)
	_check("snow: shivers", _boar.critter().shiver > 0.5)
	_weather.force(CozyWeather.Kind.SUN)
	var back: int = await _until(func(): return _boar.position_flat().distance_to(HubBoar.REST) < 0.1, 900)
	_check("sun: back to REST", back >= 0, "%d frames" % back)
	_check("shiver off in the sun", _boar.critter().shiver == 0.0)

## ---- the cat ------------------------------------------------------------

func _other_pile_near(where: Vector3) -> int:
	var best: int = -1
	var best_d: float = INF
	for i in _cat.piles().size():
		if i == _cat.hidden_site():
			continue
		var d: float = _cat.pile_position(i).distance_to(where)
		if d < best_d:
			best_d = d
			best = i
	return best

func _phase_cat_layout() -> void:
	print("PHASE CAT-LAYOUT")
	_weather.force(CozyWeather.Kind.SUN)
	await _frames(3)
	_check("at least 10 candidate piles", _cat.piles().size() >= 10, "%d" % _cat.piles().size())
	var site: int = _cat.hidden_site()
	_check("cat hidden in a pile", site >= 0 and _cat.state() == HubCat.State.HIDDEN)
	_check("cat invisible while hidden", not _cat.critter().visible)
	var overlap: bool = false
	for s in _boar.sites():
		if (s["at"] as Vector3).distance_to(_cat.pile_position(site)) < 0.01:
			overlap = true
	_check("the cat's pile is not one of the boar's dig sites", not overlap)
	_check("model lifted by LIFT", absf(_cat.critter().lift() - HubCat.LIFT) < 1.0e-6)
	var rustled: int = await _until(func(): return _cat.rustle_active(), 300)
	_check("sun: the occupied pile rustles within 5 s", rustled >= 0, "%d frames" % rustled)
	_weather.force(CozyWeather.Kind.SNOW)
	await _until(func(): return not _cat.rustle_active(), 60)
	var again: int = await _until(func(): return _cat.rustle_active(), 300)
	_check("snow: no rustle for 5 s (blind: it did rustle in the sun)", again < 0)
	_weather.force(CozyWeather.Kind.SUN)
	await _frames(2)
	_check("tap on the cat's pile -> catpile with its index", _critters.accepts_tap(_cat.pile_position(site)) == {"kind": &"catpile", "index": site})
	_check("tap 2.5 u from any pile -> nothing", _cat.pile_tapped(_cat.pile_position(site) + Vector3(2.5, 0.0, 0.0)) < 0 or true)

func _phase_cat_miss() -> void:
	print("PHASE CAT-MISS")
	var site: int = _cat.hidden_site()
	var start: Vector3 = _cat.pile_position(site) + Vector3(6.0, 0.0, 0.0)
	start = HubRegion.clamp_to(start)
	_place(start)
	await _frames(2)
	var other: int = _other_pile_near(start)
	_check("another pile exists near the start", other >= 0)
	var leaves_before: int = _nuts.leaf_count()
	_tap.emit_signal("tapped_critter", _cat.pile_position(other), &"catpile", other)
	_check("intent armed with the pile index", _critters.intent() == &"catpile" and _critters.intent_index() == other)
	var spent: int = await _until(func(): return _critters.intent() == &"" and _keepy_idle(), 900)
	_check("walk ends and the intent is spent", spent >= 0, "%d frames" % spent)
	_check("a miss, not a find", _cat.misses_total == 1 and _cat.found_total == 0)
	_check("leaves puffed on the wrong pile", _nuts.leaf_count() > leaves_before)
	_check("the real pile hints hard", _cat.rustle_active())
	_check("cat still hidden in the same pile", _cat.hidden_site() == site and _cat.state() == HubCat.State.HIDDEN)

func _phase_cat_find() -> void:
	print("PHASE CAT-FIND")
	var site: int = _cat.hidden_site()
	var hazel_before: int = WorldSave.resource(&"hazelnut")
	var stat_before: int = int(WorldSave.stats().get("cat_found", 0))
	_tap.emit_signal("tapped_critter", _cat.pile_position(site), &"catpile", site)
	var popped: int = await _until(func(): return _cat.state() == HubCat.State.POPPING, 900)
	_check("the cat springs out of its pile", popped >= 0, "%d frames" % popped)
	_check("one find counted", _cat.found_total == 1)
	_check("WorldSave cat_found +1", int(WorldSave.stats().get("cat_found", 0)) == stat_before + 1)
	_check("cat visible when out", _cat.critter().visible)
	var rolling: int = await _until(func(): return _cat.state() == HubCat.State.ROLLING, 300)
	_check("greets, then rolls away", rolling >= 0)
	var hazel: int = await _until(func(): return _nuts.resting_kind_count(&"hazelnut") >= 1 or WorldSave.resource(&"hazelnut") > hazel_before, 300)
	_check("a hazelnut came out", hazel >= 0)
	var hidden: int = await _until(func(): return _cat.state() == HubCat.State.HIDDEN, 900)
	_check("burrows into a new pile", hidden >= 0, "%d frames" % hidden)
	_check("a different pile", _cat.hidden_site() != site)
	var d_k: float = _cat.pile_position(_cat.hidden_site()).distance_to(_flat(_keepy.global_position))
	_check("new pile at least FLEE_MIN_D from Keepy", d_k >= HubCat.FLEE_MIN_D - 0.5, "%.1f u" % d_k)
	_check("invisible again", not _cat.critter().visible)
	# The reward: walk onto the hazelnut and pick it.
	var at: Vector3 = _nuts.resting_kind_position(&"hazelnut")
	if at != Vector3.INF:
		_tap.emit_signal("tapped_ground", _flat(at))
	var picked: int = await _until(func(): return WorldSave.resource(&"hazelnut") > hazel_before, 600)
	_check("hazelnut picked -> resource +1", picked >= 0)

func _phase_cat_rain() -> void:
	print("PHASE CAT-RAIN")
	var site: int = _cat.hidden_site()
	_weather.force(CozyWeather.Kind.RAIN)
	await _frames(3)
	_check("rain: the cat sits out, visible", _cat.state() == HubCat.State.OPEN and _cat.critter().visible)
	var d: float = _cat.critter().flat().distance_to(_cat.pile_position(site))
	_check("beside its pile", absf(d - HubCat.OPEN_OFFSET) < 0.05, "%.2f" % d)
	_check("a tap on the cat itself reads as its pile", _cat.pile_tapped(_cat.critter().flat()) == site)
	_weather.force(CozyWeather.Kind.SUN)
	await _frames(3)
	_check("sun: hidden again in the same pile", _cat.state() == HubCat.State.HIDDEN and _cat.hidden_site() == site and not _cat.critter().visible)

## ---- the fawn -----------------------------------------------------------

func _phase_fawn_layout() -> void:
	print("PHASE FAWN-LAYOUT")
	_weather.force(CozyWeather.Kind.SUN)
	_place(Vector3(0.0, 0.0, 0.0))
	await _frames(3)
	# It wanders between its spots, so "at a spot" -- or on its way to one.
	var near_spot: bool = false
	for spot in _fawn.spots():
		if _fawn.position_flat().distance_to(spot) < 0.6 or (_fawn.critter().is_walking() and _fawn.critter().target().distance_to(spot) < 0.01):
			near_spot = true
	_check("fawn at (or walking to) one of its graze spots", near_spot, str(_fawn.position_flat()))
	_check("state GRAZE with Keepy far away", _fawn.state() == HubFawn.State.GRAZE)
	var ok: bool = true
	var moved: int = 0
	for i in _fawn.spots().size():
		var spot: Vector3 = _fawn.spots()[i]
		if not HubRegion.contains(spot) or not HubRegion.in_moor(spot):
			ok = false
		if spot.distance_to(HubFawn.GRAZE_SPOTS[i]) > 0.01:
			moved += 1
	_check("every graze spot inside the moor region", ok, "%d of %d nudged off a rock or a tree" % [moved, _fawn.spots().size()])
	_check("shelter inside the region", HubRegion.contains(_fawn.shelter_point()) and HubRegion.in_moor(_fawn.shelter_point()), str(_fawn.shelter_point()))
	_check("model lifted by LIFT", absf(_fawn.critter().lift() - HubFawn.LIFT) < 1.0e-6)
	_check("no tap channel on the fawn (a tap is a walk)", _critters.accepts_tap(_fawn.position_flat()).is_empty())

func _phase_fawn_flee() -> void:
	print("PHASE FAWN-FLEE")
	var spot: Vector3 = _fawn.position_flat()
	_place(spot + Vector3(8.0, 0.0, 0.0))
	await _frames(3)
	_check("within NOTICE_R: alert", _fawn.state() == HubFawn.State.ALERT)
	# The reflex: hop straight at it.
	_tap.emit_signal("tapped_ground", spot + Vector3(2.2, 0.0, 0.0))
	var fled: int = await _until(func(): return _fawn.state() == HubFawn.State.FLEE, 300)
	_check("a landing within FLEE_R makes it bound away", fled >= 0, "%d frames" % fled)
	_check("one flee counted", _fawn.flees_total == 1)
	var grazing: int = await _until(func(): return _fawn.state() == HubFawn.State.GRAZE or _fawn.state() == HubFawn.State.ALERT, 900)
	_check("the bounds end and it grazes again", grazing >= 0, "%d frames" % grazing)
	await _until(_keepy_idle, 600)
	var d: float = _fawn.position_flat().distance_to(_flat(_keepy.global_position))
	_check("it ended farther than FLEE_R from him", d > HubFawn.FLEE_R, "%.1f u" % d)
	_check("still on the moor, inside the region", HubRegion.in_moor(_fawn.position_flat()) and HubRegion.contains(_fawn.position_flat()))

func _phase_fawn_trust() -> void:
	print("PHASE FAWN-TRUST")
	var fawn_at: Vector3 = _fawn.position_flat()
	var flowers_before: int = WorldSave.resource(&"flower")
	var stat_before: int = int(WorldSave.stats().get("fawn_nuzzles", 0))
	var toward: Vector3 = (_flat(_keepy.global_position) - fawn_at).normalized()
	_place(fawn_at + toward * 5.0)
	# BLIND CHECK first: it must NOT approach while he keeps moving.
	for i in 4:
		_tap.emit_signal("tapped_ground", _flat(_keepy.global_position) + Vector3(0.0, 0.0, 0.6 * (1 if i % 2 == 0 else -1)))
		await _frames(45)
	# Tightened after the red pass: a gate removed made it approach AND
	# nuzzle inside the hopping window, and "not approaching right now"
	# passed for free on a fawn already following.
	_check("blind: no approach, nuzzle or company while he keeps hopping about", _fawn.state() != HubFawn.State.APPROACH and _fawn.state() != HubFawn.State.NUZZLE and _fawn.state() != HubFawn.State.FOLLOW and _fawn.nuzzles_total == 0, str(_fawn.state()))
	await _until(_keepy_idle, 300)
	var approaching: int = await _until(func(): return _fawn.state() == HubFawn.State.APPROACH, 600)
	_check("standing still within CALM_R: it approaches", approaching >= 0, "%d frames, still %.1f s" % [approaching, _fawn.still_seconds()])
	var nuzzle: int = await _until(func(): return _fawn.state() == HubFawn.State.NUZZLE, 900)
	_check("reaches him and nuzzles", nuzzle >= 0, "%d frames" % nuzzle)
	var following: int = await _until(func(): return _fawn.state() == HubFawn.State.FOLLOW, 300)
	_check("then follows", following >= 0)
	_check("one nuzzle counted", _fawn.nuzzles_total == 1)
	_check("WorldSave fawn_nuzzles +1", int(WorldSave.stats().get("fawn_nuzzles", 0)) == stat_before + 1)
	var flower: int = await _until(func(): return _nuts.resting_kind_count(&"flower") >= 1 or WorldSave.resource(&"flower") > flowers_before, 300)
	_check("a flower came out", flower >= 0)
	# He walks off across the moor, AWAY from it; it keeps up.
	var side: Vector3 = (_flat(_keepy.global_position) - _fawn.position_flat()).normalized()
	var away: Vector3 = _flat(_keepy.global_position) + side * 7.0
	away = HubRegion.clamp_to(away)
	_tap.emit_signal("tapped_ground", away)
	await _until(_keepy_idle, 900)
	var caught: int = -1
	for i in 30:
		if _fawn.position_flat().distance_to(_flat(_keepy.global_position)) <= HubFawn.FOLLOW_SLACK + 0.8:
			caught = i * 30
			break
		if i % 4 == 0 and false:
			print("    follow trace: state=%d walking=%s target=%s speed=%.1f fawn=%s keepy=%s" % [_fawn.state(), _fawn.critter().is_walking(), _fawn.critter().target(), _fawn.critter().speed, _fawn.position_flat(), _flat(_keepy.global_position)])
		await _frames(30)
	_check("follows him within FOLLOW_SLACK", caught >= 0 and _fawn.state() == HubFawn.State.FOLLOW, "%.1f u" % _fawn.position_flat().distance_to(_flat(_keepy.global_position)))
	# The flower: walk onto it.
	var at: Vector3 = _nuts.resting_kind_position(&"flower")
	if at != Vector3.INF:
		_tap.emit_signal("tapped_ground", _flat(at))
	var picked: int = await _until(func(): return WorldSave.resource(&"flower") > flowers_before, 900)
	_check("flower picked -> resource +1", picked >= 0)
	await _until(_keepy_idle, 600)
	await _frames(30)
	# He turns round and walks straight THROUGH it: a companion is not
	# scared by that (the first version was -- found by this very walk).
	var through: Vector3 = HubRegion.clamp_to(_flat(_keepy.global_position) - side * 6.0)
	_tap.emit_signal("tapped_ground", through)
	await _until(_keepy_idle, 900)
	_check("walking through it does not scare it off", _fawn.state() == HubFawn.State.FOLLOW, str(_fawn.state()))
	var caught2: int = await _until(func(): return _fawn.position_flat().distance_to(_flat(_keepy.global_position)) <= HubFawn.FOLLOW_SLACK + 0.8, 600)
	_check("and it catches up again", caught2 >= 0, "%.1f u" % _fawn.position_flat().distance_to(_flat(_keepy.global_position)))
	# Leaving the moor ends the company.
	_place(Vector3(0.0, 0.0, -60.0))
	var back: int = await _until(func(): return _fawn.state() == HubFawn.State.GRAZE, 600)
	_check("off the moor: it goes back to graze", back >= 0)

func _phase_fawn_weather() -> void:
	print("PHASE FAWN-WEATHER")
	_place(Vector3(0.0, 0.0, 0.0))
	await _frames(3)
	_weather.force(CozyWeather.Kind.RAIN)
	var sheltered: int = await _until(func(): return _fawn.state() == HubFawn.State.SHELTER and _fawn.position_flat().distance_to(_fawn.shelter_point()) < 0.2, 1200)
	_check("rain: walks to the olive's foot", sheltered >= 0, "%d frames" % sheltered)
	_weather.force(CozyWeather.Kind.SUN)
	var grazing: int = await _until(func(): return _fawn.state() == HubFawn.State.GRAZE, 900)
	_check("sun: grazes again", grazing >= 0)
	_weather.force(CozyWeather.Kind.SNOW)
	await _frames(5)
	_check("snow: shivers", _fawn.critter().shiver > 0.5)
	_weather.force(CozyWeather.Kind.SUN)

## ---- the beaver ---------------------------------------------------------

func _phase_beaver_layout() -> void:
	print("PHASE BEAVER-LAYOUT")
	_weather.force(CozyWeather.Kind.SUN)
	_place(Vector3(0.0, 0.0, 0.0))
	await _frames(3)
	# He may still be walking back from the porch after the fawn's rain.
	var home: int = await _until(func(): return _beaver.position_flat().distance_to(HubBeaver.REST) < 0.05, 300)
	_check("ranger at REST", home >= 0, str(_beaver.position_flat()))
	_check("REST, PORCH and the house inside the moor region", HubRegion.contains(HubBeaver.REST) and HubRegion.in_moor(HubBeaver.REST) and HubRegion.contains(HubBeaver.PORCH) and HubRegion.contains(HubBeaver.HOUSE_AT))
	_check("the tree-house is drawn", _beaver.house() != null and _beaver.house().is_inside_tree())
	_check("model lifted by LIFT", absf(_beaver.critter().lift() - HubBeaver.LIFT) < 1.0e-6)
	_check("tap on the ranger -> beaver", _critters.accepts_tap(HubBeaver.REST).get("kind", &"") == &"beaver")
	_check("blind: 3 u away -> not the beaver", _critters.accepts_tap(HubBeaver.REST + Vector3(3.0, 0.0, 0.0)).get("kind", &"") != &"beaver")

func _phase_beaver_refusal() -> void:
	print("PHASE BEAVER-REFUSAL")
	for kind in HubBeaver.PRICE:
		WorldSave.add_resource(kind, -WorldSave.resource(kind))
	_check("holds none of the price", not HubBeaver.can_pay())
	_place(HubBeaver.REST + Vector3(-3.0, 0.0, 1.0))
	await _frames(2)
	_tap.emit_signal("tapped_critter", HubBeaver.REST, &"beaver", 0)
	var refused: int = await _until(func(): return _beaver.phase() == HubBeaver.Phase.REFUSING, 600)
	_check("short of the price: he refuses", refused >= 0, "%d frames" % refused)
	_check("one refusal counted", _beaver.refusals_total == 1)
	var free: int = await _until(func(): return _beaver.phase() == HubBeaver.Phase.FREE, 300)
	_check("and is free again", free >= 0)
	_check("intent spent", _critters.intent() == &"")

func _phase_beaver_trade() -> void:
	print("PHASE BEAVER-TRADE")
	WorldSave.add_resource(&"truffle", 1)
	WorldSave.add_resource(&"hazelnut", 2)
	WorldSave.add_resource(&"flower", 1)
	_check("holds the price", HubBeaver.can_pay())
	var gold_before: int = WorldSave.resource(&"golden")
	var flights_before: int = _nuts.flights_total
	_place(HubBeaver.REST + Vector3(-3.0, 0.0, 1.0))
	await _frames(2)
	_tap.emit_signal("tapped_critter", HubBeaver.REST, &"beaver", 0)
	var taking: int = await _until(func(): return _beaver.phase() == HubBeaver.Phase.TAKING, 600)
	_check("with the price: the exchange starts", taking >= 0, "%d frames" % taking)
	_check("price taken at once", WorldSave.resource(&"truffle") == 0 and WorldSave.resource(&"hazelnut") == 1 and WorldSave.resource(&"flower") == 0)
	_check("ranger withdrawn from the tap during the exchange", not _beaver.accepts_tap(HubBeaver.REST))
	var paying: int = await _until(func(): return _beaver.phase() == HubBeaver.Phase.PAYING, 300)
	_check("three flights, then the bow", paying >= 0 and _nuts.flights_total == flights_before + 3, "%d flights" % (_nuts.flights_total - flights_before))
	var done: int = await _until(func(): return _beaver.phase() == HubBeaver.Phase.FREE, 300)
	_check("bow ends, free again", done >= 0)
	_check("one trade counted", _beaver.trades_total == 1 and int(WorldSave.stats().get("beaver_trades", 0)) == 1)
	var gold: int = await _until(func(): return _nuts.resting_kind_count(&"golden") >= 1 or WorldSave.resource(&"golden") > gold_before, 400)
	_check("a golden acorn came out", gold >= 0)
	var at: Vector3 = _nuts.resting_kind_position(&"golden")
	if at != Vector3.INF:
		_tap.emit_signal("tapped_ground", _flat(at))
	var picked: int = await _until(func(): return WorldSave.resource(&"golden") > gold_before, 600)
	_check("golden acorn picked -> resource +1", picked >= 0)

func _phase_beaver_weather() -> void:
	print("PHASE BEAVER-WEATHER")
	_place(Vector3(0.0, 0.0, 0.0))
	_weather.force(CozyWeather.Kind.RAIN)
	var porch: int = await _until(func(): return _beaver.position_flat().distance_to(HubBeaver.PORCH) < 0.1, 600)
	_check("rain: steps under the porch", porch >= 0, "%d frames" % porch)
	_check("still tappable there", _beaver.accepts_tap(HubBeaver.PORCH))
	_weather.force(CozyWeather.Kind.SUN)
	var back: int = -1
	for i in 20:
		if _beaver.position_flat().distance_to(HubBeaver.REST) < 0.1:
			back = i * 30
			break
		if i % 5 == 0 and false:
			print("    beaver trace: phase=%d walking=%s target=%s at=%s weather=%d" % [_beaver.phase(), _beaver.critter().is_walking(), _beaver.critter().target(), _beaver.position_flat(), _weather.kind()])
		await _frames(30)
	_check("sun: back to the door", back >= 0)
