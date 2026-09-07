extends RefCounted
class_name SurfaceDrive
## CH41 -- THE COMPOSITE CH35 Q2-B RECOMMENDED: a vehicle that drives on a
## SURFACE instead of on the y = 0 plane.
##
## =====================================================================
## WHAT IT IS, AND WHAT IT IS NOT
##
## It OWNS a VehicleDrive and it OWNS the ground query, and it does the
## three things CH35 Q2 strategy A prescribed, once, so that no vehicle
## has to write them again:
##
##   1. step() runs on a FLAT position, exactly as it has always run, so
##      its arithmetic is the arithmetic three vehicles were validated on;
##   2. the gravity of the slope is injected into the WORLD VELOCITY the
##      model just wrote -- it is a force, not a speed, so it accelerates
##      the way a hill accelerates;
##   3. the returned position is REBASED onto the surface (y = height_at)
##      and the surface normal is published for the caller's chassis.
##
## ⚠️ STEP 2 IS AFTER STEP 1, AND CH35 Q2 SAID BEFORE. That is a
## MEASURED correction to its letter, not a liberty, and the measurement
## is this: with the force injected BEFORE, a vehicle standing still and
## facing UPHILL is FROZEN AT EXACTLY ZERO. The force makes v_fwd negative
## before the model looks at it; VehicleDrive then takes its "reversing
## and the throttle comes back" branch (`move_toward(v_fwd, 0, brake_decel
## * delta)`), which pulls the reversal back to zero and NEVER past it, so
## the throttle branch that would have driven it forward is never reached.
## At zero speed that model gives no yaw authority either (its `ratio`),
## so the player is parked on a hillside with no steering and no way off
## -- the sand yacht's own lock-up (SandYacht._wall step 3), arrived at
## from the other side. SledProbe PHASE E measured it: 0.000 u/s and
## 0.00 u travelled in 240 frames, on the steepest flank.
##
## Injected AFTER, the model sees v_fwd = 0, accelerates it forward on its
## ordinary branch, and the slope then takes its share back. The vehicle
## crawls uphill instead of sticking. Everything else is unchanged: the
## terminal speed of a descent is still cap + force/off_lambda (the force
## is added outside the damping either way), and a flat hub still adds
## exactly zero. The cost is a one-frame lag on the force -- the
## difference between an explicit and a semi-implicit integration order,
## which at 60 Hz is 0.17 u/s on the steepest ground this map has.
##
## SledProbe PHASE E gates the climb from rest, so the day someone puts
## the injection back in front of step() it fails on the sentence above.
##
## It is NOT a fork of VehicleDrive and it does not touch that file. It
## does not replace the caller's wall either: SandYacht's axis-separated
## slide stays where it is, because "where may this vehicle go" is a
## property of the vehicle and not of the ground under it.
##
## ⚠️ NOBODY IS MIGRATED ONTO THIS. The kart, the sand yacht and the
## sailboat are three conduites Mathieu validated on device; CH35 Q2's
## recommendation is explicit that the composite is adopted by the NEW
## vehicle only. On a flat hub this class is arithmetically a no-op
## (height_at 0, normal UP, slope force 0), so migrating them later is a
## provable move -- but it is not this lot's move, and KartBody's own
## `global_position = out["position"]` is untouched.
##
## =====================================================================
## WHY THE SLOPE IS A FORCE AND NOT A SPEED
##
## A hill does not set a speed, it adds acceleration for as long as you
## are on it -- which is why a long shallow flank ends up faster than a
## short steep one, and why letting go at the top feels different from
## letting go halfway down. Writing the slope as a speed target would have
## given a hill a "pace" and lost both of those.
##
## The vector is the ordinary tangential gravity, PROJECTED ON XZ because
## that is the plane step() moves in:
##
##   n = normalize(-hx, 1, -hz)              the surface normal
##   a = g - (g . n) n                       gravity minus its normal part
##   a.xz = (-g hx, -g hz) / (1 + hx^2 + hz^2)
##
## whose magnitude is g sin(theta) cos(theta) -- the horizontal shadow of
## the along-slope acceleration, which is the right number for a model
## whose position moves in xz. `slope_gain` scales it: a real 4.5 u hill
## is short, and the gain is the knob that makes a short hill FEEL like a
## hill without deforming the relief (which CH41's brief forbids).
##
## =====================================================================
## THE SPEED CAP IS THE CALLER'S BUSINESS, AND THAT IS THE VERROU
##
## VehicleDrive pulls any speed above `max_speed` back toward it at
## `off_lambda` (1.6/s). That pull is a DAMPING, not a ceiling: with a
## constant acceleration `a` the speed settles at max_speed + a/off_lambda
## rather than at max_speed, so a slope DOES overtake the engine on its
## own. What it does not do on its own is overtake it by ENOUGH to read as
## a plunge, and `max_speed` is a plain instance variable that SailBoat
## already modulates every frame -- so a vehicle whose ceiling rises with
## the grade needs nothing from VehicleDrive.gd. `grade_at()` below is
## what it reads to do that, and it is published here so the caller does
## not differentiate the ground a second time.

## Standard gravity. Named rather than written 9.81 inside a formula: it
## is the one number here that is physics and not feel, and a lot that
## wants a different pull moves `slope_gain`, never this.
const GRAVITY: float = 9.81

## The driving model this composite owns. PUBLIC: a vehicle configures its
## own eight constants on it exactly as it does today, and reads
## `max_speed` back on it every frame if it modulates the cap.
var motion: VehicleDrive = VehicleDrive.new()

## How much of the slope's true gravity is actually applied. 1.0 is a
## frictionless block on a ramp; a vehicle that wants a hill to read as a
## hill on a 4.5 u relief turns this up, and one that wants to ignore
## relief entirely sets it to 0 and gets today's arithmetic back.
var slope_gain: float = 1.0

## Last step's readings, published rather than recomputed by the caller.
var normal: Vector3 = Vector3.UP
var slope_accel: Vector3 = Vector3.ZERO
var grade: float = 0.0

## The DOWNHILL rate along `yaw`, dimensionless: +0.5 means the ground
## falls half a unit for every unit travelled forward (about 26.6 deg
## nose-down), -0.5 the same climbing. EXACTLY 0 off every domain.
##
## Read BEFORE step() by a caller that raises its own ceiling with the
## grade -- which is the whole reason it is a separate function and not
## just a field of the returned dictionary.
static func grade_at(flat: Vector3, yaw: float) -> float:
	var g: Vector2 = HubSurface.gradient_at(flat)
	# The heading, in the same xz spelling VehicleDrive uses.
	return -(g.x * sin(yaw) + g.y * cos(yaw))

## The horizontal shadow of tangential gravity at `flat`, before gain.
## EXACTLY Vector3.ZERO off every domain -- so the injection below adds
## nothing at all on a flat hub, which is what makes this composite a
## no-op there rather than an approximation of one.
static func slope_accel_at(flat: Vector3) -> Vector3:
	var g: Vector2 = HubSurface.gradient_at(flat)
	var denom: float = 1.0 + g.x * g.x + g.y * g.y
	return Vector3(-GRAVITY * g.x / denom, 0.0, -GRAVITY * g.y / denom)

## One physics step ON THE SURFACE. Same signature as VehicleDrive.step()
## plus nothing, same returned keys plus "normal" and "grade", and the
## returned "position" carries its REAL y -- the caller writes it into the
## node exactly as it writes VehicleDrive's today.
##
## ORDER MATTERS AND IT IS THE ORDER CH35 Q2 PRESCRIBED: read the ground
## under where the vehicle IS, add the force, step flat, land on the
## ground under where it ENDED. Reading the slope after the move would
## make the push a frame late and, on the crest, push it the wrong way.
func step(position: Vector3, yaw: float, velocity: Vector3, delta: float, input: KartInput,
		on_surface: bool, fence: Rect2, steer_rate: float) -> Dictionary:
	var flat := Vector3(position.x, 0.0, position.z)
	slope_accel = slope_accel_at(flat)
	grade = grade_at(flat, yaw)
	# 1. THE MODEL, on a flat position, untouched.
	var out: Dictionary = motion.step(flat, yaw, velocity, delta, input, on_surface, fence, steer_rate)
	# 2. THE FORCE, into the world velocity the model just wrote.
	var moved: Vector3 = out["velocity"] as Vector3
	moved += slope_accel * slope_gain * delta
	out["velocity"] = moved
	# 3. THE REBASE, and the normal for the chassis, both under where it
	#    actually ended rather than where it started.
	var landed: Vector3 = out["position"] as Vector3
	normal = HubSurface.normal_at(landed)
	out["position"] = HubSurface.ground(landed)
	out["normal"] = normal
	out["grade"] = grade
	return out
