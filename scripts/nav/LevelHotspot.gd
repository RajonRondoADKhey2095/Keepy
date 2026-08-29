extends RefCounted
class_name LevelHotspot
## A tappable point of interest that is NOT a level change.

## A door, a bed, a chest: something on one level that answers a tap and
## does something other than move Keepy between storeys.
##
## =====================================================================
## WHY THIS IS NOT A LevelTransition WITH A FLAG
##
## A transition has TWO sides and no direction, and every accessor on it --
## other_side(), entry_for(), exit_from() -- is about the level you are not
## on yet. A door out of the building has no other side IN THIS WORLD: it
## ends the scene. Modelling it as a transition would mean a level index
## that names nothing, and every one of those accessors returning -1 or
## Vector3.ZERO for it -- values a caller has to remember to disbelieve.
##
## So it is a sibling class, not a subclass and not a flag.
##
## =====================================================================
## ⚠️ THE BOAT'S WITHDRAWAL IS COPIED VERBATIM, AND THE LADDER'S IS BANNED
##
## Same rule LevelTransition states at length, and for the same measured
## reason -- it is repeated here rather than referenced because the next
## person to add a hotspot will read THIS file:
##
## THE BOAT withdraws: BoatMooring.accepts_boarding_tap() answers false for
## the whole of a ride, so a tap during one falls THROUGH to the ground
## path. One tap, one signal, either way.
##
## THE LADDER does not: HubTapInput emits its signal whatever Keepy is
## doing and the listener drops it. That has cost this repository TWO bugs
## where it was copied to something that needed the withdrawal -- one of
## them the cabin's own stray entry tap. It is BANNED here.
##
## For a door specifically the withdrawal is load-bearing rather than
## tidy: change_scene_to_file() is deferred to the end of the frame, so
## without it a second tap landing in the same frame calls it twice.
##
## =====================================================================
## ⚠️ ASKED ON THE **AIM**, NEVER ON A CLAMPED DESTINATION
##
## The lot-1 rule, restated on the function that would break without it.
## clamp_to() answers "where can he stand"; this answers "what did the
## player mean". Reading the second off the first turns the clamp into a
## FUNNEL -- every tap on ground that does not exist is dragged to the
## nearest ground that does, so a hotspot near an EDGE starts meaning the
## whole half-plane behind it.
##
## That is not hypothetical for the cabin's door. It stands 0.35 world
## units inside the ground floor's +Z edge, so on the CLAMPED point every
## tap aimed anywhere past that edge -- the entire half-plane in front of
## the house, most of it aimed at floor that does not exist -- would land
## within 0.35 of the door and mean "leave". On the AIM it means what it
## points at.

## Which level this hotspot lives on. ONE level, unlike a transition:
## a thing you can tap is somewhere you are standing.
var level_index: int = -1

## Where it is, ALREADY at that level's floor height. Built by the caller
## from the LevelDefinition so the point a player aims at and the point
## this radius is measured from are one fact rather than two.
var point: Vector3 = Vector3.ZERO

## How close an AIM has to land to mean this hotspot, in WORLD units.
##
## World units and not pixels, for the reason every other prop radius in
## this project is: a pixel target shrinks with distance, so the same
## gesture would mean different things depending on where the player
## happens to be standing.
var tap_radius: float = 1.0

## What it is, for the listener to switch on. A StringName and not an
## enum: an enum here would have to be edited in this generic file every
## time a screen invents a new kind of thing to tap.
var kind: StringName = &""

## What the marker above it says. Empty draws no label.
var label: String = ""

## THE WITHDRAWAL. False once whatever this hotspot starts is running.
var _available: bool = true

static func make(level_index: int, point: Vector3, tap_radius: float,
		kind: StringName, label: String = "") -> LevelHotspot:
	var spot := LevelHotspot.new()
	spot.level_index = level_index
	spot.point = point
	spot.tap_radius = maxf(tap_radius, 0.0)
	spot.kind = kind
	spot.label = label
	return spot

## The boat's is_available(). Read before anything else is asked.
func is_available() -> bool:
	return _available

## Held off by whoever runs what this hotspot starts.
func set_busy(busy: bool) -> void:
	_available = not busy

## Does this hotspot exist on `index` at all?
func serves(index: int) -> bool:
	return index == level_index

## ⚠️ ASKED ON THE **AIM**. See the header.
func accepts_tap(aim: Vector3, index: int) -> bool:
	# Through is_available(), NEVER the field directly -- LevelTransition's
	# red-before-green pass found that a second reader bypassing the
	# accessor is how one field starts giving two answers.
	if not is_available():
		return false
	if not serves(index):
		return false
	var flat_aim := Vector3(aim.x, 0.0, aim.z)
	var flat_here := Vector3(point.x, 0.0, point.z)
	return flat_aim.distance_to(flat_here) <= tap_radius
