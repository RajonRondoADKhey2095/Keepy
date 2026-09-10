class_name SkateFeel
extends RefCounted
## CH62 -- THE ONE PLACE THE BOARD'S SPEED BECOMES A SENSATION.
##
## =====================================================================
## WHY THIS FILE EXISTS AT ALL, AND WHY IT IS NOT FOUR FILES
##
## CH61 gave the board a real velocity and measured it: 0.098 u climbed
## at 2.98 u/s against 1.106 u at 8.97 u/s on the same quarterpipe. The
## device verdict on that build was "je ne vois pas de difference". The
## physics was never the problem -- NOTHING ON SCREEN RESTITUED IT.
## CLAUDE.md has had the rule since CH53: une mecanique invisible n'existe
## pas pour le joueur.
##
## This lot adds four responses -- a camera that reacts, streaks at the
## edge of the frame, a rolling sound, a shadow that separates when the
## board leaves the ground. Every one of them is a function of ONE
## reading: how fast the board is going, as a fraction of its cruise.
##
## ⚠️ AND THAT READING IS PUBLISHED ONCE. CLAUDE.md: "un fait est publie
## une fois, jamais recopie". Four effects each carrying their own
## `speed / 10.0 clamped` would be four chances to disagree, and the
## disagreement would be invisible -- each effect is correct against
## itself, and CH46 already paid for a probe that can only ask each thing
## whether it is itself. One curve, four readers, and the probe gates the
## CURVE.
##
## =====================================================================
## THE SHAPE OF THE CURVE, AND WHY IT IS NOT A THRESHOLD
##
## The brief's constraint: "Doit s'intensifier continument avec la
## vitesse, pas s'allumer par palier." A threshold is what a player
## notices as an EFFECT; a continuous ramp is what they read as SPEED,
## because it is the only shape that has an answer at every velocity they
## can be travelling at.
##
## `rush()` is therefore a smoothstep between two paces:
##
##   * BELOW `RUSH_FLOOR` it is exactly zero. Not a taste: a board
##     trundling at a third of cruise is the pace a player uses to line
##     up a module, and dressing that up as speed would make the fast
##     reading mean less. The floor is what keeps the top of the range
##     legible.
##   * ABOVE `RUSH_CEIL` it is exactly one. The board CAN exceed cruise
##     -- down a transition, which is exactly when it is going fastest --
##     and an unbounded ramp would put the camera somewhere no probe
##     bounded and no frame budget priced.
##
## Smoothstep rather than a straight line because both ends are joins: at
## the floor the effects have to appear out of nothing rather than pop in
## at their first derivative, and at the ceiling a board oscillating
## around cruise would otherwise jitter every reader at once.
##
## =====================================================================
## WHAT IS DELIBERATELY *NOT* HERE
##
## No node, no state, no timer. Every function is pure and static, which
## is what lets a probe sweep the curve without building a world -- and
## what makes "the effect is wired to the speed" a thing a headless bench
## can actually prove. What a bench CANNOT prove is whether any of it
## feels good; that judgement is Mathieu's, on device, and the lot's
## report says so rather than dressing a monotonicity assertion up as an
## opinion about fun.

## Fractions of cruise. Below the floor nothing reads; above the ceiling
## everything is at full and stays there.
const RUSH_FLOOR: float = 0.32
const RUSH_CEIL: float = 1.00

## ---- what the CAMERA does with it (effect 1) ------------------------
## Extra distance BEHIND Keepy at full rush, in world units, added to
## HubCamera.OFFSET.z (8.9). A dolly, never a rotation: the hub camera's
## fixed basis is the reason the horizon does not bounce, and CH62 opens
## D6 by the smallest possible amount -- the frame keeps its shape and
## only its distance and its angle of view answer to the ride.
##
## ⚠️ 1.20 AND NOT 2.30, AND THE HONEST REASON IS NOT THE ONE THIS
## COMMENT FIRST GAVE.
##
## The first version of it said the dolly had been trimmed because
## `SkateFeelProbe` PHASE F priced it at +6 867 primitives against the
## fov's +1 488. THAT MEASUREMENT DID NOT SURVIVE ITS OWN BENCH. Once
## every pose was read through the shake protocol (see `_read_pose` --
## a frozen camera's cull set is not re-evaluated until it moves, and a
## repeat reading cannot see a stale value), the split came out +203 for
## the dolly and +1 460 for the fov against +8 165 for the two TOGETHER.
## The parts do not sum to the whole, the bench says so, and it prices
## the camera effect only as a whole.
##
## So the trim stands on a DESIGN argument and on a bound, not on a
## decomposition: a camera that moves BACK makes everything on screen
## SMALLER, which works against the sensation the effect exists to
## produce, and 1.20 u is enough for the small lean-back that says the
## frame is reacting at all. The whole camera effect costs about 8 200
## primitives and 16 draw calls at the measured station -- ~10 % of that
## frame -- and it is paid ONLY while somebody is riding behind the dev
## switch. The lot's report gives Mathieu the number and this constant.
const CAMERA_BACK: float = 1.20
## And UP, added to OFFSET.y (7.6). Together with the dolly this keeps the
## board at roughly the same place in frame while widening what is around
## it, which is the whole trick: what reads as speed is the SCENERY
## moving, so the effect has to put more scenery on screen.
const CAMERA_UP: float = 0.45
## Degrees added to the hub's fov (45). Small on purpose: a big fov pump
## is the runner-arcade tell the brief bans, and a wider frustum admits
## more of the park at exactly the station CH52 priced at zero. 6 deg on
## 45 is a 13 % wider picture -- enough that the edge of the frame
## streams, small enough that the plateau does not visibly bend. This is
## the term that does the WORK of the camera effect: what reads as speed
## is scenery in motion, and the fov is what puts more of it on screen
## without moving the board further away.
const CAMERA_FOV: float = 6.0
## What fraction of the board's height above the surface the camera
## climbs with. NOT 1.0: at 1.0 the board is pinned to one screen row and
## a climb reads as the world sinking, which is the same non-event as a
## camera that does not move at all. At 0.0 a 1.7 u peak moves the board
## 1.7 u up the frame and off the top of it. The value between them is
## what makes a climb read as a climb.
const CAMERA_LIFT_SHARE: float = 0.72
## Seconds-ish smoothing on the rush READING itself, before any reader
## sees it. The board's speed changes on a physics tick; a camera that
## followed it tick for tick would shake on every kerb.
const RUSH_LAMBDA: float = 3.2

## ---- what the STREAKS do with it (effect 2) -------------------------
## Peak alpha of the edge streaks.
##
## ⚠️ THIS IS THE ONE NUMBER IN THE LOT THAT A BENCH CANNOT CHOOSE, and
## it is deliberately the only place it is written. Too low and the lot
## repeats the defect it exists to fix -- CH61 was correct, measured and
## invisible. Too high and it is the runner-arcade tell the brief bans.
## ⚠️ AND IT WAS MEASURED RATHER THAN PICKED, TWICE. At 0.20 the field
## brightened the pixels it covers by a MEAN of 0.046 of full scale --
## about 5 % -- read off two captures of one frozen frame with the
## streaks shown and hidden. That is under the threshold of casual
## visibility, and a still frame confirmed it: nothing was there. The lot
## that exists because CH61 was correct and invisible must not ship its
## own invisible cue, so the doubt is resolved UPWARD here and only here.
##
## 0.28 over an ink coverage the probe measures at about 2.5 % of the
## frame, in a warm white, moving 1.35 screen-heights a second: legible
## in the corner of the eye, still soft in a screenshot. If it reads
## wrong on device, THIS CONSTANT IS THE WHOLE FIX and nothing else
## changes -- no other file names a streak intensity.
const STREAK_ALPHA: float = 0.28

## ---- what the SOUND does with it (effect 3) -------------------------
## The rolling loop is pitched and levelled by the RAW pace, not by
## `rush()`: a board rolling slowly still makes a noise, and silencing it
## below the floor would make the ride start with a click. The floor here
## is a speed, not a fraction, and it exists only so a parked board is
## silent.
const ROLL_SILENT_PACE: float = 0.02
const ROLL_PITCH_LOW: float = 0.62
const ROLL_PITCH_HIGH: float = 1.55
const ROLL_DB_LOW: float = -26.0
const ROLL_DB_HIGH: float = -9.0

## The landing cue. Its loudness follows the DOWNWARD speed at touchdown
## and not the height fallen: the two agree in free fall and disagree on
## a transition, where the board comes down a curved face and lands soft
## from high up. What a player hears is the impact, so the impact is what
## is measured.
##
## Below `LAND_FALL_MIN` there is no cue at all -- a board rolling over
## the seam between two modules technically leaves the floor for a tick,
## and a thud on every seam would turn the cue into a rattle.
const LAND_FALL_MIN: float = 1.60
const LAND_FALL_REF: float = 9.00
const LAND_DB_SOFT: float = -22.0
const LAND_DB_HARD: float = -7.0

## ---- what the SHADOW does with it (effect 4) ------------------------
## The blob shrinks and fades with height, which is what makes the gap
## read as ALTITUDE rather than as a shadow that came loose. Full size on
## the deck, floor size at HEIGHT_FULL and above.
##
## ⚠️ THE FADE IS DELIBERATELY SHALLOW, AND THAT IS A CORRECTION TO A
## FIRST VERSION THAT WAS PHYSICALLY RIGHT AND BACKWARDS AS A CUE.
## A real contact shadow softens as the body rises, so 0.30 down to 0.09
## looked like the obvious ramp -- until the blob was located on a
## captured frame at the top of a real jump (board at screen (540, 912),
## blob at (540, 1071), 159 px apart, which is the cue working) and read
## at alpha 0.112 over pale concrete, which is the cue being invisible AT
## EXACTLY THE MOMENT IT MATTERS MOST. The gap IS the message, and the
## message has to survive the height that produces the biggest gap.
##
## So the pair fades and shrinks enough to read as ALTITUDE -- without
## which a blob that stayed put would look like a decal that came loose
## -- and no further.
const SHADOW_HEIGHT_FULL: float = 2.20
const SHADOW_SCALE_MIN: float = 0.62
const SHADOW_ALPHA_NEAR: float = 0.34
const SHADOW_ALPHA_FAR: float = 0.20

## THE reading. `pace` is SkateBoardBody.pace() -- speed over cruise --
## and the answer is in [0, 1], zero at and below the floor, one at and
## above the ceiling, non-decreasing everywhere and strictly increasing
## between them.
static func rush(pace: float) -> float:
	var t: float = clampf((pace - RUSH_FLOOR) / (RUSH_CEIL - RUSH_FLOOR), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## The camera's extra offset, in the same frame as HubCamera.OFFSET. `lift`
## is how far the board is above HubSurface, in world units; it is passed
## in rather than read here because this file owns no node and reads no
## world.
static func camera_offset(r: float, lift: float) -> Vector3:
	return Vector3(0.0, CAMERA_UP * r + CAMERA_LIFT_SHARE * maxf(lift, 0.0), CAMERA_BACK * r)

static func fov_gain(r: float) -> float:
	return CAMERA_FOV * r

static func streak_alpha(r: float) -> float:
	return STREAK_ALPHA * r

## Pitch of the rolling loop. Linear in pace and NOT in `rush()`: pitch is
## the term a player hears as speed directly, and a floor in it would make
## the board sound like it changes gear.
static func roll_pitch(pace: float) -> float:
	var t: float = clampf(pace, 0.0, 1.4) / 1.4
	return lerpf(ROLL_PITCH_LOW, ROLL_PITCH_HIGH, t)

static func roll_volume_db(pace: float) -> float:
	var t: float = clampf(pace, 0.0, 1.0)
	return lerpf(ROLL_DB_LOW, ROLL_DB_HIGH, t)

static func roll_audible(pace: float) -> bool:
	return pace > ROLL_SILENT_PACE

static func land_audible(fall: float) -> bool:
	return fall >= LAND_FALL_MIN

static func land_volume_db(fall: float) -> float:
	var t: float = clampf((fall - LAND_FALL_MIN) / (LAND_FALL_REF - LAND_FALL_MIN), 0.0, 1.0)
	return lerpf(LAND_DB_SOFT, LAND_DB_HARD, t)

## Blob shadow, as a function of the board's height above the surface.
static func shadow_scale(lift: float) -> float:
	var t: float = clampf(maxf(lift, 0.0) / SHADOW_HEIGHT_FULL, 0.0, 1.0)
	return lerpf(1.0, SHADOW_SCALE_MIN, t)

static func shadow_alpha(lift: float) -> float:
	var t: float = clampf(maxf(lift, 0.0) / SHADOW_HEIGHT_FULL, 0.0, 1.0)
	return lerpf(SHADOW_ALPHA_NEAR, SHADOW_ALPHA_FAR, t)

## Frame-rate independent smoothing, in the exponential form HubCamera
## already uses -- so a 30 fps phone and a 60 fps one settle at the same
## rate rather than the phone lagging twice as far behind.
static func smooth(current: float, wanted: float, delta: float) -> float:
	return lerpf(current, wanted, 1.0 - exp(-RUSH_LAMBDA * delta))
