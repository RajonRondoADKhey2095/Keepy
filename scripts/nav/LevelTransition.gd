extends RefCounted
class_name LevelTransition
## A link between two adjacent levels, and the gate that stops a tap
## re-triggering one that is already running.
##
## =====================================================================
## THE GATE IS THE BOAT'S ACTIVE WITHDRAWAL, AND THE LADDER'S IS BANNED
##
## Two patterns exist in the hub for "a prop that answers taps", and only
## one of them is safe here.
##
## THE BOAT withdraws: BoatMooring.accepts_boarding_tap() returns false for
## the whole of a ride, so a tap during one falls THROUGH to the ground
## path and becomes the eject. One tap, one signal, either way.
##
## THE LADDER does not: HubTapInput emits tapped_ladder whatever Keepy is
## doing and HubWorld drops it. That is harmless for a plank -- whose only
## other meaning would be a dive already handled by state -- and it has
## cost this repository TWO separate bugs where it was copied to something
## that needed the withdrawal (the cabin's stray entry, and the historical
## ladder). It is BANNED here, not merely discouraged.
##
## Why it would be wrong for a transition specifically: a tap made while a
## transition is running has to be able to reach the ordinary ground path.
## A player whose taps are being swallowed by the very thing carrying him
## between levels has no way to say anything at all until it finishes.
##
## =====================================================================
## A TRANSITION HAS TWO SIDES AND NO DIRECTION
##
## It is not "the way up"; it is a link, asked from whichever level Keepy
## is standing on. Writing a direction into it would mean a second entry
## for the way back, and two entries describing one ladder is how the two
## ends stop agreeing about where the ladder is.

## Level indices this links. Adjacent by convention -- nothing here checks
## that they are, because "adjacent" is a fact about a world and this is
## one link in it.
var level_a: int = -1
var level_b: int = -1

## Where Keepy has to stand on each side, ALREADY at that level's floor
## height. Built by the caller from the two LevelDefinitions, so the point
## a player aims at and the point this radius is measured from are one
## fact rather than two.
var point_a: Vector3 = Vector3.ZERO
var point_b: Vector3 = Vector3.ZERO

## How close an AIM has to land to mean this transition, in WORLD units.
##
## World units and not pixels, for the reason the boat's radius is: a pixel
## target shrinks with distance, so the same gesture would mean different
## things depending on where the player happens to be standing.
var tap_radius: float = 1.0

## THE WITHDRAWAL. False for the whole of a crossing.
var _available: bool = true

static func make(level_a: int, level_b: int, point_a: Vector3, point_b: Vector3,
		tap_radius: float) -> LevelTransition:
	var link := LevelTransition.new()
	link.level_a = level_a
	link.level_b = level_b
	link.point_a = point_a
	link.point_b = point_b
	link.tap_radius = maxf(tap_radius, 0.0)
	return link

## The boat's is_available(). Read before anything else is asked.
func is_available() -> bool:
	return _available

## Held off for the whole of a crossing by whoever runs it.
func set_busy(busy: bool) -> void:
	_available = not busy

## Does this transition serve `level_index` at all?
func serves(level_index: int) -> bool:
	return level_index == level_a or level_index == level_b

## The level on the other side of `level_index`, or -1 when this link does
## not serve it. -1 rather than a default: a caller that asks about a level
## this link does not touch has a bug, and returning level_a would hide it.
func other_side(level_index: int) -> int:
	if level_index == level_a:
		return level_b
	if level_index == level_b:
		return level_a
	return -1

## Where Keepy stands on `level_index` to use this link.
func entry_for(level_index: int) -> Vector3:
	if level_index == level_a:
		return point_a
	if level_index == level_b:
		return point_b
	return Vector3.ZERO

## Where he arrives when crossing FROM `level_index`.
func exit_from(level_index: int) -> Vector3:
	var other := other_side(level_index)
	if other < 0:
		return Vector3.ZERO
	return entry_for(other)

## ⚠️ ASKED ON THE **AIM**, NEVER ON A CLAMPED DESTINATION.
##
## This is the lot-1 rule, and it is stated on the function that would
## break if it were forgotten. clamp_to() answers "where can he stand"; a
## prop test answers "what did the player mean". Reading the second off the
## first turns the clamp into a FUNNEL: every tap on ground that does not
## exist is dragged to the nearest ground that does, so a link sitting near
## an EDGE starts meaning the whole half-plane behind it.
##
## MEASURED on the shipped hub before it was fixed: the cabin doorstep
## stands 0.655 u inside the plateau's north edge, and taps aimed from as
## far as 49.8 u off the map landed on it and MEANT "go inside" -- standing
## at the door, 15.26% of all visible ground said "go inside", 89.2% of it
## aiming at ground that is not there.
##
## A MULTI-LEVEL WORLD MAKES THIS WORSE, NOT EQUAL: every level has its own
## edge, so every transition placed near one is another potential funnel.
## That is why the rule is taken from the first line here rather than
## rediscovered, and why the probe gates it explicitly.
func accepts_tap(aim: Vector3, level_index: int) -> bool:
	# Through is_available(), NEVER the field directly. Found by the
	# red-before-green pass: with the accessor sabotaged to model the
	# ladder pattern, this function still read `_available` and kept
	# refusing, so only ONE of the two gate checks went red. One field,
	# two readers, one of them bypassing the accessor is how the two
	# answers start to differ.
	if not is_available():
		return false
	if not serves(level_index):
		return false
	var here := entry_for(level_index)
	var flat_aim := Vector3(aim.x, 0.0, aim.z)
	var flat_here := Vector3(here.x, 0.0, here.z)
	return flat_aim.distance_to(flat_here) <= tap_radius
