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
## GameState.PURSUER_VISIBLE_LEAD_S. Kept a metre clear of the camera's own
## Z (7.0, see CameraFollow.offset) so it enters frame from the far edge
## rather than materialising on top of the lens.
const FAR_Z: float = 6.0
## Z at zero lead -- the player's own position, since that is what being
## caught means. The two ends of the lerp are therefore both meaningful
## rather than tuned: "at the camera" and "on top of you".
const CAUGHT_Z: float = 0.0

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
const FAR_SCALE: float = 1.0
const NEAR_SCALE: float = 2.2

@onready var _mesh: MeshInstance3D = $Silhouette
@onready var _eye_left: MeshInstance3D = $Silhouette/EyeLeft
@onready var _eye_right: MeshInstance3D = $Silhouette/EyeRight

## Free-running animation phase. Reset every time the pursuer (re)appears so
## a fresh sighting always starts from the same pose rather than picking up
## mid-sway from a previous one.
var _anim_t: float = 0.0

## Per-instance material, duplicated once in _ready for the same reason
## Obstacle.gd duplicates its enemy materials: the scene defines it as a
## shared sub-resource, and animating a shared material would bleed into
## anything else that ever used it.
var _material: StandardMaterial3D
var _base_emission_energy: float = 0.0

func _ready() -> void:
	visible = false
	var shared := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if shared:
		_material = shared.duplicate()
		_mesh.set_surface_override_material(0, _material)
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
	# could not promise (see the shader's per-channel inversion).
	if _material:
		_material.emission_energy_multiplier = lerpf(_base_emission_energy, _base_emission_energy * 3.0, t)
