extends RefCounted
class_name MinimapMarkers
## CH46 -- THE VOCABULARY OF THE MINIMAP, AND THE ONLY THING THE MAP AND
## THE WORLD SHARE.
##
## =====================================================================
## WHY A GROUP AND NOT A PATH
##
## CH44 axe 3 measured what a map built on node paths would have to cite,
## and half of it does not exist: the bear and the badger never receive a
## `.name` (Godot calls them `@Node3D@228` / `@Node3D@230`), and two of
## the three portals are `@Area3D@10` / `@Area3D@11`. Those names come
## from the instantiation counter, so they move the day a prop is built
## before them -- silently, with no error, and the marker simply stops
## being drawn.
##
## So nothing here is a path. An entity that wants to be on the map calls
## `mark()` once, at the place it is built, and `HubMinimap` enumerates
## the groups. Adding or removing a marker is one line at the entity's
## own site; the map is never edited for it.
##
## =====================================================================
## THE KIND IS THE GROUP -- THERE IS NO NAME TABLE
##
## The brief's rule, and the reason there are four groups rather than one
## group plus a lookup: the marker must carry its own type so the map can
## choose an icon without matching on a node name. A name table would be
## the same dette as a path -- `HubBoar` renamed, and the boar quietly
## draws as a place.
##
## The four kinds are the four things a player asks a map:
##
##   PLAYER   where am I
##   VEHICLE  what can I drive, and where did I leave it
##   NPC      who is about
##   PLACE    what is worth walking to
##
## `mark()` takes a Node rather than a Node3D so a caller never has to
## cast; the map is what refuses a member with no world position, and it
## says so out loud (see HubMinimap._positions).
const PLAYER: StringName = &"minimap_player"
const VEHICLE: StringName = &"minimap_vehicle"
const NPC: StringName = &"minimap_npc"
const PLACE: StringName = &"minimap_place"

## The route the map draws as a LINE rather than as a marker: the karting
## circuit. Its member publishes `ideal_line() -> Array[Vector3]`, which
## is exactly what `KartTrack` already publishes for the AI (CLAUDE.md: a
## fact is published once) -- the map asks for it by method, never by
## class, so a second route joins the group without an edit here.
const ROUTE: StringName = &"minimap_route"

const KINDS: Array[StringName] = [PLAYER, VEHICLE, NPC, PLACE]

## Put `node` on the map as `kind`. Idempotent (Godot's add_to_group is),
## and safe to call before the node is in the tree.
static func mark(node: Node, kind: StringName) -> void:
	if node == null:
		push_error("MinimapMarkers.mark: null node for kind '%s'." % kind)
		return
	node.add_to_group(kind)
