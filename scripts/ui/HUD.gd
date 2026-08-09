extends CanvasLayer
class_name HUD
## In-run score + collectible counters + combo display. Purely reactive to
## GameState signals -- holds no gameplay logic of its own, and in
## particular owns NO part of the combo rules (when it increments, when it
## lapses and what multiplier it buys all live in GameState; this file only
## draws them).
##
## =====================================================================
## COMBO FEEDBACK -- three DISTINCT reactions, deliberately escalating,
## because they answer three different questions for the player:
##
##   INCREMENT  "that counted"        -- a short scale pop on the row.
##   TIER-UP    "that changed things" -- a much bigger, longer pop on the
##                                      multiplier, which is also the
##                                      moment it appears at all.
##   EXPIRING   "you are about to     -- a sustained pulse over the last
##               lose this"             COMBO_WARNING_S.
##
## The third one is the mechanic, not the polish. A chain that vanished
## silently would teach the player nothing: they would see a number, then
## no number, with no instant in between at which they could have acted.
## The pulse is the game asking "go find some danger or let this go", and
## it is the only part of the loop that can push a cautious player TOWARD a
## hazard. It is sized accordingly -- it is the loudest thing on the HUD.
##
## VOCABULARY REUSED, NOT INVENTED: the pop is the same triangular envelope
## (linear rise to a peak at the midpoint, linear fall back to 1.0) as the
## jump-marker pop the previous batch shipped and playtested -- see
## Obstacle._update_marker_pop / MARKER_POP_DURATION_S. Same shape, same
## hand-rolled per-frame t, no Tween and no AnimationPlayer anywhere: a
## Tween would allocate a node on every single risk event, and this HUD
## reacts to events that fire several times a second at a high combo.
## Nothing in this file allocates after _ready().
##
## =====================================================================
## LEGIBILITY -- this HUD is a CanvasLayer at the default layer 1, while
## DarkModeEffect sits at layer 0 (see Game.tscn). Canvas layers draw in
## layer order and the invert shader samples the screen texture BENEATH
## it, so the HUD's own colours are never inverted and never tinted: they
## are the same values in the light phase and in all six dark palettes.
##
## What DOES change under the player is the BACKGROUND behind the text.
## That is why the feedback deliberately does not rest on colour:
##   - the multiplier is spelled out as TEXT ("x3"), not encoded as a hue;
##   - every reaction above is a SCALE change, which survives any palette;
##   - both labels carry a heavy dark OUTLINE (see HUD.tscn) around a white
##     fill, so one of the two always contrasts: the fill carries it
##     against a dark background, the outline against a light one.
## Measured per palette rather than asserted -- see
## scripts/dev/ComboContrastAudit.gd, which renders the real HUD over the
## real game under each palette and samples actual pixels.
##
## =====================================================================
## PURSUER TELEGRAPH -- two cues, because the brief has two halves that one
## widget cannot both satisfy:
##
##   VIGNETTE  read PERIPHERALLY, without looking away from the track. This
##             is the half that matters in play: the player must always know
##             roughly how close the thing behind them is while still
##             watching what is in front.
##   GAUGE     read DELIBERATELY, when the player chooses to check. Precise
##             where the vignette is only suggestive.
##
## Placed at the BOTTOM of the screen on purpose -- the pursuer is behind
## the player, and the bottom edge of a forward-facing view is the nearest
## thing this HUD has to "behind you". The score and combo own the top.
##
## The moment the pursuer becomes VISIBLE gets the tier-up pop, not the
## increment one -- it is the strongest tension beat in the run and it
## borrows the loudest reaction already validated on this HUD rather than
## introducing a new one.
##
## =====================================================================
## STRIKES -- two surfaces for the non-fatal contact model (see GameState's
## STRIKES block), answering two questions that a single widget cannot:
##
##   FLASH  "you were just HIT"    -- a full-screen impact, gone in a third
##                                    of a second. Reflex-scale: it has to
##                                    land before the player has read
##                                    anything, because the thing they must
##                                    understand is that this instant is
##                                    when they lost ground.
##   PIPS   "how much is left"     -- a permanent, glanceable count. The
##                                    player must always know whether they
##                                    are at full or one hit from being
##                                    caught, without an event having to
##                                    remind them.
##
## FOUR PIPS, NOT TWO, AND THEY COUNT CONTACTS -- see the ALARM LADDER below
## for the half-strike rebalance this row had to absorb. GameState counts in
## half-units because that is the arithmetic-safe way to price a contact at
## "half a strike"; this row does NOT repeat that framing at the player.
## They take four hits and they are caught, so the row shows four slots and
## spends one per hit. A half-filled pip would ask a player mid-run to
## decode a fraction; four pips ask them to count, which they already do.
##
## The pips sit directly ABOVE the pursuer gauge, in the same bottom column,
## because the two are one story: the pips are what the pursuer is counting.
##
## LEGIBILITY, same discipline as the combo row above and measured the same
## way (scripts/dev/StrikeContrastAudit.gd, real pixels under all six dark
## palettes and the light phase). A pip is THREE nested rectangles, and each
## one is load-bearing:
##
##   a bright outer BORDER -- carries the pip against a dark background;
##   a near-black inner RING -- carries it against a light one;
##   the INTERIOR -- bright when the strike is available, near-black when it
##     is spent. This is the only part that changes.
##
## Border and ring together are the same "outlined glyph" trick the combo
## labels use (white fill, heavy dark outline, one of the two always reads),
## expressed in geometry instead of type. The two-layer frame is NOT
## decoration: the first version of this pip had a single dark frame, and the
## probe measured the SPENT state at 2.20:1 against the violet dark palette
## -- near-black on dark violet, i.e. a player one hit from death could not
## see the slot they had lost. Nothing about the design predicted that; the
## measurement did.
##
## The spent/intact distinction is an interior COLOUR change, but it is never
## the only cue: from halfway through the budget the whole row pulses, which
## survives any palette because it is scale.
##
## =====================================================================
## THE ALARM LADDER -- what replaced the binary warning
##
## Before the half-strike rebalance the capacity was 2, so `danger := used >=
## CAPACITY - 1` meant the amber alarm armed on the FIRST contact and never
## changed again before the second one ended the run. One hit, full alarm:
## binary, and correct at that capacity.
##
## At a capacity of 4 the same expression is still the right one for "one
## more and you are done" -- it just no longer fires until the third
## contact, which would leave the first two marked by nothing but a flash
## that is gone in a third of a second. The middle of the ladder is exactly
## where a player most needs to feel the budget draining, so it gets its own
## step:
##
##   CLEAR    0-1 contacts   white, still. A single stumble is a stumble.
##   CAUTION  2 contacts     amber, SLOW shallow pulse. Half the resistance
##                           is gone. New state, and the reason this is a
##                           ladder rather than a rename.
##   DANGER   3 contacts     amber, the ORIGINAL fast deep pulse + the entry
##                           kick. "One more and you are done", unchanged in
##                           kind from what shipped -- only its trigger
##                           moved from contact 1 to contact 3.
##   FATAL    4 contacts     coral red, fastest and deepest. Owns the row.
##
## ESCALATION IS CARRIED BY PULSE RATE, not by inventing a third hue. Hue
## changes exactly once, at the step that matters most (white -> amber, "you
## are now in trouble"), and then rate and amplitude climb monotonically
## across all four steps. That keeps STRIKE_FATAL_COLOR's argument intact --
## the fatal beat is still its own hue family, not a shade of the warning --
## while giving the ladder a cue that is pure scale/motion and therefore
## survives every palette, including the DARK/4 case that colour alone
## cannot (see STRIKE_FATAL_COLOR's own doc).
##
## THE ENTRY KICK STILL FIRES ON EVERY NON-FINAL CONTACT, including the ones
## below CAUTION where there is no steady pulse to ride on. That is why
## _update_strike_display applies it OUTSIDE the tier branches: scoping it
## inside the danger branch, as it was when danger began at contact 1, would
## silently drop the kick for contacts 1 and 2 -- armed, advanced, expired,
## never drawn.

# --- INCREMENT pop -------------------------------------------------
## Same envelope as Obstacle.MARKER_POP_DURATION_S, and deliberately as
## brief: at a high combo these fire in quick succession, and a pop still
## playing when the next one starts reads as a wobble rather than as a
## count.
const POP_DURATION_S: float = 0.30
## Modest on purpose -- this is the QUIET one of the three reactions, so
## the tier-up below has somewhere louder to go.
const POP_PEAK_SCALE: float = 1.30

# --- TIER-UP pop ---------------------------------------------------
## Longer and much larger than an increment: crossing a tier is the rarest
## and most valuable thing that happens on this HUD (one every
## GameState.COMBO_TIER_SIZE events, at most COMBO_MAX_MULTIPLIER - 1 times
## per chain), so it gets a reaction an increment can never be mistaken for.
const TIER_POP_DURATION_S: float = 0.55
const TIER_POP_PEAK_SCALE: float = 2.10

# --- EXPIRING pulse ------------------------------------------------
## Pulse rate over the warning window. Fast enough to read as an alarm
## rather than as a breathing idle animation, slow enough to stay countable
## by eye (~4 full pulses across GameState.COMBO_WARNING_S).
const WARNING_PULSE_HZ: float = 3.5
## Scale swing of the pulse, around 1.0.
const WARNING_PULSE_AMPLITUDE: float = 0.18
## Colour the row takes while expiring. A SECOND cue on top of the pulse,
## never the only one (see the LEGIBILITY note above) -- hot amber, chosen
## to sit clear of the two collectible golds directly above it in the same
## HUD column, which would otherwise be the nearest thing on screen.
const WARNING_COLOR: Color = Color(1.0, 0.45, 0.15, 1)
const NORMAL_COLOR: Color = Color(1.0, 1.0, 1.0, 1)

# --- PURSUER telegraph ---------------------------------------------
## Widest the gauge fill ever gets, in pixels -- matches GaugeTrack's own
## custom_minimum_size in HUD.tscn, less the 3px inset on each side.
const GAUGE_WIDTH_PX: float = 414.0
## Proximity at which the gauge switches to the alarm colour. Chosen to line
## up with the moment the silhouette actually appears, so the colour change
## and the thing on screen are one event rather than two:
## 1 - VISIBLE_LEAD / MAX_LEAD.
const GAUGE_ALARM_PROXIMITY: float = 1.0 - GameState.PURSUER_VISIBLE_LEAD_S / GameState.PURSUER_MAX_LEAD_S
## Peak opacity the vignette reaches at zero lead. Short of 1.0 on purpose:
## the screen edges must darken enough to be unmissable without ever
## obscuring a hazard the player still has to read.
const VIGNETTE_MAX_ALPHA: float = 0.78
## Proximity below which the vignette stays fully off. Same value as the
## gauge's alarm point, so nothing about the pursuer is on screen until the
## pursuer itself is.
const VIGNETTE_ONSET_PROXIMITY: float = GAUGE_ALARM_PROXIMITY
## Colour the gauge fill takes far from / close to the pursuer.
const GAUGE_SAFE_COLOR: Color = Color(0.95, 0.85, 0.3, 1)
const GAUGE_ALARM_COLOR: Color = Color(1.0, 0.25, 0.2, 1)

# --- STRIKE flash + pips -------------------------------------------
## How long the impact flash lasts. Shorter than every other reaction on this
## HUD on purpose: it is the instant of the hit, not a state -- the state is
## the slowdown, which lasts twenty times longer and is felt rather than read.
## Same triangular envelope as everything else here (see _pop_scale), so it
## fades in and out rather than cutting.
const STRIKE_FLASH_DURATION_S: float = 0.30
## Peak opacity of the flash. Short of opaque by a wide margin: the player is
## still driving, and a hazard they have to read may already be on screen --
## this must be impossible to miss without being a blindfold.
const STRIKE_FLASH_MAX_ALPHA: float = 0.55
## Colour of a pip's INTERIOR when the strike is still available / already
## spent. Only the interior changes: the pip's bright outer border and dark
## inner ring are fixed (see HUD.tscn), which is what makes the pip visible
## at all against any background -- see the LEGIBILITY note in the class doc.
## The spent interior sits close to the ring colour, so a used slot reads as
## an empty socket rather than as a second kind of full one.
const PIP_INTACT_COLOR: Color = Color(1.0, 1.0, 1.0, 1)
const PIP_SPENT_COLOR: Color = Color(0.10, 0.09, 0.12, 1)
## Colour the row's label takes once the alarm is armed at all -- the same
## hot amber the expiring combo uses, reused rather than invented: it already
## means "act now" everywhere else on this HUD.
##
## Shared by CAUTION and DANGER on purpose. See the ALARM LADDER in the class
## doc: the two steps are told apart by pulse RATE, not by a second amber.
const STRIKE_DANGER_COLOR: Color = WARNING_COLOR

## --- CAUTION step (half-strike rebalance) --------------------------
## The pulse for "half your resistance is gone", i.e. the step that did not
## exist while the capacity was two contacts.
##
## Deliberately BELOW the danger pulse on both axes (3.5 Hz / 0.18) and
## visibly so: roughly a third the rate and a third the swing. It has to
## read as a heartbeat the player notices without being told to act NOW --
## if it competed with the danger step, arriving at contact 3 would mean
## nothing and the ladder would be back to binary with extra steps.
##
## The threshold is derived, not typed: half the budget, so it moves with
## GameState.STRIKE_CAPACITY_HALF instead of stranding the caution step on
## the wrong slot the way a literal 2 would.
const STRIKE_CAUTION_PULSE_HZ: float = 1.2
const STRIKE_CAUTION_PULSE_AMPLITUDE: float = 0.06

## The steps of the ALARM LADDER, named rather than left as 0/1/2 at the
## comparison sites -- `tier == TIER_CAUTION` says what it means where
## `tier == 1` would need the reader to go and look.
const TIER_CLEAR: int = 0
const TIER_CAUTION: int = 1
const TIER_DANGER: int = 2

## --- STRIKE-1 ENTRY KICK (reinforcement batch) ---------------------
## A single sharp scale spike on the strike row the instant strike 1 is
## credited, decaying into the ordinary WARNING_PULSE_* cycle underneath it.
##
## WHY IT EXISTS. The amber danger pulse (STRIKE_DANGER_COLOR +
## WARNING_PULSE_*) is armed the moment the FIRST strike lands and then runs
## unchanged until the run ends -- see STRIKE_FATAL_COLOR's own doc for the
## playtest finding that produced it. But its own entry is SOFT: the pulse is
## `1 + A * sin(t)` restarted at t=0, and sin(0) is exactly 0, so the row
## begins pulsing from precisely its resting scale and takes a quarter of a
## 3.5Hz cycle (~71ms) to reach its first peak. Nothing marks the INSTANT the
## state changed -- the player's first opportunity to notice is a slow swell
## that looks the same as every later swell.
##
## A follow-up capture investigation (staging playtest, score 355) measured
## the counting itself as correct -- two genuinely distinct contacts, 1.483s
## apart at the closest, well outside STRIKE_INVULNERABLE_S -- and concluded
## the gap was PERCEPTUAL: the warning was on screen and did its job poorly
## at the one moment it most needed to land. This is that moment, given an
## edge.
##
## DELIBERATELY ADDITIVE rather than a replacement: it rides on top of the
## existing pulse and expires, so the steady-state cue a player reads for the
## rest of the run is byte-for-byte the one that already shipped. And it is
## scoped to the DANGER branch only -- the fatal beat owns the row outright
## when it arms (see _update_strike_display), so this can never blunt the
## strike-2 cue's own distinctness.
const STRIKE_KICK_DURATION_S: float = 0.34
## Peak added scale at the top of the kick. Comfortably past
## WARNING_PULSE_AMPLITUDE (0.18) so the entry reads as its own event rather
## than as one unusually strong beat of the cycle, and short of the fatal
## pulse's own 0.32 swing so the two never trade places in prominence.
const STRIKE_KICK_PEAK: float = 0.26

## --- FATAL STRIKE (the capture beat, playtest-fixes batch) ---------
## Colour + pulse for the strike that actually catches the player, armed by
## GameState.pursuer_caught (see _on_pursuer_caught below) and held for the
## rest of GameState.CAPTURE_SEQUENCE_DURATION_S.
##
## Playtest finding (recorded at the old capacity of 2, and the reason this
## state exists at all): a player who took two contacts did not understand
## the second one was different from the first -- STRIKE_DANGER_COLOR/
## WARNING_PULSE_* had already been running continuously since strike one
## (`danger := used >= CAPACITY - 1` with a capacity of 2 means the amber
## pulse starts at the FIRST strike and never changes again before the
## second one ends the run), so the fatal hit looked like "the same warning,
## still going" rather than "the thing the warning was about, now
## happening". This state OWNS the row once armed -- it does not fall back
## to or alternate with the ordinary danger pulse, because by definition the
## ordinary pulse already had its one chance to be enough.
##
## THE HALF-STRIKE REBALANCE DID NOT MAKE THIS REDUNDANT, and it is worth
## saying so because the ALARM LADDER above solves a related problem. The
## ladder fixes "the warning is flat across the whole run"; this fixes "the
## last hit looks like the warning that preceded it". At capacity 4 the
## danger step now precedes the fatal one by a single contact rather than
## running for the whole run, which makes the two ADJACENT -- so the fatal
## beat needing its own hue and its own rate is, if anything, sharper than
## it was.
##
## A coral RED (hue 0deg), deliberately a different hue family from
## STRIKE_DANGER_COLOR's amber (hue ~21deg, also the expiring-combo pulse's
## colour) rather than a lighter/darker shade of the same one -- this needed
## to read as its OWN colour, not a variant of one already spoken for.
## Faster and with a bigger swing than the ordinary danger pulse too.
##
## MEASURED, not assumed -- scripts/dev/StrikeFatalContrastAudit.gd, same
## WCAG-on-real-pixels method as StrikeContrastAudit.gd/ComboContrastAudit.gd
## -- against the light phase and all 6 dark palettes: PASSES 6 of 7 at the
## 3.0:1 large-text floor (LIGHT 6.22:1, DARK/0 3.03:1, DARK/1 4.12:1, DARK/2
## 4.14:1, DARK/3 3.37:1, DARK/5 3.02:1). DARK/4 measures 2.79:1 (fill
## 2.53:1, outline via the shared near-black StrikeLabel outline 2.75:1) --
## a genuine, structural shortfall: DARK/4's real background sits in the
## narrow luminance band where NEITHER a red-hued fill nor the fixed
## near-black outline clears 3.0:1 at once, and pushing the fill brighter
## to close that gap (tried up to (1.0, 0.6, 0.4), worst-case 3.18:1) moves
## its hue to within ~1deg of STRIKE_DANGER_COLOR's amber -- which defeats
## the whole point of this colour existing. NOT fixed by chasing the number
## further at the cost of the colour becoming amber-with-training-wheels;
## accepted the same way this HUD's own class doc already argues no cue here
## should depend on colour ALONE (see the STRIKES section) -- the pulse
## (faster, bigger swing than the ordinary danger one) is the redundant cue
## that survives DARK/4 regardless, being pure scale/motion rather than hue.
const STRIKE_FATAL_COLOR: Color = Color(1.0, 0.46, 0.46, 1)
const FATAL_PULSE_HZ: float = 7.0
const FATAL_PULSE_AMPLITUDE: float = 0.32

@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var nut_label: Label = $MarginContainer/VBoxContainer/CountsRow/NutLabel
@onready var gland_label: Label = $MarginContainer/VBoxContainer/CountsRow/GlandLabel
@onready var combo_row: HBoxContainer = $MarginContainer/VBoxContainer/ComboRow
@onready var combo_label: Label = $MarginContainer/VBoxContainer/ComboRow/ComboLabel
@onready var multiplier_label: Label = $MarginContainer/VBoxContainer/ComboRow/MultiplierLabel
@onready var pursuer_row: VBoxContainer = $MarginContainer/PursuerRow
@onready var pursuer_label: Label = $MarginContainer/PursuerRow/PursuerLabel
@onready var gauge_fill: ColorRect = $MarginContainer/PursuerRow/GaugeTrack/GaugeFill
@onready var pursuer_vignette: ColorRect = $PursuerVignette
@onready var strike_flash: ColorRect = $StrikeFlash
## THE PROJECT'S FIRST AUDIO. There was no AudioStreamPlayer, no bus layout
## and no sound file anywhere in this repo before this batch (assets/audio/
## held a lone .gitkeep), so there was no existing SFX autoload or pattern to
## reuse -- these two players are deliberately plain scene nodes on the HUD
## rather than a new global audio service, because two one-shot cues do not
## justify one and the HUD is already the node that owns every other strike
## cue (flash, pips, pulse, colour).
##
## Both are fired from _on_strike_taken, i.e. the same signal and the same
## frame as the visual flash, so sound and picture can never disagree about
## when a strike landed. Separate players rather than one with a swapped
## stream: the fatal cue is longer than the warning (0.55s vs 0.20s) and the
## two must never cut each other off mid-tail.
@onready var strike_warning_sfx: AudioStreamPlayer = $StrikeWarningSfx
@onready var strike_fatal_sfx: AudioStreamPlayer = $StrikeFatalSfx
@onready var strike_row: HBoxContainer = $MarginContainer/PursuerRow/StrikeRow
@onready var strike_label: Label = $MarginContainer/PursuerRow/StrikeRow/StrikeLabel
## Fixed-size, resolved once. One entry per STRIKE_CAPACITY_HALF slot, in the
## same order as the scene authors them, so the Nth pip is the Nth contact.
## Went from 2 to 4 with the half-strike rebalance -- the count is asserted
## against the capacity in _ready() rather than left to agree by luck.
@onready var pip_fills: Array[ColorRect] = [
	$MarginContainer/PursuerRow/StrikeRow/Pip0/Ring/Fill,
	$MarginContainer/PursuerRow/StrikeRow/Pip1/Ring/Fill,
	$MarginContainer/PursuerRow/StrikeRow/Pip2/Ring/Fill,
	$MarginContainer/PursuerRow/StrikeRow/Pip3/Ring/Fill,
]

## Elapsed time in each pop, or < 0.0 when that pop is not playing -- the
## same "-1.0 means idle" convention as Obstacle._marker_pop_t.
var _pop_t: float = -1.0
var _tier_pop_t: float = -1.0
## Free-running phase for the warning pulse, in seconds. Reset to 0 every
## time the warning window is ENTERED (not every frame it is active) so the
## pulse always starts at its own beginning and the first beat is a full
## one, never a fragment picked up mid-cycle.
var _warning_t: float = 0.0
var _warning_active: bool = false
## The colour currently pushed onto the two labels. Tracked so the theme
## override is only written when it actually CHANGES: add_theme_color_override
## is a hashed insert into the Control's override map plus a theme-changed
## notification and a redraw request, and calling it every frame of every
## warning window would be exactly the kind of avoidable per-frame churn
## this codebase keeps out of the game loop. Starts at NORMAL_COLOR, which
## is what HUD.tscn authors both labels with.
var _applied_color: Color = NORMAL_COLOR

## Pop timer for the pursuer row, same "-1.0 means idle" convention as the
## two combo pops above.
var _pursuer_pop_t: float = -1.0
## Last vignette intensity pushed into the shader. Tracked so the uniform is
## only written when it actually moves -- set_shader_parameter every frame
## would be avoidable per-frame churn for a value that is zero for most of
## a run.
var _applied_vignette: float = -1.0

## Impact-flash timer, same "-1.0 means idle" convention as the pops above.
var _strike_flash_t: float = -1.0
## Entry-kick timer for the strike-1 alarm -- see STRIKE_KICK_DURATION_S.
## Same "-1.0 means idle" convention, and advanced by the same _advance_pop /
## _pop_scale pair every other one-shot on this HUD uses, so it cannot drift
## into being a second animation shape of its own.
var _strike_kick_t: float = -1.0
## Free-running phase for the alarm pulse, restarted when a STEP of the
## ladder is entered so its first beat is always a whole one -- exactly the
## contract _warning_t follows for the combo. Restarting on every step
## change, not only on arming, matters now that there are two pulsing steps:
## stepping CAUTION -> DANGER swaps the rate, and picking the faster beat up
## mid-cycle would blunt the one transition the ladder most needs to land.
var _strike_pulse_t: float = 0.0
## Which step of the ALARM LADDER is currently drawn (see the class doc):
## 0 clear, 1 caution, 2 danger. Replaced a plain `_strike_danger_active`
## bool, which could not tell the two pulsing steps apart.
var _strike_tier: int = 0
## The strike label's font colour actually pushed to the theme override.
## Tracked, same reasoning as _applied_color for the combo labels, so the
## override is only written on a real change -- with three possible states
## now (normal / danger / fatal) rather than two, a plain bool toggle can no
## longer tell "did this change" on its own.
var _applied_strike_color: Color = NORMAL_COLOR
## Whether the FATAL strike beat is currently playing -- see
## STRIKE_FATAL_COLOR's own doc. Armed by GameState.pursuer_caught
## (_on_pursuer_caught below), which fires exactly once per capture whether
## it came from the lead draining to zero or from the capacity-th contact --
## see GameState._begin_capture_sequence. Cleared the moment
## strikes_used_half next
## returns to 0 (a fresh start_run(), see _update_strike_display), never by
## a timer of its own: this HUD does not need to know
## GameState.CAPTURE_SEQUENCE_DURATION_S to stay in step with it, because
## the row is either hidden behind GameOverScreen or about to be reset by
## the next run by the time that duration elapses either way.
var _fatal_active: bool = false
## Free-running phase for the fatal pulse, same "restart on entry" contract
## as _strike_pulse_t/_warning_t.
var _fatal_pulse_t: float = 0.0
## Half-unit count currently DRAWN. The pips are repainted from
## GameState.strikes_used_half on change rather than driven by the strike_taken /
## strike_cleared signals, and that is deliberate: a count is a STATE, and a
## surface rebuilt from the state cannot drift out of step with it -- there is
## no reset signal to forget to connect, and a run starting fresh repaints on
## its first frame for free. The signals stay for the EVENTS (the flash, the
## camera shake), which are the thing a state cannot express.
## Starts at -1 so the first frame always paints.
var _drawn_half: int = -1

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.counts_changed.connect(_on_counts_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.combo_tier_up.connect(_on_combo_tier_up)
	GameState.pursuer_became_visible.connect(_on_pursuer_became_visible)
	GameState.strike_taken.connect(_on_strike_taken)
	GameState.pursuer_caught.connect(_on_pursuer_caught)
	# The scene authors the pips; GameState owns the capacity. Nothing makes
	# the two agree, so say so loudly here rather than silently drawing a row
	# that cannot represent the state -- too few pips and the last contacts
	# are invisible, too many and the player is shown resistance they do not
	# have. Costs one comparison at startup and would have caught this
	# batch's own scene edit had it been forgotten.
	if pip_fills.size() != GameState.STRIKE_CAPACITY_HALF:
		push_error("HUD: %d pips authored in HUD.tscn against a capacity of %d half-units -- the strike row cannot draw the real state." % [
			pip_fills.size(), GameState.STRIKE_CAPACITY_HALF])
	score_label.text = str(GameState.score)
	_on_counts_changed(GameState.nut_count, GameState.gland_count)
	_on_combo_changed(GameState.combo_count, GameState.combo_multiplier)
	_update_pursuer_telegraph(0.0)
	_update_strike_display(0.0)

func _on_score_changed(new_score: int) -> void:
	score_label.text = str(new_score)

func _on_counts_changed(nut_count: int, gland_count: int) -> void:
	nut_label.text = "Noisettes : %d" % nut_count
	gland_label.text = "Glands : %d" % gland_count

## Drives every combo visual off the ONE signal that fires in both
## directions (see GameState.combo_changed) -- including the collapse to
## (0, 1), which is what hides the row again. combo_tier_up is additive on
## top of this, never a substitute for it.
func _on_combo_changed(count: int, multiplier: int) -> void:
	var active := count > 0
	combo_row.visible = active
	if not active:
		# Every animation state is cleared on the way out, so a chain
		# started later can never inherit a pop or a pulse (or a warning
		# colour) left over from the one that just lapsed.
		_pop_t = -1.0
		_tier_pop_t = -1.0
		_warning_active = false
		_reset_visuals()
		return
	combo_label.text = "COMBO %d" % count
	multiplier_label.text = "x%d" % multiplier
	# Shown only once it actually multiplies something: a permanent "x1"
	# would be a label that means "no bonus", which is worse than no label.
	multiplier_label.visible = multiplier > 1
	_pop_t = 0.0

func _on_combo_tier_up(_multiplier: int) -> void:
	# The text/visibility were already set by the combo_changed that fires
	# immediately before this -- this handler exists purely to arm the
	# louder animation.
	_tier_pop_t = 0.0

## The pursuer coming into view borrows the TIER-UP pop, not the increment
## one -- see the class doc: it is the loudest beat in the run and deserves
## the loudest reaction this HUD already has.
func _on_pursuer_became_visible() -> void:
	_pursuer_pop_t = 0.0

## Stops both cues before this HUD leaves the tree.
##
## NOT housekeeping for its own sake -- it is load-bearing for the dev probes.
## Every probe in scripts/dev/ runs dozens to hundreds of runs by
## instantiating Game.tscn and queue_free()ing it, so a HUD is torn down over
## and over, and a player still mid-playback when its node goes leaves its
## stream referenced by the audio server. Measured: without this, StrikeAudit
## (the probe that deliberately stumbles its bots the most, and therefore
## fires these cues the most) ended every run with "1 resources still in use
## at exit" -- deterministically, byte-for-byte reproducible across runs.
##
## That warning changed no measurement and no verdict (the probe's own output
## was identical either way, the lines land after its PASSED), but it broke
## the byte-identical comparison this project gates asset and UI changes on,
## which is a check worth more than the two lines it costs to keep clean.
## Ordinary teardown hygiene: every probe in scripts/dev/ instantiates and
## queue_free()s Game.tscn dozens to hundreds of times, so these players are
## torn down constantly and should not be left mid-playback when they go.
##
## HONEST LIMIT, measured rather than claimed: this does NOT fully release the
## audio resource at engine shutdown. With these two cues present, StrikeAudit
## ends with "1 resources still in use at exit" on 5 of 6 observed runs; the
## no-audio baseline shows it on 0 of 4. Neither `stop()` alone nor
## additionally clearing `stream` removed it (3 of 3 runs still showed it), so
## what survives is held somewhere this script cannot reach from GDScript.
##
## It changes no measurement and no verdict -- the lines land after the
## probe's own PASSED, every number above them is byte-identical, and
## scripts/dev/* is excluded from the shipped build entirely, so nothing here
## reaches a player. It is recorded as a known, open cosmetic defect rather
## than papered over. See docs/MESHY_SPEC.md §11.
func _exit_tree() -> void:
	strike_warning_sfx.stop()
	strike_fatal_sfx.stop()

## Arms the impact flash, the entry kick and the audio cue. The pips
## themselves are NOT repainted here -- see _drawn_half for why they are
## rebuilt from the state instead.
##
## `strikes_used_half` is the count AFTER this contact (see
## GameState.register_strike, which increments before emitting), so the
## capacity comparison below is the same discriminator _on_pursuer_caught
## already uses: this IS the fatal one exactly when the count has reached
## STRIKE_CAPACITY_HALF.
##
## The two branches are the WHOLE of the sound design's separation rule: the
## warning cue is short and high, the fatal one long and roughly two octaves
## below it, mirroring in sound the deliberate "different hue family, not a
## shade of the same one" rule STRIKE_FATAL_COLOR's doc states for colour.
## Neither is ever played on the other's frame.
##
## THE WARNING CUE FIRES ON EVERY NON-FINAL CONTACT, which at capacity 4
## means up to three times a run rather than the old once. It is NOT graded
## per step of the ALARM LADDER: that would need cues this project does not
## have (there are exactly two .wav files, see the audio note above), and
## inventing a pitch ramp in code would put the sound design somewhere no
## one would look for it. The escalation the player hears is the FREQUENCY
## of this cue; the escalation they see is the ladder. Flagged for the
## device review as the most likely thing to want a third asset later.
func _on_strike_taken(_source_type: int, strikes_used_half: int) -> void:
	_strike_flash_t = 0.0
	if strikes_used_half >= GameState.STRIKE_CAPACITY_HALF:
		strike_fatal_sfx.play()
		return
	# A contact that was not the last one. Kick and warning cue both scoped
	# here so neither can fire on the capture frame the fatal branch owns.
	# The kick is DRAWN outside the ladder's branches (see
	# _update_strike_display) precisely so it still shows at the lower steps,
	# where there is no steady pulse for it to ride on.
	_strike_kick_t = 0.0
	strike_warning_sfx.play()

## Arms the fatal-strike beat -- see STRIKE_FATAL_COLOR's own doc.
## GameState.pursuer_caught fires for BOTH ways a run can end at the
## pursuer's hands (the lead draining to zero, or the capacity-th contact --
## see GameState._begin_capture_sequence), but this beat is scoped to the
## contact-driven one on purpose: it lives on the strike row (the pips and
## this label), and a lead-drain capture can happen with strikes_used_half
## sitting anywhere from 0 to STRIKE_CAPACITY_HALF - 1 -- pips still
## showing slots available. Arming the fatal red there would tell the wrong
## story ("you ran out of resistance") about an event that was actually the
## gauge running out. GameState.strikes_used_half is already at STRIKE_CAPACITY
## by the time this signal fires FOR a strike-triggered capture (register_
## strike increments it before emitting), so that comparison is exactly the
## discriminator needed, without this HUD having to know WHICH of the two
## call sites in GameState actually fired.
func _on_pursuer_caught() -> void:
	if GameState.strikes_used_half < GameState.STRIKE_CAPACITY_HALF:
		return
	_fatal_active = true
	_fatal_pulse_t = 0.0

func _process(delta: float) -> void:
	# Both run unconditionally, unlike the combo block below: the pursuer
	# gauge and the strike pips are PERMANENT (the player must always be able
	# to read either), so neither can be gated on another widget being on
	# screen.
	_update_pursuer_telegraph(delta)
	_update_strike_display(delta)
	if not combo_row.visible:
		return
	_update_warning(delta)
	_update_pops(delta)

## Drives both pursuer cues from the single normalised proximity GameState
## exposes, so the vignette, the gauge width and the gauge colour can never
## disagree about how close the thing is.
func _update_pursuer_telegraph(delta: float) -> void:
	var proximity := GameState.pursuer_proximity()

	# Gauge: fill shows REMAINING LEAD, so it drains toward empty as the
	# pursuer closes -- the direction a player already reads as "running
	# out" from every other bar in every other game.
	gauge_fill.size.x = maxf(0.0, (1.0 - proximity) * GAUGE_WIDTH_PX)
	var alarm_t := 0.0
	if GAUGE_ALARM_PROXIMITY < 1.0:
		alarm_t = clampf((proximity - GAUGE_ALARM_PROXIMITY) / (1.0 - GAUGE_ALARM_PROXIMITY), 0.0, 1.0)
	gauge_fill.color = GAUGE_SAFE_COLOR.lerp(GAUGE_ALARM_COLOR, alarm_t)

	# Vignette: off entirely until the pursuer is actually on screen, then
	# ramps to VIGNETTE_MAX_ALPHA at zero lead.
	var vignette := alarm_t * VIGNETTE_MAX_ALPHA
	if not is_equal_approx(vignette, _applied_vignette):
		_applied_vignette = vignette
		var mat: ShaderMaterial = pursuer_vignette.material
		if mat:
			mat.set_shader_parameter("intensity", vignette)

	# Pop on first sighting -- same triangular envelope as everything else
	# on this HUD.
	_pursuer_pop_t = _advance_pop(_pursuer_pop_t, delta, TIER_POP_DURATION_S)
	_apply_scale(pursuer_label, _pop_scale(_pursuer_pop_t, TIER_POP_DURATION_S, TIER_POP_PEAK_SCALE))

## The two strike surfaces -- see the STRIKES section of the class doc, and
## the ALARM LADDER section for the three-step warning this drives.
##
## Everything here is edge-triggered against what is already drawn: the pips
## repaint only when the count moves, the label colour only when the STATE
## (normal / caution / danger / fatal) actually changes. The only per-frame
## writes are the pulse's scale and the flash's alpha, and both are plain
## value-type assignments.
func _update_strike_display(delta: float) -> void:
	var used: int = GameState.strikes_used_half
	if used != _drawn_half:
		_drawn_half = used
		for i in pip_fills.size():
			# Pips are spent LEFT TO RIGHT: with `used` half-units spent, the
			# first `used` slots are empty and the rest are still available.
			pip_fills[i].color = PIP_SPENT_COLOR if i < used else PIP_INTACT_COLOR
		if used == 0:
			# The only way this count falls back to 0 is a fresh start_run()
			# (see GameState.gd) -- clear the one-shot fatal beat along with
			# it so a NEW run's very first contact can never inherit the
			# PREVIOUS run's capture-beat colour/pulse.
			_fatal_active = false

	# THE LADDER. Both thresholds are DERIVED from the capacity, never typed
	# as literals, so changing STRIKE_CAPACITY_HALF moves both steps with it
	# instead of stranding one on the wrong slot -- which is exactly what a
	# literal `>= 1` would have done to this row when the capacity went from
	# 2 to 4.
	var tier := TIER_CLEAR
	if used >= GameState.STRIKE_CAPACITY_HALF - 1:
		tier = TIER_DANGER
	elif used >= GameState.STRIKE_CAPACITY_HALF / 2:
		tier = TIER_CAUTION
	# Restart the phase on ANY step change, not only on arming: stepping
	# CAUTION -> DANGER swaps the pulse rate, and picking the faster beat up
	# mid-cycle would blunt the one transition the ladder most needs to land.
	if tier != _strike_tier:
		_strike_pulse_t = 0.0
	_strike_tier = tier

	var scale := 1.0
	if _fatal_active:
		# THE final contact -- see STRIKE_FATAL_COLOR's own doc for why this
		# does not fall back to the ladder below: it OWNS the row for the
		# rest of the capture beat, kick included.
		_apply_strike_color(STRIKE_FATAL_COLOR)
		_fatal_pulse_t += delta
		scale = 1.0 + FATAL_PULSE_AMPLITUDE * sin(_fatal_pulse_t * TAU * FATAL_PULSE_HZ)
	else:
		if tier == TIER_DANGER:
			_apply_strike_color(STRIKE_DANGER_COLOR)
			_strike_pulse_t += delta
			scale = 1.0 + WARNING_PULSE_AMPLITUDE * sin(_strike_pulse_t * TAU * WARNING_PULSE_HZ)
		elif tier == TIER_CAUTION:
			# Same amber, a third the rate and a third the swing -- see
			# STRIKE_CAUTION_PULSE_HZ for why the step is told apart by rate
			# rather than by a second colour.
			_apply_strike_color(STRIKE_DANGER_COLOR)
			_strike_pulse_t += delta
			scale = 1.0 + STRIKE_CAUTION_PULSE_AMPLITUDE * sin(_strike_pulse_t * TAU * STRIKE_CAUTION_PULSE_HZ)
		else:
			_apply_strike_color(NORMAL_COLOR)
		# The entry kick rides ON TOP of whatever steady pulse this step has,
		# INCLUDING none -- which is why it sits outside the branches above
		# rather than inside the danger one where it used to live. At the old
		# capacity of 2 the two were the same thing (every non-fatal contact
		# armed the danger step on the same frame); at capacity 4 the first
		# two contacts land at TIER_CLEAR, and leaving the kick in the danger
		# branch would arm, advance and expire it without ever drawing it.
		# _pop_scale returns 1.0 at rest, so subtracting 1 turns the shared
		# envelope into a pure additive spike that vanishes when the kick
		# expires, leaving the steady pulse untouched for the rest of the run.
		scale += _pop_scale(_strike_kick_t, STRIKE_KICK_DURATION_S, 1.0 + STRIKE_KICK_PEAK) - 1.0
	# On the ROW, not on the label: the pips are the information, so the pulse
	# has to move them too -- pulsing only the word would draw the eye to the
	# one part of the widget that never changes.
	strike_row.pivot_offset = strike_row.size * 0.5
	strike_row.scale = Vector2(scale, scale)

	# Advanced unconditionally, like the flash below it: a kick armed on the
	# frame a run ended must still expire on its own rather than be left
	# primed for whatever draws this row next.
	_strike_kick_t = _advance_pop(_strike_kick_t, delta, STRIKE_KICK_DURATION_S)
	_strike_flash_t = _advance_pop(_strike_flash_t, delta, STRIKE_FLASH_DURATION_S)
	# _pop_scale returns 1.0 at rest and peaks at its `peak` argument, so
	# passing (1 + max_alpha) and subtracting 1 turns that same envelope into
	# an alpha ramp from 0 -- reusing the one shape this HUD animates
	# everything with rather than writing a second one that could drift from it.
	strike_flash.color.a = _pop_scale(
		_strike_flash_t, STRIKE_FLASH_DURATION_S, 1.0 + STRIKE_FLASH_MAX_ALPHA) - 1.0

## The "about to lapse" alarm -- see the class doc for why this is the
## load-bearing part of the feedback rather than a finishing touch.
func _update_warning(delta: float) -> void:
	var expiring := GameState.combo_time_left_s() <= GameState.COMBO_WARNING_S
	if expiring and not _warning_active:
		_warning_t = 0.0 # entering the window: start the pulse at its own beginning
	_warning_active = expiring
	if not expiring:
		_apply_color(NORMAL_COLOR)
		return
	_warning_t += delta
	_apply_color(WARNING_COLOR)

## Applies both pops AND the warning pulse as ONE scale per label, rather
## than letting each effect write `scale` in turn -- two writers would mean
## whichever ran last silently won, and a tier-up landing inside the warning
## window (entirely possible: a risk event taken in the last second both
## re-arms the chain and can cross a tier) would flicker between the two.
func _update_pops(delta: float) -> void:
	var pulse := 1.0
	if _warning_active:
		pulse += WARNING_PULSE_AMPLITUDE * sin(_warning_t * TAU * WARNING_PULSE_HZ)

	_pop_t = _advance_pop(_pop_t, delta, POP_DURATION_S)
	_tier_pop_t = _advance_pop(_tier_pop_t, delta, TIER_POP_DURATION_S)

	var combo_scale := pulse * _pop_scale(_pop_t, POP_DURATION_S, POP_PEAK_SCALE)
	# The multiplier carries BOTH pops: the ordinary one so it keeps step
	# with the count beside it, and the tier pop multiplied on top so a
	# tier-up is unmistakably the bigger event.
	var multiplier_scale := combo_scale * _pop_scale(_tier_pop_t, TIER_POP_DURATION_S, TIER_POP_PEAK_SCALE)

	_apply_scale(combo_label, combo_scale)
	_apply_scale(multiplier_label, multiplier_scale)

func _advance_pop(t: float, delta: float, duration: float) -> float:
	if t < 0.0:
		return -1.0
	var next := t + delta
	return -1.0 if next >= duration else next

## Triangular envelope: linear rise to `peak` at the midpoint, linear fall
## back to 1.0 -- the same readable shape Obstacle._update_marker_pop uses,
## rather than a smoother curve that is harder to reason about.
func _pop_scale(t: float, duration: float, peak: float) -> float:
	if t < 0.0:
		return 1.0
	var half := duration * 0.5
	var ramp := t / half if t < half else 2.0 - t / half
	return lerpf(1.0, peak, clampf(ramp, 0.0, 1.0))

## A Control scales about its top-left corner unless pivot_offset says
## otherwise, which would make a pop slide the text sideways instead of
## growing it in place. Recomputed each frame rather than cached: the
## labels' size changes with their own text ("COMBO 9" is wider than
## "COMBO 10" is not), and both this and the scale assignment are plain
## value-type writes -- no allocation.
func _apply_scale(label: Label, value: float) -> void:
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(value, value)

## Edge-triggered -- see _applied_color for why this must not run every
## frame.
func _apply_color(value: Color) -> void:
	if _applied_color == value:
		return
	_applied_color = value
	combo_label.add_theme_color_override("font_color", value)
	multiplier_label.add_theme_color_override("font_color", value)

func _reset_visuals() -> void:
	_apply_color(NORMAL_COLOR)
	_apply_scale(combo_label, 1.0)
	_apply_scale(multiplier_label, 1.0)

## Edge-triggered, same discipline as _apply_color above -- see
## _applied_strike_color for why this needed its own tracked value once a
## third state (fatal) joined normal/danger.
func _apply_strike_color(value: Color) -> void:
	if _applied_strike_color == value:
		return
	_applied_strike_color = value
	strike_label.add_theme_color_override("font_color", value)
