extends RefCounted
class_name VehicleDrive
## CH30 -- THE DRIVING MODEL, extracted from KartBody so a SECOND vehicle
## can be driven by it without a second copy of the arithmetic.
##
## =====================================================================
## WHAT THIS IS
##
## Everything KartBody.drive() did to a position, a heading and a world
## velocity, and NOTHING it did to a chassis. The body still owns its
## art, its lean, its wheels and its bump; this owns the kinematics and
## the eight constants that shape them. One instance per vehicle, holding
## that vehicle's own numbers.
##
## The extraction was a PURE MOVE (brief CH30): the statements are in the
## same order, on the same values, with the same expressions -- so the
## same seed produces the same lap, bit for bit. That is not an argument,
## it is a measurement: RaceBalanceProbe and KartProbe were run on
## `origin/staging` and on this tree and their lap times and sampled
## trajectories compared (journal CH30). CLAUDE.md's rule for a shared
## mode applies here in full -- a regression on a karting Mathieu has just
## validated costs more than a duplication would have.
##
## ONE THING MOVED AND IT IS DELIBERATE: `steer_rate` is a PARAMETER
## rather than a read of KartTuning. The kart passes KartTuning.steer_rate()
## on every frame (so the live 8/7/6 preset still reaches it, unchanged);
## the sand yacht passes its own, because a yacht that steered like a kart
## would be a kart with a sail on it.
##
## =====================================================================
## WHY A RETURNED DICTIONARY AND NOT A MUTATED NODE
##
## The caller owns its transform. A Node3D's `global_position` is a
## round trip through its parent's transform, and a model that wrote it
## four times per step (add, flatten, fence x2) would be doing that round
## trip four times per frame per vehicle for no gain. Here the whole step
## is arithmetic on plain Vector3s and the node is written ONCE, by the
## caller, from the returned triple. On the hub both parents are identity
## (World and Karting are authored at the origin in HubWorld.tscn), so
## the two forms are numerically the same -- which is what made the
## byte-identical comparison above possible in the first place.

## Speed caps and how quickly speed approaches them.
var max_speed: float = 13.0
var max_speed_off: float = 5.5
var reverse_speed: float = 3.5
var boost_speed_ratio: float = 1.0
var accel_lambda: float = 0.85
var coast_lambda: float = 0.30
var off_lambda: float = 1.6
var brake_decel: float = 15.0
## Steering: below `steer_full_speed` the yaw rate scales in, and it eases
## back to `steer_high_speed_keep` of itself at `max_speed`.
var steer_full_speed: float = 4.5
var steer_high_speed_keep: float = 0.72
## Lateral velocity decay (1/s) on and off the good surface, and the
## forward speed lost per unit of lateral speed per second.
var grip_on: float = 5.0
var grip_off: float = 1.8
var scrub: float = 0.55
## Soft fence: velocity into the wall is reflected and scaled by this.
var fence_bounce: float = 0.35

## ⚠️ A FLOAT32 CELL FOR THE HEADING, AND IT IS LOAD-BEARING.
##
## MEASURED, and it is the whole reason the first version of this
## extraction was NOT a pure move. The caller stores the heading in
## `rotation.y`, a component of a Vector3, which in a single-precision
## Godot build is a FLOAT32: `rotation.y -= x` therefore rounds to 32 bits
## on every physics frame, and always has. A GDScript `float` is a
## FLOAT64, so an extraction that carried the heading in a plain local
## variable silently kept ~29 extra bits the shipped kart never had.
##
## That is not a rounding curiosity on a pure-pursuit controller: the
## steering feeds back into the line, which feeds back into the steering.
## Measured on KartTraceProbe over 5400 frames, the two builds separated
## at the last printed digit by frame 30 and were 0.07 u apart by frame
## 1200, with lap times drifting 17 ms over three laps. Nothing was
## WRONG -- it was a different drive, and "different" is exactly what the
## brief forbade.
##
## Writing the heading through a Vector3 component reproduces the
## truncation at the same place the node does it, and the trace then
## matches origin/staging line for line (journal CH30).
var _yaw32: Vector3 = Vector3.ZERO

## One physics step. Returns {position, yaw, velocity, hit_fence}.
##
## `on_surface` is the caller's verdict on where the vehicle is (the
## track's ribbon for a kart, the sand for a yacht); `fence` is the
## rectangle it is kept inside, on x/z; `steer_rate` is the yaw rate at
## full lock, read live by the caller.
func step(position: Vector3, yaw: float, velocity: Vector3, delta: float, input: KartInput,
		on_surface: bool, fence: Rect2, steer_rate: float) -> Dictionary:
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var v_fwd: float = velocity.dot(fwd)
	# ---- steering: rotate the HEADING; the velocity stays in the world.
	var ratio: float = clampf(absf(v_fwd) / steer_full_speed, 0.0, 1.0)
	var ease: float = 1.0 - (1.0 - steer_high_speed_keep) * clampf(absf(v_fwd) / max_speed, 0.0, 1.0)
	var gain: float = ratio * ease
	if v_fwd < -0.05:
		gain = -gain * 0.7
	# The float32 truncation the node itself performs -- see _yaw32.
	_yaw32.y = yaw - input.steer * steer_rate * gain * delta
	yaw = _yaw32.y
	fwd = Vector3(sin(yaw), 0.0, cos(yaw))
	var rgt := Vector3(fwd.z, 0.0, -fwd.x)
	# ---- decompose the (unchanged) world velocity in the NEW frame: the
	# turn just gave the vehicle a lateral component, which grip now eats.
	v_fwd = velocity.dot(fwd)
	var v_lat: float = velocity.dot(rgt)
	var grip: float = grip_on if on_surface else grip_off
	v_lat *= exp(-grip * delta)
	# Sliding scrubs pace.
	v_fwd = move_toward(v_fwd, 0.0, absf(v_lat) * scrub * delta)
	# ---- throttle / brake.
	var cap: float = max_speed if on_surface else max_speed_off
	cap *= lerpf(1.0, boost_speed_ratio, clampf(input.boost, 0.0, 1.0))
	if input.brake:
		if v_fwd > 0.3:
			v_fwd = maxf(v_fwd - brake_decel * delta, 0.0)
		else:
			v_fwd = move_toward(v_fwd, -reverse_speed, brake_decel * 0.4 * delta)
	else:
		var target: float = cap * input.throttle
		var lambda: float
		if v_fwd > cap:
			lambda = off_lambda
		elif target > v_fwd:
			lambda = accel_lambda
		else:
			lambda = coast_lambda
		if v_fwd < 0.0 and input.throttle > 0.0:
			# Reversing and the throttle comes back: brake the reverse
			# firmly, then the ordinary curve takes over.
			v_fwd = move_toward(v_fwd, 0.0, brake_decel * delta)
		else:
			v_fwd = lerpf(v_fwd, target, 1.0 - exp(-lambda * delta))
	velocity = fwd * v_fwd + rgt * v_lat
	position += velocity * delta
	position.y = 0.0
	var hit := false
	if position.x < fence.position.x:
		position.x = fence.position.x
		if velocity.x < 0.0:
			velocity.x = -velocity.x * fence_bounce
			hit = true
	elif position.x > fence.end.x:
		position.x = fence.end.x
		if velocity.x > 0.0:
			velocity.x = -velocity.x * fence_bounce
			hit = true
	if position.z < fence.position.y:
		position.z = fence.position.y
		if velocity.z < 0.0:
			velocity.z = -velocity.z * fence_bounce
			hit = true
	elif position.z > fence.end.y:
		position.z = fence.end.y
		if velocity.z > 0.0:
			velocity.z = -velocity.z * fence_bounce
			hit = true
	return {"position": position, "yaw": yaw, "velocity": velocity, "hit_fence": hit}
