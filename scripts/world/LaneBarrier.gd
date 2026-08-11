extends Node3D
class_name LaneBarrier
## The visible half of the temporary track shrink: a wall that rises out
## of the ground along the condemned lane, holds, then sinks again -- see
## GameState's TRACK SHRINK section for the mechanic and for why only an
## edge lane is ever condemned.
##
## OWNS NO TIMING AND NO RULES. Which lane is shut, and how far through
## the window we are, both live in GameState (shrink_lane /
## shrink_amount); this node is a dumb renderer of that state, exactly
## the split SwampAtmosphere.gd already uses for the mist breath. Nothing
## here decides anything a probe would need to re-derive.
##
## IT HAS NO COLLIDER, ON PURPOSE. The lane is made unavailable by
## Keepy.move_lane refusing to enter it and by TrackManager never
## spawning into it -- two rules, both checkable by reading them. Giving
## the wall a hitbox instead would have made "closed lane" a new way to
## DIE, which would have reached into the strike system, the death cause
## enum and the pursuer's own accounting; none of those are touched by
## this batch, and this is the decision that keeps it that way.
##
## POOLING: one instance for the whole run, declared in Game.tscn under
## World and never freed. It is repositioned and hidden, never
## re-instantiated -- the same contract every other node in the running
## loop honours. Its mesh and material are built once in _ready(), so
## nothing here allocates per frame either.
##
## It builds its own mesh in code rather than carrying a .tscn: that is
## what lets scripts/dev/DarkPaletteAudit.gd measure the real thing with
## a bare `LaneBarrier.new()`, instead of measuring a second copy of the
## geometry maintained alongside it.

## Lane pitch is 2.0m (TrackSegment.LANE_X); the wall is kept just under
## it so the two lanes it separates still read as distinct lanes rather
## than as one merged strip.
const WIDTH: float = 1.7
const HEIGHT: float = 2.4
## Long enough to run past the far end of the pooled track
## (TrackManager.SEGMENT_COUNT * SEGMENT_LENGTH = 140m) so the wall never
## visibly stops short of the horizon, plus the stretch behind the player
## that is still on screen.
const LENGTH: float = 170.0
## Z the box is centred on, so it spans from behind the player out past
## the furthest live segment.
const CENTER_Z: float = -75.0

## Y the wall sits at when fully closed. Half its height, i.e. its base
## exactly on the ground plane.
const RAISED_Y: float = HEIGHT * 0.5
## Y it sits at when fully open -- entirely below the ground plane, which
## is what hides it: the track's own ground mesh is opaque, so a buried
## wall needs no clipping, no alpha and no visibility flicker on the way
## down.
const BURIED_Y: float = -HEIGHT * 0.5

## Metres per light/dark stripe pair. Pushed INTO the shader in _ready
## rather than left to the shader's own uniform default, so this script
## is the single source of truth for the value it also has to wrap the
## scroll offset against -- reading the default back out with
## get_shader_parameter() would return null on a material that has never
## explicitly set it, which is exactly the case here.
const STRIPE_PERIOD: float = 2.4

var _mesh: MeshInstance3D
var _material: ShaderMaterial

func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(WIDTH, HEIGHT, LENGTH)
	_mesh.mesh = box
	_material = ShaderMaterial.new()
	_material.shader = load("res://assets/shaders/lane_barrier.gdshader")
	_material.set_shader_parameter("stripe_period", STRIPE_PERIOD)
	_mesh.set_surface_override_material(0, _material)
	_mesh.position = Vector3(0.0, 0.0, CENTER_Z)
	add_child(_mesh)
	visible = false

func _process(_delta: float) -> void:
	if GameState.state != GameState.State.PLAYING or not GameState.shrink_active():
		# A run that ends mid-window must not leave a wall standing on the
		# game over screen -- same reasoning as SwampAtmosphere's own
		# not-PLAYING branch.
		visible = false
		return
	visible = true
	position.x = TrackSegment.LANE_X[GameState.shrink_lane]
	# Eased rather than linear so the wall reads as being PUSHED up and
	# settling, instead of sliding at a constant rate -- the close is the
	# moment the player has to notice, so it earns the easing.
	var t := ease(GameState.shrink_amount, 0.45)
	position.y = lerpf(BURIED_Y, RAISED_Y, t)
	# Metres travelled, straight through: the stripes then move at exactly
	# the world's speed rather than at a rate that would have to be
	# re-tuned for every palier. Wrapped to the stripe period so the value
	# handed to the shader stays small on a long run instead of growing
	# without bound and losing float precision in fract().
	_material.set_shader_parameter("scroll", fmod(GameState.distance_travelled, STRIPE_PERIOD))
