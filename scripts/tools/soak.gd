## Soak / stress probe for the demo: `-- --demo --soak` (main.gd adds it). While the demo bots play,
## every STRESS_EVERY seconds it zaps a random effect onto a random object (grow, shrink, bouncy,
## balloon, freeze, magnet) and now and then glues a random pair or unglues one, so many effects stay
## stacked. Every LOG_EVERY seconds it prints one "soak:" line: objects, nodes, orphans, joints,
## effects on, recalls, and the mean wall-clock frame time over the window. Use --fixed-fps 60 so
## seconds are simulated seconds, and --screenshot-after=<s> to end the run.
class_name SoakProbe
extends Node

const STRESS_EVERY := 0.4
const LOG_EVERY := 30.0
const ZAPS: Array[StringName] = [&"grow", &"grow", &"shrink", &"bouncy", &"balloon", &"freeze", &"magnet"]

var level: YardLevel
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _stress := 0.0
var _log := 0.0
var _frames := 0
var _usec := 0
var _last := 0
var zaps := 0
var glues := 0


func _ready() -> void:
	_rng.seed = 20261110
	_last = Time.get_ticks_usec()
	_line()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	_usec += now - _last
	_last = now
	_frames += 1
	_t += delta
	_stress += delta
	_log += delta
	if _stress >= STRESS_EVERY:
		_stress = 0.0
		_poke()
	if _log >= LOG_EVERY:
		_log = 0.0
		_line()


func _objects() -> Array:
	return get_tree().get_nodes_in_group(PhysicsObject.GROUP)


func _poke() -> void:
	var objs := _objects()
	if objs.size() < 2:
		return
	var o: PhysicsObject = objs[_rng.randi() % objs.size()]
	if _rng.randf() < 0.15:
		var other: PhysicsObject = objs[_rng.randi() % objs.size()]
		var joints := get_tree().get_nodes_in_group(&"glue_joints")
		if joints.size() > 6:
			(joints[0].get_meta(&"glue") as Effects.Glue).undo(null)
		elif Effects.glue(o, other):
			glues += 1
		return
	if Effects.zap(ZAPS[_rng.randi() % ZAPS.size()], o):
		zaps += 1


func _line() -> void:
	var on := 0
	for o in _objects():
		on += (o as PhysicsObject).stack.effects.size()
	var ms := (_usec / 1000.0) / maxf(_frames, 1)
	print("soak: t=%5.1f objects=%d nodes=%d orphans=%d objs_db=%d joints=%d effects_on=%d zaps=%d glues=%d recalls=%d frame_ms=%.2f" % [
			_t, _objects().size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
			get_tree().get_nodes_in_group(&"glue_joints").size(), on, zaps, glues, Yard.recalls, ms])
	_frames = 0
	_usec = 0
