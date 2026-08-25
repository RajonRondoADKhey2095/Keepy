extends Resource
class_name HubLayout
## The plateau's contents AS DATA, so moving a portal is an edit to a text
## file rather than an edit to a scene.
##
## WHY THIS EXISTS AT ALL. Hub.tscn placed its three entries as UI nodes in
## a container: their positions were a consequence of layout, so there was
## nothing to tune. A 3D plateau has the opposite problem -- every prop has
## a hand-picked position, and the first version of that always ends up
## wrong on device. Baking those numbers into HubWorld.tscn would mean each
## tuning pass is a scene diff, in a file that also carries the viewport,
## the camera and the fallback menu; a bad merge there costs the whole
## screen, not one rock.
##
## So: HubWorld.tscn carries STRUCTURE (viewport, camera, Keepy, the empty
## Portals/Props parents, the fallback UI) and this resource carries
## PLACEMENT. Nothing in the scene names a world coordinate.
##
## =====================================================================
## ENTRY SHAPE
##
## Each entry is a Dictionary. Dictionary rather than a per-prop Resource
## because the whole point is that the layout be editable as text without
## opening Godot -- a sub-resource per rock would put a load_steps count
## and a dozen [sub_resource] blocks between the author and the numbers.
##
##   type        StringName  &"portal", &"rock", &"tree", &"bush",
##                           &"flower", &"stump", &"pond" or &"landmark"
##   position    Vector3     world position, y is ignored for props that
##                           sit on the ground (they are placed AT y = 0)
##   rotation_y  float       degrees
##   scale       float       uniform
##   game_id     StringName  &"chased" / &"quizz" / &"battle"  (portals only)
##   label       String      text shown on the portal              (portals only)
##   variant     int         corolla tint index, 0..2              (flowers only,
##                           optional -- out of range falls back to 0)
##                           OR landmark silhouette, 0..2:            (landmarks)
##                           0 spire, 1 cairn, 2 twin slabs. Same
##                           fallback rule.
##
## WHICH TYPES ARE BATCHED. rock / tree / bush / flower are drawn as
## MultiMesh instances, one batch per unique (mesh, colour) pair;
## portal / landmark / stump / pond are individual nodes. That split is
## HubBuilder's business and changes nothing here -- an entry looks the
## same either way -- but it is worth knowing that adding a hundred
## flowers costs a hundred instances and no new nodes, while adding a
## hundred stumps costs a hundred nodes.
##
## HubBuilder.gd validates every entry and skips a malformed one with a
## push_error rather than crashing the screen: a typo in a decor file must
## never be the reason a player cannot reach their games.

## Every prop and portal on the plateau, in build order.
@export var props: Array[Dictionary] = []
