extends Node
## Earth-tone colour RECON for the boar's (CHARGER) resting-state albedo,
## run across BOTH bands the ground contrast floor leaves open.
## NOT part of the shipped game (scripts/dev/* is excluded from the web
## export). NOT gated -- a measurement/report tool, not a probe with a
## pass/fail verdict: it writes a PNG and prints a table, nothing more.
##
## WHY THIS EXISTS -- every CHARGER colour lot to date (candidate 03 ->
## the dusty pink-brown currently live, H=348.0deg) stayed inside the SAME
## rose/mauve family, ~284-348deg. This script asks the question that
## family has never been asked: does a REAL earth-tone saturation
## (S ~ 0.15-0.25) buy CHARGER a dependable separation on its OWN axis,
## grey-brown rather than rose? Method copied verbatim from
## EnemyEarthtoneAxisSheet.gd (branch claude/enemy-earthtone-axis-qnlzo5,
## the lot that found the rat's kaki B1) -- not reinvented, and adapted
## for the one real structural difference: CHARGER carries no alarm ramp
## (ModelSlot direct, see Obstacle.configure -- only ENEMY/AIR_ENEMY tint
## toward ENEMY_ALARM_ALBEDO), so there is no settling guard to fight here,
## only a per-instance material OVERRIDE to install so a pooled resource
## is never mutated in place.
##
## ⚠️ TWO BANDS, NOT ONE -- and this is the whole shape of the problem,
## unchanged from the rat lot. The ground renders at Lrel ~ 0.15, so
## clearing 3.0:1 against it means Lrel >= ~0.549 (BRIGHT band) or
## Lrel <= ~0.0165 (DARK band). Nothing in between clears, at any hue, at
## any saturation -- arithmetic on the WCAG formula, verified repeatedly
## on this tree already, not re-derived here. So the axis is explored in
## both bands at once:
##   BRIGHT -- candidates sit beside the RAT (Obstacle.Type.ENEMY,
##     H~105deg, Lrel~0.6), CHARGER's newest neighbour and the one this
##     recolour must not collide with. JUMP (H~43.6) and STOMPER (H~202.3)
##     also live here, and CHARGER's own shipped rose (H~348) is the
##     family this lot exists to get OFF of.
##   DARK -- candidates sit beside DODGE (H~5.8, S=1.0), the band's only
##     current occupant.
## Each candidate is composed in the same frame as its OWN band-mate only
## (RAT for BRIGHT, DODGE for DARK) -- two objects in different luminance
## bands separate trivially and comparing across bands would flatter
## every candidate. Distances/contrasts to ALL FOUR reference hazards
## (DODGE/JUMP/STOMPER/ENEMY-rat) are still reported on every row, per the
## brief: this lot must not reopen a collision with the rat OR with DODGE,
## and JUMP/STOMPER are checked for the same reason the rat lot checked
## CHARGER even though it never composed against it.
##
## ⚠️ HSV SATURATION IS SCALE-INVARIANT -- THE DARK-BAND TRAP, unchanged
## from the rat lot. A colour at V=0.12 with S=0.22 reports a perfectly
## respectable saturation, but its ABSOLUTE chroma (max-min of its RGB
## channels) can be near zero. Every row prints `chroma8` -- the rendered
## max-min RGB spread on the 0..255 scale -- next to S, and the report
## must lean on chroma8 in the dark band, never on S alone.
##
## Three independent signals per candidate, same discipline as the rat
## lot (hue degrees alone are never the verdict):
##   1. Contrast vs GROUND (the gated floor, 3.0:1, safe margin 3.05:1).
##   2. Separation from its BAND-MATE and the other hazards: hue
##      distance, luminance distance, AND a direct pairwise contrast
##      ratio against the band-mate.
##   3. A real RENDERED composed shot: candidate and band-mate in the
##      SAME frame, real camera, real lanes, at the real decision
##      distance (z=DECISION_Z).
##
## METHOD -- private calibration scene whose WorldEnvironment,
## DirectionalLight3D and ground material are READ OUT OF Game.tscn /
## TrackSegment.tscn at run time (PackedScene.get_state(), never
## hand-copied hex), a camera posed at CameraFollow's own steady-state
## transform, the REAL Obstacle.tscn instantiated twice, and the REAL
## SwampAtmosphere.gd driving the mist breath through
## GameState.mist_intensity so both ends of the breath are measured.
##
## ⚠️ CHARGER'S OWN FORWARD SPEED WOULD OTHERWISE DRIFT THE MEASUREMENT --
## Obstacle._process_charger runs every physics tick once
## GameState.state == PLAYING (Obstacle.own_speed_factor =
## CHARGER_SPEED_FACTOR at configure() time). `_configure_at` therefore
## re-applies position AFTER every wait_frames() call, not just before --
## carried over verbatim from the rat lot's own comment on this ("drift
## once GameState.state == PLAYING"), which was already written generic
## enough to cover whichever type occupies `_obstacle`.
##
## ⚠️ CHARGER HAS NO PER-INSTANCE MATERIAL OF ITS OWN -- unlike
## `_enemy_material`/`_air_enemy_material` (duplicated once in
## Obstacle._ready() specifically because those two need a per-instance
## alarm ramp), `_charger_mesh.slot_material()` returns either the
## SHARED .glb-baked material or a scene-authored override -- mutating it
## in place would bleed into every pooled Obstacle. This script captures
## the shipped material ONCE (`_charger_shipped_material`, read before any
## override exists) and duplicates it fresh on every `_configure_at` call,
## exactly the discipline `ModelSlot.apply_material()`'s own doc comment
## describes for a per-instance tint.
##
## ⚠️ THE RAT BAND-MATE NEEDS THE SAME ALARM GUARD THE RAT LOT USED FOR
## ITSELF -- `_ref_obstacle` plays the rat (Obstacle.Type.ENEMY) as
## CHARGER's BRIGHT band-mate. GameState.state == PLAYING means its own
## `_physics_process` would otherwise start oscillating/alarming it
## exactly like any other spawned ENEMY. `_enemy_settling = false` is
## forced on it the same way `_configure_at` forces it on `_obstacle`
## whenever ENEMY is involved.
##
## ⚠️ NEVER add --headless: it forces the DUMMY rendering driver and
## silently overrides --rendering-driver, so every sample reads (0,0,0)
## and every ratio computes 1.00:1 while the process still exits 0.
## Run under xvfb-run, WITHOUT --headless.
##
## Run it with:
##   xvfb-run -a godot4 --rendering-driver opengl3 --path . \
##     res://scripts/dev/ChargerEarthtoneAxisSheet.tscn

const SETTLE_FRAMES: int = 3
const CAPTURE_Z: float = -2.2 # same close framing DarkPaletteAudit/EnemyEarthtoneAxisSheet use
const DECISION_Z: float = -12.0 # real decision distance
const GAME_SCENE_PATH := "res://scenes/Game.tscn"
const TRACK_SEGMENT_SCENE_PATH := "res://scenes/TrackSegment.tscn"

const SAMPLE_HALF_PX: int = 14
const GROUND_STRIP_TOP_FRAC: float = 0.92

const CONTRAST_FLOOR: float = 3.0
const CONTRAST_SAFE_MARGIN: float = 3.05 # brief's own stop line -- clearing 3.0 exactly is not enough margin
const HUE_MIN_SEPARATION: float = 45.0
const HUE_RELIABLE_MIN_SAT: float = 0.10 # relative-saturation floor, inherited from the rat lot
## ABSOLUTE chroma floor, 0..255 scale. Independent of, and not
## interchangeable with, HUE_RELIABLE_MIN_SAT -- see class doc.
const CHROMA8_RELIABLE_MIN: float = 18.0
## Below this pairwise contrast, two objects are not separable by
## BRIGHTNESS at all and the whole separation rests on hue. Flagging aid.
const PAIRWISE_CONTRAST_WEAK: float = 1.30

const CROP_PAD_PX: int = 36
const CROP_MAX_DIM: int = 260
const WIDE_CROP_PAD_PX: int = 48
const WIDE_CROP_MAX_W: int = 900
const WIDE_CROP_MAX_H: int = 320

const OUT_PNG_PATH := "res://docs/color-sheets/charger_earthtone_axis_sheet.png"

const MESH_NODE_FOR_TYPE := {
	Obstacle.Type.DODGE: "DodgeMesh",
	Obstacle.Type.JUMP: "JumpMesh",
	Obstacle.Type.STOMPER: "StomperMesh",
	Obstacle.Type.CHARGER: "ChargerMesh",
	Obstacle.Type.ENEMY: "EnemyMesh",
}

var _root3d: Node3D
var _camera: Camera3D
var _atmosphere: Node
var _obstacle: Obstacle
## Second, independent Obstacle instance, reconfigured per band to play
## the band-mate in the composed shots (ENEMY/rat for BRIGHT, DODGE for
## DARK). Two instances rather than one reused back-to-back because a
## composed shot needs BOTH objects on screen in the SAME frame.
var _ref_obstacle: Obstacle

## Captured ONCE, before any override exists -- see class doc. Every
## `_configure_at(..., CHARGER, ...)` call duplicates fresh off this
## rather than mutating the shared/pooled material in place.
var _charger_shipped_material: StandardMaterial3D

var _results: Dictionary = {}
var _crops: Dictionary = {}
var _wide_crops: Dictionary = {}

## Currently installed on `staging` -- STAYS LIVE, nothing in this lot
## installs anything. Measured for real (no override) so the current
## rose/rat separation reproduces on this tree before anything is judged.
const CHARGER_SHIPPED_LABEL := "CHARGER shipped (rose H=348, stays live -- this lot installs nothing)"

## BRIGHT band. Must render at Lrel >= ~0.549 to clear the ground floor,
## which forces V high -- so the honest question this array asks is
## whether anything at that luminance still reads as an EARTH tone.
## Hues are held clear of the RAT (105), JUMP (43.6), STOMPER (202.3) and
## the shipped rose/mauve family (~284-348, the whole range every prior
## CHARGER lot has tested, not just a +/-45 slice of it). Union of those
## four exclusions leaves TWO windows open: (150.0, 157.3), a 7.3deg
## sliver far too narrow to hold a candidate 45deg from both its
## neighbours, and (247.3, 284.0), ~37deg of indigo/blue-violet -- open by
## the hue-separation rule, but not an earth tone by any reading. E1 tests
## the sliver (expected to fail on separation alone); E2/E3 test two
## points inside the one real window, as a CONTROL that documents what
## the axis buys when a genuine earth hue is unavailable, not a genuine
## earth-tone candidate. No beige/ochre candidate is tested: that hue sits
## on JUMP's, same exclusion the rat lot already applied to its own axis.
const BRIGHT_CANDIDATES: Array = [
	{"label": "E1 Sauge-teal (sliver test, 150-157.3deg -- expected too narrow)", "h": 153.0, "s": 0.20, "v": 0.85},
	{"label": "E2 Indigo terreux (controle: seule fenetre reelle, PAS un ton de terre)", "h": 262.0, "s": 0.20, "v": 0.85},
	{"label": "E3 Ardoise mauve (controle, bord oppose de la meme fenetre)", "h": 278.0, "s": 0.18, "v": 0.88},
	{"label": "E4 Indigo pousse a V=0.95 (le meme controle E2, luminosite maximale)", "h": 262.0, "s": 0.20, "v": 0.95},
]

## DARK band. Must render at Lrel <= ~0.0165, which forces V ~0.12 --
## every candidate here is a near-black, and `chroma8` is the column that
## matters, not `sat`. Hues are held >45deg from DODGE (5.8): true warm
## browns (H ~ 0-40 and H > 320) are STRUCTURALLY UNAVAILABLE, same
## exclusion the rat lot found on its own dark band. D1 reuses the rat
## lot's own D1 hue (brown-green, terre humide) as a direct cross-check
## that the same recipe behaves the same way on a second object; D2 is
## the closest warm hue the 45deg rule allows on DODGE's SAFE side; D3 is
## the deliberate opposite-wheel control.
const DARK_CANDIDATES: Array = [
	{"label": "D1 Brun-vert profond (terre humide, meme hue que le lot du rat)", "h": 110.0, "s": 0.22, "v": 0.115},
	{"label": "D2 Terre d'ombre / brun jaune (hue la plus proche que la regle 45deg autorise)", "h": 55.0, "s": 0.24, "v": 0.12},
	{"label": "D3 Brun-violet profond (terre froide, controle cote oppose)", "h": 290.0, "s": 0.22, "v": 0.12},
]

func _ready() -> void:
	# FIRST statement, before anything that could itself hang -- see
	# ProbeWatchdog.gd. Not gated, but every scripts/dev/ entry point
	# still owes the timeout guarantee ProbeTimeoutAudit checks.
	ProbeWatchdog.arm(self, "ChargerEarthtoneAxisSheet")
	_run.call_deferred()

func _run() -> void:
	_build_calibration_scene()
	await _wait_frames(SETTLE_FRAMES)
	GameState.state = GameState.State.PLAYING

	print("=== CHARGER (boar) EARTH-TONE recon -- real saturation (S~0.15-0.25), BOTH bands ===")
	print("Ground floor arithmetic: clearing %.1f:1 needs Lrel >= ~0.549 (BRIGHT) or <= ~0.0165 (DARK). Nothing between." % CONTRAST_FLOOR)
	print("")

	print("--- Reference hazards (measured this run, on staging's current tree -- never trusted from docs) ---")
	for type in [Obstacle.Type.DODGE, Obstacle.Type.JUMP, Obstacle.Type.STOMPER, Obstacle.Type.ENEMY]:
		var label: String = "ENEMY (rat, kaki -- CHARGER's new neighbour)" if type == Obstacle.Type.ENEMY else Obstacle.Type.keys()[type]
		var rec := await _measure_close(label, type, null, true)
		_print_row(rec)

	print("")
	print("--- CHARGER reference row (currently rose, this lot installs nothing) ---")
	var shipped := await _measure_close(CHARGER_SHIPPED_LABEL, Obstacle.Type.CHARGER, null, true)
	shipped["band_mate"] = "ENEMY (rat, kaki -- CHARGER's new neighbour)"
	_results[CHARGER_SHIPPED_LABEL] = shipped
	_print_row(shipped)
	# The shipped rose gets a composed shot in the SAME format as every
	# candidate -- the calibration of the whole sheet: without it,
	# "E2 separates from the rat" is a claim with nothing to be measured
	# against. `null` means "no override" -- composed with the REAL
	# installed albedo read off the material, never a hex copied from docs.
	await _capture_wide(CHARGER_SHIPPED_LABEL, null, Obstacle.Type.ENEMY)

	print("")
	print("--- BRIGHT BAND -- earth tones beside the RAT (band-mate for the composed shot) ---")
	for c in BRIGHT_CANDIDATES:
		await _run_candidate(c, Obstacle.Type.ENEMY)

	print("")
	print("--- DARK BAND -- earth tones beside DODGE (band-mate for the composed shot) ---")
	for c in DARK_CANDIDATES:
		await _run_candidate(c, Obstacle.Type.DODGE)

	print("")
	_print_verdict_block()

	print("")
	print("=== Writing composite PNG to %s ===" % OUT_PNG_PATH)
	await _compose_png()
	print("DONE")
	get_tree().quit(0)

func _run_candidate(c: Dictionary, band_mate: Obstacle.Type) -> void:
	var color := Color.from_hsv(float(c.h) / 360.0, c.s, c.v, 1.0)
	var label := String(c.label)
	var rec := await _measure_close(label, Obstacle.Type.CHARGER, color, true)
	# Input HSV kept on the record alongside the RENDERED HSV so the
	# report can say whether rendering moved the saturation, instead of
	# quoting the value that was typed in.
	rec["in_hue"] = float(c.h)
	rec["in_sat"] = float(c.s)
	rec["in_val"] = float(c.v)
	rec["band_mate"] = "ENEMY (rat, kaki -- CHARGER's new neighbour)" if band_mate == Obstacle.Type.ENEMY else Obstacle.Type.keys()[band_mate]
	_results[label] = rec
	_print_row(rec)
	await _capture_wide(label, color, band_mate)

# =====================================================================
# CALIBRATION SCENE -- env, light and ground material are READ from the
# shipped scenes, never hand-copied.
# =====================================================================

func _build_calibration_scene() -> void:
	_root3d = Node3D.new()
	_root3d.name = "Root3D"
	add_child(_root3d)

	var env: Environment = _scene_environment(GAME_SCENE_PATH).duplicate()
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	_root3d.add_child(world_env)

	var light := _scene_directional_light(GAME_SCENE_PATH)
	_root3d.add_child(light)

	var ground_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6, 0.4, 60) # long enough to still read as ground at DECISION_Z
	ground_mesh.mesh = box
	ground_mesh.set_surface_override_material(0, _scene_ground_material(TRACK_SEGMENT_SCENE_PATH))
	ground_mesh.position = Vector3(0, -0.2, -15)
	_root3d.add_child(ground_mesh)

	_camera = Camera3D.new()
	_root3d.add_child(_camera)
	# CameraFollow's own converged steady-state against a target fixed at
	# (0,1,0): offset (0,4.2,7), look_ahead (0,1,-4). Kept STATIONARY for
	# both the close (CAPTURE_Z) and far (DECISION_Z) shots -- only the
	# objects move -- so every crop is the same real camera down the same
	# real lane.
	_camera.position = Vector3(0, 5.2, 7)
	_camera.look_at(Vector3(0, 2, -4), Vector3.UP)
	_camera.current = true

	_atmosphere = Node.new()
	_atmosphere.set_script(load("res://scripts/world/SwampAtmosphere.gd"))
	_atmosphere.set("world_environment_path", NodePath("../Root3D/WorldEnvironment"))
	add_child(_atmosphere)

	_obstacle = preload("res://scenes/Obstacle.tscn").instantiate()
	_root3d.add_child(_obstacle)
	_obstacle.configure(Obstacle.Type.CHARGER)
	_obstacle.position = Vector3(0.0, 0.0, CAPTURE_Z)
	_obstacle.visible = true

	_ref_obstacle = preload("res://scenes/Obstacle.tscn").instantiate()
	_root3d.add_child(_ref_obstacle)
	_ref_obstacle.configure(Obstacle.Type.DODGE)
	_ref_obstacle.position = Vector3(TrackSegment.LANE_X[0], 0.0, DECISION_Z)
	_ref_obstacle.rotation = Vector3.ZERO
	_ref_obstacle.visible = false # only shown during composed shots

	# Captured HERE, before this run ever installs an override -- the
	# clean baseline every `_configure_at(..., CHARGER, ...)` duplicates
	# from. `_obstacle` was just configured as CHARGER above, so its
	# ModelSlot has already resolved to the shipped .glb material.
	var shipped_mat := _obstacle._charger_mesh.slot_material() as StandardMaterial3D
	if shipped_mat:
		_charger_shipped_material = shipped_mat.duplicate()
	else:
		push_error("ChargerEarthtoneAxisSheet: could not read CHARGER's shipped material -- ChargerMesh drew nothing.")

# =====================================================================
# MEASUREMENT -- close row (CAPTURE_Z), worst of shallow/deep vs ground.
# =====================================================================

func _measure_close(label: String, type: Obstacle.Type, albedo_override, capture_crop: bool) -> Dictionary:
	var rec := {"label": label, "type": type, "override": albedo_override}
	for phase in [{"key": "shallow", "intensity": 0.0}, {"key": "deep", "intensity": 1.0}]:
		GameState.mist_intensity = phase.intensity
		_configure_at(_obstacle, type, Vector3(0.0, 0.0, CAPTURE_Z), albedo_override)
		await _wait_frames(SETTLE_FRAMES)
		# Re-apply AFTER the settle wait too: self-moving types
		# (CHARGER/STOMPER) drift once GameState.state == PLAYING, and
		# ENEMY's alarm guard must be re-forced every time configure()
		# runs (configure() resets _enemy_settling to true on every call).
		_configure_at(_obstacle, type, Vector3(0.0, 0.0, CAPTURE_Z), albedo_override)
		await _wait_frames(1)

		var ground := _sample_strip(GROUND_STRIP_TOP_FRAC, 1.0)
		var point := _obstacle_sample_point(_obstacle, type)
		var color := _sample_point(point)
		var ratio := _contrast_ratio(color, ground)
		rec[phase.key + "_color"] = color
		rec[phase.key + "_ground"] = ground
		rec[phase.key + "_ratio"] = ratio

		if capture_crop and phase.key == "deep":
			_crops[label] = _capture_crop([_obstacle_sample_bounds(_obstacle, type)], CROP_PAD_PX, CROP_MAX_DIM, CROP_MAX_DIM)

	rec["worst_ratio"] = minf(rec["shallow_ratio"], rec["deep_ratio"])
	# Hue/sat/val/luminance reported from the DEEP-phase colour --
	# SwampAtmosphere only ever touches sky/haze/fog_density, so these
	# are expected phase-invariant for gameplay objects; the shallow
	# colour stays on the record too.
	var deep_color: Color = rec["deep_color"]
	rec["hue"] = deep_color.h * 360.0
	rec["sat"] = deep_color.s
	rec["val"] = deep_color.v
	rec["lum"] = _relative_luminance(deep_color)
	rec["chroma8"] = _chroma8(deep_color)
	_results[label] = rec
	return rec

## Configures `node` as `type` at `pos`, optionally overriding CHARGER's
## per-instance material albedo (a fresh duplicate of the shipped
## material every call -- never mutates the shared/pooled one) or ENEMY's
## real per-instance material albedo. Also forces `_enemy_settling` back
## to false when `type` is ENEMY -- see class doc.
func _configure_at(node: Obstacle, type: Obstacle.Type, pos: Vector3, albedo_override) -> void:
	node.configure(type)
	node.position = pos
	node.rotation = Vector3.ZERO
	if type == Obstacle.Type.ENEMY:
		node._enemy_settling = false
		if albedo_override != null and node._enemy_material:
			node._enemy_material.albedo_color = albedo_override
	elif type == Obstacle.Type.CHARGER:
		if _charger_shipped_material:
			var mat: StandardMaterial3D = _charger_shipped_material.duplicate()
			if albedo_override != null:
				mat.albedo_color = albedo_override
			node._charger_mesh.apply_material(mat)

# =====================================================================
# COMPOSED SHOT -- candidate CHARGER (right lane) next to its OWN
# BAND-MATE (left lane, RAT for BRIGHT, DODGE for DARK), both at
# DECISION_Z, same camera, same frame. Never against the other band: two
# objects in different luminance bands separate trivially and would
# flatter every candidate.
# =====================================================================

## `candidate_color` may be null -- that means "no albedo override", i.e.
## compose the SHIPPED rose CHARGER as it really is (used for the
## calibration row).
func _capture_wide(label: String, candidate_color, band_mate: Obstacle.Type) -> void:
	GameState.mist_intensity = 1.0 # deep end -- worst-case atmosphere, matches the gated rows
	var charger_pos := Vector3(TrackSegment.LANE_X[2], 0.0, DECISION_Z)
	var ref_pos := Vector3(TrackSegment.LANE_X[0], 0.0, DECISION_Z)

	_configure_at(_obstacle, Obstacle.Type.CHARGER, charger_pos, candidate_color)
	_ref_obstacle.configure(band_mate)
	_ref_obstacle.position = ref_pos
	_ref_obstacle.rotation = Vector3.ZERO
	if band_mate == Obstacle.Type.ENEMY:
		_ref_obstacle._enemy_settling = false # see class doc -- otherwise it alarms mid-composition
	_ref_obstacle.visible = true
	await _wait_frames(SETTLE_FRAMES)

	# Re-apply after the settle wait -- same reason as _measure_close.
	_configure_at(_obstacle, Obstacle.Type.CHARGER, charger_pos, candidate_color)
	_ref_obstacle.configure(band_mate)
	_ref_obstacle.position = ref_pos
	_ref_obstacle.rotation = Vector3.ZERO
	if band_mate == Obstacle.Type.ENEMY:
		_ref_obstacle._enemy_settling = false
	await _wait_frames(1)

	var charger_bounds := _obstacle_sample_bounds(_obstacle, Obstacle.Type.CHARGER)
	var ref_bounds := _obstacle_sample_bounds(_ref_obstacle, band_mate)
	_wide_crops[label] = _capture_crop([charger_bounds, ref_bounds], WIDE_CROP_PAD_PX, WIDE_CROP_MAX_W, WIDE_CROP_MAX_H)

	_ref_obstacle.visible = false

# =====================================================================
# BOUNDS / SAMPLING
# =====================================================================

func _obstacle_sample_point(node: Obstacle, type: Obstacle.Type) -> Vector3:
	return _obstacle_sample_bounds(node, type).get_center()

func _obstacle_sample_bounds(node: Obstacle, type: Obstacle.Type) -> AABB:
	var slot := node.get_node_or_null(NodePath(MESH_NODE_FOR_TYPE[type]))
	if slot == null:
		push_error("ChargerEarthtoneAxisSheet: no mesh node '%s' on Obstacle." % MESH_NODE_FOR_TYPE[type])
		return AABB(node.global_position, Vector3.ONE * 0.1)
	var merged := AABB()
	var any := false
	for n in _visual_descendants(slot):
		var box: AABB = n.global_transform * n.get_aabb()
		if box.size == Vector3.ZERO:
			continue
		merged = box if not any else merged.merge(box)
		any = true
	if not any:
		push_error("ChargerEarthtoneAxisSheet: mesh node '%s' draws nothing measurable." % MESH_NODE_FOR_TYPE[type])
		return AABB(node.global_position, Vector3.ONE * 0.1)
	return merged

func _visual_descendants(node: Node) -> Array[VisualInstance3D]:
	var found: Array[VisualInstance3D] = []
	if node is VisualInstance3D and node.visible:
		found.append(node)
	for child in node.get_children():
		found.append_array(_visual_descendants(child))
	return found

# =====================================================================
# PIXEL SAMPLING / CONTRAST
# =====================================================================

func _sample_point(world_pos: Vector3) -> Color:
	var img: Image = get_viewport().get_texture().get_image()
	var screen := _camera.unproject_position(world_pos)
	var visible_size := get_viewport().get_visible_rect().size
	var sx := float(img.get_width()) / maxf(visible_size.x, 1.0)
	var sy := float(img.get_height()) / maxf(visible_size.y, 1.0)
	return _sample_box(img, int(screen.x * sx), int(screen.y * sy), SAMPLE_HALF_PX)

func _sample_strip(top_frac: float, bottom_frac: float) -> Color:
	var img: Image = get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var y0 := int(h * top_frac)
	var y1 := int(h * bottom_frac)
	var cx := w / 2
	return _sample_box(img, cx, (y0 + y1) / 2, mini((y1 - y0) / 2, w / 4))

func _sample_box(img: Image, cx: int, cy: int, half: int) -> Color:
	var w := img.get_width()
	var h := img.get_height()
	var acc := Vector3.ZERO
	var samples := 0
	var step := maxi(1, half / 6)
	for y in range(maxi(0, cy - half), mini(h, cy + half), step):
		for x in range(maxi(0, cx - half), mini(w, cx + half), step):
			var c := img.get_pixel(x, y)
			acc += Vector3(c.r, c.g, c.b)
			samples += 1
	if samples == 0:
		push_error("ChargerEarthtoneAxisSheet: sample box (%d,%d) half=%d off-screen." % [cx, cy, half])
		return Color(0, 0, 0)
	acc /= float(samples)
	return Color(acc.x, acc.y, acc.z)

## Crops the rendered frame down to the union of `bounds_list`'s
## projected screen rects, with padding, capped to max_w x max_h.
func _capture_crop(bounds_list: Array, pad_px: int, max_w: int, max_h: int) -> Image:
	var img: Image = get_viewport().get_texture().get_image()
	var visible_size := get_viewport().get_visible_rect().size
	var sx := float(img.get_width()) / maxf(visible_size.x, 1.0)
	var sy := float(img.get_height()) / maxf(visible_size.y, 1.0)
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for bounds in bounds_list:
		var b: AABB = bounds
		for i in 8:
			var corner := b.position + Vector3(
				b.size.x if (i & 1) else 0.0,
				b.size.y if (i & 2) else 0.0,
				b.size.z if (i & 4) else 0.0)
			var s := _camera.unproject_position(corner)
			s.x *= sx
			s.y *= sy
			minp.x = minf(minp.x, s.x)
			minp.y = minf(minp.y, s.y)
			maxp.x = maxf(maxp.x, s.x)
			maxp.y = maxf(maxp.y, s.y)
	var x0 := maxi(0, int(minp.x) - pad_px)
	var y0 := maxi(0, int(minp.y) - pad_px)
	var x1 := mini(img.get_width(), int(maxp.x) + pad_px)
	var y1 := mini(img.get_height(), int(maxp.y) + pad_px)
	if x1 <= x0 or y1 <= y0:
		push_error("ChargerEarthtoneAxisSheet: crop rect degenerate, off-screen object.")
		var fallback := Image.create(max_w, max_h, false, Image.FORMAT_RGB8)
		fallback.fill(Color.MAGENTA)
		return fallback
	var crop := img.get_region(Rect2i(x0, y0, x1 - x0, y1 - y0))
	var scale := 1.0
	if crop.get_width() > max_w:
		scale = minf(scale, float(max_w) / float(crop.get_width()))
	if crop.get_height() > max_h:
		scale = minf(scale, float(max_h) / float(crop.get_height()))
	if scale < 1.0:
		crop.resize(maxi(1, int(crop.get_width() * scale)), maxi(1, int(crop.get_height() * scale)))
	return crop

func _contrast_ratio(a: Color, b: Color) -> float:
	var la := _relative_luminance(a)
	var lb := _relative_luminance(b)
	var hi := maxf(la, lb)
	var lo := minf(la, lb)
	return (hi + 0.05) / (lo + 0.05)

func _relative_luminance(c: Color) -> float:
	return 0.2126 * _linearize(c.r) + 0.7152 * _linearize(c.g) + 0.0722 * _linearize(c.b)

func _linearize(channel: float) -> float:
	if channel <= 0.03928:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)

## ABSOLUTE chroma on the 0..255 scale -- max minus min RGB channel of
## the RENDERED colour. This is the column that separates "S looks fine"
## from "the tint is actually visible"; see class doc.
func _chroma8(c: Color) -> float:
	var hi := maxf(c.r, maxf(c.g, c.b))
	var lo := minf(c.r, minf(c.g, c.b))
	return (hi - lo) * 255.0

func _hue_distance(a: float, b: float) -> float:
	var d := absf(a - b)
	return minf(d, 360.0 - d)

func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

# =====================================================================
# SHIPPED-SCENE READERS
# =====================================================================

func _scene_environment(scene_path: String) -> Environment:
	var packed: PackedScene = load(scene_path)
	var value: Variant = _scene_property(packed, "environment")
	var env := value as Environment
	if env == null:
		push_error("ChargerEarthtoneAxisSheet: no WorldEnvironment.environment found in %s" % scene_path)
		return Environment.new()
	return env

func _scene_directional_light(scene_path: String) -> DirectionalLight3D:
	var packed: PackedScene = load(scene_path)
	var state := packed.get_state()
	var light := DirectionalLight3D.new()
	for i in state.get_node_count():
		if state.get_node_type(i) != &"DirectionalLight3D":
			continue
		for j in state.get_node_property_count(i):
			light.set(state.get_node_property_name(i, j), state.get_node_property_value(i, j))
		return light
	push_error("ChargerEarthtoneAxisSheet: no DirectionalLight3D found in %s" % scene_path)
	return light

func _scene_ground_material(scene_path: String) -> StandardMaterial3D:
	var packed: PackedScene = load(scene_path)
	var value: Variant = _scene_property(packed, "surface_material_override/0")
	var mat := value as StandardMaterial3D
	if mat == null:
		push_error("ChargerEarthtoneAxisSheet: no ground surface_material_override/0 found in %s" % scene_path)
		return StandardMaterial3D.new()
	return mat.duplicate()

func _scene_property(packed: PackedScene, property_name: String) -> Variant:
	var state := packed.get_state()
	for i in state.get_node_count():
		for j in state.get_node_property_count(i):
			if String(state.get_node_property_name(i, j)) == property_name:
				return state.get_node_property_value(i, j)
	return null

# =====================================================================
# REPORTING
# =====================================================================

func _print_row(rec: Dictionary) -> void:
	var d_dodge: Variant = _hue_distance_to(rec, "DODGE")
	var d_jump: Variant = _hue_distance_to(rec, "JUMP")
	var d_stomper: Variant = _hue_distance_to(rec, "STOMPER")
	var d_rat: Variant = _hue_distance_to(rec, "ENEMY (rat, kaki -- CHARGER's new neighbour)")
	var l_dodge: Variant = _lum_distance_to(rec, "DODGE")
	var l_jump: Variant = _lum_distance_to(rec, "JUMP")
	var l_stomper: Variant = _lum_distance_to(rec, "STOMPER")
	var l_rat: Variant = _lum_distance_to(rec, "ENEMY (rat, kaki -- CHARGER's new neighbour)")
	var flag := _flag_string(rec, d_dodge, d_jump, d_stomper, d_rat, l_dodge)
	print("%-72s hue=%6.1f sat=%.3f chroma8=%5.1f val=%.2f lum=%.5f | shallow=%.2f:1 deep=%.2f:1 worst=%.2f:1" % [
		rec.label, rec.hue, rec.sat, rec.chroma8, rec.val, rec.lum,
		rec.shallow_ratio, rec.deep_ratio, rec.worst_ratio,
	])
	if rec.has("in_sat"):
		print("    input HSV = H%.1f S%.3f V%.3f  ->  RENDERED sat %.3f (%s)" % [
			rec.in_hue, rec.in_sat, rec.in_val, rec.sat,
			"dans la fourchette 0.15-0.25" if rec.sat >= 0.15 and rec.sat <= 0.25 else "HORS fourchette 0.15-0.25",
		])
	print("    dHue vs D/J/S/RAT  = %s / %s / %s / %s deg  (floor %.0fdeg)" % [
		_fmt_dist(d_dodge), _fmt_dist(d_jump), _fmt_dist(d_stomper), _fmt_dist(d_rat), HUE_MIN_SEPARATION,
	])
	print("    dLum vs D/J/S/RAT  = %s / %s / %s / %s  (relative luminance, WCAG 0..1 scale)" % [
		_fmt_dist(l_dodge), _fmt_dist(l_jump), _fmt_dist(l_stomper), _fmt_dist(l_rat),
	])
	if rec.has("band_mate"):
		var pair: Variant = _pairwise_contrast_to(rec, String(rec.band_mate))
		print("    contraste PAIRE vs %s (band-mate) = %s:1  (< %.2f:1 => separables par la TEINTE seule)" % [
			rec.band_mate, _fmt_dist(pair), PAIRWISE_CONTRAST_WEAK,
		])
	if flag != "":
		print("   " + flag)

func _fmt_dist(d) -> String:
	if d == null:
		return "n/a"
	return "%.3f" % d if absf(float(d)) < 10.0 else "%.1f" % d

func _hue_distance_to(rec: Dictionary, ref_label: String):
	var ref = _find_ref(ref_label)
	if ref == null or String(rec.label) == ref_label:
		return null
	return _hue_distance(rec.hue, ref.hue)

func _lum_distance_to(rec: Dictionary, ref_label: String):
	var ref = _find_ref(ref_label)
	if ref == null or String(rec.label) == ref_label:
		return null
	return absf(float(rec.lum) - float(ref.lum))

## Direct WCAG contrast between a candidate and a reference hazard --
## the number that says whether the two are separable by BRIGHTNESS at
## all, independent of hue and independent of the ground.
func _pairwise_contrast_to(rec: Dictionary, ref_label: String):
	var ref = _find_ref(ref_label)
	if ref == null or String(rec.label) == ref_label:
		return null
	var hi := maxf(float(rec.lum), float(ref.lum))
	var lo := minf(float(rec.lum), float(ref.lum))
	return (hi + 0.05) / (lo + 0.05)

func _find_ref(ref_label: String) -> Variant:
	if _results.has(ref_label):
		return _results[ref_label]
	return null

func _flag_string(rec: Dictionary, d_dodge, d_jump, d_stomper, d_rat, _l_dodge) -> String:
	var reasons: Array[String] = []
	if rec.worst_ratio < CONTRAST_FLOOR:
		reasons.append("SOUS LE PLANCHER SOL (%.2f:1 < %.1f:1)" % [rec.worst_ratio, CONTRAST_FLOOR])
	elif rec.worst_ratio < CONTRAST_SAFE_MARGIN:
		reasons.append("MARGE TROP FINE (%.2f:1, veut >= %.2f:1)" % [rec.worst_ratio, CONTRAST_SAFE_MARGIN])
	if rec.sat < HUE_RELIABLE_MIN_SAT:
		reasons.append("SATURATION RELATIVE SOUS LE PLANCHER (%.3f < %.2f)" % [rec.sat, HUE_RELIABLE_MIN_SAT])
	if rec.chroma8 < CHROMA8_RELIABLE_MIN:
		reasons.append("CHROMA ABSOLUE QUASI NULLE (%.1f/255 < %.0f -- S est scale-invariant, pas la teinte VUE)" % [rec.chroma8, CHROMA8_RELIABLE_MIN])
	var mins := [d_dodge, d_jump, d_stomper, d_rat]
	for d in mins:
		if d != null and float(d) < HUE_MIN_SEPARATION:
			reasons.append("TEINTE TROP PROCHE D'UN HAZARD (%.1fdeg < %.0fdeg)" % [float(d), HUE_MIN_SEPARATION])
			break
	if rec.has("band_mate"):
		var pair: Variant = _pairwise_contrast_to(rec, String(rec.band_mate))
		if pair != null and float(pair) < PAIRWISE_CONTRAST_WEAK:
			reasons.append("SEPARATION PORTEE PAR LA TEINTE SEULE (contraste paire %.2f:1 vs %s)" % [float(pair), rec.band_mate])
	if reasons.is_empty():
		return ""
	return "<<< " + " | ".join(reasons)

## Compact end-of-run block -- the one place the two bands are compared
## side by side. Prints raw facts only; the verdict itself is written by
## a human against the composed shots, not derived here.
func _print_verdict_block() -> void:
	print("=== SYNTHESE (faits mesures -- le verdict se lit sur les rendus composes, pas sur ce bloc) ===")
	print("%-72s %-8s %-9s %-9s %-11s %s" % ["candidat", "worst", "chroma8", "dHue min", "paire", "band-mate"])
	for arr in [BRIGHT_CANDIDATES, DARK_CANDIDATES]:
		for c in arr:
			var label := String(c.label)
			if not _results.has(label):
				continue
			var rec: Dictionary = _results[label]
			var dmin := 9999.0
			for ref_label in ["DODGE", "JUMP", "STOMPER", "ENEMY (rat, kaki -- CHARGER's new neighbour)"]:
				var d: Variant = _hue_distance_to(rec, ref_label)
				if d != null:
					dmin = minf(dmin, float(d))
			var pair: Variant = _pairwise_contrast_to(rec, String(rec.get("band_mate", "")))
			print("%-72s %-8s %-9s %-9s %-11s %s" % [
				label,
				"%.2f:1" % rec.worst_ratio,
				"%.1f" % rec.chroma8,
				"%.1f" % dmin,
				("%.2f:1" % float(pair)) if pair != null else "n/a",
				String(rec.get("band_mate", "-")),
			])

# =====================================================================
# PNG COMPOSITE
# =====================================================================

const CANVAS_W: int = 1500
const ROW_H: int = 230
const WIDE_ROW_H: int = 340
const CROP_CELL: int = 160
const SWATCH_CELL: int = 160
const HEADER_H: int = 170

func _compose_png() -> void:
	var order: Array[String] = []
	order.append_array(["DODGE", "JUMP", "STOMPER", "ENEMY (rat, kaki -- CHARGER's new neighbour)"])
	order.append(CHARGER_SHIPPED_LABEL)
	var bright_labels: Array[String] = []
	for c in BRIGHT_CANDIDATES:
		bright_labels.append(String(c.label))
	var dark_labels: Array[String] = []
	for c in DARK_CANDIDATES:
		dark_labels.append(String(c.label))
	order.append_array(bright_labels)
	order.append_array(dark_labels)

	var section_breaks := {
		4: "CHARGER REFERENCE ROW -- le rose installe, reste live: ce lot n'installe rien.",
		5: "BANDE CLAIRE (Lrel >= ~0.549) -- chaque candidat compose avec le vrai RAT, meme frame, z=%d" % int(DECISION_Z),
		5 + bright_labels.size(): "BANDE SOMBRE (Lrel <= ~0.0165) -- chaque candidat compose avec le vrai DODGE, meme frame, z=%d" % int(DECISION_Z),
	}

	var row_y := {}
	var wide_row_y := {}
	var y := HEADER_H
	for i in order.size():
		if section_breaks.has(i):
			y += 40
		var label: String = String(order[i])
		row_y[label] = y
		y += ROW_H
		if _wide_crops.has(label):
			wide_row_y[label] = y
			y += WIDE_ROW_H
	var canvas_h := y + 40

	var sub := SubViewport.new()
	sub.size = Vector2i(CANVAS_W, canvas_h)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.transparent_bg = false
	add_child(sub)

	var canvas := EarthtoneAxisCanvas.new()
	canvas.size = Vector2(CANVAS_W, canvas_h)
	canvas.custom_minimum_size = Vector2(CANVAS_W, canvas_h)
	canvas.results = _results
	canvas.order = order
	canvas.section_breaks = section_breaks
	canvas.row_y = row_y
	canvas.wide_row_y = wide_row_y
	canvas.hue_distance_fn = Callable(self, "_hue_distance_to")
	canvas.lum_distance_fn = Callable(self, "_lum_distance_to")
	canvas.pair_fn = Callable(self, "_pairwise_contrast_to")
	canvas.flag_fn = Callable(self, "_flag_string")
	sub.add_child(canvas)

	await _wait_frames(1)
	canvas.queue_redraw()
	await _wait_frames(3)

	var out_img: Image = sub.get_texture().get_image()
	out_img.convert(Image.FORMAT_RGBA8)

	# ------------------------------------------------------------------
	# CROPS BLITTED HERE, PLAIN CPU PIXEL COPY -- NOT draw_texture_rect()
	# IN THE CONTROL ABOVE. Same reason as EnemyEarthtoneAxisSheet.gd /
	# EnemyGreyAxisSheet.gd / EnemyColourSheetAxis.gd: in this sandbox's
	# software GL stack, draw_texture_rect() on an ImageTexture built from
	# a captured viewport crop rendered flat WHITE, while draw_rect()
	# fills were never affected. Sidestepping the 2D texture-draw path
	# entirely avoids the whole class of bug. DO NOT "simplify" this back.
	for label in _crops.keys():
		if not row_y.has(label):
			continue
		var crop: Image = _crops[label]
		crop.convert(Image.FORMAT_RGBA8)
		var iw := crop.get_width()
		var ih := crop.get_height()
		var scale := minf(float(CROP_CELL) / maxf(iw, 1.0), float(CROP_CELL) / maxf(ih, 1.0))
		var dw := maxi(1, int(iw * scale))
		var dh := maxi(1, int(ih * scale))
		if dw != iw or dh != ih:
			crop.resize(dw, dh)
		var yy: int = row_y[label]
		var dst_x := 20 + int((CROP_CELL - dw) / 2.0)
		var dst_y := yy + int((CROP_CELL - dh) / 2.0)
		out_img.blit_rect(crop, Rect2i(0, 0, dw, dh), Vector2i(dst_x, dst_y))

	for label in _wide_crops.keys():
		if not wide_row_y.has(label):
			continue
		var crop: Image = _wide_crops[label]
		crop.convert(Image.FORMAT_RGBA8)
		var iw := crop.get_width()
		var ih := crop.get_height()
		var avail_w := CANVAS_W - 40
		var avail_h := WIDE_ROW_H - 30
		var scale := minf(float(avail_w) / maxf(iw, 1.0), float(avail_h) / maxf(ih, 1.0))
		scale = minf(scale, 1.0)
		var dw := maxi(1, int(iw * scale))
		var dh := maxi(1, int(ih * scale))
		if dw != iw or dh != ih:
			crop.resize(dw, dh)
		var yy: int = wide_row_y[label]
		var dst_x := 20 + int((avail_w - dw) / 2.0)
		var dst_y := yy + 10
		out_img.blit_rect(crop, Rect2i(0, 0, dw, dh), Vector2i(dst_x, dst_y))

	var err := out_img.save_png(OUT_PNG_PATH)
	if err != OK:
		push_error("ChargerEarthtoneAxisSheet: save_png failed with error %d" % err)
	else:
		print("Saved %dx%d PNG to %s" % [out_img.get_width(), out_img.get_height(), OUT_PNG_PATH])

## Inner Control that draws the composite: crop cell frame, flat swatch
## (the real measured rendered colour), text block, and a labelled wide
## cell under every candidate row for its composed shot.
class EarthtoneAxisCanvas:
	extends Control

	var results: Dictionary = {}
	var order: Array = []
	var section_breaks: Dictionary = {}
	var row_y: Dictionary = {}
	var wide_row_y: Dictionary = {}
	var hue_distance_fn: Callable
	var lum_distance_fn: Callable
	var pair_fn: Callable
	var flag_fn: Callable

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.08, 1.0))
		draw_string(font, Vector2(20, 30), "CHARGER (sanglier) -- AXE GRIS-BRUN TERREUX a saturation reelle (S~0.15-0.25), les DEUX bandes",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 24, Color(1, 1, 1))
		draw_string(font, Vector2(20, 58), "Sol rendu a Lrel ~0.15 -> franchir 3.0:1 exige Lrel >= ~0.549 (BANDE CLAIRE) OU <= ~0.0165 (BANDE SOMBRE). Rien entre les deux, a aucune teinte.",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 15, Color(0.75, 0.78, 0.75))
		draw_string(font, Vector2(20, 80), "Crop proche / pastille = CAPTURE_Z=-2.2 (chiffres gates). Crop large = candidat + SON band-mate, meme camera, meme frame, z=-12 -- le vrai verdict.",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 15, Color(0.9, 0.9, 0.6))
		draw_string(font, Vector2(20, 102), "chroma8 = ecart max-min RGB du rendu sur 0..255. S est SCALE-INVARIANT: un quasi-noir peut afficher S=0.22 avec une chroma absolue de ~7/255.",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 15, Color(1.0, 0.8, 0.55))
		draw_string(font, Vector2(20, 124), "Le rose installe (H~348) reste live: ce lot n'installe rien. Aucun candidat ne doit recreer de collision avec le RAT (kaki) ni avec DODGE.",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 15, Color(0.85, 0.75, 0.75))

		var crop_cell := 160
		var swatch_cell := 160
		var text_x := 20 + crop_cell + 12 + swatch_cell + 20
		var text_w := int(size.x) - text_x - 20

		for i in order.size():
			var label: String = String(order[i])
			if not row_y.has(label):
				continue
			var yy: int = row_y[label]
			if section_breaks.has(i):
				var header: String = String(section_breaks[i])
				draw_rect(Rect2(0, yy - 40, size.x, 34), Color(0.16, 0.18, 0.14, 1.0))
				draw_string(font, Vector2(20, yy - 17), header,
					HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 17, Color(0.95, 0.95, 0.55))
			if not results.has(label):
				continue
			var rec: Dictionary = results[label]

			draw_rect(Rect2(20, yy, crop_cell, crop_cell), Color(0.15, 0.15, 0.15, 1), false, 1.0)

			var deep_c: Color = rec.get("deep_color", Color.MAGENTA)
			draw_rect(Rect2(20 + crop_cell + 12, yy, swatch_cell, crop_cell), deep_c)
			draw_rect(Rect2(20 + crop_cell + 12, yy, swatch_cell, crop_cell), Color(0.15, 0.15, 0.15, 1), false, 1.0)

			var d_do: Variant = hue_distance_fn.call(rec, "DODGE")
			var d_j: Variant = hue_distance_fn.call(rec, "JUMP")
			var d_s: Variant = hue_distance_fn.call(rec, "STOMPER")
			var d_r: Variant = hue_distance_fn.call(rec, "ENEMY (rat, kaki -- CHARGER's new neighbour)")
			var l_do: Variant = lum_distance_fn.call(rec, "DODGE")
			var l_j: Variant = lum_distance_fn.call(rec, "JUMP")
			var l_s: Variant = lum_distance_fn.call(rec, "STOMPER")
			var l_r: Variant = lum_distance_fn.call(rec, "ENEMY (rat, kaki -- CHARGER's new neighbour)")
			var flag: String = flag_fn.call(rec, d_do, d_j, d_s, d_r, l_do)

			var lines := PackedStringArray()
			lines.append(label)
			lines.append("H=%.1fdeg  S=%.3f  chroma8=%.1f/255  V=%.2f  Lrel=%.5f    RGB rendu=(%.4f, %.4f, %.4f)" % [
				rec.hue, rec.sat, rec.chroma8, rec.val, rec.lum, deep_c.r, deep_c.g, deep_c.b])
			if rec.has("in_sat"):
				lines.append("HSV saisi = H%.1f S%.3f V%.3f  ->  saturation RENDUE %.3f (%s)" % [
					rec.in_hue, rec.in_sat, rec.in_val, rec.sat,
					"dans 0.15-0.25" if rec.sat >= 0.15 and rec.sat <= 0.25 else "HORS 0.15-0.25"])
			lines.append("contraste vs sol: shallow=%.2f:1  deep=%.2f:1  worst(gate)=%.2f:1  (plancher 3.0:1, sur 3.05:1)" % [
				rec.shallow_ratio, rec.deep_ratio, rec.worst_ratio])
			lines.append("dHue -> D/J/S/RAT = %s/%s/%s/%s deg  (plancher 45)" % [
				_fmt(d_do), _fmt(d_j), _fmt(d_s), _fmt(d_r)])
			lines.append("dLum -> D/J/S/RAT = %s/%s/%s/%s  (luminance relative, 0..1)" % [
				_fmt(l_do), _fmt(l_j), _fmt(l_s), _fmt(l_r)])
			if rec.has("band_mate"):
				var pair: Variant = pair_fn.call(rec, String(rec.band_mate))
				lines.append("contraste PAIRE vs %s (band-mate) = %s:1" % [rec.band_mate, _fmt(pair)])
			if flag != "":
				lines.append(flag)
			else:
				lines.append("OK sur les planchers imprimes -- juger quand meme le rendu compose ci-dessous a l'oeil")

			var text_color := Color(1, 0.6, 0.55) if flag != "" else Color(0.85, 0.9, 0.85)
			var ty := yy + 2
			for li in lines.size():
				var line_color := text_color if li == lines.size() - 1 else Color(0.85, 0.87, 0.85)
				if li == 0:
					line_color = Color(1, 1, 1)
				draw_string(font, Vector2(text_x, ty + 16), String(lines[li]),
					HORIZONTAL_ALIGNMENT_LEFT, text_w, 15, line_color)
				ty += 24

			if wide_row_y.has(label):
				var wy: int = wide_row_y[label]
				var mate: String = String(rec.get("band_mate", "?"))
				draw_string(font, Vector2(20, wy - 6), "Compose a distance de decision (z=-12): candidat CHARGER (voie droite) a cote du vrai %s (voie gauche) -- meme bande, meme frame" % mate,
					HORIZONTAL_ALIGNMENT_LEFT, size.x - 40, 14, Color(0.8, 0.85, 1.0))
				draw_rect(Rect2(20, wy + 8, size.x - 40, 300), Color(0.15, 0.15, 0.15, 1), false, 1.0)

	func _fmt(d) -> String:
		if d == null:
			return "n/a"
		return "%.3f" % d if absf(float(d)) < 10.0 else "%.1f" % d
