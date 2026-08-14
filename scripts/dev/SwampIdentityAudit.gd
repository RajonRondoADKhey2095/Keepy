extends Node
## GATED probe for the PERMANENT swamp art direction -- NOT part of the
## shipped game (nothing instantiates it; scripts/dev/* is excluded from the
## web export). Must run with a REAL GL context, since the whole point is to
## look at pixels the Compatibility renderer this project pins actually
## produced:
##
##   xvfb-run -a godot4 --rendering-driver opengl3 --fixed-fps 60 \
##     --path . res://scripts/dev/SwampIdentityAudit.tscn
##
## ⚠️ DO NOT ADD --headless. It forces the DUMMY rendering driver, which
## overrides --rendering-driver silently: get_image() then returns a blank
## surface, every sample reads (0,0,0), every contrast ratio computes to
## 1.00:1 and the probe still EXITS 0. That is a faux vert, and it was hit
## for real while writing this batch -- the same class of invocation trap as
## the flag-order one ProbeWatchdog warns about, on a different flag.
##
## =====================================================================
## WHAT IT REPLACES: SwampGradeCapture.gd
##
## That probe asserted four properties of the full-screen grade -- that it
## fired, landed green, darkened the frame, and faded monotonically. The
## permanent-swamp batch deleted the grade, so all four questions expired
## at once, exactly the way SwampGradeCapture's own header records
## InvertCapture's premise expiring one layer earlier. It is replaced
## rather than patched, for the reason that header gives: a file named
## after a mechanism it no longer measures is the same trap one step along.
##
## =====================================================================
## WHAT IT ASSERTS NOW
##
## The acceptance criterion the art direction was actually briefed with:
## THERE IS NO STATE OF THIS GAME THAT SHOWS A BLUE SKY OR A PASTEL TRACK.
## Not "after 18 seconds", not "once the cycle starts" -- none, ever. That
## used to be a thing a person had to check by looking at a phone, and it
## is the single property most likely to regress silently, because the
## daylight look was not deleted by editing one file: it was spread across
## an Environment, a light, a ground albedo, six prop constants and three
## billboard tints, and any one of them reverting would go unnoticed by
## every other probe in scripts/dev.
##
## Four states are sampled, chosen to cover every distinct thing a screen
## capture could catch:
##
##   TITLE          the very first frame a player ever sees
##   RUN OPENING    PLAYING at mist_intensity 0 -- what the first ~18s show
##   RUN DEEP MIST  PLAYING at mist_intensity 1 -- the other end of the breath
##   GAME OVER      the run-ended screen, over a live world
##
## ⚠️ scenes/TitleScreen.tscn ITSELF IS NOT ONE OF THE FOUR, DELIBERATELY --
## see CLAUDE.md, "Écran-titre : couverture graphique dédiée, hors périmètre
## SwampIdentityAudit". A dedicated cover illustration was installed there
## (14 août 2026): it is not swamp-green by design, so asserting green
## dominance / saturation / darkness against it would be gating the wrong
## thing on purpose. "WORLD AT TITLE" below still covers the 3D world
## rendered BEHIND the title screen at GameState.State.TITLE, which is the
## surface this probe's brief actually concerns -- only the standalone
## TitleScreen.tscn overlay is out of scope now.
##
## and in each one, three assertions on the mean frame colour:
##
##   1. GREEN DOMINANT. g > r and g > b. This is the one that catches a
##      blue sky coming back, and it is the direct expression of the
##      brief. Cheap, and it is precisely the check whose absence meant
##      two dark-mode hues shipped blue and only a device playtest noticed.
##
##   2. NOT A PASTEL. Saturation of the mean frame colour must clear a
##      floor. A washed-out frame can still be green-dominant -- daylight
##      blue graded halfway to olive is -- so dominance alone does not
##      express "not pastel". Mean saturation does.
##
##   3. DARK. Mean luma under a ceiling. A swamp night that renders as
##      bright as the daylight scene it replaced is a contradiction, and
##      mean luma is the cheapest statement of it.
##
## Deliberately measured on the MEAN of the whole frame, not on regions:
## this probe answers "is the picture the right picture", full stop.
## Whether any individual object reads against any other is a different
## question with a different metric, and it belongs to DarkPaletteAudit
## (hazards, collectibles) and PursuerContrastAudit (silhouette). Nothing
## here should ever grow a per-object assertion.
##
## WHY GATED rather than reporting: every other art-direction property in
## this project is carried by a colour constant that a future session could
## plausibly retune with good reason. This one is not a tuning knob, it is
## the brief. A batch that turns the sky blue again should fail, loudly, in
## CI, without anyone having to open a screenshot.

const SETTLE_FRAMES: int = 20

## Mean-frame-colour floors and ceilings. Deliberately LOOSE: they are
## drawn where "this is a swamp" stops being true, not around the values
## this batch happens to produce. A tight bound here would fail on any
## honest future retune of the palette and teach the next session to edit
## the probe, which is how a gate stops meaning anything.
##
## The headroom is real and measured -- see the batch report for the four
## states' actual numbers against these bounds.
const MAX_MEAN_LUMA: float = 0.42
const MIN_MEAN_SATURATION: float = 0.14

var _game: Node = null
var _rows: Array[Dictionary] = []

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- a watchdog
	# armed after the hang is no watchdog. See ProbeWatchdog.gd.
	ProbeWatchdog.arm(self, "SwampIdentityAudit")
	_run.call_deferred()

func _run() -> void:
	print("=== SWAMP IDENTITY AUDIT (permanent art direction) ===")
	print("asserts: the frame is green-dominant, saturated and dark in EVERY game state")
	print("bounds : mean luma <= %.2f, mean saturation >= %.2f" % [MAX_MEAN_LUMA, MIN_MEAN_SATURATION])
	print("")

	_game = load("res://scenes/Game.tscn").instantiate()
	add_child(_game)
	await _wait_frames(SETTLE_FRAMES)

	# WORLD AT TITLE first, and without touching anything: this is literally
	# the state the scene loads in, so measuring it before any probe-side
	# poking is what makes it a statement about the shipped first frame.
	GameState.state = GameState.State.TITLE
	await _freeze_and_settle()
	_record("WORLD AT TITLE")

	# scenes/TitleScreen.tscn is intentionally NOT sampled here -- it now
	# carries a dedicated cover illustration (14 août 2026) rather than the
	# swamp palette, an explicit exception documented in CLAUDE.md. Sampling
	# it against MAX_MEAN_LUMA / MIN_MEAN_SATURATION would fail a screen
	# that was never meant to look like the rest of the game.

	await _settle_playing_at(0.0)
	_record("RUN OPENING (mist 0.00)")

	await _settle_playing_at(1.0)
	_record("RUN DEEP MIST (mist 1.00)")

	GameState.state = GameState.State.GAME_OVER
	await _freeze_and_settle()
	_record("GAME OVER")

	var ok := true
	for row in _rows:
		var mean: Vector3 = row["mean"]
		if not bool(row["green"]) or not bool(row["dark"]) or not bool(row["saturated"]):
			ok = false
		print("%-24s rgb=(%.4f, %.4f, %.4f)  luma %.4f  sat %.4f   green %s / dark %s / saturated %s" % [
			row["label"], mean.x, mean.y, mean.z, row["luma"], row["sat"],
			"OK" if row["green"] else "FAIL",
			"OK" if row["dark"] else "FAIL",
			"OK" if row["saturated"] else "FAIL",
		])

	print("")
	print("SWAMP_IDENTITY_VERIFIED=" + ("yes" if ok else "NO"))
	if not ok:
		push_error("SWAMP IDENTITY AUDIT FAILED: at least one game state does not render as a dark, saturated, green-dominant swamp. A blue or pastel frame is a hard failure of the art direction, not a tuning miss.")
		get_tree().quit(1)
		return
	get_tree().quit()

func _record(label: String) -> void:
	var mean := _sample()
	var luma := _luma(mean)
	var sat := _saturation(mean)
	_rows.append({
		"label": label,
		"mean": mean,
		"luma": luma,
		"sat": sat,
		"green": mean.y > mean.x and mean.y > mean.z,
		"dark": luma <= MAX_MEAN_LUMA,
		"saturated": sat >= MIN_MEAN_SATURATION,
	})

## Holds the world still, then lets a few frames render.
##
## THE WORLD MUST BE HELD STILL, and this is a correction inherited from
## SwampGradeCapture rather than a tidy-up. Left running, the track
## scrolls, Keepy meets a hazard, and HUD.gd's full-screen strike flash
## lands over the frame -- so the mean pixel stops being "the world" and
## becomes "the world plus a red flash caught at some arbitrary point in
## its decay". Measured on the predecessor probe, not theorised: with the
## run live its day sample came back bright orange (0.84, 0.50, 0.41)
## instead of the sky that was actually there. Same defect
## docs/PROBE_AUDIT.md records as F10c for the strike-contrast probes.
func _freeze_and_settle() -> void:
	GameState.current_speed = 0.0
	GameState.pursuer_enabled = false
	await _wait_frames(SETTLE_FRAMES)

## Pins the mist breath at a chosen intensity and HOLDS it there.
##
## Writing GameState.mist_intensity once is NOT enough, and the predecessor
## probe got that wrong in a way worth carrying forward: while the run is
## PLAYING, GameState._update_mist_cycle move_toward()s the intensity every
## frame toward whatever the current mist_phase implies, so a one-shot
## write decays back over the settle frames and the probe samples a
## half-faded frame while reporting it as an end state. Matching the PHASE
## to the intensity makes GameState's own move_toward hold the value
## instead of fighting it, and pushing the phase start to INF stops the
## cycle flipping mid-measurement.
func _settle_playing_at(intensity: float) -> void:
	GameState.state = GameState.State.PLAYING
	GameState.current_speed = 0.0
	GameState.pursuer_enabled = false
	GameState.mist_phase = GameState.MistPhase.DEEP if intensity > 0.5 else GameState.MistPhase.SHALLOW
	GameState.set("_mist_phase_started_s", INF)
	for i in SETTLE_FRAMES:
		# Re-pinned EVERY frame, not once: _update_mist_cycle runs on the
		# same frames this loop does.
		GameState.mist_intensity = intensity
		await get_tree().process_frame
	GameState.mist_intensity = intensity

func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _luma(c: Vector3) -> float:
	return 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z

## Ordinary HSV saturation of the mean colour: (max - min) / max. Zero for
## any grey, and low for exactly the washed-out pastels this batch removed.
func _saturation(c: Vector3) -> float:
	var hi: float = maxf(c.x, maxf(c.y, c.z))
	var lo: float = minf(c.x, minf(c.y, c.z))
	if hi <= 0.0001:
		return 0.0
	return (hi - lo) / hi

func _sample() -> Vector3:
	var img: Image = get_viewport().get_texture().get_image()
	var acc := Vector3.ZERO
	var samples := 0
	# Coarse grid over the whole frame rather than every pixel.
	var step := 16
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			acc += Vector3(c.r, c.g, c.b)
			samples += 1
	return acc / float(samples)
