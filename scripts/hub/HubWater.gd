extends RefCounted
class_name HubWater

## "IS THIS POINT IN WATER?", for all five bodies at once.
##
## The plateau has five separate waters -- pond, small lake, the great
## lake's two lobes, and the stream -- and until this file they had no
## single answer between them. HubRegion.contains() knows about two of them
## (the great-lake lobes, which it SUBTRACTS from the walkable region) and
## deliberately says the other three are walkable, because they are: the
## boat is boarded from the stream's head, which sits on the pond's shore.
## That file answers "may Keepy stand here", which is a different question
## and has to keep its own answer.
##
## This file answers "is Keepy wet", and nothing else. It is a QUERY, not a
## rule: it refuses no tap, clamps no destination, and moves nothing.
##
## =====================================================================
## EVERY NUMBER IS BORROWED, NONE IS RESTATED
##
## Four of the five bodies are discs and the fifth is a ribbon, and not one
## of their dimensions is written down here:
##
##   pond        centre HubBuilder.pond_centre()        r HubBuilder.POND_WATER_RADIUS
##   small lake  centre HubBuilder.small_lake_centre()  r HubBuilder.SMALL_LAKE_WATER_RADIUS
##   great lake  centre+r straight out of HubRegion.lakes(), both lobes
##   stream      HubBuilder.stream_spine() + stream_half_width()
##
## The builder's accessors report where a disc was actually DRAWN, so the
## water this file can be asked about is the water on the screen. That is
## the whole reason they exist; the alternative -- reading the layout a
## second time here -- is how one circle quietly becomes two.
##
## =====================================================================
## AN ISLET IS DRY GROUND, EVEN THOUGH IT SITS INSIDE A LAKE'S DISC
##
## The great lake carries three islets (`&"islet"` layout entries), each a
## flat shingle disc the player stands on and walks around. A plain
## centre/radius disc test cannot see them: an islet's own centre is well
## inside the water disc it stands on (the closest is 6.80 u from the great
## lake's centre against its 16.0 u radius), so `body_at()` used to answer
## "great_lake_0" for a point ON the islet exactly as it does for a point
## on open water beside it -- the tint and the splash never told the two
## apart, and the fix is not "widen the islet", it is a second test that
## SUBTRACTS the islet's own footprint from whatever disc it sits in.
##
## Checked FIRST, before any disc or the stream: an islet excludes water, it
## does not compete with it for the answer. HubBuilder.islets() reports
## each one AS BUILT (position, radius already scaled) for the same reason
## the discs above are borrowed and not restated.
##
## =====================================================================
## THE STREAM IS NOT A FIFTH DISC ROW, AND ITS RIM IS NOT THE DISCS' RIM
##
## A disc test is one distance_to(centre). The stream test is a distance to
## the nearest point of an 88-segment polyline, which HubStreamRoute already
## computes for the mooring -- so the ribbon needed no new geometry either,
## only a different comparison.
##
## It also does not behave like a disc at the float32 boundary, and that is
## MEASURED rather than assumed. See DISC_RIM_MARGIN / STREAM_RIM_MARGIN
## below: the discs clear one millimetre past their edge and the ribbon does
## not, because its distance is a composition of a per-segment projection
## and a Euclidean distance and carries the error of both.

## The one turquoise every water body on the plateau is painted with. Read
## from the pond rather than restated: HubBuilder.POND_WATER_COLOR carries
## the decision and the alpha, and all five bodies share the hue.
##
## Alpha is dropped on purpose. This is the colour something IN the water is
## tinted toward, not the colour the water is drawn with -- a tint has no
## transparency to inherit.
static func hue() -> Color:
	var c := HubBuilder.POND_WATER_COLOR
	return Color(c.r, c.g, c.b, 1.0)

## How far past a boundary a point has to be pushed before it reliably reads
## as LAND. Both are MEASURED by WaterTintProbe's rim sweep. They differ by
## twenty times, and NOT because one shape is noisier than the other -- the
## two numbers answer to two entirely different causes.
##
## DISCS -- float32, exactly as HubRegion's own rim note already documents
## for the great lake. At exactly the radius, 52 to 141 of 360 sampled
## azimuths still slip under the strict `<`; every one of them clears one
## millimetre out, on all four discs.
##
## ⚠️ THE STREAM IS NOT A FLOAT32 CASE AT ALL, and calling it one is what
## made the first two numbers written here wrong.
##
## The ribbon is DRAWN as perpendicular offsets at each of the 89 spine
## samples with quads between them, so its edge follows the curve. But
## distance_to() measures to the CHORD polyline through those same samples.
## On a bend the two are not the same line: they differ by a sagitta,
## r*(1-cos(theta/2)), which at this stream's tightest radius (1.4058, its
## own published figure) and 0.469 segment length is 0.0195. That is a
## GEOMETRIC gap between how the water is drawn and how it is measured, and
## it does not shrink with better precision.
##
## Measured across three independent sampling schemes -- 2000 span
## midpoints, the 89 spine vertices, and 5000 uniform abscissas, both sides
## each -- the worst overshoot is 0.0141 and the residual is:
##
##     +0.001 -> 116/4000, 46/178, 283/10000 still read as water
##     +0.010 ->   3/4000,  2/178,   8/10000 still read as water
##     +0.020 ->      0/4000,   0/178,      0/10000
##
## ⚠️ Both earlier numbers for this constant were caught by that sweep and
## not by review: the recon's +0.001 (its 40 samples found 1 residual and
## under-read the size of the problem) and this batch's own first attempt at
## +0.010, which looked green only because its own sweep was 80 samples --
## too sparse to land on a bend. The probe now samples densely enough to
## fail, which is the only reason this number can be trusted.
##
## Nothing in the tint path uses either constant. A tint that flickers at
## the exact waterline is a cosmetic non-event, and widening the test by a
## margin would move the waterline itself -- Keepy would read as wet while
## visibly standing on the bank. What the stream figure DOES say, and a
## caller placing anything near the ribbon should know, is that a point up
## to ~1.4cm outside the drawn edge is reported as water on a tight bend.
const DISC_RIM_MARGIN: float = 0.001
const STREAM_RIM_MARGIN: float = 0.020

## {"name": StringName, "centre": Vector3, "radius": float}, y flattened.
## Built once, in the order the bodies are named above.
var _discs: Array[Dictionary] = []

## Every great-lake islet, {"centre": Vector3, "radius": float}, y flattened.
## Checked BEFORE `_discs` in body_at(): an islet is dry ground that happens
## to sit inside a water disc, not a fifth body of water.
var _islets: Array[Dictionary] = []

## The stream, or null when the layout carries none -- a legal plateau, and
## then this file simply has four bodies to answer about.
var _route: HubStreamRoute = null
var _stream_half_width: float = 0.0

## Reads every dimension off the builder that just built them, plus the
## great lake's own published table.
##
## `route` is passed in rather than built here because HubWorld already
## builds exactly one HubStreamRoute for the ride, and two routes over one
## spine is the same duplication this file exists to avoid. Null is fine.
func _init(builder: HubBuilder, route: HubStreamRoute = null) -> void:
	if builder != null:
		var pond := builder.pond_centre()
		if pond != Vector3.INF:
			_add_disc(&"pond", pond, HubBuilder.POND_WATER_RADIUS)
		var small := builder.small_lake_centre()
		if small != Vector3.INF:
			_add_disc(&"small_lake", small, HubBuilder.SMALL_LAKE_WATER_RADIUS)
		_stream_half_width = builder.stream_half_width()
		for islet in builder.islets():
			var centre: Vector3 = islet["centre"]
			_islets.append({
				"centre": Vector3(centre.x, 0.0, centre.z),
				"radius": float(islet["radius"]),
			})
	# Both great-lake lobes, from the table that already publishes them.
	# Named by index so a third lobe would report as one without an edit.
	var lakes := HubRegion.lakes()
	for i in lakes.size():
		_add_disc(
			StringName("great_lake_%d" % i),
			lakes[i]["centre"] as Vector3,
			float(lakes[i]["radius"]))
	# CH29: the sea, from the same owner (HubRegion) as the lakes.
	_add_disc(&"sea", HubRegion.SEA_CENTRE, HubRegion.SEA_RADIUS)
	if route != null and route.is_valid() and _stream_half_width > 0.0:
		_route = route

func _add_disc(name: StringName, centre: Vector3, radius: float) -> void:
	_discs.append({
		"name": name,
		"centre": Vector3(centre.x, 0.0, centre.z),
		"radius": radius,
	})

## True when `point` lies inside ANY of the five bodies AND not on an islet.
## Y is ignored: every water surface on this plateau sits within 10cm of
## Keepy's rest height, so height cannot tell them apart and was never the
## question.
##
## Strict `<`, like HubRegion's own disc test: a point exactly on the rim
## reads as LAND. A boundary has to fall on one side deterministically, and
## land is the side that keeps a player standing on the bank looking dry.
func contains(point: Vector3) -> bool:
	return body_at(point) != &""

## Which body holds `point`, or &"" for none -- none INCLUDES standing on an
## islet, checked first and unconditionally: an islet is dry ground carved
## out of whatever disc it sits in, so it wins over every body before any of
## them get a say. First disc match wins after that; the bodies do not
## overlap today (the closest pair is 0.347 apart), and if a future layout
## overlaps two, naming one deterministically beats naming neither.
##
## The name is what makes a probe able to report WHICH body a landing was
## in, instead of only that it was in one.
func body_at(point: Vector3) -> StringName:
	var flat := Vector3(point.x, 0.0, point.z)
	for islet in _islets:
		if flat.distance_to(islet["centre"] as Vector3) < float(islet["radius"]):
			return &""
	for disc in _discs:
		if flat.distance_to(disc["centre"] as Vector3) < float(disc["radius"]):
			return disc["name"] as StringName
	if _route != null and _route.distance_to(flat) < _stream_half_width:
		return &"stream"
	return &""

## Every disc this instance answers for, in build order. For probes; the
## stream is not in it because it is not a disc.
func discs() -> Array[Dictionary]:
	return _discs

## Every islet this instance excludes water for, in build order. For probes.
func islets() -> Array[Dictionary]:
	return _islets

## True when a stream was found and is being tested against.
func has_stream() -> bool:
	return _route != null
