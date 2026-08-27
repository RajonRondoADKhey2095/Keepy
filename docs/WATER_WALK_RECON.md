# WATER-WALK RECON -- what an "arret a la berge" would cost, measured

**26 aout 2026. RECON ONLY: this batch changes no gameplay file.** Branch
`claude/keepy-water-collision-recon-6w1a0a`, cut from `origin/staging`
(`2ba12e0`); `origin/main` is `ae13b99`, `origin/staging` is `ab37db0` +
`2ba12e0`, both exactly as the brief expected. Refs sorted by date, trees
compared rather than names: the freshest ref in the repo is
`origin/staging` itself and no branch carries this brief -- no concurrent
session.

Every number below was produced by a THROWAWAY probe driving the shipped
`scenes/HubWorld.tscn`, the shipped `KeepyHopper`, and the spine
`HubBuilder` actually ribbons -- `godot4 --headless --fixed-fps 60`,
exit 0, stderr empty. The probe was deleted before the commit, so
`ProbeTimeoutAudit` returns to its baseline count.

Each claim is tagged **MEASURED** or **EXTRAPOLATED**. Nothing here is
gated, and no design decision is taken: the ARRET A LA BERGE is already
Mathieu's decision and is not re-litigated.

---

## Q1 -- the chain is computed HOP BY HOP, never in one go **MEASURED (code)**

`scripts/hub/KeepyHopper.gd`, read in full:

| line | function | what it does |
|---|---|---|
| 240 | `hop_to(point)` | refuses while `RIDING` (246); stores `_target` (depth one); calls `_advance()` only if `IDLE` |
| 418 | `_advance()` | returns if no target (419) or `RIDING` (421); reads the CURRENT position (423); `delta = _target - here`; arrives when `delta.length() <= ARRIVE_EPSILON` (425); otherwise `_begin_hop` |
| 432 | `_begin_hop(here, delta)` | ONE hop: `_hop_to = here + delta.normalized() * minf(HOP_DISTANCE, delta.length())` (434-436), then a single tween |
| 488 | `_on_hop_finished()` | snaps to `_hop_to`, emits `hop_landed` (500), then calls `_advance()` again (504) |

There is no precomputed path anywhere: the chord is re-derived from the
live position on every landing. **The insertion point for a truncation is
therefore between `_begin_hop` computing `_hop_to` (line 436) and starting
its tween (line 450)** -- or equivalently a test in `_advance` before the
call on line 430. Both see one candidate landing at a time, which is
exactly the granularity a bank stop needs.

## Q2 -- the membership test is centralised, and it knows 2 of the 5 waters

**PREMISE PUBLISHED IN FAILURE.** The brief asks for "la fonction de
HubRegion.gd qui expose le test de membership (test unique, deja
centralise)". It exists -- `HubRegion.contains()` (line 250), built on
`in_lake_water()` (215) -> `_lake_holding()` (243), a loop over
`HubRegion.lakes()` (221). It is genuinely the one owner. **But it
subtracts only the great-lake family.** Measured on the shipped region:

| body | centre | water radius | `HubRegion.contains(centre)` | `in_lake_water(centre)` |
|---|---|---|---|---|
| pond | (20.700, 7.400) | 3.200 | **YES, walkable** | false |
| small lake | (-25.100, -5.300) | 8.000 | **YES, walkable** | false |
| great lake A | (15.500, -19.000) | 16.000 | no (subtracted) | true |
| great lake B | (-12.000, -19.500) | 10.000 | no (subtracted) | true |
| stream (mid sample) | ribbon, 89 samples, arc 41.284 u | half-width 0.600 | **YES, walkable** | false |

`HubRegion.lakes()` holds **2** entries. This is deliberate and documented
in that file's own header (the boat boards from the stream head, which sits
on the pond's rim). **A guard covering the 5 bodies cannot be written
against today's `HubRegion`**: the pond and small-lake radii live in
`HubBuilder` (`POND_WATER_RADIUS`, `LAKE_WATER_RADIUS`) and the stream is a
ribbon around a spine only `HubBuilder` owns (`stream_spine()`,
`stream_half_width()`). Extending the region is a real piece of work, not a
one-line call.

**Float32 rim, MEASURED and it confirms the brief.** 360 azimuths per disc,
each disc tested against ITSELF only:

| disc | at exactly `radius` | at `radius + 0.001` | worst float32 slip |
|---|---|---|---|
| pond | **141 / 360 read as WATER** | 0 / 360 | 1.001e-06 |
| small lake | **171 / 360** | 0 / 360 | 1.907e-06 |
| great lake A | **115 / 360** | 0 / 360 | 1.907e-06 |
| great lake B | **54 / 360** | 0 / 360 | 9.54e-07 |

A strict `<` drops between 15% and 48% of exact-rim points INSIDE the
water. Sample at `radius + 0.001`, as `HubRegion._out_of_lake()` already
does.

## Q3 -- the boat: the eject is safe, BOARDING is what breaks

**Half the brief's premise does not survive measuring.** It warns that a
naive guard "casse les deux" -- boarding and ejection. Ejection is fine;
boarding is not.

**The eject leap is INERT to a `_begin_hop` guard. MEASURED (code).**
`leave_ride()` (313-343) builds its tween INLINE at lines 337-343: it sets
`_hop_from`, `_hop_to = _bank_point(...)`, `_hop_height =
EJECT_HOP_HEIGHT`, and creates the tween itself. It never calls
`_begin_hop` or `_advance` before leaping. A guard placed in
`_begin_hop`/`_advance` therefore cannot touch it. The whole of `RIDING` is
equally out of reach: `_advance` returns at 421, `hop_to` refuses at 246,
and `_place_on_route()` (363) writes the body directly.

**But the chain AFTER the eject is not inert. MEASURED (live ride).** A
full ride from the head, self-disembarking at the tail:

```
    landing 1 after the ride: (-17.548,  -1.646)  DRY
    landing 2 after the ride: (-19.047,  -1.705)  IN SMALL LAKE
```

The auto-disembark aims `ahead` (line 358) along the tangent PAST the end
-- and at the tail that direction points into the small lake. The eject
lands dry; the very next ordinary hop does not. A uniform guard would stop
that chain one hop after every ride.

**BOARDING IS THE REAL BREAKAGE. MEASURED.** `_mooring_pose()` parks the
hull at the ribbon end, on the water, and says so in its own comment. Read
off the built spine:

* head (17.580, 6.670): **IN STREAM**; 0.0043 u OUTSIDE the pond water.
* tail (-18.540, -0.730): **IN SMALL LAKE** (7.995 from centre, radius 8).

`_try_board` requires `d(hull) <= BoatMooring.BOARD_TAP_RADIUS = 2.500`.
Simulating a bank stop on real boarding walks -- 6 azimuths per mooring
end, each starting 9 u out on dry ground, truncated at the last dry
landing:

| moored at | approaches run | BOARD | CANNOT BOARD | worst d(hull) |
|---|---|---|---|---|
| HEAD (pond end) | 6 | 2 | **4** | 7.500 u |
| TAIL (lake end) | 4 (2 starts were themselves wet) | 3 | **1** | 3.000 u |
| **total** | **10** | **5** | **5** | |

**A uniform guard makes the boat unboardable from half the approaches**,
by 0.5 u to 5.0 u. Not inconclusive -- measured on the shipped hopper.

## Q4 -- the stream: instructed, NOT decided

**(a) Width. MEASURED.** The ribbon is **constant 1.2 u** by construction:
`HubBuilder._make_stream` offsets `+-half = 0.600` along the perpendicular
at every one of the 89 spine samples, so there is no widest and no
narrowest point. What varies is the **wet span a straight chord sees**,
swept over 36 azimuths through the mid-sample: **min 1.199 u**
(perpendicular) to **max 8.013 u** (grazing).

**(b) Hop amplitude. MEASURED (read from code, not estimated).**
`HOP_DISTANCE = 1.500`, `HOP_HEIGHT = 0.600`, `ARRIVE_EPSILON = 0.450`.

**(c) Do hops clear it? MEASURED, and the answer is no.** 40 parallel
crossings (x from -12.0 to +11.4 in 0.6 steps, z 16 -> 2):

* **39 of 40** put at least one landing IN the ribbon.
* 40 wet landings in total, i.e. **~1 stop per crossing**, never a run.
* **1 of 40** cleared the ribbon in a single hop -- despite 1.5 > 1.2.

The shipped instrumented crossing ((-2,4) -> (-2,16)) agrees: 8 hops, 1 wet
landing, first wet is hop 4 of 8.

**The choice, chiffres a l'appui, left to Mathieu:**

| option | wet runs over the 13 trips | trips stopped at least once |
|---|---|---|
| uniform guard on all 5 bodies | **12** | **10 of 13** |
| stream exempted (hop over it) | **7** *(derived from the per-chord table)* | **7 of 13** |

Exempting the stream makes three trips completely free again -- the stream
crossing itself, `centre -> NE corner` and `centre -> NW corner`, whose
chords touch no other water. The four remaining stream-crossing trips
(pond, both diagonals, W->E) are stopped by a lake anyway. **Not chosen
here.**

## Q5 -- portal detection survives truncation **MEASURED + code**

* **No phantom portal.** `_begin_hop` is deterministic in `here` and
  `_target`, so a truncated chain's landings are the exact PREFIX of the
  untruncated one. Truncation removes landings; it never invents one.
* **No portal disc overlaps water.** Nearest water to a portal centre is
  **1.589 u** (battle vs great lake A); the trigger radius is read off the
  portal's own `CylinderShape3D` (`HubPortal._radius`). A landing inside a
  portal therefore cannot be a wet landing, so a guard can never suppress a
  legitimate portal entry at the portal itself.
* **The guaranteed path is untouched.** All three portals are dry; the
  spawn -> portal chords have **0.000 u** of wet span; the three
  spawn -> portal trips are 5 hops each with **0 wet landings**.
* **No portal is detected during a ride** -- `HubWorld._on_hop_landed`
  refuses outright while `is_riding()` (line 240). Unchanged by any of this.
* **BUT approaches are mostly blocked. MEASURED**, dry starts 20 u out:
  chased **12 of 16**, quizz **12 of 15**, battle **13 of 18** cross water
  on the way in. No portal becomes unreachable; about three quarters of
  straight approaches would need a second tap.

## Q6 -- what it costs, per trip **MEASURED**, plus one EXTRAPOLATED factor

Real hopper, `--fixed-fps 60`, the 10 LAKE-MOVE / SPAWN-LAKE trips plus the
3 spawn -> portal trips. "1st wet" is the hop a bank stop would refuse;
"lost" is how many hops of that trip the first tap no longer buys.

| trip | hops | wet | runs | 1st wet | lost | s |
|---|---|---|---|---|---|---|
| small lake (-35,-5) -> (-15,-5) | 14 | **10** | 1 | 2 | 13 | 3.967 |
| pond (14,7) -> (28,8) | 10 | 5 | 1 | 2 | 9 | 2.833 |
| stream (-2,4) -> (-2,16) | 8 | 1 | 1 | 4 | 5 | 2.267 |
| small lake, long | 25 | 11 | 1 | 7 | 19 | 7.083 |
| square diagonal | 66 | 12 | **2** | 13 | 54 | 18.700 |
| anti-diagonal | 66 | 22 | **2** | 26 | 41 | 18.700 |
| centre -> NE corner | 33 | 1 | 1 | 9 | 25 | 9.350 |
| centre -> SE corner | 33 | 21 | 1 | 6 | 28 | 9.350 |
| centre -> NW corner | 33 | 1 | 1 | 7 | 27 | 9.350 |
| W edge -> E edge | 47 | 9 | 1 | 3 | 45 | 13.317 |
| spawn -> portal chased | 5 | **0** | 0 | -- | -- | 1.417 |
| spawn -> portal quizz | 5 | **0** | 0 | -- | -- | 1.417 |
| spawn -> portal battle | 5 | **0** | 0 | -- | -- | 1.417 |
| **totals** | **350** | **93 (26.6%)** | **12** | | | |

The 350 hops and the three dry spawn -> portal trips reproduce the figures
the brief quotes, which is what validates the bench before anything new is
read off it.

**THE TRAP, MEASURED: an identical retap from the bank buys NOTHING.**
Placed at the last dry landing and re-issued the SAME destination:

| case | bank point | dry hops the second tap buys |
|---|---|---|
| small lake (-35,-5) -> (-15,-5) | (-33.50, -5.30) | **0** |
| pond (14,7) -> (28,8) | (15.50, 7.46) | **0** |
| square diagonal | (-22.27, -22.27) | **0** |
| centre -> SE corner | (5.30, -5.30) | **0** |

Four cases out of four. The chord from the bank still enters the water on
its first hop, so the player MUST aim off the chord; tapping the same place
again is a no-op.

**EXTRAPOLATED, and marked as such:** a wet run therefore costs **at least
two** extra taps -- one to a point beside the water, one to resume -- so
**>= 24 extra taps across the 10 affected trips, >= 2.4 per affected
trip**. The true number depends on how well a player aims around an
obstacle, which no probe in this repo can measure. What IS measured is that
the floor is not one tap per run, and that the first tap buys very little
of the trip: **2 hops of 47** on W edge -> E edge (4%), **1 of 14** on the
short small-lake crossing (7%), **12 of 66** on the square diagonal (18%).

Wall-clock is unchanged -- the worst crossing is still 18.700 s -- but it
stops being one gesture.

---

## What a follow-up batch has to decide before it can be scoped

1. **Where the water test lives.** `HubRegion` covers 2 of 5 bodies today
   (Q2). Either it grows to own all five -- which means it starts reading
   radii that live in `HubBuilder` -- or the guard gets its own source, and
   then there are two descriptions of the same water.
2. **How boarding survives.** 5 of 10 approaches lose the boat under a
   uniform guard (Q3). An exemption keyed to "the tap that started this
   walk was a boarding tap" is the obvious shape, but `_begin_hop` does not
   know why it is walking -- that intent lives in `HubWorld._boarding`.
3. **The stream, uniform or exempt** (Q4). Both costs are tabulated above.
4. **The auto-disembark's own target** aims into the small lake at the tail
   (Q3): whatever guard is chosen, that point needs clamping too.
