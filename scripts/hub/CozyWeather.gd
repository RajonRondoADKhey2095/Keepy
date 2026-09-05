extends Node
class_name CozyWeather
## Carte-blanche v2 -- weather and the passing of time.
##
## A looping cycle of states with soft crossfades. Every frame the current
## LOOK (a dictionary of sky / haze / tint / wind / water / snow values,
## blended between the previous look and the target's) is handed to
## CozyPalette.apply_weather(), which is the ONE place that writes the
## materials; this node itself touches only the WorldEnvironment's sky and
## the 2D overlay. Reactions that need a decision (the bear taking
## shelter) listen to `weather_changed`.
##
## Forcing: force(kind) pins a state (the preview menu), force_auto()
## resumes the cycle where it was.

enum Kind { SUN, RAIN, STORM, SNOW }
const NAMES: Array[String] = ["sun", "rain", "storm", "snow"]

signal weather_changed(kind: int)

## The cycle: [kind, seconds]. ~3 min 50 s for a full loop, so every state
## shows up within a few minutes of play.
const CYCLE: Array = [[Kind.SUN, 70.0], [Kind.RAIN, 40.0], [Kind.STORM, 30.0], [Kind.SUN, 50.0], [Kind.SNOW, 40.0]]
const TRANSITION_S: float = 6.0
## How long the ground stays dark-and-saturated after rain stops.
const DRY_S: float = 25.0
const FLASH_DECAY: float = 7.0

var _index: int = 0
var _elapsed: float = 0.0
var _forced: int = -1
var _to: int = Kind.SUN
var _from_look: Dictionary = {}
var _current: Dictionary = {}
var _blend: float = 1.0
var _wet: float = 0.0
var _flash: float = 0.0
var _next_flash: float = 2.0
var _rng := RandomNumberGenerator.new()
var _env: WorldEnvironment = null
var _overlay: ColorRect = null

func _ready() -> void:
	_rng.seed = 20260905
	_env = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	_from_look = CozyPalette.weather_look(Kind.SUN)
	_current = _from_look.duplicate()
	_apply()

func set_overlay(overlay: ColorRect) -> void:
	_overlay = overlay

func kind() -> int:
	return _to

func kind_name() -> String:
	return NAMES[_to]

func is_forced() -> bool:
	return _forced >= 0

## 0..1 weight of `k` in what is on screen right now.
func weight(k: int) -> float:
	var w: float = _blend if _to == k else 0.0
	if _from_look.get("kind", -1) == k:
		w += 1.0 - _blend
	return clampf(w, 0.0, 1.0)

func force(k: int) -> void:
	_forced = k
	_set_target(k)

func force_auto() -> void:
	_forced = -1
	_elapsed = 0.0
	_set_target(CYCLE[_index][0])

func _set_target(k: int) -> void:
	if k == _to:
		return
	_from_look = _current.duplicate()
	_from_look["kind"] = _to if _blend >= 1.0 else -1
	_to = k
	_blend = 0.0
	weather_changed.emit(k)

func _process(delta: float) -> void:
	if _forced < 0:
		_elapsed += delta
		if _elapsed >= float(CYCLE[_index][1]):
			_elapsed = 0.0
			_index = (_index + 1) % CYCLE.size()
			_set_target(CYCLE[_index][0])
	_blend = minf(1.0, _blend + delta / TRANSITION_S)
	var raining: float = weight(Kind.RAIN) + weight(Kind.STORM)
	_wet = maxf(raining, _wet - delta / DRY_S)
	var storm: float = weight(Kind.STORM)
	if storm > 0.5:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_flash = 1.0
			_next_flash = _rng.randf_range(2.5, 7.0)
	_flash = maxf(0.0, _flash - delta * FLASH_DECAY)
	_apply()

func _apply() -> void:
	_current = CozyPalette.blend_looks(_from_look, CozyPalette.weather_look(_to), _blend)
	_current["wet"] = _wet
	_current["flash"] = _flash
	CozyPalette.apply_weather(_current)
	if _env != null and _env.environment != null:
		var sky: Color = _current["sky"]
		_env.environment.background_color = sky.lerp(Color(1.0, 1.0, 1.0), _flash * 0.6)
	if _overlay != null:
		var o: Color = _current["overlay"]
		_overlay.color = o.lerp(Color(0.95, 0.97, 1.0, 0.35), _flash)

## For probes: the blended look as applied this frame.
func current_look() -> Dictionary:
	return _current
