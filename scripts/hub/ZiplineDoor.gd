extends Node
class_name ZiplineDoor
## The zipline's tap door: it answers the one question HubTapInput has to
## ask before it resolves a ground destination -- was that tap on the
## badger waiting to ride?
##
## =====================================================================
## THE BOAT PATTERN, AND WHY IT HAD TO BE A NODE AND NOT A FLAG
##
## `BoatMooring.accepts_boarding_tap()` answers false for the whole of a
## ride, so a tap made meanwhile falls through to `tapped_ground` and
## BECOMES the eject. That withdrawal is the whole of the pattern, and
## RECON 1 (docs/lots/CH21_TYROLIENNE.md) settled that the banned LADDER
## pattern is exactly its absence: a channel that emits whatever the body
## is doing, and a listener that drops it, leaves a player with no way left
## to say anything.
##
## The owl gets away with a plain `owl_available` bool on HubTapInput
## because there is only ever ONE thing to withdraw: the perch. A zipline
## has TWO boarding points -- one at each end -- and it is bidirectional,
## so "is this end open" is a question with a different answer at each end
## AND a shared answer during a trip. A single bool on the tap node could
## express the shared half and not the per-end half; two bools could
## express both and would be free to disagree. So the state lives HERE, in
## one object, and both ends are read off it.
##
## ⚠️ BOTH ENDS WITHDRAW FOR THE WHOLE OF A TRIP, IN EITHER DIRECTION.
## That is the brief's rule and it is implemented as one flag rather than
## as two: `_riding` is asked before the end is even looked at, so there is
## no ordering in which one end could stay open while the other closed.
##
## =====================================================================
## WHY THE TAP TARGET IS THE BADGER AND NOT THE STAIR
##
## RECON 1: a stair that carries a hotspot and emits nothing is the ladder
## pattern. The stair therefore carries nothing at all, and the only
## tappable thing at a tower is the badger standing beside it -- an actor
## that MOVES, because it rides across with Keepy and waits at whichever
## end the pair last arrived at.
##
## So the disc this node tests is not a layout constant: it is read off the
## actor's live position, the same rule the boat's radius is measured on
## the hull's live position rather than on its authored mooring.
##
## =====================================================================
## WHY THE RADIUS IS IN WORLD UNITS
##
## Identical to the boat's reasoning: a pixel radius would mean a
## different-sized target depending on how far away the badger happens to
## be drawn, and both towers are drawn small and far apart. The radius is
## measured on the GROUND POINT the tap resolves to, which is the same
## quantity a hop destination is.

## Ground radius, in world units, within which a tap means "ride" rather
## than "walk there".
##
## 1.8, the owl's number and for the owl's reason: the badger is drawn
## 1.3501 u tall at this camera distance, far smaller than a fingertip, so
## a target the size of the rig would be a target nobody could hit. Safe to
## be generous here -- the ground inside the disc is the foot of a tower
## nobody has another reason to aim at, and the two discs are 25.9 u apart,
## so no tap can ever be inside both.
const BOARD_TAP_RADIUS: float = 1.8

## The two ends, flat, in the order `HubBuilder.ziplines()` published them
## (near end first). Empty until HubWorld hands the built zipline over, so
## a layout with no zipline simply never emits `tapped_zipline`.
var _ends: Array[Vector3] = []

## The actor whose live position IS the tap target. Never a copy of where
## it was put: it walks and it rides, so a remembered point would be a disc
## left behind at the end it departed from.
var _rider: Node3D = null

## Which end index the badger is waiting at, or -1 while it is in transit.
## Written by HubWorld at the two moments it can change: setup, and the end
## of a trip.
var _at_end: int = -1

## True for the whole of a trip, in EITHER direction. Asked before the end
## is looked at, so there is no order in which one end could stay open.
var _riding: bool = false

## Hands over the two built ends and the actor that waits at them. Called
## once, by HubWorld, after HubBuilder has built the zipline -- this node
## owns neither and builds neither.
func setup(ends: Array[Vector3], rider: Node3D, at_end: int) -> void:
	_ends = ends.duplicate()
	_rider = rider
	_at_end = at_end

## True when there is a zipline, a badger, and no trip running.
func is_available() -> bool:
	return _rider != null and is_instance_valid(_rider) and _ends.size() == 2 and not _riding

## True when END `index` is open for boarding: the zipline is idle AND the
## badger is standing at that end.
##
## ⚠️ BOTH CALLS ARE FALSE FOR THE WHOLE OF A TRIP. `is_available()` is
## asked first and does not look at `index` at all, so a trip closes both
## ends by construction rather than by two agreeing answers.
func is_available_at(index: int) -> bool:
	if not is_available():
		return false
	return index == _at_end

## The end index the badger is waiting at, or -1 in transit.
func waiting_end() -> int:
	return _at_end

## The end the badger is waiting at, flat. Vector3.ZERO when it is in
## transit or nothing is set up, which only matters to a caller that
## already checked `is_available()`.
func waiting_point() -> Vector3:
	if _at_end < 0 or _at_end >= _ends.size():
		return Vector3.ZERO
	return _ends[_at_end]

## The OTHER end -- where a trip from `waiting_end()` arrives. -1 when
## there is nothing to travel to.
func far_end() -> int:
	if _at_end < 0 or _ends.size() != 2:
		return -1
	return 1 - _at_end

## Where the badger is standing right now, flat. THE TAP TARGET, read off
## the live actor rather than off a remembered point: it rides across, so a
## stored position would leave a disc at the end it left.
func rider_position() -> Vector3:
	if _rider == null or not is_instance_valid(_rider):
		return Vector3.ZERO
	return Vector3(_rider.global_position.x, 0.0, _rider.global_position.z)

## True when `point` is close enough to the waiting badger to mean "ride".
## False for the whole of a trip, so a tap then falls through to the ground
## path -- which is what stops the pair being a prop that swallows taps.
func accepts_boarding_tap(point: Vector3) -> bool:
	if not is_available() or _at_end < 0:
		return false
	return Vector3(point.x, 0.0, point.z).distance_to(rider_position()) <= BOARD_TAP_RADIUS

## Called by HubWorld at the start and end of a trip. The end is handed in
## on the way back so that the door and the actor cannot disagree about
## where the pair came to rest: one write, from the site that moved them.
func set_riding(riding: bool, arrived_at: int = -1) -> void:
	_riding = riding
	if riding:
		_at_end = -1
	elif arrived_at >= 0:
		_at_end = arrived_at
