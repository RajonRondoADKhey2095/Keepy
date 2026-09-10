extends Node
class_name SkateAudio
## CH62 EFFECT 3 -- THE HUB'S FIRST SOUND, AND IT IS TWO PLAYERS AND TWO
## FILES.
##
## =====================================================================
## WHAT WAS ALREADY THERE, AND WHAT WAS NOT
##
## Measured before anything was built: this repository has THREE sound
## files, all under `assets/audio/`, all owned by `HUD.gd` -- the two
## strike cues and the pursuer-lost cue of Keepy Chased. There is no SFX
## autoload, no bus layout, no audio service and NOTHING AT ALL in the
## hub. HUD.gd says why in as many words: two one-shot cues do not justify
## a global service.
##
## That reasoning has not changed, so this lot does NOT build an audio
## system. It builds the MINIMUM VIABLE thing the brief asked for -- "un
## son de roulement dont le pitch/volume suit la vitesse, un impact a
## l'atterrissage" -- as two plain `AudioStreamPlayer` nodes owned by the
## one door that mounts and dismounts the board, exactly the shape HUD.gd
## already ships. If the hub ever wants ambience, weather and footsteps,
## THAT is the lot that writes a service; this one would be its first
## customer, not its obstacle.
##
## ⚠️ NOT `AudioStreamPlayer3D`. The world lives in a SubViewport and
## nothing in this project has ever placed a listener; positional audio
## would need one, plus attenuation curves nobody has measured, plus a
## doppler decision. The loudness already follows the speed, which is the
## thing the brief asks to be able to HEAR. Positional is a later lot's
## call, and it is a small one from here.
##
## =====================================================================
## THE TWO FILES, AND WHY THEY SOUND LIKE THAT
##
## `skate_roll.wav` -- 16 384 frames at 22 050 Hz mono 16-bit (0.743 s),
## peaked at 0.55 of full scale. It is EXACTLY PERIODIC by construction:
## the spectrum was written directly (a broad body around 170 Hz, a pink
## tilt above it, a small shelf near 2.3 kHz for the grain of the
## concrete) and inverse-transformed, so the last sample joins the first
## with no seam and the loop cannot click however long a ride lasts. A
## 3-cycle-per-loop amplitude wobble rides on top for the bearings, at an
## exact multiple of the loop length so it survives the join too.
##
## `skate_land.wav` -- 5 292 frames (0.240 s), peaked at 0.70. A wooden
## slap rather than a drum: a noise transient over a body that falls from
## 174 Hz to 46 Hz as it decays. Short on purpose, so a board that lands
## twice inside half a second never has the cue cutting itself off.
##
## Both are quieter than any Chased cue (-26 to -9 dB against -4 / -2),
## because this is a hub a player sits in rather than a chase they are
## losing.

const ROLL_STREAM := "res://assets/audio/skate_roll.wav"
const LAND_STREAM := "res://assets/audio/skate_land.wav"
## CH64: the two tricks' pops, generated the way the two above were
## (22 050 Hz mono 16-bit, 0.18 s): a wood-and-bearings pop whose body
## sweeps down from 880 Hz (kickflip) or 1 240 Hz (heelflip). Two pitches
## so the two senses are distinguishable with the eyes closed.
const FLIP_KICK_STREAM := "res://assets/audio/skate_flip_kick.wav"
const FLIP_HEEL_STREAM := "res://assets/audio/skate_flip_heel.wav"
const FLIP_DB: float = -8.0

var _body: SkateBoardBody = null
var _roll: AudioStreamPlayer = null
var _land: AudioStreamPlayer = null
var _riding: bool = false
## Peak downward speed seen since the board left the ground, u/s. Read at
## touchdown and reset there -- the LOUDNESS of a landing is its impact,
## and the impact is the fall the board actually did.
var _fall: float = 0.0
var _was_airborne: bool = false
## Published so a bench can read what the last landing was worth without
## listening to anything.
var _last_land_db: float = -1e9
var _land_count: int = 0
var _flip: AudioStreamPlayer = null
var _flip_count: int = 0
var _last_flip: String = ""

func setup(body: SkateBoardBody) -> void:
	_body = body
	_roll = AudioStreamPlayer.new()
	_roll.name = "SkateRoll"
	# ⚠️ THE LOOP LIVES IN `skate_roll.wav.import` (edit/loop_mode=1), not
	# in a line here. The importer is the one thing that knows how many
	# FRAMES the sample has after whatever it did to it, so it is the one
	# thing that can set `loop_end` correctly; a hand-written loop_end in
	# this file would be a second spelling of the sample's length, and it
	# would be wrong the day the file is re-cut. The assertion below
	# fails loudly rather than shipping a ride whose sound stops after
	# three quarters of a second.
	var roll_stream: AudioStreamWAV = load(ROLL_STREAM)
	if roll_stream != null and roll_stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		push_error("SkateAudio: skate_roll.wav imported without a loop -- check its .import")
	_roll.stream = roll_stream
	_roll.volume_db = SkateFeel.ROLL_DB_LOW
	add_child(_roll)
	_land = AudioStreamPlayer.new()
	_land.name = "SkateLand"
	_land.stream = load(LAND_STREAM)
	add_child(_land)
	_flip = AudioStreamPlayer.new()
	_flip.name = "SkateFlip"
	_flip.volume_db = FLIP_DB
	add_child(_flip)

## CH64: one pop per trick, the stream chosen by the sense.
func play_trick(clockwise: bool) -> void:
	if _flip == null:
		return
	_last_flip = FLIP_KICK_STREAM if clockwise else FLIP_HEEL_STREAM
	_flip.stream = load(_last_flip)
	_flip.play()
	_flip_count += 1

func flip_count() -> int:
	return _flip_count

func last_flip_stream() -> String:
	return _last_flip

## Called by HubTransport on mount and dismount. The roll only ever plays
## while a rider is on the board: a board parked at the far end of the
## park is not making a noise in the player's ear.
func set_riding(riding: bool) -> void:
	_riding = riding
	if _roll == null:
		return
	if riding:
		_fall = 0.0
		_was_airborne = false
		if not _roll.playing:
			_roll.play()
	else:
		_roll.stop()

func is_rolling() -> bool:
	return _roll != null and _roll.playing

func last_land_db() -> float:
	return _last_land_db

func land_count() -> int:
	return _land_count

## On the PHYSICS tick, not on the frame: the airborne edge is one tick
## wide and a frame-rate that dips below the tick rate would step over
## it. The pitch and the level are cheap enough to write at 60 Hz.
func _physics_process(_delta: float) -> void:
	if not _riding or _body == null or not is_instance_valid(_body):
		return
	var pace: float = _body.pace()
	if _roll != null:
		_roll.pitch_scale = SkateFeel.roll_pitch(pace)
		# Silence is a LEVEL and not a stop: stopping and restarting the
		# loop on a board that pauses at the foot of a ramp would put a
		# click in the middle of every run.
		_roll.volume_db = SkateFeel.roll_volume_db(pace) if SkateFeel.roll_audible(pace) else -80.0
	var airborne: bool = _body.airborne()
	if airborne:
		_fall = maxf(_fall, -_body.velocity.y)
	elif _was_airborne:
		if SkateFeel.land_audible(_fall) and _land != null:
			_last_land_db = SkateFeel.land_volume_db(_fall)
			_land.volume_db = _last_land_db
			_land.play()
			_land_count += 1
		_fall = 0.0
	_was_airborne = airborne
