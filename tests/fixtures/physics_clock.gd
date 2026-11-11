## Pins the physics clock for a suite, so a test that counts physics frames means the same seconds on
## every machine. The yard tests step with `await get_tree().physics_frame` and write their waits as
## frame counts at 60 Hz ("75 frames = 4 grow steps of 0.25 s"). A runner with another tick rate
## (an override.cfg, a CI image, a suite that changed it) or a time scale left behind would turn those
## waits into a different amount of simulated time. Pin in before(), restore in after():
##
##     const Clock := preload("res://tests/fixtures/physics_clock.gd")
##     var _clock := Clock.new()
##     func before() -> void: _clock.pin()
##     func after() -> void: _clock.restore()
##
## Tests only. Gameplay never reads this.
extends RefCounted

const HZ := 60
const MAX_STEPS := 8   # Godot's default: physics catches up the same way on a slow box

var _hz := HZ
var _scale := 1.0
var _steps := MAX_STEPS
var _pinned := false


func pin() -> void:
	if not _pinned:
		_hz = Engine.physics_ticks_per_second
		_scale = Engine.time_scale
		_steps = Engine.max_physics_steps_per_frame
		_pinned = true
	Engine.physics_ticks_per_second = HZ
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = MAX_STEPS


func restore() -> void:
	if not _pinned:
		return
	Engine.physics_ticks_per_second = _hz
	Engine.time_scale = _scale
	Engine.max_physics_steps_per_frame = _steps
	_pinned = false
