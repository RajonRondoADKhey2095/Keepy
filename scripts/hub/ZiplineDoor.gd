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
##
## =====================================================================
## ⚠️ 4 SEPTEMBRE 2026 (tier 3) -- DOCTRINE CHANGE ON THE STAIR, BY EXPLICIT
## REQUEST, NOT A REVERSAL DISCOVERED IN ERROR.
##
## RECON 1 read "the only tappable thing at a tower is the badger" as a
## permanent rule; it was a description of tier 1's shape, and Mathieu has
## since asked, in so many words, for a second tap target ON the structure
## itself, so Keepy can ride ALONE in either direction without the badger.
## What RECON 1 actually settled -- and what still holds, unchanged -- is
## narrower than "the stair carries nothing": a tap channel must never be
## the LADDER PATTERN, an unconditional emit whose listener drops it. A
## structure channel that withdraws on the boat's own terms is not that
## pattern; it is a second boat moored at the same dock. See
## docs/lots/CH21_TYROLIENNE.md for the doctrine note in full.
##
## THE TWO DISCS AT END 0 ARE NOT DISJOINT, AND THAT IS DECIDED IN CODE, NOT
## BY DISTANCE. The badger's disc (radius 1.8, generous by the reasoning
## below) is centred 2.0165 u from the tower's own centre -- a geometry
## measured from BADGER_SIDE_OFFSET and the stair's own run, not supposed --
## so no structure disc big enough to cover the visible tower could also
## clear the badger's disc by geometry alone: 2.0165 - 1.8 leaves 0.2165 u,
## a target under 22 cm across and nobody could hit it. `accepts_structure_tap` therefore
## EXCLUDES, by construction, any point the badger's own disc would also
## accept at the end where a badger stands -- so the two channels can never
## agree on the same tap regardless of which order a caller asks them in.
## The player-facing result: a tap ON the badger rides with it; a tap
## anywhere else on the tower or its stair goes alone. At the far end there
## is no badger to exclude, so the whole structure disc is the solo target.

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

## Ground radius, in world units, within which a tap on the STRUCTURE
## itself -- tower, deck or stair, at either end -- means "ride alone".
##
## 2.0, chosen to cover `ZiplineStructureProbe.STRUCTURE_RADIUS_BUDGET`
## (1.932, the measured worst emprise of a tower's drawn parts) with a
## small margin, so the whole visible structure is inside the disc rather
## than a liseré of ground around it that reads as empty. `_ends` already
## holds the tower centres this is measured from -- the same points the
## badger's own waiting position and every clearance check in
## ZiplineStructureProbe are built off, so this cannot drift from what is
## actually drawn.
const STRUCTURE_TAP_RADIUS: float = 2.0

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

## Marks the badger away from BOTH ends, or back at one of them, without a
## cable trip -- CH24's campfire detour. Reuses the exact gate a trip
## already relies on rather than adding a second flag: `accepts_boarding_tap`
## refuses whenever `_at_end < 0`, which is already the "in transit" reading
## `set_riding(true)` writes, so setting `_at_end` to -1 here withdraws the
## badger channel on the SAME terms, and setting it back to a real index
## reopens it -- exactly HubTapInput's boat pattern (a withdrawal through a
## node, never a flag `HubTapInput` itself has to know a second name for).
##
## ⚠️ `_riding` IS DELIBERATELY LEFT ALONE. Walking away to the campfire
## does not touch the cable, so `accepts_structure_tap`'s solo channel --
## which only reads `is_available()`, i.e. `not _riding` -- stays exactly as
## available as it already was. Only the badger's own boarding disc closes.
func set_badger_at(index: int) -> void:
	_at_end = index

## Called by HubWorld at the start and end of a trip. The end is handed in
## on the way back so that the door and the actor cannot disagree about
## where the pair came to rest: one write, from the site that moved them.
func set_riding(riding: bool, arrived_at: int = -1) -> void:
	_riding = riding
	if riding:
		_at_end = -1
	elif arrived_at >= 0:
		_at_end = arrived_at

## =====================================================================
## THE STRUCTURE CHANNEL -- a tap on the tower itself, for a SOLO ride.
##
## Shares `_riding` with the badger channel (one cable, one trip at a
## time), and asks nothing about `_at_end`: unlike the badger, the
## structure is standing at BOTH ends always, so a tap on either tower
## means "ride away from here" whenever the cable is idle. Which way is
## decided later, at the moment of boarding, from wherever Keepy is
## actually standing -- the same rule the badger's own boarding already
## follows, and for the same reason: a remembered index could go stale
## between the tap and the walk it starts.

## The end index a structure tap at `point` means, or -1 when the point is
## not on either tower, the cable is riding, or the point belongs to the
## badger's own disc at the end it is waiting.
func accepts_structure_tap(point: Vector3) -> int:
	if not is_available():
		return -1
	var flat := Vector3(point.x, 0.0, point.z)
	for i in _ends.size():
		if flat.distance_to(_ends[i] as Vector3) > STRUCTURE_TAP_RADIUS:
			continue
		if i == _at_end and accepts_boarding_tap(point):
			continue
		return i
	return -1

## The two tower centres, flat, in the order `_ends` carries them --
## `HubWorld` uses this to work out which end Keepy is actually standing
## beside at the moment of boarding, the same way it reads the badger's
## live position rather than a remembered tap.
func structure_point(index: int) -> Vector3:
	if index < 0 or index >= _ends.size():
		return Vector3.ZERO
	return _ends[index]
