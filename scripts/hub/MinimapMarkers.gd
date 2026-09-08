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

## =====================================================================
## CH48 -- THE THUMBNAIL ROSTER, AND WHY IT IS A LIST AND NOT A LOOKUP
##
## CH47 gave each of the four KINDS its own shape and its own size, and
## Mathieu still could not read the map on device ("je la trouve pas
## lisible"). What he asked for instead is a MINIATURE OF THE REAL THING
## for the player, the twelve vehicles and the nine animals -- 22 pictures
## -- with the fifteen places keeping an abstract dot.
##
## A picture is per-ENTITY, not per-kind, so the map now needs to know
## WHICH of the 22 a given node is. Everything CH46 wrote about not
## matching on node names still holds -- five of the 37 markers have no
## name at all, and the ones that do move with the instantiation counter --
## so the identity is declared the same way membership already is: ONE
## ARGUMENT, at the site that builds the entity, next to the `mark()` call
## that is already there.
##
## THUMBS is the ORDER, and it is the only place that order exists. The
## baker (scripts/dev/MinimapThumbBake.gd) writes the atlas rows in it and
## HubMinimap reads the cells in it; MinimapProbe asserts that the two
## agree and that every id in this list is claimed by exactly one live
## node. A second spelling of this order anywhere would be the CH46
## draw-order defect again -- two files agreeing about a list until the
## day they do not.
##
## ⚠️ AN ENTITY WITH NO ENTRY HERE IS NOT AN ERROR: it keeps the abstract
## icon. That is how the fifteen places stay places, and it is the fallback
## for anything a later lot marks without a portrait.
const THUMB_META: StringName = &"minimap_thumb"
const THUMBS: Array[StringName] = [
	&"keepy",
	&"boat", &"balloon_0", &"balloon_1", &"balloon_2", &"hopball",
	&"yacht", &"sailboat", &"sled", &"kart_0", &"kart_1", &"kart_2", &"kart_3",
	&"bird_0", &"bird_1", &"bird_2",
	&"boar", &"cat", &"fawn", &"beaver", &"bear", &"badger"]

## The thumbnail a node declared, or &"" for "draw me as a shape".
static func thumb_of(node: Node) -> StringName:
	if node == null or not node.has_meta(THUMB_META):
		return &""
	return StringName(node.get_meta(THUMB_META))

## Which row of the atlas a thumbnail id occupies; -1 for none.
static func thumb_row(id: StringName) -> int:
	return THUMBS.find(id)

## Put `node` on the map as `kind`. Idempotent (Godot's add_to_group is),
## and safe to call before the node is in the tree. `thumb` is the entity's
## own entry in THUMBS, or &"" to keep the abstract icon.
static func mark(node: Node, kind: StringName, thumb: StringName = &"") -> void:
	if node == null:
		push_error("MinimapMarkers.mark: null node for kind '%s'." % kind)
		return
	node.add_to_group(kind)
	if thumb == &"":
		return
	if THUMBS.find(thumb) < 0:
		# Said out loud rather than dropped: a typo here would silently
		# demote a portrait to a dot, which is exactly the class of failure
		# CH46 built the group scheme to make impossible.
		push_error("MinimapMarkers.mark: '%s' is not in THUMBS." % thumb)
		return
	node.set_meta(THUMB_META, thumb)
