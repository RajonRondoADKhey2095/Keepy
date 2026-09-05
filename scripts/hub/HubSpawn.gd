extends RefCounted
class_name HubSpawn
## Where Keepy should be standing the next time HubWorld loads.
##
## =====================================================================
## WHY THIS EXISTS AT ALL -- measured, not assumed
##
## Every route out of the hub today is one line: change_scene_to_file to
## HubWorld.tscn. Chased, Quizz, Battle, the login screen and the nav-test
## bench all do exactly that, and HubWorld.tscn's Keepy node carries NO
## transform -- so every one of them puts him back at the world origin.
##
## That is right for a sub-game. You went somewhere else and came back to
## the middle of the plateau. It is WRONG for a door: walking out of a
## cabin has to put you in front of that cabin, and the plateau has no way
## to say so.
##
## =====================================================================
## WHY A static var AND NOT AN AUTOLOAD
##
## HubRouter's own header refuses to be an autoload, and the argument
## applies with more force here: "a routing table that grows a second
## caller stops being a hub detail and starts being a framework". An
## autoload is reachable from everywhere, so every future screen could
## write a spawn into it, and the one thing this must not become is a
## general-purpose teleport.
##
## A static var on a plain class is the smallest thing that survives a
## scene change -- script classes stay loaded across change_scene_to_file,
## the tree does not -- and it is reachable only by files that name it.
##
## =====================================================================
## ⚠️ IT IS CONSUMED, NOT READ
##
## take() clears as it returns. A spawn that stayed set would apply to the
## NEXT load of the hub too: come out of the cabin, walk away, go into
## Chased, come back -- and be standing at the cabin door again with no
## idea why. One write, one read, and the pending flag is the thing that
## says which.
##
## The Y is deliberately discarded on the way in: the plateau is a
## single-altitude model and a spawn is a place on it, not a point in the
## air. Storing a height here would be the first line of a second opinion
## about where the ground is.

static var _pending: bool = false
static var _where: Vector3 = Vector3.ZERO

## Asks that the next HubWorld load start Keepy at `where` instead of the
## scene's authored origin. Flattened on the way in -- see the header.
static func request(where: Vector3) -> void:
	_pending = true
	_where = Vector3(where.x, 0.0, where.z)

## True while a spawn is waiting to be consumed. Published so a probe can
## assert the clearing, and so a caller can branch without having to read
## a sentinel value out of the point itself.
static func has_pending() -> bool:
	return _pending

## The pending spawn, CLEARED as it is handed over. Returns ZERO when
## nothing is pending -- which is why the caller checks has_pending()
## rather than comparing the point against the origin: the origin is a
## legal place to stand.
static func take() -> Vector3:
	var where := _where
	_pending = false
	_where = Vector3.ZERO
	return where

## Drops a pending spawn without using it. For a caller that decided not
## to leave after all, and for a probe that has to start from a known
## state rather than from whatever the last test left behind.
static func clear() -> void:
	_pending = false
	_where = Vector3.ZERO
