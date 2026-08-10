extends Node
## Dev-only probe: how many trackside props of EACH KIND are on screen at
## once, and what each kind costs in triangles.
##
## =====================================================================
## WHY THIS EXISTS SEPARATELY FROM TrackPropsAudit
##
## TrackPropsAudit reports the props as ONE family -- a single "trackside
## props: 781 tri" line. That is the right shape for the question it
## asks ("do the props fit their share of the frame"), and the wrong
## shape for the question that comes up the moment a real .glb is
## proposed for one of the kinds: WHICH kind, and how many of it.
##
## A single family total cannot answer that. Six kinds are rolled from
## _PROP_KIND_WEIGHTS, so they do not appear in equal numbers, and they
## cost wildly different amounts (a sign is 22 triangles, a bush is 108).
## Swapping one kind for a model therefore moves the total by an amount
## that depends entirely on how often that kind is drawn -- which is a
## measurement, not an arithmetic guess from the weights, because
## presence, kind and count are all rolled per slot per populate().
##
## So this probe counts INSTANCES per kind, per frame, over a long run:
## mean and max, alongside the measured per-instance triangle cost. That
## is what makes it possible to say "replacing the tree costs N triangles
## a frame" and to target the expensive kind rather than shrinking all
## six uniformly.
##
## =====================================================================
## WHAT IT DOES NOT DO
##
## It ASSERTS NOTHING and gates nothing. It is a census: it prints what
## is there. Every invariant about props -- the keep-out, the absence of
## colliders, the family triangle budget -- is already asserted by
## TrackPropsAudit, and restating them here would mean two probes that
## have to agree, which is a way of eventually having two probes that
## disagree.
##
## It is also NOT SEEDED, for the same reason TrackPropsAudit is not: it
## measures a distribution, and a single seeded run would report one
## sample of it as though it were the shape. Run it more than once; the
## per-kind maxima move by a couple of instances between runs, which is
## itself part of the answer.
##
## Excluded from the web export (export_presets.cfg excludes
## scripts/dev/*), never instantiated by a shipped scene.
##
## Run it with:
##   godot4 --headless --fixed-fps 60 --path . \
##     res://scripts/dev/TracksidePropCensus.tscn

const GAME_SCENE := preload("res://scenes/Game.tscn")

## Long enough to cover many recycles: a segment recycles roughly every
## SEGMENT_LENGTH / speed seconds, so a few thousand frames sees each of
## the seven pooled segments re-rolled many times over.
const FRAMES: int = 3600

## The kinds, and which node-name prefixes belong to each. Derived from
## TrackSegment's own _PROP_KIND_MESHES rather than restated by hand
## where possible; the prefixes are what the scene actually names its
## instances (see _build_trackside_props).
##
## `tree` and `stump` each name ONE node since they became imported meshes
## (MESHY_SPEC 11, this batch): the trunk+canopy and body+dome pairs are
## gone. A stale prefix here does not fail loudly -- it reports the kind at
## zero instances and a nonsense per-instance cost, which is exactly what
## this table did on the first run after the swap, so it is worth checking
## against _build_trackside_props whenever a prop node is renamed.
const KIND_PREFIXES: Dictionary = {
	"tree":  ["PropTree"],
	"rock":  ["PropRock"],
	"bush":  ["PropBushBlob"],
	"stump": ["PropStump"],
	"bench": ["PropBenchSeat", "PropBenchBack", "PropBenchLeg"],
	"sign":  ["PropSignPost", "PropSignBoard"],
}

## The mesh that identifies ONE instance of a kind, so a bush's three
## blobs are counted as one bush rather than three props. Chosen as the
## part every instance of that kind has exactly one of.
const KIND_ANCHOR: Dictionary = {
	"tree":  "PropTree",
	"rock":  "PropRock",
	"bush":  "PropBushBlob0",
	"stump": "PropStump",
	"bench": "PropBenchSeat",
	"sign":  "PropSignPost",
}

var _frames: int = 0
var _count_sum: Dictionary = {}
var _count_max: Dictionary = {}
var _tri_sum: Dictionary = {}
var _tri_max: Dictionary = {}
## Per-kind triangle cost of a single instance, sampled whenever one is
## visible. Kept as min/max because sizes are re-rolled per placement --
## on primitives that does not change the triangle count, but on an
## installed .glb it would not either, and a range that turns out to be a
## single value is a stronger statement than an average that hides one.
var _per_instance_min: Dictionary = {}
var _per_instance_max: Dictionary = {}

func _ready() -> void:
	ProbeWatchdog.arm(self, "TracksidePropCensus")
	for kind in KIND_PREFIXES:
		_count_sum[kind] = 0
		_count_max[kind] = 0
		_tri_sum[kind] = 0
		_tri_max[kind] = 0
		_per_instance_min[kind] = -1
		_per_instance_max[kind] = 0
	add_child(GAME_SCENE.instantiate())
	print("TracksidePropCensus -- per-kind instance count and triangle cost")
	print("  sampling %d frames of a live run\n" % FRAMES)

func _process(_delta: float) -> void:
	_sample()
	_frames += 1
	if _frames >= FRAMES:
		_report()
		get_tree().quit()

func _sample() -> void:
	var per_kind_count: Dictionary = {}
	var per_kind_tri: Dictionary = {}
	for kind in KIND_PREFIXES:
		per_kind_count[kind] = 0
		per_kind_tri[kind] = 0

	for node in _visible_mesh_instances(get_tree().root):
		var kind := _kind_of(node)
		if kind == "":
			continue
		var tris := _triangles(node)
		per_kind_tri[kind] = int(per_kind_tri[kind]) + tris
		if node.name.begins_with(KIND_ANCHOR[kind]):
			per_kind_count[kind] = int(per_kind_count[kind]) + 1

	for kind in KIND_PREFIXES:
		var c: int = int(per_kind_count[kind])
		var t: int = int(per_kind_tri[kind])
		_count_sum[kind] = int(_count_sum[kind]) + c
		_tri_sum[kind] = int(_tri_sum[kind]) + t
		_count_max[kind] = maxi(int(_count_max[kind]), c)
		_tri_max[kind] = maxi(int(_tri_max[kind]), t)
		if c > 0:
			# Integer division on purpose: this is the per-instance cost of
			# a kind whose parts are identical across instances, so the
			# division is exact and a float would only invite a reader to
			# treat a rounding artefact as variation.
			var per: int = t / c
			if int(_per_instance_min[kind]) < 0 or per < int(_per_instance_min[kind]):
				_per_instance_min[kind] = per
			_per_instance_max[kind] = maxi(int(_per_instance_max[kind]), per)

## Every VISIBLE MeshInstance3D under `node`. Visibility is checked with
## is_visible_in_tree(), not `.visible`: a prop whose own flag is true
## inside a hidden segment is not being drawn, and counting it would
## inflate exactly the number this probe exists to establish.
func _visible_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var mesh_instance := node as MeshInstance3D
	if mesh_instance and mesh_instance.is_visible_in_tree() and mesh_instance.mesh != null:
		found.append(mesh_instance)
	for child in node.get_children():
		found.append_array(_visible_mesh_instances(child))
	return found

func _kind_of(node: MeshInstance3D) -> String:
	for kind in KIND_PREFIXES:
		for prefix in KIND_PREFIXES[kind]:
			if node.name.begins_with(prefix):
				return kind
	return ""

## get_faces() returns three vertices per triangle across every surface --
## the same measure TrackPropsAudit uses, so the two probes' numbers are
## directly comparable.
func _triangles(node: MeshInstance3D) -> int:
	var mesh := node.mesh
	if mesh == null:
		return 0
	return mesh.get_faces().size() / 3

func _report() -> void:
	print("  frames sampled : %d\n" % _frames)
	print("  %-8s %10s %8s %10s %10s %12s" % [
		"kind", "per inst", "mean n", "max n", "mean tri", "max tri"])
	print("  " + "-".repeat(64))
	var total_mean := 0.0
	var total_max := 0
	var kinds := KIND_PREFIXES.keys()
	kinds.sort()
	for kind in kinds:
		var mean_n := float(_count_sum[kind]) / float(_frames)
		var mean_t := float(_tri_sum[kind]) / float(_frames)
		total_mean += mean_t
		total_max += int(_tri_max[kind])
		var per_lo: int = int(_per_instance_min[kind])
		var per_hi: int = int(_per_instance_max[kind])
		var per := str(per_hi) if per_lo == per_hi else "%d-%d" % [per_lo, per_hi]
		print("  %-8s %10s %8.2f %10d %10.1f %12d" % [
			kind, per, mean_n, int(_count_max[kind]), mean_t, int(_tri_max[kind])])
	print("  " + "-".repeat(64))
	# The per-kind maxima do not all fall on the same frame, so their sum
	# is an upper bound the run may never actually have drawn -- said out
	# loud rather than printed as though it were a measured frame.
	print("  mean total %.1f tri;  sum of per-kind maxima %d tri (upper bound," % [
		total_mean, total_max])
	print("  not one observed frame -- the maxima land on different frames)")
	print("\n  Census only. Invariants are asserted by TrackPropsAudit.")
