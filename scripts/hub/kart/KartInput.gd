extends RefCounted
class_name KartInput
## What a kart is TOLD, by whoever is driving it -- and nothing about who.
##
## Carte-blanche V7. The one seam the karting chantier is built around: a
## KartBody reads this object every physics frame and never asks where the
## values came from. KartTouchInput writes it from a thumb on the screen
## (and from the keyboard off-web, for probes and the editor); the lot-2
## opponents will write it from a line follower. Same body, same physics,
## same track, same lap logic -- only the writer differs.
##
## Values are HELD, not events: whoever writes them is responsible for
## clearing them (a lifted finger writes 0), and a writer that stops
## writing leaves the last frame's intent in place. That is deliberate --
## an AI that updates every other frame still drives -- but it is also why
## reset() exists and why HubKarting calls it on every mode change.

## -1 full left .. +1 full right. Proportional: a light touch is a light
## turn, which is what makes the kart forgiving.
var steer: float = 0.0
## 0 .. 1. The player's writer holds this at 1 (automatic accelerator);
## it is a float so a follower can feather it.
var throttle: float = 0.0
## Brake while moving forward, reverse once stopped.
var brake: bool = false
## V7b: 0..1, how hard the player is PUSHING for extra pace on top of the
## automatic cruise (KartBody.BOOST_MAX_SPEED). Defaults to 0, so every
## writer that predates the accelerator retour (KartLineInput, KartProbe's
## direct set_all calls) drives exactly as before.
var boost: float = 0.0

func reset() -> void:
	steer = 0.0
	throttle = 0.0
	brake = false
	boost = 0.0

func set_all(new_steer: float, new_throttle: float, new_brake: bool, new_boost: float = 0.0) -> void:
	steer = clampf(new_steer, -1.0, 1.0)
	throttle = clampf(new_throttle, 0.0, 1.0)
	brake = new_brake
	boost = clampf(new_boost, 0.0, 1.0)
