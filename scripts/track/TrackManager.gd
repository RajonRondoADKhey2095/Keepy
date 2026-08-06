extends Node3D
class_name TrackManager
## Spawns track segments ahead of the player and recycles them once
## they pass behind -- a fixed-size object pool, never queue_free() /
## re-instantiate in the running loop.
##
## Architecture note -- the WORLD moves toward the static player
## instead of the player moving through the world. Keepy never
## advances on Z (see Keepy.gd); every frame this script instead
## nudges each TrackSegment's Z position toward the player by the
## current run speed. This keeps every moving Node3D's coordinates
## bounded to a small range around the origin forever, which avoids
## the floating point precision loss a genuinely unbounded player
## Z coordinate would eventually introduce (visible transform jitter
## after enough kilometers of "real" travel on a 32-bit float). It
## also means recycling a segment is just "move it back to the front
## and repopulate its contents" -- no allocation, no destruction.

const SEGMENT_SCENE: PackedScene = preload("res://scenes/TrackSegment.tscn")
const SEGMENT_LENGTH: float = 20.0
# GameState.MAX_LOOKAHEAD_S restates SEGMENT_COUNT * SEGMENT_LENGTH /
# BASE_SPEED as a literal (not a reference to these two constants) to
# avoid an autoload taking a compile-time dependency on this plain scene
# script -- if either of these two ever changes, that constant's comment
# is where to also update.
const SEGMENT_COUNT: int = 7
const RECYCLE_Z: float = 12.0 # segment behind the player past this Z gets recycled
const SAFE_START_SEGMENTS: int = 2 # no obstacles on the first N segments of a run

# =====================================================================
# ADAPTIVE OBSTACLE SPACING -- the whole reason the speed cap can be
# raised without the track turning into an unreadable wall.
#
# Obstacles sit on a fixed 20m grid (one per TrackSegment), so at a
# constant spawn probability the time between two of them shrinks in
# direct proportion to the run speed. Measured on the real scene, two
# adjacent rows leave the player 20/26 = 0.77s at the cap, of which the
# lane switch itself eats 0.25s -- 0.52s to actually read the next
# obstacle and commit. That is the number that makes a fast runner feel
# cheap rather than fast.
#
# The fix is spacing, not a lower cap: the minimum gap is expressed in
# SECONDS and converted to a number of rows against the current speed,
# so the track physically opens up as the run accelerates.
# =====================================================================

## Time the player is guaranteed to still have, once the previous
## obstacle has passed them, to READ the next one and commit to a lane --
## ON TOP of the time the lane switch itself then takes. The single knob
## for "how fair does the track feel"; raising it thins the track at
## speed, lowering it packs it tighter.
##
## LOWERED from 0.6 to 0.55 (playtest-fixes batch, chantier 4: "encore
## un cran de difficulte" + the mid-palier density dip already noted
## below on OBSTACLE_CHANCE_CAP). This is the ~0.55 the task's own
## difficulty knob points at, not a number picked in isolation -- see
## MIN_OBSTACLE_GAP_S for what it actually changes. Re-verified after
## the change (scripts/dev/PacingAudit.gd) that the worst-case reaction
## budget stays positive at every palier including the cap -- see that
## constant's own measured numbers in the commit message for this batch;
## a reaction budget of 0.55s is still comfortably above the ~0.1s
## PERCEPTION_REACTION_S floor Obstacle.gd's own ENEMY encounter uses,
## so this is not pushing the track into "impossible", only "tighter".
const OBSTACLE_REACTION_BUDGET_S: float = 0.55

## Minimum time that must therefore separate two consecutive obstacles,
## perception budget plus the lane switch's own travel time. Stated in
## seconds (never in metres) for exactly the same reason as
## Obstacle.ENEMY_REACTION_WINDOW_S: a fixed metre value would silently
## become a shorter and shorter reaction window as the speed table ramps.
const MIN_OBSTACLE_GAP_S: float = Obstacle.LANE_SWITCH_TIME_S + OBSTACLE_REACTION_BUDGET_S

## Spawn probability of an ELIGIBLE row (one far enough behind the last
## obstacle to be allowed one at all), lerped over
## GameState.BASE_SPEED..MAX_SPEED.
##
## It rises with speed to COMPENSATE the enforced gap above, not to add
## difficulty on top of it: once the minimum gap crosses one row, every
## other row becomes ineligible and a flat low chance would leave the
## late game emptier than the early game -- the spacing fix would have
## quietly made the hard part easier.
##
## RAISED from 0.55/0.85 to 0.60/0.90 alongside OBSTACLE_REACTION_BUDGET_S's
## drop to 0.55 (chantier 4, "encore un cran de difficulte") -- and the
## SAME budget drop also NARROWS the mid-ramp density dip this pair
## exists to compensate for, not just independently of it. MEASURED
## before/after with scripts/dev/PacingAudit.gd (never hand-derived from
## the formula alone -- GameState.lookahead_speed() means a row's actual
## spacing can be laid out for a LATER, faster palier than the one it
## visually sits in, which makes the raw "gap crosses one row at speed
## X" arithmetic an unreliable predictor on its own):
##
##   palier speed   OLD mean gap (0.6/0.55/0.85)   NEW mean gap (0.55/0.60/0.90)
##   ------------   -----------------------------   ------------------------------
##   20.5 m/s        1.300s                          1.628s
##   22.5 m/s        2.225s  <- the dip                0.889s  <- dip gone
##   24.0 m/s        1.675s                          0.837s
##   25.0 m/s        1.606s                          1.604s  <- unchanged, see below
##   26.0 m/s (cap)  1.724s                          1.648s
##
## Paliers 22.5 and 24.0 m/s were sparser than BOTH their neighbours
## under the old constants (the "dip" -- 22.5 m/s in particular, at
## 2.225s, was the single sparsest palier in the whole ramp, sparser even
## than 18.0 m/s at the START of the run). The lower reaction budget
## shrinks MIN_OBSTACLE_GAP_S enough that these two paliers stay in the
## cheaper 1-row spacing regime instead of prematurely falling into
## 2-row spacing, and they are now the DENSEST paliers in the entire
## ramp (0.889s / 0.837s) rather than the sparsest -- the dip is
## eliminated, not just narrowed. 25.0 m/s stays unchanged: it was
## ALREADY being spaced for the cap's speed via lookahead before this
## batch (its whole 7.5s palier duration sits inside
## GameState.MAX_LOOKAHEAD_S, ~11.7s, so rows populated anywhere in it
## are laid out at-or-near 26 m/s regardless of the budget knob), so
## thinning now genuinely only affects the last two speed steps of the
## ramp instead of the last three. See the commit message for the full
## PacingAudit output (min gap / min budget per palier, not just the
## means above).
const OBSTACLE_CHANCE_BASE: float = 0.60
const OBSTACLE_CHANCE_CAP: float = 0.90

# =====================================================================
# RUSH EVENTS (playtest-fixes-2 batch) -- OBSTACLE_CHANCE_BASE/_CAP above
# already ramp with speed, but that is a CONTINUOUS climb: nothing about
# it reads as a distinct moment the player can point to afterward, just
# one long escalating grind (playtest: "difficulte diffuse qui ne marque
# pas"). This layers a TEMPORARY density spike on top of that continuous
# ramp, independent of which speed palier happens to be active: a brief
# RUSH (denser than the palier's own baseline) always followed by a brief
# CALM (sparser than baseline) gives the run distinct PEAKS instead of a
# flat climb.
#
# SAFETY: a rush can only raise the PROBABILITY that an already-ELIGIBLE
# row spawns an obstacle (the multiplier scales _obstacle_chance()'s
# output, see that function) -- it NEVER touches MIN_OBSTACLE_GAP_S /
# _required_gap_rows(), and therefore never touches the reaction time
# ENEMY_REACTION_WINDOW_S already guarantees either (the gap already
# accounts for it, see MIN_OBSTACLE_GAP_S's own doc). The probability is
# also hard-clamped to 1.0 (_obstacle_chance() below), so "every eligible
# row gets one" -- exactly the ceiling the gap rule already allows on its
# own -- is the densest a rush can ever get. There is no multiplier value
# large enough to spawn MORE obstacles than the gap rule permits; clamping
# the probability IS "plafonner le multiplicateur" the task asks for, it
# just falls out of the chance formula already being a probability.
# =====================================================================

## No rush before this much run time has elapsed -- the player's own
## "taking its bearings" window (task's explicit ask: no rush in the
## first 15-20s). Independent of LOW_DENSITY_LAST_STAGE_INDEX above on
## purpose: a rush is keyed to TIME, paliers are keyed to SPEED, and a
## rush must be able to land at ANY palier once eligible, not just once a
## particular speed is reached.
const RUSH_MIN_START_S: float = 18.0

## A RUSH window's duration is drawn uniformly from this range EACH TIME
## one starts (not a fixed value) -- see the section header for why: no
## two runs, and no two rushes within the same run, should be
## memorizable by their timing.
const RUSH_DURATION_MIN_S: float = 5.0
const RUSH_DURATION_MAX_S: float = 8.0

## The CALM window that always follows a rush -- same per-occurrence
## random duration as the rush itself.
const CALM_DURATION_MIN_S: float = 2.0
const CALM_DURATION_MAX_S: float = 3.0

## Once a calm window ends, how long the run waits (drawn per-occurrence,
## same reasoning as above) before the NEXT rush is even eligible to
## start. Without this, rushes could chain back-to-back into one long
## "rush" in every way that matters, defeating the point of a rush being
## a distinct, bounded event with breathing room on either side.
const RUSH_COOLDOWN_MIN_S: float = 4.0
const RUSH_COOLDOWN_MAX_S: float = 10.0

## Obstacle-chance multiplier applied for the duration of a RUSH window --
## a RANGE, drawn once per rush, not a single fixed value (same
## per-occurrence variation as the durations above).
const RUSH_CHANCE_MULT_MIN: float = 1.8
const RUSH_CHANCE_MULT_MAX: float = 2.2

## Obstacle-chance multiplier applied for the duration of a CALM window --
## deliberately BELOW 1.0 so calm reads as a genuine dip under the
## palier's own baseline, not just "the rush ended, back to normal".
const CALM_CHANCE_MULT: float = 0.45

# =====================================================================
# AIR_ENEMY <-> JUMP / GLAND SEPARATION -- AIR_ENEMY sits at the exact
# same height as a Gland and shares its lane with whatever JUMP obstacle
# happens to be nearby, so it is the first hazard whose fairness depends
# on ANOTHER ROW's content, not just its own. See Obstacle.gd
# Type.AIR_ENEMY for what it does; the two conflicts this section guards
# against are both "the player is forced to jump into it with no way to
# have seen it coming":
#   - a JUMP obstacle (which REQUIRES a jump to clear) landing too close,
#     on the same lane, to an AIR_ENEMY (which PUNISHES a jump) -- the
#     player would be forced to jump into the very thing that kills them;
#   - a Gland (which REQUIRES a jump to reach) landing too close, on the
#     same lane, to an AIR_ENEMY the player had no time to notice yet.
# Distinct lanes at the same Z are the OPPOSITE of a problem -- "do I
# switch lanes for the Gland, or stay safe" is exactly the interesting
# decision this obstacle exists to create -- so this rule is scoped to
# the SAME lane only, never across lanes.
# =====================================================================

## Minimum TIME that must separate an AIR_ENEMY obstacle from a JUMP
## obstacle or a Gland occupying the SAME lane, on either side (earlier
## or later -- generation is strictly sequential row by row, so whichever
## of the two is placed SECOND is always the one that can see the other
## and back off). Reuses OBSTACLE_REACTION_BUDGET_S (the ground track's
## own "time left to read and commit" budget) doubled: these two hazards
## sit higher up the screen than a ground obstacle and are read at a
## glance rather than dead ahead, so they need more margin to be told
## apart, not less. Converted to rows the same seconds-not-metres way as
## MIN_OBSTACLE_GAP_S, so it stays a constant amount of REACTION time
## across the whole speed ramp instead of shrinking as the run speeds up.
const AIR_HAZARD_SEPARATION_S: float = OBSTACLE_REACTION_BUDGET_S * 2.0

# =====================================================================
# PROGRESSIVE LANE FILL (playtest-fixes-2 batch) -- the map was already
# using close to its full width at the LOWEST speed palier, which capped
# perceived difficulty early and then made the rest of the ramp feel flat
# ("il faut la remplir au fur et a mesure" playtest note). MEASURED before
# this change via scripts/dev/LaneFillAudit.gd (150 resets, ~54k physics
# frames sampled, all within palier 0 / 12 m/s): 2 DISTINCT lanes already
# carried an active obstacle SIMULTANEOUSLY 50.9% of the time, and ALL 3
# lanes 39.5% of the time -- the track already read as "full width" before
# the run had ramped up at all.
#
# The fix caps how many DISTINCT lanes may carry an active obstacle AT THE
# SAME TIME across the whole pooled track (SEGMENT_COUNT rows, ~140m
# ahead), tiered by which palier a row is laid out for (GameState.
# lookahead_stage_index(), same look-ahead every other spacing rule in
# this file already uses -- a row is spawned well before the player
# reaches it, so the cap must be sized for the SPEED IT WILL BE MET AT,
# not the speed at spawn time).
#
# Scoped to the DETERMINISTIC, spawn-time lane picks only (DODGE, JUMP,
# AIR_ENEMY's FLIGHT lane) -- never to ground ENEMY's or AIR_ENEMY's own
# LATE lock/landing-lane decision (Obstacle._resolve_late_lock /
# _resolve_air_enemy_landing_lane). Those two are deliberately player-
# TARGETED at a moment TrackManager cannot predict (see their own docs);
# forcing them to respect a lane-fill cap picked at spawn time would mean
# sometimes NOT locking onto the player's actual lane, which would defeat
# the mechanic outright rather than merely make the track look fuller.
# They are also, empirically, a small contributor to the measured
# baseline above: ENEMY only sits on a discrete lane_x once locked (mid-
# sway, its position is excluded from "occupies a lane" by construction,
# same exclusion LaneFillAudit.gd applies), and that locked window is a
# fraction of a second before contact -- the 50.9%/39.5% baseline is
# overwhelmingly DODGE/JUMP/AIR_ENEMY-in-flight, all long-lived and all
# in scope here.
# =====================================================================

## Palier index (0-based into GameState.STAGE_SPEEDS) at or below which a
## row is generated under the STRICTER cap (MAX_ACTIVE_LANES_EARLY) --
## covers the first three paliers, 12/15/18 m/s: the run's own "taking
## its bearings" window (task's explicit ask: "les 2-3 premiers paliers").
const LOW_DENSITY_LAST_STAGE_INDEX: int = 2

## Maximum DISTINCT lanes allowed to carry an active obstacle at once,
## for a row laid out at LOW_DENSITY_LAST_STAGE_INDEX or below -- always
## leaves at least 2 of the 3 lanes clear, so the run visibly has
## somewhere to escalate TO as it speeds up.
const MAX_ACTIVE_LANES_EARLY: int = 1

## Maximum DISTINCT lanes allowed to carry an active obstacle at once,
## for every palier AFTER LOW_DENSITY_LAST_STAGE_INDEX -- held at 2 for
## the REST of the run, deliberately never raised to 3: "full width
## blocked" removes the one guaranteed-clear lane a jump-vs-switch choice
## needs to stay a CHOICE rather than a coin flip on whether an escape
## exists at all (AntiFrustrationAudit.gd's per-frame guarantee already
## proves an escape is always there regardless, but standing at "every
## lane already has something coming" reads as unfair even when it
## technically isn't). Task's explicit ask: never touch the 3rd lane.
const MAX_ACTIVE_LANES_LATE: int = 2

# Relative weights for which Obstacle.Type spawns when an obstacle spawns
# at all. DODGE and JUMP stay the bulk of the spawn table; ENEMY (moving,
# forces a late reaction) and AIR_ENEMY (punishes a jump, see Obstacle.gd
# Type.AIR_ENEMY) are rarer additional variants, not a replacement -- kept
# EQUALLY rare as each other so neither one saturates the track. Must sum
# to 1.0.
const DODGE_TYPE_CHANCE: float = 0.40
const JUMP_TYPE_CHANCE: float = 0.40
const ENEMY_TYPE_CHANCE: float = 0.10
# AIR_ENEMY_TYPE_CHANCE is implicitly 1.0 - the three above (0.10) -- see
# _pick_obstacle_type(). Kept as a remainder rather than a fourth named
# constant so the four weights can never silently drift out of summing
# to 1.0 by editing one and forgetting to compensate another.

# Chance of a noisette appearing at all in a segment. Only ONE lane is
# ever picked per segment (see TrackSegment.populate) -- Keepy can only
# be on one lane at a time, so this is no longer "per lane".
# Was 0.5. The one-noisette-per-row cap (TrackSegment.populate, previous
# fix) mechanically halved the ceiling on noisettes per row (two lanes
# could show one each before that cap), and roughly a third of remaining
# rolls are further dropped when the picked lane collides with the
# obstacle's lane (obstacle wins, see populate) -- both silently thin out
# the total count. Bumped to 0.85 to bring the actual per-run pickup
# density back in line with what it was before the cap.
const NOISETTE_CHANCE_PER_ROW: float = 0.85
# Gland is a rarer bonus than the ground noisette (it also requires jump
# timing to reach, see Gland.gd/TrackSegment.GLAND_Y) -- deliberately kept
# well below NOISETTE_CHANCE_PER_ROW.
const GLAND_CHANCE_PER_ROW: float = 0.12

var _segments: Array[TrackSegment] = []

## Distance, IN ROWS, from the row currently being populated back to the
## last row that got an obstacle -- so it is directly comparable to
## _required_gap_rows() with no off-by-one to get wrong: 1 means "the
## previous row had one", not "zero rows have passed since". Starts at
## SEGMENT_COUNT, which reads as "no obstacle anywhere behind us".
##
## Segments are always populated in the order the player will meet them
## (at reset front to back, and mid-run one at a time as each recycles to
## the far end), so this single counter is enough to space a stream of
## rows -- no per-segment bookkeeping, no allocation.
var _rows_to_last_obstacle: int = SEGMENT_COUNT

# Same idea as _rows_to_last_obstacle above, but PER LANE and per hazard
# kind, for the AIR_ENEMY <-> JUMP / Gland separation rule (see
# AIR_HAZARD_SEPARATION_S). Index-aligned with TrackSegment.LANE_X (3
# lanes); fixed-size arrays allocated once here, never resized in the
# game loop. _NO_RECENT_HAZARD is a sentinel comfortably larger than any
# real separation gate, reading as "nothing recent on this lane" --
# same spirit as _rows_to_last_obstacle's SEGMENT_COUNT start value.
const _NO_RECENT_HAZARD: int = 9999
var _rows_since_jump_on_lane: Array[int] = [_NO_RECENT_HAZARD, _NO_RECENT_HAZARD, _NO_RECENT_HAZARD]
var _rows_since_air_enemy_on_lane: Array[int] = [_NO_RECENT_HAZARD, _NO_RECENT_HAZARD, _NO_RECENT_HAZARD]
var _rows_since_gland_on_lane: Array[int] = [_NO_RECENT_HAZARD, _NO_RECENT_HAZARD, _NO_RECENT_HAZARD]

# RUSH EVENTS state -- see the section header above. Defaults here match
# reset()'s own values: _ready() populates the initial segments BEFORE
# Game.gd ever calls reset() (see _ready() below), so these must already
# be sane on first use, not just after a reset.
enum DensityPhase { NORMAL, RUSH, CALM }
var _density_phase: DensityPhase = DensityPhase.NORMAL
## Multiplier _obstacle_chance() applies on top of the palier-derived
## base chance -- 1.0 outside a rush/calm window, see _enter_rush/_enter_calm.
var _density_multiplier: float = 1.0
## Run time (GameState.run_time_s) at which the CURRENT rush or calm
## window ends -- meaningless while _density_phase == NORMAL.
var _density_phase_ends_at_s: float = 0.0
## Run time at or after which the NEXT rush is allowed to start -- also
## doubles as the "no rush before RUSH_MIN_START_S" guard at the start of
## a run, since it is initialised to that same constant.
var _next_rush_eligible_s: float = RUSH_MIN_START_S

func _ready() -> void:
	# Looked up by group (Obstacle.gd's ground ENEMY late lock, see
	# _resolve_late_lock / lane_has_conflicting_jump_hazard below) rather
	# than a NodePath -- an Obstacle instance has no fixed relationship to
	# the TrackManager that pools it in the scene tree.
	add_to_group("track_manager")
	for i in SEGMENT_COUNT:
		var segment: TrackSegment = SEGMENT_SCENE.instantiate()
		add_child(segment)
		segment.position = Vector3(0.0, 0.0, -float(i) * SEGMENT_LENGTH)
		_segments.append(segment)
		_populate_segment(segment, i)

func _physics_process(delta: float) -> void:
	if GameState.state != GameState.State.PLAYING:
		return

	_update_density_phase(GameState.run_time_s)

	# THE WORLD's own speed, and the only thing this loop moves. An
	# element that closes on the player faster than the world does adds
	# its own displacement on top of this, from its own _physics_process,
	# never by having this loop treat its segment differently -- see
	# Obstacle.gd's CLOSING SPEED section header.
	var move_amount := GameState.current_speed * delta
	GameState.add_distance(move_amount)

	for segment in _segments:
		segment.position.z += move_amount
		if segment.position.z > RECYCLE_Z:
			_recycle_segment(segment)

## Called by Game.gd when a new run starts (fresh game or retry) so the
## track always looks the same at the starting line.
func reset() -> void:
	_rows_to_last_obstacle = SEGMENT_COUNT
	_density_phase = DensityPhase.NORMAL
	_density_multiplier = 1.0
	_density_phase_ends_at_s = 0.0
	_next_rush_eligible_s = RUSH_MIN_START_S
	for lane in 3:
		_rows_since_jump_on_lane[lane] = _NO_RECENT_HAZARD
		_rows_since_air_enemy_on_lane[lane] = _NO_RECENT_HAZARD
		_rows_since_gland_on_lane[lane] = _NO_RECENT_HAZARD
	for i in _segments.size():
		var segment := _segments[i]
		segment.position = Vector3(0.0, 0.0, -float(i) * SEGMENT_LENGTH)
		_populate_segment(segment, i)

func _recycle_segment(segment: TrackSegment) -> void:
	var furthest_z := 0.0
	for s in _segments:
		furthest_z = minf(furthest_z, s.position.z)
	segment.position.z = furthest_z - SEGMENT_LENGTH
	_populate_segment(segment, -1)

## index >= 0 is only used to keep the very first segments obstacle-free
## so a run always has a safe start; index == -1 means "mid-run recycle",
## always eligible for obstacles.
func _populate_segment(segment: TrackSegment, index: int) -> void:
	for lane in 3:
		_rows_since_jump_on_lane[lane] += 1
		_rows_since_air_enemy_on_lane[lane] += 1
		_rows_since_gland_on_lane[lane] += 1

	var eligible := (index == -1 or index >= SAFE_START_SEGMENTS) \
		and _rows_to_last_obstacle >= _required_gap_rows()
	var spawn_obstacle := eligible and randf() < _obstacle_chance()
	# 1, not 0: the NEXT row to be populated sits exactly one row after
	# this one, which is the value the gate above compares.
	_rows_to_last_obstacle = 1 if spawn_obstacle else _rows_to_last_obstacle + 1
	var obstacle_type := _pick_obstacle_type()

	var obstacle_lane := -1
	if spawn_obstacle:
		# Snapshot of which lanes ALREADY carry an active obstacle
		# elsewhere on the pooled track, and this row's density cap --
		# see the PROGRESSIVE LANE FILL section header above. Taken once
		# per row (not per obstacle-type branch): every deterministic
		# lane pick below shares the exact same snapshot, so two picks
		# in the same call can never disagree about what "already
		# occupied" meant at spawn time. `segment` itself is excluded --
		# its own previous obstacle is about to be overwritten
		# regardless of what this call decides.
		var occupied_lanes := _active_lane_occupancy(segment)
		var lane_cap := _max_active_lanes_for_row()
		match obstacle_type:
			Obstacle.Type.ENEMY:
				# Provisional sway-start lane only -- see the section
				# header above for why ENEMY's real (late-locked) lane is
				# deliberately left OUT of the density cap.
				obstacle_lane = _pick_enemy_final_lane()
			Obstacle.Type.JUMP:
				obstacle_lane = _pick_jump_lane(occupied_lanes, lane_cap)
			Obstacle.Type.AIR_ENEMY:
				obstacle_lane = _pick_air_enemy_lane(occupied_lanes, lane_cap)
				if obstacle_lane == -1:
					# Every lane was too close to a recent JUMP or Gland
					# (see AIR_HAZARD_SEPARATION_S) -- demote to DODGE
					# rather than force an unfair placement or waste the
					# row silently. DODGE has no lane restriction of its
					# own, so this can never cascade into a second demotion.
					obstacle_type = Obstacle.Type.DODGE
					obstacle_lane = _pick_dodge_lane(occupied_lanes, lane_cap)
			_: # DODGE
				obstacle_lane = _pick_dodge_lane(occupied_lanes, lane_cap)

		if obstacle_type == Obstacle.Type.JUMP:
			_rows_since_jump_on_lane[obstacle_lane] = 0
		elif obstacle_type == Obstacle.Type.AIR_ENEMY:
			_rows_since_air_enemy_on_lane[obstacle_lane] = 0

	var noisette_lane := -1
	if randf() < NOISETTE_CHANCE_PER_ROW:
		noisette_lane = randi_range(0, 2)

	var gland_lane := -1
	if randf() < GLAND_CHANCE_PER_ROW:
		var candidate := randi_range(0, 2)
		if _rows_since_air_enemy_on_lane[candidate] >= _required_air_hazard_separation_rows():
			gland_lane = candidate
		# else: too close to a recent AIR_ENEMY on this lane -- skip the
		# gland this row rather than force it onto a different lane (same
		# cancel-not-relocate precedent as the noisette/obstacle-lane
		# collision handled in TrackSegment.populate()).
	if gland_lane != -1:
		_rows_since_gland_on_lane[gland_lane] = 0

	segment.populate(spawn_obstacle, obstacle_type, obstacle_lane, noisette_lane, gland_lane)

# =====================================================================
# SECONDS -> ROWS, AGAINST A CLOSING SPEED (never against "the speed")
#
# Every spacing rule in this file is stated in SECONDS of reaction time
# and has to be turned into a distance (a number of 20m rows) to be
# enforced at generation time. That conversion needs a speed, and the
# right speed is the rate at which the element in question CLOSES on the
# player -- which used to be the same thing as the world speed for every
# hazard in the game, and no longer is by definition once an element can
# carry a forward speed of its own (see Obstacle.gd's CLOSING SPEED
# section header).
#
# So the speed is now an explicit ARGUMENT everywhere rather than an
# implicit GameState.lookahead_speed() read inside each rule. Callers
# state which element they are spacing; _row_closing_speed() answers how
# fast it will be arriving. Passing 0.0 (no own speed) returns
# lookahead_speed() unchanged -- a multiplication by 1.0 is exact -- so
# every existing rule keeps its exact previous value.
# =====================================================================

## The speed at which an element laid out RIGHT NOW, with an own speed of
## `own_speed_factor` times the world speed, will actually close on the
## player by the time it gets there.
##
## Built on GameState.lookahead_speed(), not current_speed, for the same
## reason every spacing rule here always has: this row is spawned ~128m
## ahead and will be RUN THROUGH several seconds later, potentially a
## palier or more faster (see lookahead_speed's own comment). The own
## speed multiplies whatever the world speed turns out to be at that
## point, so an element defined this way stays coherent across the whole
## ramp instead of being tuned for one palier.
func _row_closing_speed(own_speed_factor: float) -> float:
	return GameState.lookahead_speed() * (1.0 + own_speed_factor)

## A reaction-time budget, in seconds, expressed as the number of 20m
## rows it spans for something arriving at `closing_speed`. Rounded UP so
## the gap is never short by a fraction of a row, and floored at 1 so two
## obstacles can never land on the same row -- which the
## one-obstacle-per-TrackSegment pool makes impossible anyway, but the
## floor states it rather than relying on it.
func _rows_for_seconds(seconds: float, closing_speed: float) -> int:
	return maxi(1, ceili(seconds * closing_speed / SEGMENT_LENGTH))

## How many rows must sit between two obstacles at the pace this row is
## being laid out for.
func _required_gap_rows() -> int:
	return _rows_for_seconds(MIN_OBSTACLE_GAP_S, _row_closing_speed(0.0))

## Same conversion as _required_gap_rows() above, sized from
## AIR_HAZARD_SEPARATION_S instead of MIN_OBSTACLE_GAP_S -- see that
## constant for the full rationale.
func _required_air_hazard_separation_rows() -> int:
	return _rows_for_seconds(AIR_HAZARD_SEPARATION_S, _row_closing_speed(0.0))

## Spawn probability for a row that is already far enough from the last
## obstacle -- see OBSTACLE_CHANCE_BASE / OBSTACLE_CHANCE_CAP. Scaled by
## the current RUSH/CALM density multiplier (see the RUSH EVENTS section
## header) and hard-clamped to [0, 1] -- a probability above 1.0 is
## meaningless, and clamping it is exactly what keeps a rush from ever
## spawning MORE than one obstacle per eligible row: the gap rule already
## caps how often a row is eligible at all (_required_gap_rows,
## untouched by any of this), so "every eligible row spawns" (chance ==
## 1.0) is the ceiling, whatever the multiplier's raw value is.
func _obstacle_chance() -> float:
	var t := clampf(
		(GameState.lookahead_speed() - GameState.BASE_SPEED)
			/ (GameState.MAX_SPEED - GameState.BASE_SPEED),
		0.0, 1.0
	)
	var base_chance := lerpf(OBSTACLE_CHANCE_BASE, OBSTACLE_CHANCE_CAP, t)
	return clampf(base_chance * _density_multiplier, 0.0, 1.0)

## Advances the RUSH -> CALM -> NORMAL(cooldown) -> RUSH cycle -- see the
## RUSH EVENTS section header. Called once per physics frame while
## PLAYING (_physics_process), driven by the real run clock
## (GameState.run_time_s), independent of GameState.stage_index /
## lookahead_stage_index() on purpose: a rush must be able to land at ANY
## speed palier once eligible, not just a specific one.
func _update_density_phase(run_time_s: float) -> void:
	match _density_phase:
		DensityPhase.RUSH:
			if run_time_s >= _density_phase_ends_at_s:
				_enter_calm(run_time_s)
		DensityPhase.CALM:
			if run_time_s >= _density_phase_ends_at_s:
				_enter_normal(run_time_s)
		DensityPhase.NORMAL:
			if run_time_s >= _next_rush_eligible_s:
				_enter_rush(run_time_s)

func _enter_rush(run_time_s: float) -> void:
	_density_phase = DensityPhase.RUSH
	_density_multiplier = randf_range(RUSH_CHANCE_MULT_MIN, RUSH_CHANCE_MULT_MAX)
	_density_phase_ends_at_s = run_time_s + randf_range(RUSH_DURATION_MIN_S, RUSH_DURATION_MAX_S)

func _enter_calm(run_time_s: float) -> void:
	_density_phase = DensityPhase.CALM
	_density_multiplier = CALM_CHANCE_MULT
	_density_phase_ends_at_s = run_time_s + randf_range(CALM_DURATION_MIN_S, CALM_DURATION_MAX_S)

func _enter_normal(run_time_s: float) -> void:
	_density_phase = DensityPhase.NORMAL
	_density_multiplier = 1.0
	_next_rush_eligible_s = run_time_s + randf_range(RUSH_COOLDOWN_MIN_S, RUSH_COOLDOWN_MAX_S)

## True for the duration of a RUSH window -- read-only accessor for dev
## probes (scripts/dev/RushFrustrationAudit.gd) that need to isolate
## measurements to specifically-during-a-rush frames. No gameplay code
## reads this; TrackManager is the sole owner of the density phase.
func is_rush_active() -> bool:
	return _density_phase == DensityPhase.RUSH

## Weighted pick among the four Obstacle.Type variants -- see
## DODGE_TYPE_CHANCE / JUMP_TYPE_CHANCE / ENEMY_TYPE_CHANCE above for the
## weights (AIR_ENEMY is the implicit remainder).
func _pick_obstacle_type() -> Obstacle.Type:
	var roll := randf()
	if roll < DODGE_TYPE_CHANCE:
		return Obstacle.Type.DODGE
	if roll < DODGE_TYPE_CHANCE + JUMP_TYPE_CHANCE:
		return Obstacle.Type.JUMP
	if roll < DODGE_TYPE_CHANCE + JUMP_TYPE_CHANCE + ENEMY_TYPE_CHANCE:
		return Obstacle.Type.ENEMY
	return Obstacle.Type.AIR_ENEMY

## PROVISIONAL spawn-time lane for an ENEMY obstacle -- where the sway
## starts, and what TrackSegment.populate reserves against a noisette
## sharing the same row. No longer the FINAL lane: since the "aujourd'hui
## il evite implicitement certaines lanes" playtest note (the enemy never
## actually targeted the player, only ever settled on an RNG draw
## independent of where they stood), the real final lane is now decided
## LATE, from Keepy's actual current lane, in Obstacle._resolve_late_lock
## -- see the Type.ENEMY doc in Obstacle.gd. This function only still
## exists to seed a plausible-looking starting point for the pre-lock
## sway; kept weighted (not a plain randi_range(0, 2) uniform draw) for
## the same reason it always was -- see the long comment below.
##
## DIAGNOSTIC (playtest report: the enemy's final lane felt very
## predictable, "almost always lateral, rarely center", killing the
## interest of the mechanic):
##
## The originally suspected cause was that Obstacle.gd's sway locks onto
## whatever lane the sinusoidal oscillation happens to be nearest to at
## an "arbitrary instant" -- and a sine wave spends most of its time near
## its two extremes (zero velocity at the bounds), so an arbitrary-instant
## sample would land near an extreme more often than near the midpoint.
## THAT HYPOTHESIS IS FALSE FOR THIS CODEBASE, measured (not assumed) via
## scripts/dev/EnemyLaneAudit.gd over 200 real enemy encounters: the lock
## lane and the lane actually collided with at contact matched in EVERY
## single sample (0/200 mismatches) -- the lock has always been a
## deterministic value pre-drawn at spawn (Obstacle._enemy_lane_x, set
## once in configure()), never derived from the sway's position at lock
## time. Same measurement also found each of the 3 INDIVIDUAL lanes
## already landing almost exactly 1/3 of the time under a plain uniform
## draw (33.5% / 32.0% / 34.5% measured) -- no RNG skew toward a specific
## lane either.
##
## So why did playtesting read it as "almost always lateral" anyway? A
## plain per-lane-uniform draw over 3 lanes still makes the CATEGORY
## "lateral" (lane 0 OR lane 2 combined) come up ~2x as often as the
## category "center" (lane 1 alone) -- 68.0% vs 32.0% measured -- simply
## because there are two lateral lanes and only one center lane, each
## drawn with equal odds. That 2:1 split is a real, learnable pattern
## ("when unsure, dodge sideways, you'll be right two times out of three")
## even though no single lane is favoured over the other two. It is this
## category-level skew, not a lane-level one, that the fix below targets:
## weighting the center lane at 50% and each edge lane at 25% makes
## "lateral" and "center" equally likely AS CATEGORIES, which is what
## actually removes the learnable "guess lateral" heuristic. Re-measured
## post-fix (same probe, same sample size): center/lateral converge to
## roughly 50/50 -- see the session report for the exact numbers.
func _pick_enemy_final_lane() -> int:
	if randf() < 0.5:
		return 1
	return 0 if randf() < 0.5 else 2

## Lane for a JUMP obstacle -- almost always a plain uniform draw, EXCEPT
## it also avoids a lane an AIR_ENEMY occupied too recently (see
## AIR_HAZARD_SEPARATION_S): landing a JUMP there would force the player,
## who MUST jump to clear it, straight into the air hazard with no way
## out. Falls back to a plain uniform draw (ignoring the rule) in the
## statistically negligible case where all 3 lanes are excluded -- unlike
## AIR_ENEMY's own picker below, there is no safe type to demote a JUMP
## obstacle TO that would not need the exact same kind of lane check, so
## an occasional unlucky JUMP is the accepted edge case rather than
## adding a second demotion path.
##
## `occupied`/`cap`: the progressive lane-fill density cap (see the
## PROGRESSIVE LANE FILL section header above) is applied ON TOP of the
## AIR_ENEMY-safety exclusion, never instead of it -- safety always wins.
## If narrowing by density leaves no candidate (the safety-filtered set
## and the already-occupied set happen to be disjoint), the density cap
## is the one that gives way, same "occasional unlucky JUMP is the
## accepted edge case" precedent as the fallback above.
func _pick_jump_lane(occupied: Array[bool], cap: int) -> int:
	var required := _required_air_hazard_separation_rows()
	var candidates: Array[int] = []
	for lane in 3:
		if _rows_since_air_enemy_on_lane[lane] >= required:
			candidates.append(lane)
	if candidates.is_empty():
		candidates = [0, 1, 2]
	var capped := _apply_lane_cap(candidates, occupied, cap)
	if capped.is_empty():
		return candidates[randi_range(0, candidates.size() - 1)]
	return capped[randi_range(0, capped.size() - 1)]

## FLIGHT lane for an AIR_ENEMY obstacle (chantier 3, playtest-fixes
## batch: this is no longer necessarily also its LANDING lane, see
## Obstacle.gd's Type.AIR_ENEMY doc + _resolve_air_enemy_landing_lane --
## that decision is made much later, at runtime, against the player's
## actual position, and is out of this function's scope entirely) --
## excludes any lane a JUMP obstacle OR a Gland occupied too recently
## (see AIR_HAZARD_SEPARATION_S): the former would force the player to
## jump into it, the latter would make grabbing the Gland fatal on a lane
## the player had no reason to distrust yet. Still meaningful even though
## the FINAL landing lane can differ: AIR_ENEMY sits on THIS lane, at
## Gland height, for most of its approach (see AIR_ENEMY_DESCENT_LEAD_S --
## the lateral drift toward the landing lane only starts a few seconds
## before contact), so the same two same-lane conflicts this check
## guards against remain live risks for as long as it's flying here.
## Returns -1 if every lane is currently excluded (rare -- caller demotes
## to a different obstacle type in that case, see _populate_segment).
##
## `occupied`/`cap`: same density cap as _pick_jump_lane above, applied
## on top of the safety exclusion, giving way to it (never returns -1 for
## a density reason alone -- only the pre-existing safety exclusion can
## trigger the caller's demotion-to-DODGE path).
func _pick_air_enemy_lane(occupied: Array[bool], cap: int) -> int:
	var required := _required_air_hazard_separation_rows()
	var candidates: Array[int] = []
	for lane in 3:
		if _rows_since_jump_on_lane[lane] >= required and _rows_since_gland_on_lane[lane] >= required:
			candidates.append(lane)
	if candidates.is_empty():
		return -1
	var capped := _apply_lane_cap(candidates, occupied, cap)
	if capped.is_empty():
		return candidates[randi_range(0, candidates.size() - 1)]
	return capped[randi_range(0, capped.size() - 1)]

## Lane for a DODGE obstacle -- DODGE has no lane exclusion of its own
## (see Obstacle.blocks_jump's own doc: it always leaves a switch escape,
## never targets the player), so the density cap is the ONLY constraint
## here. `capped` is guaranteed non-empty: either fewer lanes are
## occupied than `cap` allows (all 3 candidates stay valid) or the
## already-occupied set itself is the candidate pool, and that set is
## non-empty whenever it is being enforced (cap is always >= 1).
func _pick_dodge_lane(occupied: Array[bool], cap: int) -> int:
	var capped := _apply_lane_cap([0, 1, 2], occupied, cap)
	return capped[randi_range(0, capped.size() - 1)]

## Which lanes CURRENTLY carry a live, visible obstacle elsewhere on the
## pooled track -- the "already occupied" half of the density cap (see
## the PROGRESSIVE LANE FILL section header above). `exclude_segment` is
## the row currently being (re)populated: its own previous obstacle is
## about to be overwritten by this same call regardless of what it decides,
## so counting it would be double-booking a lane against itself.
func _active_lane_occupancy(exclude_segment: TrackSegment) -> Array[bool]:
	var occupied: Array[bool] = [false, false, false]
	for segment in _segments:
		if segment == exclude_segment:
			continue
		var obstacle := _active_obstacle_in(segment)
		if obstacle == null:
			continue
		var lane := _lane_index_for_x(obstacle.position.x)
		if lane != -1:
			occupied[lane] = true
	return occupied

## This row's density cap -- see MAX_ACTIVE_LANES_EARLY/_LATE and
## LOW_DENSITY_LAST_STAGE_INDEX above. Uses GameState.lookahead_stage_index(),
## not GameState.stage_index: same "spaced for the speed it will be MET
## at, not the speed at spawn time" reasoning as every other look-ahead
## rule in this file (_required_gap_rows, _obstacle_chance).
func _max_active_lanes_for_row() -> int:
	if GameState.lookahead_stage_index() <= LOW_DENSITY_LAST_STAGE_INDEX:
		return MAX_ACTIVE_LANES_EARLY
	return MAX_ACTIVE_LANES_LATE

## Narrows `candidates` to respect the density cap against `occupied`
## (see _active_lane_occupancy): if fewer lanes are already occupied than
## `cap` allows, every candidate can still open a NEW lane, unchanged; once
## `cap` is already met, only candidates that REUSE an already-occupied
## lane remain -- opening a further lane is what the cap forbids. Shared
## by every deterministic lane picker above so the rule is expressed in
## exactly one place.
func _apply_lane_cap(candidates: Array[int], occupied: Array[bool], cap: int) -> Array[int]:
	var occupied_count := 0
	for is_occupied in occupied:
		if is_occupied:
			occupied_count += 1
	if occupied_count < cap:
		return candidates
	var result: Array[int] = []
	for lane in candidates:
		if occupied[lane]:
			result.append(lane)
	return result

## Lane index (0/1/2) whose TrackSegment.LANE_X value is closest to `x` --
## same "closest lane" resolution EnemyLaneAudit.gd/AntiFrustrationAudit.gd/
## Obstacle._lane_index_for_x already use, needed here so
## _active_lane_occupancy can turn a raw obstacle.position.x back into a
## lane index.
func _lane_index_for_x(x: float) -> int:
	var best_index := 0
	var best_dist := INF
	for i in TrackSegment.LANE_X.size():
		var d := absf(x - TrackSegment.LANE_X[i])
		if d < best_dist:
			best_dist = d
			best_index = i
	return best_index

# =====================================================================
# RUNTIME CROSS-OBSTACLE SAFETY SCAN -- the anti-frustration guarantee
# for the ground ENEMY's late lock (see Obstacle._resolve_late_lock) AND,
# since the playtest-fixes batch (chantier 3), for AIR_ENEMY's own late
# LANDING-lane decision (see Obstacle._resolve_air_enemy_landing_lane) --
# the same function serves both callers unchanged, because they pose the
# exact same question ("would committing to `lane` right now leave
# jumping over it lethal or mandatory-but-incompatible").
#
# Every other lane-exclusion rule in this file (JUMP vs AIR_ENEMY,
# AIR_ENEMY vs Gland) is decided at SPAWN time, against the small
# per-lane recency counters above (_rows_since_*_on_lane) -- cheap, and
# correct because every OTHER obstacle's lane is already known the
# instant it spawns. Ground ENEMY's final lane and (as of chantier 3)
# AIR_ENEMY's landing lane are the two exceptions: neither is decided
# until seconds after spawn, and both target whichever lane the PLAYER
# happens to occupy at that moment -- a value this file cannot know in
# advance. So the check they need cannot live in the spawn-time counters
# either; it has to read the LIVE state of whatever obstacles are
# actually on the track right now, which is what this scan does.
# =====================================================================

## True if committing an obstacle onto `lane` right now (ground ENEMY's
## late lock, OR AIR_ENEMY's own late landing-lane pick, see the section
## header above) would leave jumping over it lethal or
## mandatory-but-incompatible: another live obstacle on the SAME lane
## that either FORCES a jump (JUMP -- the player would need to jump there
## anyway) or PUNISHES one (an AIR_ENEMY that has not yet landed, see
## Obstacle.air_enemy_landed) arriving close enough in time
## (AIR_HAZARD_SEPARATION_S, the same margin that already keeps JUMP and
## AIR_ENEMY apart from EACH OTHER at spawn) to the caller's own contact
## that the two hazards' timing could collide. Called from Obstacle.gd,
## never from within this file.
##
## `exclude`: the CALLING obstacle itself, skipped from the scan.
## Unnecessary for ground ENEMY's own call (Obstacle.Type.ENEMY never
## matches `forces_jump`/`punishes_jump` below, so an ENEMY could never
## flag itself as a conflict regardless), but AIR_ENEMY's late landing-
## lane pick (chantier 3) calls this on ITSELF while still airborne
## (`obstacle_type == AIR_ENEMY and not air_enemy_landed` is exactly the
## `punishes_jump` condition) targeting a lane that, at the moment of the
## call, is very often still its OWN flight lane -- without excluding
## itself it would see itself as a same-lane, zero-time-delta "conflict"
## every time it tries to land on the lane it is already flying over,
## and be redirected away for no real reason. Optional (defaults to
## null) rather than required so ground ENEMY's existing call site needs
## no change.
func lane_has_conflicting_jump_hazard(lane: int, caller_time_to_contact: float, exclude: Node3D = null) -> bool:
	var target_x := TrackSegment.LANE_X[lane]
	for segment in _segments:
		var obstacle: Node3D = _active_obstacle_in(segment)
		if obstacle == null or obstacle == exclude:
			continue
		if not is_equal_approx(obstacle.position.x, target_x):
			continue
		var forces_jump: bool = obstacle.obstacle_type == Obstacle.Type.JUMP
		var punishes_jump: bool = obstacle.obstacle_type == Obstacle.Type.AIR_ENEMY and not obstacle.air_enemy_landed
		if not (forces_jump or punishes_jump):
			continue
		# Both sides of this comparison are computed against their OWN
		# closing speed (Obstacle.time_to_contact_s), which is what makes
		# two obstacles with different own speeds comparable at all -- a
		# raw distance difference, or two times derived from one shared
		# world speed, would not be.
		if absf(obstacle.time_to_contact_s() - caller_time_to_contact) < AIR_HAZARD_SEPARATION_S:
			return true
	return false

## The single live Obstacle in `segment`, or null if this segment has no
## active hazard right now. Returned as a loosely-typed Node3D rather
## than Obstacle -- see the matching comment on Obstacle.gd's
## _track_manager_ref for why a hard mutual class_name dependency between
## this file and Obstacle.gd cannot be resolved by the resource loader;
## `is Obstacle` below still works for the type CHECK (class_name is a
## runtime-checkable global identifier), only the static var/return type
## is avoided. `visible` (not just `monitoring`, see TrackSegment's own
## comment on why toggles are deferred) is the ground truth for "is this
## pooled instance actually in play" -- a hidden instance may still carry
## a stale obstacle_type from its last real use
## (TrackSegment._deactivate_obstacle never resets it), so this filter is
## what keeps that residue out of the safety scan.
func _active_obstacle_in(segment: TrackSegment) -> Node3D:
	for child in segment.get_children():
		if child is Obstacle and child.visible:
			return child
	return null
