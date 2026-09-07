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
##
## ⚠️ THIS IS THE *AI's* BRAKE, and CH42 is what separated the two
## meanings. KartAiDriver presses it before a bend, at speeds where the
## reverse half of VehicleDrive's brake branch is never reached; the
## player's second finger used to press the same field for the opposite
## intent -- "stop, then back me out of here". One field answering two
## questions is how this repo lost a lot to `clamp_to` (CLAUDE.md, AIM vs
## DESTINATION CLAMPEE), so the player's intent moved to `reverse` below
## and this one stayed exactly what the opponents mean by it.
var brake: bool = false
## 0 .. 1, HELD: the REVERSE GEAR, and a separate axis from `throttle`
## rather than a negative value on it.
##
## CH42, and it is a diagnosis and not a feature request. Pinned nose-first
## against a region wall a vehicle keeps almost no forward speed (the wall
## eats it every frame) -- and VehicleDrive's steering gain is
## `|v_fwd| / steer_full_speed`, so at the wall FULL LOCK buys 2 % of a
## turn: measured 17.15 deg in 3 s on the ridge's north edge, and exactly
## 0.0000 u/s with no yaw at all in its corners. The only way out is
## backwards, which is why this is an INPUT and not a tuning constant.
##
## A float rather than a bool so a writer can feather it and so a probe can
## hold a fraction; 0.0 by default, which is what makes every writer that
## predates CH42 -- KartAiDriver, KartProbe's set_all calls, the trace
## probes -- drive exactly as it did.
var reverse: float = 0.0
## V7b: 0..1, how hard the player is PUSHING for extra pace on top of the
## automatic cruise (KartBody.BOOST_MAX_SPEED). Defaults to 0, so every
## writer that predates the accelerator retour (KartLineInput, KartProbe's
## direct set_all calls) drives exactly as before.
var boost: float = 0.0

func reset() -> void:
	steer = 0.0
	throttle = 0.0
	brake = false
	reverse = 0.0
	boost = 0.0

## `new_reverse` defaults to 0, so every existing call site -- all of which
## predate CH42 -- keeps writing exactly the four values it always wrote.
func set_all(new_steer: float, new_throttle: float, new_brake: bool, new_boost: float = 0.0,
		new_reverse: float = 0.0) -> void:
	steer = clampf(new_steer, -1.0, 1.0)
	throttle = clampf(new_throttle, 0.0, 1.0)
	brake = new_brake
	boost = clampf(new_boost, 0.0, 1.0)
	reverse = clampf(new_reverse, 0.0, 1.0)
