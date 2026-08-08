extends CollectibleBase
class_name Noisette
## A collectible hazelnut worth +1 score.
##
## Pooled by TrackSegment: picking one up hides it and disables its
## collision instead of freeing the node. TrackSegment.populate() resets
## `collected` and reactivates the slot on the next recycle. See
## CollectibleBase for the shared pooled lifecycle, size and spin/bob
## animation (identical between Noisette and Gland by design -- both must
## read as "ramassable", not just Noisette).

func _on_collected() -> void:
	GameState.add_noisette()
