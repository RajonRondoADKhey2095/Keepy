extends Node3D
## LOT B SPIKE -- prove the animated bear rig survives the WebGL2/Compatibility
## export before Lot C builds a walking system on top of it.
##
## DISPOSABLE. This scene, this script and the temporary "Spike ours (dev)"
## button on LoginScreen exist only to get the rig in front of a real phone.
## All three come out before anything here reaches `main`.
##
## WHY THE SIZE IS NOT READ OFF get_aabb()
##
## keepy_bear_walker.glb authors its mesh with a Y span of 1.700000 (measured
## on the POSITION accessor, not guessed) and then puts a 0.01 scale on its
## Armature node. MeshInstance3D.get_aabb() returns the MESH resource's own
## bound, so anything that multiplies it by the node scale reads 0.017 -- a
## hundredfold undercount, and the exact number Lot A hit. The skin's inverse
## bind matrices reconcile the two spaces, so the only honest measurement is
## the one taken off the SKELETON in rest pose.
##
## So BEAR_SCALE below is derived from Skeleton3D.get_bone_global_pose(), and
## _ready() re-measures every run and fails loudly if the shipped constant has
## drifted from what the rig actually is. The constant is never trusted alone.

## Keepy's DRAWN height in the hub, and the reference this spike scales
## against. NOT a collider: the hub walker has no collider at all -- grepped,
## see the report -- so Hitboxes.KEEPY_HEIGHT (1.6, the Chased capsule) is a
## contract for a different game and is deliberately not used here.
## 1.3501 = the hub Body ModelSlot's model_scale 1.07368 times the squirrel's
## own 1.257416 model-space span, the same product CabinInterior.gd derives.
const KEEPY_DRAWN_HEIGHT: float = 1.3501

## Where in the briefed 1.3x-1.5x band this spike lands. 1.4 is the middle:
## 1.3 is close enough to Keepy that "is the bear bigger?" stops being a
## judgeable question on a phone, and 1.5 starts looming over him at the
## hub's -34 degree camera. The middle leaves room to move either way once
## a device has been looked at.
const HEIGHT_FACTOR: float = 1.4

## Target drawn height: 1.3501 * 1.4.
const BEAR_TARGET_HEIGHT: float = 1.89014

## Rest-pose skeleton span, MEASURED IN-ENGINE off get_bone_global_pose().
##
## A control walk of the glTF node hierarchy done in Python gives 1.705818 --
## 2.1% larger -- because glTF node TRS is whatever pose the rig happened to
## be exported in, while Godot builds its rest from the skin's
## inverseBindMatrices, which is the pose the mesh is actually bound to. The
## engine's number is the one that is right, and the control is kept in this
## comment rather than dropped: it is close enough to look like agreement and
## far enough to move a scale by 2%, which is the whole reason the assertion
## below re-measures instead of trusting the constant.
const BEAR_REST_SPAN: float = 1.671335

## BEAR_TARGET_HEIGHT / BEAR_REST_SPAN, written out rather than computed so a
## reader sees the number the scene actually applies.
const BEAR_SCALE: float = 1.130876

## The animation this spike loops. "Running" also ships in the same glb and is
## deliberately left alone -- one thing at a time.
const WALK_ANIM: StringName = &"Walking"

@onready var _rig: Node3D = $Rig
@onready var _readout: Label = $UI/Panel/VBox/Readout


func _ready() -> void:
	SafeArea.fill_screen()
	$UI/Panel/VBox/BackButton.pressed.connect(_on_back)

	var skel: Skeleton3D = _find_skeleton(_rig)
	if skel == null:
		push_error("BearAnimSpike: no Skeleton3D under the imported rig.")
		return

	# Rest-pose span, measured off the bones and NOT off any AABB.
	var rig_from_world: Transform3D = _rig.global_transform.affine_inverse()
	var low: float = INF
	var high: float = -INF
	for i in skel.get_bone_count():
		# In the RIG'S OWN space, never the world's: skel.global_transform
		# already carries BEAR_SCALE, so measuring through it and then
		# multiplying by BEAR_SCALE again applies the scale twice. That is
		# exactly what the first run of this scene did -- it reported a span
		# of 1.851959 for a rig that is 1.671335, and the assertion below is
		# the only reason the doubling did not ship as a "measurement".
		var y: float = (rig_from_world * skel.global_transform
				* skel.get_bone_global_pose(i)).origin.y
		low = minf(low, y)
		high = maxf(high, y)
	var span: float = high - low

	# The shipped constant is checked against the live rig every run. A
	# re-export of the glb that changes its proportions fails here rather
	# than quietly drawing the wrong size.
	if absf(span - BEAR_REST_SPAN) > 0.01:
		push_error("BearAnimSpike: rest span is %.6f, constant says %.6f."
				% [span, BEAR_REST_SPAN])

	var drawn: float = span * BEAR_SCALE
	if absf(drawn - BEAR_TARGET_HEIGHT) > 0.01:
		push_error("BearAnimSpike: drawn height is %.6f, target %.6f."
				% [drawn, BEAR_TARGET_HEIGHT])

	var player: AnimationPlayer = _find_player(_rig)
	var anim_state: String = "MISSING"
	if player != null and player.has_animation(WALK_ANIM):
		var anim: Animation = player.get_animation(WALK_ANIM)
		anim.loop_mode = Animation.LOOP_LINEAR
		player.play(WALK_ANIM)
		anim_state = "%s, %.2fs, looping" % [WALK_ANIM, anim.length]
	else:
		push_error("BearAnimSpike: animation %s not found." % WALK_ANIM)

	var lines := PackedStringArray()
	lines.append("bones            %d" % skel.get_bone_count())
	lines.append("rest span        %.4f" % span)
	lines.append("scale            %.6f" % BEAR_SCALE)
	lines.append("drawn height     %.4f  (Keepy %.4f x %.1f)"
			% [drawn, KEEPY_DRAWN_HEIGHT, HEIGHT_FACTOR])
	lines.append("animation        %s" % anim_state)
	lines.append("renderer         %s" % RenderingServer.get_video_adapter_name())
	_readout.text = "\n".join(lines)
	print("\n".join(lines))


## Depth-first, because the glTF importer's node names are its own business
## and hard-coding a path here would break on the next re-export.
func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var found: Skeleton3D = _find_skeleton(c)
		if found != null:
			return found
	return null


func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var found: AnimationPlayer = _find_player(c)
		if found != null:
			return found
	return null


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/LoginScreen.tscn")
