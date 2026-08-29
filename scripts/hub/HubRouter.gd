extends Node
class_name HubRouter
## The ONE place that knows a game_id maps to a scene path, and the one
## place that changes scene.
##
## Deliberately a plain node inside HubWorld.tscn and NOT an autoload: it
## holds no state, survives nothing, and is needed by exactly one screen.
## An autoload would make it reachable from everywhere and therefore
## something a future screen could call instead of doing its own
## navigation -- a routing table that grows a second caller stops being a
## hub detail and starts being a framework.
##
## The portals do not call change_scene_to_file themselves. A portal is a
## thing you can stand on; where standing on it takes you is a property of
## the hub, not of the portal. That split is what lets HubWorld connect a
## portal to something else entirely (a confirmation, an animation) later
## without touching HubPortal.gd.

## ⚠️ THE CABIN IS ROUTED HERE TOO, and it is NOT a portal.
##
## It is in this table because this file is "the ONE place that knows a
## game_id maps to a scene path, and the one place that changes scene", and
## the cabin became a scene change. Letting HubWorld call
## change_scene_to_file itself for the one prop that is not a portal would
## put a second scene-changer in the hub -- which is precisely the thing
## the header above refuses.
##
## What it does NOT share with the three portals is the way it is REACHED.
## A portal is entered by LANDING on it, and a landing is easy to make by
## accident -- a hop aimed past a portal flies through its volume -- so the
## three of them go through HubConfirmDialog first. The cabin is entered by
## TAPPING ITS DOORSTEP, which is already a deliberate act on a target
## measured and narrowed for exactly that reason, so it routes straight
## through with no question asked. That difference is in HubWorld, where
## the decision to route is taken; the table itself does not care.
const ROUTES: Dictionary = {
	&"chased": "res://scenes/TitleScreen.tscn",
	&"quizz": "res://scenes/QuizzHomeScreen.tscn",
	&"battle": "res://scenes/Battle.tscn",
	&"cabin": "res://scenes/CabinInterior.tscn",
}

## Guards against a second transition being requested while the first is
## already in flight -- change_scene_to_file is deferred, so two portals
## reached on the same frame would otherwise both queue a load.
var _leaving: bool = false

## Sends the player to the scene `game_id` names. Unknown ids are reported
## and ignored: an unroutable portal must leave the player standing on the
## plateau, not drop them into a blank scene.
func route(game_id: StringName) -> void:
	if _leaving:
		return
	if not ROUTES.has(game_id):
		push_error("HubRouter: no route for game_id '%s'." % game_id)
		return
	_leaving = true
	var path: String = ROUTES[game_id]
	get_tree().change_scene_to_file(path)
