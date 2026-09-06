extends Node
## CH31 -- THE PROOF THAT THE KART'S ACCELERATOR CHANGE DID NOT REACH THE
## SAND YACHT. A deterministic trace of a KartTouchInput driven by a fixed
## gesture script, printed as numbers a diff can compare between trees.
##
## =====================================================================
## WHY THIS FILE EXISTS, AND WHY IT TRACES THE INPUT RATHER THAN THE HULL
##
## CH30's sand yacht is validated on device and the CH31 brief freezes it.
## But the yacht is driven by a SECOND KartTouchInput instance, so CH31's
## accelerator repair -- a shorter push span, a smaller dead zone, and a
## release that bleeds instead of snapping -- lands in a file BOTH vehicles
## read. The brief's condition for touching shared code is "prouvee sans
## effet sur le char, par sonde de trace comparative, pas par relecture de
## diff", and that is what this is.
##
## It traces the KartInput rather than the hull on purpose: the yacht's
## SandYacht.drive() reads nothing from the touch layer except that
## object's four values, so if the four values are identical the hull
## cannot differ -- and tracing them isolates the change instead of
## measuring it through a second model's arithmetic. A hull section is
## printed as well, because "cannot differ" is an argument and the brief
## asked for a measurement.
##
## ⚠️ IT MUST PARSE ON BOTH TREES. `origin/staging` has no boost_span
## property at all, so every CH31 name is reached through `in` and `set`,
## never written as an identifier the parser has to resolve.
##
## =====================================================================
## THE BLIND CHECK
##
## "The two traces are identical" passes for FREE against a probe that
## cannot see a difference (CLAUDE.md). So section B replays the SAME
## gesture through an instance configured with the KART's values and the
## trace MUST differ -- on this tree. On origin/staging the two sections
## are expected to be identical, because there is nothing to configure,
## and that is itself the statement being made.
##
## Exit 0 always (a measurement, not a contract). Args: --frames=N

const DEFAULT_FRAMES: int = 420
## The gesture, in frames: {at, kind, index, x, y}. One finger down at the
## middle of a 1080x1920 screen, then a drag that steers and pushes, a
## LIFT (the case CH31 changed), a re-press, a diagonal, and a second
## finger for the brake.
const SCRIPT: Array = [
	{"at": 10, "kind": "down", "index": 0, "x": 540.0, "y": 1400.0},
	{"at": 20, "kind": "drag", "index": 0, "x": 600.0, "y": 1330.0},
	{"at": 40, "kind": "drag", "index": 0, "x": 660.0, "y": 1260.0},
	{"at": 60, "kind": "drag", "index": 0, "x": 700.0, "y": 1180.0},
	{"at": 80, "kind": "drag", "index": 0, "x": 540.0, "y": 1240.0},
	{"at": 110, "kind": "up", "index": 0, "x": 540.0, "y": 1240.0},
	{"at": 160, "kind": "down", "index": 0, "x": 500.0, "y": 1500.0},
	{"at": 175, "kind": "drag", "index": 0, "x": 420.0, "y": 1300.0},
	{"at": 200, "kind": "drag", "index": 0, "x": 380.0, "y": 1360.0},
	{"at": 230, "kind": "down", "index": 1, "x": 900.0, "y": 1600.0},
	{"at": 260, "kind": "up", "index": 1, "x": 900.0, "y": 1600.0},
	{"at": 300, "kind": "up", "index": 0, "x": 380.0, "y": 1360.0},
	{"at": 340, "kind": "down", "index": 0, "x": 700.0, "y": 1700.0},
	{"at": 380, "kind": "drag", "index": 0, "x": 640.0, "y": 1500.0},
]

var _frames_total: int = DEFAULT_FRAMES
var _touch: Node = null

func _ready() -> void:
	ProbeWatchdog.arm(self, "YACHTTRACE", 300.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_frames_total = maxi(60, int(arg.substr(9)))
	_run()

func _run() -> void:
	await get_tree().process_frame
	print("YACHT TRACE -- the gesture a thumb makes, through a KartTouchInput")
	await _section("A -- the YACHT's instance (nothing configured: the shipped V7b mapping)", false)
	await _section("B -- the KART's instance (CH31 values, blind check: this MUST differ)", true)
	print("")
	print("YACHT TRACE PROBE: done.")
	get_tree().quit(0)

func _section(title: String, kart_values: bool) -> void:
	print("")
	print("  %s" % title)
	var touch: Node = KartTouchInput.new()
	add_child(touch)
	_touch = touch
	if kart_values:
		# Reached dynamically so this file also parses on origin/staging,
		# where none of these properties exist.
		if "boost_span" in touch:
			touch.set("boost_span", 105.0)
			touch.set("boost_dead_zone", 14.0)
			touch.set("boost_release_s", 0.45)
		else:
			print("    (this tree has no per-instance mapping: section B is section A)")
	touch.set("enabled", true)
	var span: float = 0.0
	if "boost_span" in touch:
		span = float(touch.get("boost_span"))
	print("    span %.1f  dead %.1f  release %.2f" % [span, 0.0 if span == 0.0 else float(touch.get("boost_dead_zone")),
		0.0 if span == 0.0 else float(touch.get("boost_release_s"))])
	print("    %-7s %-10s %-10s %-7s %s" % ["frame", "steer", "boost", "brake", "throttle"])
	var next_event: int = 0
	for f in _frames_total:
		while next_event < SCRIPT.size() and int(SCRIPT[next_event]["at"]) == f:
			_send(touch, SCRIPT[next_event])
			next_event += 1
		await get_tree().physics_frame
		if f % 20 == 0:
			var input: KartInput = touch.get("input")
			print("    %-7d %-10.6f %-10.6f %-7s %.6f" % [f, input.steer, input.boost, str(input.brake), input.throttle])
	touch.queue_free()
	await get_tree().process_frame

func _send(touch: Node, ev: Dictionary) -> void:
	var kind: String = String(ev["kind"])
	var pos := Vector2(float(ev["x"]), float(ev["y"]))
	if kind == "drag":
		var drag := InputEventScreenDrag.new()
		drag.index = int(ev["index"])
		drag.position = pos
		touch.call("_unhandled_input", drag)
		return
	var t := InputEventScreenTouch.new()
	t.index = int(ev["index"])
	t.position = pos
	t.pressed = kind == "down"
	touch.call("_unhandled_input", t)
