extends Resource
class_name SwampPalette
## The swamp's shared colour identity, in one place, for every screen that
## has to look like the same marsh.
##
## =====================================================================
## WHAT THIS IS, AND WHAT IT DELIBERATELY IS NOT
##
## This is an EXTRACTION, not a redesign. Every value below is a byte-exact
## copy of what the shipped tree already renders -- the batch that created
## this file changed no colour, no density and no energy. If a future
## session finds a value here that disagrees with what the game draws, the
## bug is that something stopped reading this file, not that this file
## holds an opinion.
##
## It is also NOT a biome system. There is one swamp. Fields are named for
## the surface they colour, not for a theme slot, because a second palette
## would immediately re-open the question section 8 of docs/MESHY_SPEC.md
## exists to keep closed: which ground luminance every hazard contrast was
## measured against.
##
## =====================================================================
## WHY A RESOURCE AND NOT A CONSTANTS SCRIPT
##
## Two screens now draw this marsh -- Keepy Chased (scenes/Game.tscn) and
## the plateau hub (scenes/HubWorld.tscn) -- and they were authored months
## apart from copies of the same numbers. A .tres is the one form both a
## scene and a script can point at, and the one form an editor can show
## while it is being tuned.
##
## =====================================================================
## WHAT THIS FILE DOES NOT OWN, AND WHY (read before "finishing" it)
##
## Three sets of colours are DELIBERATELY still authored where they are:
##
##   1. scenes/Game.tscn's and scenes/TrackSegment.tscn's own literals.
##      scripts/dev/DarkPaletteAudit.gd reads those scenes through
##      PackedScene.get_state() and measures the values it finds there --
##      that is how the shipped baseline gets asserted without a running
##      game. Replacing those literals with runtime assignment would leave
##      the probe measuring whatever stub was left behind. The fields here
##      that mirror them (`ambient_light_color`, `ambient_light_energy`,
##      `sun_light_color`, `ground_albedo`) are therefore DECLARED, so this
##      file is a complete description of the palette, but the scenes stay
##      the thing that renders. Keeping them in step is a manual contract
##      until a probe is written to assert it.
##
##   2. scenes/Obstacle.tscn's hazard albedos. Those are the FALLBACK path
##      only: all six hazards ship a .glb whose baseColorFactor is what
##      actually draws, and CLAUDE.md's hazard sections require the
##      placeholder to mirror the asset exactly -- a placeholder that
##      diverged from its .glb is the "fixture that diverges from the real
##      thing" trap AlarmRampAudit exists to close. A .glb cannot read a
##      .tres, so moving only the placeholder half here would MANUFACTURE
##      that divergence.
##
##   3. scripts/hub/HubBuilder.gd's plateau prop colours. They are numerically
##      distinct from Chased's trackside props and are read by nothing else,
##      so they are hub-local, not shared identity.

# =====================================================================
# ATMOSPHERE -- the two ends of the mist breath.
#
# scripts/world/SwampAtmosphere.gd lerps between them on
# GameState.mist_intensity. The SHALLOW pair is also what
# scenes/Game.tscn's Environment ships, so the first frame of a run is
# correct with or without that node; the DEEP pair exists only here.

## Sky / background at mist_intensity 0. #0F1D0B.
@export var sky_shallow: Color = Color(0.062, 0.115, 0.044)

## Sky / background at mist_intensity 1. #091106.
##
## Deliberately CLOSE to the shallow value: the breath is a marsh exhaling,
## not a second look. A DEEP colour that reads as a different place is the
## phase system the permanent-swamp batch removed, growing back.
@export var sky_deep: Color = Color(0.035, 0.068, 0.024)

## Fog light colour at mist_intensity 0. #26421D.
@export var haze_shallow: Color = Color(0.151, 0.260, 0.114)

## Fog light colour at mist_intensity 1. #1B3014.
@export var haze_deep: Color = Color(0.107, 0.190, 0.080)

## Fog density at each end of the breath. fog_sky_affect is 0.0 and the
## gameplay zone sits within a few metres of the camera, so the breath
## moves the BACKDROP only and cannot reach the contrast of anything the
## player must react to -- which is why every figure in section 8 of
## docs/MESHY_SPEC.md holds at both ends by construction.
@export var fog_density_shallow: float = 0.0035
@export var fog_density_deep: float = 0.0052

# =====================================================================
# SCENE-AUTHORED VALUES -- declared here, rendered from the .tscn.
# See "WHAT THIS FILE DOES NOT OWN" above before wiring these up.

## Ambient light both scenes ship. Shared byte-for-byte by Chased and the
## hub, and the multiplier that turns every albedo below into the colour
## actually measured on screen.
@export var ambient_light_color: Color = Color(0.42, 0.5, 0.35)
@export var ambient_light_energy: float = 0.75

## scenes/Game.tscn's DirectionalLight3D colour.
@export var sun_light_color: Color = Color(0.66, 0.74, 0.52)

## scenes/TrackSegment.tscn's ground slab albedo, before the per-segment
## drift scripts/track/TrackSegment.gd adds. This is the surface every
## hazard contrast in section 8 is measured AGAINST, so it is the single
## most load-bearing colour in the project.
@export var ground_albedo: Color = Color(0.24, 0.46, 0.17)

# =====================================================================
# HUB ATMOSPHERE -- where scenes/HubWorld.tscn deviates, on purpose.
#
# The hub shares sky_shallow, ambient_light_color and ambient_light_energy
# with Chased. It does NOT share the fog: a plateau read from a fixed
# camera wants the haze to close the horizon much sooner than a track the
# player is running down, so it fogs toward the SKY colour at roughly
# 4.6x the density instead of toward the haze colour.

@export var hub_fog_light_color: Color = Color(0.062, 0.115, 0.044)
@export var hub_fog_density: float = 0.016

# =====================================================================
# TRACK DRESSING -- scripts/track/TrackSegment.gd.

## Lane curbs. The brightest thing on the slab; it is what gives the track
## its edge without lighting the scene.
@export var curb_color: Color = Color(0.475, 0.760, 0.380)

## The six trackside prop types, in the order TrackSegment weights them.
## All sit outside the 6m slab keep-out, so none of them is ever adjacent
## to a hazard the player has to read.
@export var prop_tree_trunk_color: Color = Color(0.070, 0.095, 0.070)
@export var prop_rock_color: Color = Color(0.140, 0.160, 0.135)
@export var prop_bush_color: Color = Color(0.105, 0.150, 0.100)
@export var prop_stump_color: Color = Color(0.200, 0.205, 0.140)
@export var prop_bench_color: Color = Color(0.275, 0.285, 0.195)
@export var prop_sign_color: Color = Color(0.340, 0.350, 0.255)

# =====================================================================
# BACKGROUND BILLBOARDS -- scripts/world/Decor.gd, multiplied into the
# source cutouts.
#
# Tinting the NEAR layer darkest is what keeps near/far/mountain reading as
# depth: the farther a layer sits, the more the fog lifts it anyway.

@export var decor_mountain_tint: Color = Color(0.274, 0.370, 0.244)
@export var decor_hill_far_tint: Color = Color(0.233, 0.340, 0.204)
@export var decor_hill_near_tint: Color = Color(0.177, 0.280, 0.151)

# =====================================================================
# CONTRAST THRESHOLDS -- the two numbers any new swamp colour must clear.
#
# These are DERIVED, not chosen. The ground renders at WCAG relative
# luminance L = 0.150 (docs/MESHY_SPEC.md section 8.4). Clearing a 3.0:1
# ratio against it therefore admits only two bands:
#
#     light:  (L + 0.05) / (0.150 + 0.05) >= 3.0  ->  L >= 0.549
#     dark:   (0.150 + 0.05) / (L + 0.05) >= 3.0  ->  L <= 0.0165
#
# NOTHING IN BETWEEN PASSES, AT ANY HUE -- that is the whole shape of this
# palette, and it is why hue alone can never rescue a mid-tone. Section 8.4
# also records that the dark ceiling is hue-dependent in V terms (0.136
# neutral grey, 0.166 at the rat's hue, 0.289 at saturated DODGE red), so
# solve in luminance, never in HSV value.
#
# NOT ASSERTED BY ANY PROBE TODAY. scripts/dev/DarkPaletteAudit.gd gates
# the MEASURED ratio against CONTRAST_FLOOR = 3.0 on rendered pixels, which
# is the stronger test; these two constants are the authoring-time shortcut
# that tells you a colour will fail before you render it.
@export var contrast_light_threshold: float = 0.549
@export var contrast_dark_threshold: float = 0.0165
