extends Node
class_name DepthFog
## Fades Environment.fog_density -- the DEPTH-fog band's maximum opacity,
## see Game.tscn's fog_mode = Depth / fog_depth_begin / fog_depth_end --
## toward a much heavier "swamp murk" value as GameState.dark_intensity
## rises. This is the ONLY thing this file owns.
##
## SCOPE, DELIBERATELY NARROW, SAME SPLIT AS NightSky.gd AND
## DarkModeEffect.gd: this does NOT touch fog_light_color or
## background_color (NightSky.gd's exclusive territory, see that file's
## own header) and it does NOT touch fog_mode / fog_depth_begin /
## fog_depth_end / fog_depth_curve (Game.tscn's static, load-time-only
## values -- see WHY THOSE STAY CONSTANT below). One script writes the
## fog's COLOUR every frame, this one writes its INTENSITY every frame,
## and a third (DarkModeEffect.gd) writes the separate full-screen
## invert/tint on top of the composited frame both of them fed into.
## Three files, three disjoint property sets, one shared clock
## (GameState.dark_intensity) -- the same decoupling this project already
## uses, not a new pattern invented for this feature.
##
## WHY fog_depth_begin / fog_depth_end / fog_depth_curve STAY CONSTANT,
## NEVER TOUCHED BY THIS OR ANY OTHER SCRIPT: those three numbers are
## what GUARANTEES a track obstacle is never fogged before the player's
## reaction window opens. Measured, not assumed: TrackManager pools
## SEGMENT_COUNT=7 segments of SEGMENT_LENGTH=20m each (see
## TrackManager.gd), so the farthest any obstacle can ever sit is
## Z=-120; CameraFollow sits at a fixed Z=+7 (Keepy never advances on Z,
## see TrackManager.gd's own class doc) and never drifts in Z (its own
## screen shake is applied through h_offset/v_offset, not position --
## see CameraFollow.gd's header). That puts the single worst-case
## camera-to-obstacle distance at sqrt(4.2^2 + 127^2) ~= 127.07m -- the
## Pursuer stays far closer still, confined to [Pursuer.CAUGHT_Z,
## Pursuer.FAR_Z] = [1.0, 3.0], a few metres from the camera. Game.tscn's
## fog_depth_begin = 150.0 sits ~23m past that 127.07m worst case with
## margin to spare, so the actual on-screen fog contribution
## (drivers/gles3/shaders/scene.glsl: fog_amount =
## pow(smoothstep(fog_depth_begin, fog_depth_end, dist), fog_depth_curve)
## * fog_density) is EXACTLY, provably zero anywhere a hazard, a
## collectible or the pursuer can ever be -- not "small", zero, and a
## fact readable straight off the .tscn on frame one, true regardless of
## whether any script here runs correctly. Letting fog_depth_begin (or
## _end, or the density it is being lerped against) be a value THIS
## script fades at runtime would turn that guarantee into an invariant a
## per-frame lerp has to uphold forever instead of a fact of the scene
## file -- so only fog_density (how heavy the murk gets PAST that
## boundary, never where the boundary itself sits) is allowed to move.
##
## Lives on its OWN Node (a sibling of WorldEnvironment under World in
## Game.tscn) rather than on NightSky.gd, which already sits on
## WorldEnvironment itself: a Godot node carries at most one script, so
## a second WorldEnvironment-owning script is not an option. Same shape
## DarkModeEffect.gd already uses for its own CanvasLayer sibling.

## On-screen swamp-night target: a much heavier depth fog than the
## day/light-phase baseline read from the scene, so the horizon and
## distant decor (Decor.gd's hill_near/hill_far/mountain layers, all
## beyond fog_depth_end -- see that file's own spawn_z bands) sink
## toward near-total murk during a dark phase. Not fully opaque (1.0): a
## hard wall of flat colour reads as a bug, not weather -- same "still
## legible, not flattened" principle DarkModeEffect.gd's own header
## argues for a different property. First pass, to be judged on a real
## capture, not assumed correct from the number alone -- same discipline
## NightSky.gd's own header holds itself to for its two colours.
const NIGHT_FOG_DENSITY: float = 0.92

@onready var _world_environment: WorldEnvironment = $"../WorldEnvironment"

var _env: Environment
var _day_density: float

func _ready() -> void:
	if not _world_environment:
		return
	_env = _world_environment.environment
	if not _env:
		return
	# DAY VALUE READ FROM THE SCENE, NEVER HARDCODED HERE -- same reason
	# as NightSky.gd's _day_sky/_day_fog: at dark_intensity == 0 this
	# script must reproduce EXACTLY what Game.tscn already ships, so the
	# .tscn stays the single source of truth for the baseline.
	_day_density = _env.fog_density

func _process(_delta: float) -> void:
	if not _env:
		return
	if GameState.state != GameState.State.PLAYING:
		# Mirror NightSky.gd / DarkModeEffect.gd's own rule: a run that
		# ends mid-dark-phase must not leave the heavy swamp murk burned
		# into the title / game over screens.
		_env.fog_density = _day_density
		return
	_env.fog_density = lerpf(_day_density, NIGHT_FOG_DENSITY, GameState.dark_intensity)
