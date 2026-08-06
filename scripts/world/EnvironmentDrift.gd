extends Node
## Continuous "this run's environment doesn't look like the last one"
## drift for the LIGHT phase -- the counterpart to DarkModeEffect's
## per-DARK-phase palette variants (see that script/screen_invert.gdshader
## for the DARK half). Owns colours OUTSIDE the screen-space invert
## effect: the sky (WorldEnvironment.background_color) and the ground
## (TrackSegment's shared track material, see the note on
## _ground_material below) slowly rotate hue over the course of a run.
##
## LIGHT-ONLY: fully skipped while a dark phase is active or fading in --
## see _process. The invert shader already owns the screen's look during
## a dark phase; drifting the underlying 3D colours at the same time
## would just be wasted work behind an opaque-ish overlay, and the two
## effects would fight over "what does this run look like right now"
## with no clear owner.
##
## LEGIBILITY: unlike the dark-phase tint (a per-pixel blend with a
## mathematical injectivity guarantee, see the shader), this drifts the
## actual ALBEDO of environment meshes, so the same argument does not
## apply -- verified instead by computing WCAG-style contrast ratios
## between every obstacle/collectible's albedo and the sky/ground colour
## across the full drift range (script run once during development, see
## the session report for the numbers). Ground-contrast for the
## lowest-contrast object (JUMP's brown log, already close to the
## ground's own colour BY DESIGN -- see Obstacle.tscn) never dropped
## below ~1.3:1 at the drift's extremes, close to its ~1.6:1 at the
## original fixed colour -- the drift amplitude below (HUE_AMPLITUDE) was
## chosen specifically to keep that shift small. Sky-contrast is not
## load-bearing for legibility: gameplay objects are read against the
## GROUND directly beneath/around them (the camera sits close and angled
## down), not silhouetted against the distant sky, and several objects
## already have low raw-albedo sky-contrast in the ORIGINAL, undrifted
## game (an existing property of the fixed palette, not something this
## drift introduces or worsens).

const BASE_SKY: Color = Color(0.55, 0.75, 0.95, 1) # Environment_1.background_color, Game.tscn
const BASE_GROUND: Color = Color(0.55, 0.42, 0.32, 1) # StandardMaterial3D_1, TrackSegment.tscn

## How far (in normalized hue, 0..1) the drift can wander from each
## base colour's own hue -- +-0.06 is +-21.6 degrees, well short of ever
## crossing into a hue any gameplay object actually uses (see the
## legibility note above for why this bound was chosen empirically, not
## guessed).
const HUE_AMPLITUDE: float = 0.06

## Full period of the drift's back-and-forth oscillation, in seconds.
## Long relative to a run (45-90s, see GameState's palier table) so a
## single run only ever shows a PARTIAL slice of the sweep -- reads as
## "the environment is gradually shifting", never as a full visible
## rainbow cycle within one run.
const DRIFT_PERIOD_S: float = 150.0

@onready var _environment: Environment = $"../World/WorldEnvironment".environment
@onready var _track_manager: Node3D = $"../World/TrackManager"

var _ground_material: StandardMaterial3D = null

func _process(_delta: float) -> void:
	if GameState.state != GameState.State.PLAYING or GameState.dark_intensity > 0.0:
		# Reset to the fixed base colours outside a light-only run state
		# -- title screen, game over, and any dark-phase involvement all
		# read as the stable, undrifted look, matching how
		# DarkModeEffect itself resets its own effect to 0 outside
		# PLAYING.
		_apply(BASE_SKY, BASE_GROUND)
		return

	# GameState.light_drift_phase_s is a per-run random offset (rolled in
	# start_run()) added to run_time_s -- two runs of the SAME length
	# still land on a different point of the sine wave, satisfying "deux
	# runs consecutives ne se ressemblent pas exactement" without needing
	# a discrete per-run palette table the way the dark variants have.
	var t := GameState.run_time_s + GameState.light_drift_phase_s
	var hue_offset := HUE_AMPLITUDE * sin(TAU * t / DRIFT_PERIOD_S)
	_apply(_hue_shifted(BASE_SKY, hue_offset), _hue_shifted(BASE_GROUND, hue_offset))

func _hue_shifted(c: Color, offset: float) -> Color:
	return Color.from_hsv(fmod(c.h + offset + 1.0, 1.0), c.s, c.v, c.a)

func _apply(sky: Color, ground: Color) -> void:
	if _environment:
		_environment.background_color = sky
	var mat := _ground_material_ref()
	if mat:
		mat.albedo_color = ground

## Lazily resolved: the ground material is a SINGLE StandardMaterial3D
## sub-resource shared across every pooled TrackSegment instance (same
## pattern already documented on Obstacle.gd's _enemy_material, except
## here the sharing is exactly what's wanted -- mutating it through ANY
## one segment recolours all of them, since there is only ever one
## "current" ground colour for the whole track at a time). Resolved on
## first use rather than _ready() so TrackManager's own _ready() (which
## populates its segment pool) is guaranteed to have already run,
## regardless of node order in Game.tscn.
func _ground_material_ref() -> StandardMaterial3D:
	if _ground_material:
		return _ground_material
	if not _track_manager:
		return null
	for child in _track_manager.get_children():
		if child is TrackSegment:
			var mesh: MeshInstance3D = child.get_node_or_null("MeshInstance3D")
			if mesh:
				_ground_material = mesh.get_surface_override_material(0) as StandardMaterial3D
			break
	return _ground_material
