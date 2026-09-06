extends Node
## CH30 -- THE EXTRACTION'S PROOF. A deterministic trace of the PLAYER's
## kart driven by the `probe` profile on the real track, printed as
## numbers that a diff can compare between two trees.
##
## =====================================================================
## WHY A TRACE AND NOT A DIFF OF THE PATCH
##
## The brief's condition for extracting KartBody's kinematics into
## VehicleDrive was "un DEPLACEMENT PUR, sans changement de comportement",
## and its condition for BELIEVING that was "sonde comparative avant/apres
## sur le meme seed, pas par relecture de diff". Reading the patch cannot
## settle it: the arithmetic is the same statements, but a Node3D's
## `global_position` is a round trip through its parent's transform, and
## the extraction writes it ONCE where the original wrote it four times.
## Whether those two are the same float is a question about the engine,
## not about the source, and only a run answers it.
##
## So: same scene, same seed, same driver, no rendering, --fixed-fps 60,
## and every 30th frame the kart's position, heading and speed to six
## decimals. Run it on `origin/staging` and on this tree and compare the
## two outputs byte for byte (CLAUDE.md: rejouer sur les DEUX arbres).
## This file is written so it parses on BOTH: it names nothing that CH30
## introduced.
##
## Exit 0 always (it is a measurement, not a contract) unless the
## watchdog fires. Args after `--`: --frames=N --every=N

const DEFAULT_FRAMES: int = 5400
const DEFAULT_EVERY: int = 30

var _hub: Node = null
var _karting: HubKarting = null
var _frames_total: int = DEFAULT_FRAMES
var _every: int = DEFAULT_EVERY

func _ready() -> void:
	ProbeWatchdog.arm(self, "KARTTRACE", 600.0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_frames_total = maxi(60, int(arg.substr(9)))
		elif arg.begins_with("--every="):
			_every = maxi(1, int(arg.substr(8)))
	WorldSave.SAVE_PATH_OVERRIDE = "user://kart_trace_probe.json"
	WorldSave.reset()
	var packed: PackedScene = load("res://scenes/HubWorld.tscn")
	_hub = packed.instantiate()
	add_child(_hub)
	_karting = _hub.get_node("WorldViewport/SubViewport/World/Karting")
	_run()

func _run() -> void:
	for i in 3:
		await get_tree().process_frame
	var pi: int = _karting.player_index()
	var kart: KartBody = _karting.player_kart()
	var lap: KartLap = _karting.player_lap()
	var track: KartTrack = _karting.track
	# One kart only, so the trace is the BODY's own motion and never a
	# collision with an opponent -- a bump would make the trace depend on
	# three other drivers' RNG and stop being a proof about drive().
	var driver := KartAiDriver.new()
	driver.setup(track, "probe", 20260905 + pi * 7919)
	driver.released = true
	var input := KartInput.new()
	var pose: Dictionary = track.start_pose(0)
	kart.place(pose["position"], pose["yaw"])
	lap.reset()
	var fence: Rect2 = track.fence()
	var hint: int = -1
	print("KART TRACE -- %d frames, sample every %d, track %s" % [_frames_total, _every, KartTrack.TRACK_ID])
	print("  frame        x           z          yaw        speed      lateral")
	var laps: Array = []
	lap.on_lap = func(ms: int): laps.append(ms)
	for f in _frames_total:
		driver.drive(kart, input, 1.0 / 60.0, [])
		var progress: Dictionary = track.progress_at(kart.global_position, hint)
		var on_track: bool = absf(float(progress["lateral"])) <= KartTrack.HALF_WIDTH + KartTrack.ON_TRACK_MARGIN
		kart.drive(1.0 / 60.0, input, on_track, fence)
		progress = track.progress_at(kart.global_position, hint)
		hint = int(progress["index"])
		var along: float = kart.velocity.dot(progress["tangent"] as Vector3)
		lap.update(float(progress["s"]), along >= -0.5, 1.0 / 60.0)
		if f % _every == 0:
			print("  %5d  %10.6f  %10.6f  %10.6f  %9.6f  %9.6f" % [
				f, kart.global_position.x, kart.global_position.z, kart.rotation.y,
				kart.speed(), float(progress["lateral"])])
		await get_tree().physics_frame
	var texts: Array = []
	for ms in laps:
		texts.append("%.3f" % (float(int(ms)) / 1000.0))
	print("  LAPS: %s" % ", ".join(PackedStringArray(texts)))
	print("  BEST: %.3f   COUNT: %d" % [float(lap.best_lap_ms) / 1000.0, lap.lap_count])
	print("  FINAL: x=%.6f z=%.6f yaw=%.6f v=%.6f" % [kart.global_position.x, kart.global_position.z, kart.rotation.y, kart.speed()])
	get_tree().quit(0)
