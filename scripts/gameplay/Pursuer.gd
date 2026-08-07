extends Node3D
class_name Pursuer
## The visible half of the pursuer -- see the PURSUER block in GameState.gd
## for the abstract lead this renders, and for why that lead is the truth
## while this node is only ever a view of it.
##
## POOLED, exactly like every hazard in this game: one instance, created
## once with the Game scene and only ever shown/hidden and repositioned.
## Nothing here is instantiated or freed during a run.
##
## NO COLLISION SHAPE AT ALL, deliberately. Being caught is decided by the
## lead reaching zero in GameState, on the run clock -- never by this node
## touching Keepy. Giving it a hitbox would create a second, competing way
## to die: a physics contact would fire Keepy.die() and report the run as a
## COLLISION, which is precisely the distinction this whole feature exists
## to draw. It is scenery that happens to be terrifying.
##
## WHERE IT SITS. The camera rides at Keepy + (0, 4.2, 7) looking forward
## (CameraFollow), and Keepy is pinned at Z=0, so positive Z -- behind the
## player -- is not off screen at all: there is a real corridor between the
## player's back and the lens. This node lives in it, which is what lets a
## thing "behind you" be genuinely visible without a rear-view mirror, a
## second viewport or any change to the camera.

## Z the pursuer sits at when it first becomes visible, i.e. at
## GameState.PURSUER_VISIBLE_LEAD_S.
##
## WAS 6.0 -- only ONE unit clear of the camera's own Z (7.0, see
## CameraFollow.offset), which is the framing bug this batch exists to fix.
## The comment that used to justify 6.0 ("enters frame from the far edge")
## had the geometry backwards: a metre from the LENS is not the far edge of
## anything, it is nearly on top of it. A perspective camera's apparent
## size scales with 1/distance, so at FAR_SCALE (1.0) and one unit out, the
## capsule's own 3.4-unit body already subtends roughly 120 degrees of a
## 75-degree vertical FOV -- comfortably wider than the screen itself,
## before NEAR_SCALE ever enters into it. See PursuerFramingAudit.gd for
## the measured, on-screen confirmation and the occupancy cap this and
## CAUGHT_Z/FAR_SCALE/NEAR_SCALE below are jointly calibrated against.
const FAR_Z: float = 3.0
## Z the pursuer eases toward as the lead drops to zero -- i.e. the closest
## it is ever allowed to sit behind the player, VISUALLY.
##
## WAS 0.0 ("the player's own position, since that is what being caught
## means"). That reading conflated two different things: capture is an
## event in GameState (the lead reaching zero), never a distance this node
## reaches -- Pursuer.gd has no collision shape and cannot itself catch
## anyone (see the class doc above). Lerping visual Z all the way to 0.0
## put the capsule's origin exactly on the camera's look-at path with
## nothing left to divide distance by, which is the second half of the
## screen-filling bug: this end of the lerp was ALSO too close, just for a
## different reason (a vanishing denominator rather than a small one).
##
## 1.0 is a floor, not a tuned distance: below it the pursuer stops
## visually closing in at all, even while pursuer_lead_s keeps counting
## down toward the real capture. The threat past that point reads through
## the OTHER cues that are still live at zero lead -- the eyes' emission
## energy peaking, the HUD gauge and strike pips, the vignette -- exactly
## as the class doc already promised none of this depends on colour alone.
const CAUGHT_Z: float = 1.0

## How far the silhouette leans side to side, and how fast. A slow lateral
## sway, unsynchronised with anything else on screen, so the shape reads as
## something ALIVE and pursuing rather than as a prop being towed along at a
## fixed offset. Deliberately not lane-quantised -- it never occupies a lane
## and can never be dodged, which is the point: the only escape is to take
## risks and push it back.
const SWAY_AMPLITUDE_X: float = 1.1
const SWAY_HZ: float = 0.55

## Vertical bob, same reasoning, and small enough that it never reads as a
## jump the player might have to react to.
const BOB_AMPLITUDE_Y: float = 0.18
const BOB_HZ: float = 0.8

## Scale at the two ends of the approach. It grows as it closes -- the
## cheapest and most legible distance cue there is, and one that survives
## every palette because it is geometry rather than colour.
##
## WAS 1.0 / 2.2 -- sized for a corridor the old FAR_Z/CAUGHT_Z never
## actually gave it (see those constants' doc). Against the REAL available
## depth (camera at Z=7.0, pursuer confined to [CAUGHT_Z, FAR_Z] = a few
## units of it), 1.0 was already oversized and 2.2 compounded it right
## where the threat is supposed to read as urgent rather than as a wall.
## Rescaled so the capsule stays identifiable as an imposing shape without
## ever eating the track, the obstacles ahead or Keepy -- see
## PursuerFramingAudit.gd for the measured occupancy this pair holds to
## (max screen-height fraction, both endpoints and the run in between).
const FAR_SCALE: float = 0.4
const NEAR_SCALE: float = 0.65

## =====================================================================
## CAPTURE SEQUENCE -- the missing moment playtest feedback pointed at
## directly: "le joueur a pris deux contacts puis a ete capture, et n'a pas
## compris qu'il s'etait fait attraper". The pursuer was on screen right up
## to the death, and the very next frame was the score screen -- nothing in
## between was ever the visible REASON. This block is what plays during
## GameState.State.CAPTURED (see that state's own doc in GameState.gd),
## between the lead/strikes reaching zero and the actual GAME_OVER: the
## pursuer alone keeps closing, past its ordinary CAUGHT_Z floor, onto a
## world every other _physics_process in the game has already frozen (every
## one of them already early-outs on `state != PLAYING`, which is what
## makes this free -- nothing else needed to change to hold the track,
## Keepy and every obstacle perfectly still while this plays).
##
## Driven for GameState.CAPTURE_SEQUENCE_DURATION_S, not a separate
## constant of this file's own: retuning how long a capture reads is a
## single-number change in GameState, not two constants kept in sync by
## hand across files.
## =====================================================================

## How far past CAUGHT_Z the lunge is allowed to close -- the one place in
## this file that is legal, because by the time this plays the run is
## already decided and there is nothing left behind the pursuer to protect
## from the screen-filling bug CAUGHT_Z's own doc describes. Still short of
## Z=0 (Keepy's own Z, and the camera's look-at path): landing exactly on it
## would put the mesh's ORIGIN on the lens' axis with nothing left to divide
## screen-space distance by -- the same vanishing-denominator failure mode,
## courted on purpose this time only if it were 0.0 instead of a hair short.
const CAPTURE_Z: float = 0.15
## Scale the lunge reaches at the end. Past NEAR_SCALE on purpose -- see
## PursuerFramingAudit.gd's dedicated, UNCAPPED "CAPTURE" sample bucket:
## filling more of the frame than the ordinary approach is ever allowed to
## is the entire point of this beat, not an oversight to budget against.
const CAPTURE_SCALE: float = 1.05
## Eyes ramp to a THIRD, higher multiplier here, past the one the ordinary
## closing approach already peaks at (_base_emission_energy * 3.0, see the
## ordinary branch below) -- the same "luminance, not hue" reasoning as
## that ramp, pushed one step further for the one moment that is allowed to.
const CAPTURE_EMISSION_MULTIPLIER: float = 5.0

## =====================================================================
## INTRO SIGHTING -- a brief, forced look at the pursuer at the very start
## of every run, before the HUD gauge can mean anything to a player who has
## never seen what it is a gauge OF.
##
## Deliberately independent of GameState.pursuer_lead_s /
## GameState.pursuer_visible: it fires straight off GameState.state_changed
## -> State.PLAYING, holds a fixed pose (the same FAR_Z/FAR_SCALE the real
## sighting later uses, so nothing new has to be separately calibrated or
## re-checked by PursuerFramingAudit) and then shrinks itself away. It
## never reads or writes pursuer_lead_s, so PURSUER_START_LEAD_S and
## PURSUER_GRACE_S are exactly as untouched as if this feature did not
## exist -- the real countdown starts the run at its usual 12.0s, unaware
## the player was ever shown anything.
##
## NON-FATAL AND NON-BLOCKING for the same reason the class doc gives for
## the real sighting having no collision shape: this node cannot end a run
## by existing on screen, intro or not, and nothing here pauses input --
## Keepy reads its own controls regardless of what this node is doing.
## =====================================================================

## Total length of the intro sighting, in seconds. Short enough that it
## never reads as a wait: TrackManager's SAFE_START_SEGMENTS keeps the
## opening rows obstacle-free regardless, so the player already has
## nothing urgent to react to for longer than this.
const INTRO_DURATION_S: float = 2.2
## Fraction of INTRO_DURATION_S spent held at full size before receding.
## The rest is the recede itself -- a scale ease to zero, never a jump cut,
## so the establishing shot reads as the same thing withdrawing rather than
## as a flash.
const INTRO_HOLD_FRACTION: float = 0.45

@onready var _mesh: MeshInstance3D = $Silhouette
@onready var _eye_left: MeshInstance3D = $Silhouette/EyeLeft
@onready var _eye_right: MeshInstance3D = $Silhouette/EyeRight

## Whether the opening sighting is currently playing. While true it owns
## visibility/position/scale outright; the ordinary lead-driven branch in
## _process does not run at all (see the guard at its top).
var _intro_active: bool = false
var _intro_t: float = 0.0

## Whether the capture lunge is currently playing -- see the CAPTURE
## SEQUENCE block above. While true it owns visibility/position/scale
## outright, same discipline as _intro_active, and is mutually exclusive
## with it by construction (_on_state_changed only ever sets one of the two,
## see below) -- PursuerFramingAudit.gd's per-frame sampling relies on that.
var _capture_active: bool = false
var _capture_t: float = 0.0
## Position/scale the lunge starts FROM -- captured once, the instant
## capture begins, from wherever the ordinary branch (or, for a strike-
## triggered capture, the strike's own lead cap) last left this node. Never
## a fixed constant like CAUGHT_Z: the lead is not guaranteed to have
## reached exactly CAUGHT_Z's own t=1.0 the frame capture starts (a strike
## caps the lead to STRIKE_PURSUER_LEAD_CAP_S, not to 0.0 directly), so
## snapping the lunge's start to a fixed pose could pop the mesh backward
## before lunging it forward again. Lerping from the REAL last pose makes
## the lunge a continuation of the approach the player was already
## watching, never a second entrance.
var _capture_start_z: float = FAR_Z
var _capture_start_x: float = 0.0
var _capture_start_y: float = 0.0
var _capture_start_scale: float = FAR_SCALE
## Same reasoning as the four above, applied to the eyes: a strike-triggered
## capture can land at any point along the ordinary branch's emission ramp
## (it does not have to be mid-lead-drain's own eventual peak), so the lunge
## has to ease FROM whatever value was actually showing, not from an assumed
## constant -- otherwise the eyes could pop brighter or dimmer on the very
## first frame of the lunge, the same class of bug the position/scale
## snapshot above exists to avoid.
var _capture_start_emission: float = 0.0

## Free-running animation phase. Reset every time the pursuer (re)appears so
## a fresh sighting always starts from the same pose rather than picking up
## mid-sway from a previous one.
var _anim_t: float = 0.0

## BODY IS UNSHADED (shading_mode = 0 in Pursuer.tscn), near-black, for the
## same reason Obstacle.gd's jump marker is: an unshaded material renders as
## exactly its albedo every frame regardless of light angle, which is the
## only way its post-inversion colour is a KNOWN value that can be verified
## ahead of time rather than merely observed. A lit body drifts with the
## DirectionalLight and its dark-mode contrast becomes unpredictable.
##
## Near-black specifically because the screen invert flips it to near-white,
## the highest luminance available on the other side of the shader -- which
## is what maximises separation from the ground in every dark palette. See
## scripts/dev/PursuerContrastAudit.gd for the measured result and for the
## structural ceiling this runs into.
##
## Per-instance material, duplicated once in _ready for the same reason
## Obstacle.gd duplicates its enemy materials: the scene defines it as a
## shared sub-resource, and animating a shared material would bleed into
## anything else that ever used it.
var _material: StandardMaterial3D
var _base_emission_energy: float = 0.0

func _ready() -> void:
	visible = false
	# The EYES' material is the animated one, not the body's -- see the
	# BODY IS UNSHADED note above: an unshaded material ignores emission
	# entirely, so the closing cue has to live somewhere that is still lit.
	var shared := _eye_left.get_surface_override_material(0) as StandardMaterial3D
	if shared:
		_material = shared.duplicate()
		_eye_left.set_surface_override_material(0, _material)
		_eye_right.set_surface_override_material(0, _material)
		_base_emission_energy = _material.emission_energy_multiplier
	GameState.pursuer_became_visible.connect(_on_became_visible)
	GameState.state_changed.connect(_on_state_changed)

## Fresh sighting: restart the animation so the entrance is always the same
## one. Visibility itself is driven every frame in _process (idempotent, and
## it means a state reset can never strand this node visible).
func _on_became_visible() -> void:
	_anim_t = 0.0

## Every start_run() emits this with State.PLAYING exactly once (see
## GameState.start_run) -- the one clean, edge-detected hook for "a run
## just began" that does not require this node to poll GameState.state
## itself every frame to notice a restart. Also the hook for the OTHER
## transition this node cares about, State.CAPTURED (see GameState.gd's
## _begin_capture_sequence) -- both arms are mutually exclusive writes to
## _intro_active/_capture_active, which is what guarantees _process below
## never has to choose between the two branches on the same frame.
func _on_state_changed(new_state: int) -> void:
	match new_state:
		GameState.State.PLAYING:
			_intro_active = true
			_capture_active = false
			_intro_t = 0.0
			_anim_t = 0.0
		GameState.State.CAPTURED:
			_intro_active = false
			_capture_active = true
			_capture_t = 0.0
			# Snapshot wherever the ordinary branch (or a strike's own lead
			# cap) last left this node -- see the vars' own doc for why the
			# lunge starts FROM this rather than from a fixed pose.
			_capture_start_z = position.z
			_capture_start_x = position.x
			_capture_start_y = position.y
			_capture_start_scale = scale.x
			if _material:
				_capture_start_emission = _material.emission_energy_multiplier
		_:
			# TITLE or GAME_OVER: neither special sequence owns this node,
			# and _process's own top-level guard (state != PLAYING) already
			# hides it every frame either state is active -- this just makes
			# sure a run that ends WHILE a sequence was mid-flight cannot
			# leave either flag stuck true for the next start_run() to
			# inherit by accident.
			_intro_active = false
			_capture_active = false

func _process(delta: float) -> void:
	if _capture_active:
		_process_capture(delta)
		return
	if GameState.state != GameState.State.PLAYING:
		visible = false
		_intro_active = false
		return
	if _intro_active:
		_process_intro(delta)
		return
	if not GameState.pursuer_visible:
		visible = false
		return
	visible = true
	_anim_t += delta

	# t: 0.0 at the visibility threshold, 1.0 at zero lead. Every visual
	# below is driven from this single progress value, so they can never
	# disagree about how close the thing is.
	var t := clampf(1.0 - GameState.pursuer_lead_s / GameState.PURSUER_VISIBLE_LEAD_S, 0.0, 1.0)

	# Z is derived from the LEAD, not integrated frame by frame -- the lead
	# is the state, and a position integrated alongside it would be a second
	# copy free to drift out of agreement with it.
	position.z = lerpf(FAR_Z, CAUGHT_Z, t)
	position.x = sin(_anim_t * TAU * SWAY_HZ) * SWAY_AMPLITUDE_X
	position.y = BOB_AMPLITUDE_Y * sin(_anim_t * TAU * BOB_HZ)

	var s := lerpf(FAR_SCALE, NEAR_SCALE, t)
	scale = Vector3(s, s, s)

	# The eyes brighten as it closes. Emission ENERGY rather than albedo, so
	# the cue is luminance and not hue -- it therefore reads the same under
	# all six dark palettes and in the light phase, which a colour shift
	# could not promise (see the shader's per-channel inversion). Both eyes
	# share one duplicated material, so this drives them together.
	if _material:
		_material.emission_energy_multiplier = lerpf(_base_emission_energy, _base_emission_energy * 3.0, t)

## Cubic Hermite smoothstep: 0 at t=0, 1 at t=1, and a derivative of exactly
## 0 at BOTH ends -- which is what makes the capture lunge below read as one
## continuous motion into whatever the ordinary lead-driven branch was doing
## the previous frame, rather than snapping onto a differently-shaped curve
## the instant capture begins.
func _smoothstep01(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

## The opening sighting. Held pose at FAR_Z/FAR_SCALE -- the exact framing
## PursuerFramingAudit already measures for the real "just became visible"
## moment, so this never needs its own occupancy check -- then a pure scale
## ease to zero. Shrinking can only ever REDUCE how much of the screen a
## fixed-position mesh covers, so the recede half of this curve is safe by
## construction once the held pose is: there is no way for it to end up
## bigger than what it started at.
func _process_intro(delta: float) -> void:
	_intro_t += delta
	if _intro_t >= INTRO_DURATION_S:
		_intro_active = false
		visible = false
		return
	visible = true
	_anim_t += delta

	position.z = FAR_Z
	position.x = sin(_anim_t * TAU * SWAY_HZ) * SWAY_AMPLITUDE_X
	position.y = BOB_AMPLITUDE_Y * sin(_anim_t * TAU * BOB_HZ)

	var hold_end := INTRO_DURATION_S * INTRO_HOLD_FRACTION
	var s := FAR_SCALE
	if _intro_t > hold_end:
		var recede_t := clampf((_intro_t - hold_end) / (INTRO_DURATION_S - hold_end), 0.0, 1.0)
		s = lerpf(FAR_SCALE, 0.0, recede_t)
	scale = Vector3(s, s, s)

	if _material:
		_material.emission_energy_multiplier = _base_emission_energy

## The capture lunge -- see the CAPTURE SEQUENCE block's doc up top. Eases
## (same _smoothstep01, so the transition INTO this from whatever the
## ordinary branch was doing the previous frame lands smoothly rather than
## snapping onto a new curve) from the pose captured at the instant capture
## began to CAPTURE_Z/CAPTURE_SCALE, over GameState.CAPTURE_SEQUENCE_DURATION_S
## -- read directly from GameState rather than a duplicate local constant,
## so the two can never fall out of sync. Sway/bob are NOT continued here:
## letting the lateral drift die out and the silhouette centre on the player
## is deliberate -- this is the one moment it stops merely pursuing and
## actually locks on, and a sequence built entirely of eases-toward-a-point
## is enough motion on its own without also fighting a live sine wave.
func _process_capture(delta: float) -> void:
	_capture_t += delta
	visible = true

	var t := clampf(_capture_t / GameState.CAPTURE_SEQUENCE_DURATION_S, 0.0, 1.0)
	var eased := _smoothstep01(t)

	position.z = lerpf(_capture_start_z, CAPTURE_Z, eased)
	position.x = lerpf(_capture_start_x, 0.0, eased)
	position.y = lerpf(_capture_start_y, 0.0, eased)

	var s := lerpf(_capture_start_scale, CAPTURE_SCALE, eased)
	scale = Vector3(s, s, s)

	if _material:
		_material.emission_energy_multiplier = lerpf(
			_capture_start_emission, _base_emission_energy * CAPTURE_EMISSION_MULTIPLIER, eased)
