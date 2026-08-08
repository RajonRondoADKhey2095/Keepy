extends CollectibleBase
class_name Gland
## A high-value bonus collectible sitting above Keepy's normal running
## height, reachable only near the apex of a jump (see TrackSegment.gd
## GLAND_Y, derived from Keepy.JUMP_PEAK_HEIGHT / CAPSULE_HALF_HEIGHT --
## never a guessed height). Missing the jump window simply means the
## Gland goes uncollected; unlike an obstacle, there is no penalty.
##
## Pooled by TrackSegment exactly like Noisette: picking one up hides it
## and disables its collision instead of freeing the node.
## TrackSegment.populate() resets `collected` and reactivates the slot
## on the next recycle. See CollectibleBase for the shared pooled
## lifecycle, size and spin/bob animation.
##
## Visually kept in the SAME golden/bright family as Noisette (never
## brown -- see Gland.tscn) so both read as "collectible" at a glance,
## deliberately distinct from the ground-level JUMP obstacle, which is
## brown and inert. The Gland's warmer tone + emissive glow (Gland.tscn)
## sets it apart from Noisette itself and helps it stay legible at its
## smaller size and elevated GLAND_Y height (worth GLAND_VALUE points,
## see GameState.gd, vs. Noisette's NOISETTE_VALUE -- the extra
## brightness reads as "worth more").

func _on_collected() -> void:
	GameState.add_gland()
