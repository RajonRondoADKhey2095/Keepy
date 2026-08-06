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

@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var nut_label: Label = $MarginContainer/VBoxContainer/CountsRow/NutLabel
@onready var gland_label: Label = $MarginContainer/VBoxContainer/CountsRow/GlandLabel
@onready var combo_row: HBoxContainer = $MarginContainer/VBoxContainer/ComboRow
@onready var combo_label: Label = $MarginContainer/VBoxContainer/ComboRow/ComboLabel
@onready var multiplier_label: Label = $MarginContainer/VBoxContainer/ComboRow/MultiplierLabel

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

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.counts_changed.connect(_on_counts_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.combo_tier_up.connect(_on_combo_tier_up)
	score_label.text = str(GameState.score)
	_on_counts_changed(GameState.nut_count, GameState.gland_count)
	_on_combo_changed(GameState.combo_count, GameState.combo_multiplier)

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

func _process(delta: float) -> void:
	if not combo_row.visible:
		return
	_update_warning(delta)
	_update_pops(delta)

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
