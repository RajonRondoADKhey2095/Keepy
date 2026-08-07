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

@onready var _mesh: MeshInstance3D = $Silhouette
@onready var _eye_left: MeshInstance3D = $Silhouette/EyeLeft
@onready var _eye_right: MeshInstance3D = $Silhouette/EyeRight

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

## Fresh sighting: restart the animation so the entrance is always the same
## one. Visibility itself is driven every frame in _process (idempotent, and
## it means a state reset can never strand this node visible).
func _on_became_visible() -> void:
	_anim_t = 0.0

func _process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING or not GameState.pursuer_visible:
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
