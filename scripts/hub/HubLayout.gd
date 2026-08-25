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
##                           &"flower", &"stump", &"pond", &"lake",
##                           &"stream" or &"landmark"
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
##   points      PackedVector3Array  the TRACE, in world space   (streams only)
##   width       float       stream width in units, optional     (streams only)
##
## =====================================================================
## &"stream" IS THE ONE TYPE WITH A TRACE INSTEAD OF A POSITION
##
## Every other entry is one point plus a rotation and a scale. A stream is
## a run of water between two places, so its placement IS its trace: it
## carries "points" and NOT position / rotation_y / scale, and HubBuilder
## warns if one of those three shows up on a stream entry rather than
## silently translating the whole watercourse.
##
## PackedVector3Array rather than a plain Array of Vector3. Both round-trip
## through this resource -- verified by writing and reloading a hand-edited
## .tres before any of this was built on top of it, not assumed -- but the
## packed form is typed by construction, so a stray float or a Vector2 in
## the list is a parse error instead of a silently different shape, and it
## stays on one line in the file.
##
## The points are CONTROL points, not the drawn polyline: HubBuilder runs a
## centripetal Catmull-Rom through them. Two control points a few tenths
## apart are therefore NOT redundant -- they are what makes the curve turn
## sharply there, and dropping them straightens a bend the trace needs.
##
## WHICH TYPES ARE BATCHED. rock / tree / bush / flower are drawn as
## MultiMesh instances, one batch per unique (mesh, colour) pair;
## portal / landmark / stump / pond / lake / stream are individual nodes. That split is
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
