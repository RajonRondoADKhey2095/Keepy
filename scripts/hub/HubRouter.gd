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

const ROUTES: Dictionary = {
	&"chased": "res://scenes/TitleScreen.tscn",
	&"quizz": "res://scenes/QuizzHomeScreen.tscn",
	&"battle": "res://scenes/Battle.tscn",
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
