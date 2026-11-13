## Soak / stress probe for the demo: `-- --demo --soak` (main.gd adds it). While the demo bots play,
## every STRESS_EVERY seconds it zaps a random effect onto a random object (grow, shrink, bouncy,
## balloon, freeze, magnet) and now and then glues a random pair or unglues one, so many effects stay
## stacked. Every LOG_EVERY seconds it prints one "soak:" line: objects, nodes, orphans, joints,
## effects on, recalls, the mean and worst wall-clock frame time over the window, mean process /
## physics CPU ms, audio voices playing and static memory. Use --fixed-fps 60 so seconds are
## simulated seconds, and --screenshot-after=<s> to end the run; or, for a real-time soak,
## `--max-fps 60 --quit-after 108000` (30 minutes at 60 fps).
## S-18 sleep proof: `--soak-calm=<s>` stops the stress and the demo bots at <s> (simulated) seconds and
## lets go of their pads, so the yard is left alone; from then on the line counts down the awake bodies
## (`awake=` physics objects not sleeping, of `bodies=`; the engine's own active-object monitor reads 0
## under Jolt, so it is not used), split into `plain=` (no effect on it, not glued) and `fx=` (a magnet,
## balloon, bouncy or glue is still acting on it, so it is not still), and logs every CALM_LOG_EVERY
## seconds, naming what is still awake. With `--soak-calm-reset` the calm starts with the yard's own
## Reset Yard (what the pause menu and the Select hold do), so the yard is left alone with no effects.
class_name SoakProbe
extends Node

const STRESS_EVERY := 0.4
const LOG_EVERY := 30.0
const CALM_LOG_EVERY := 5.0
const ZAPS: Array[StringName] = [&"grow", &"grow", &"shrink", &"bouncy", &"balloon", &"freeze", &"magnet"]

var level: YardLevel
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _stress := 0.0
var _log := 0.0
var _frames := 0
var _usec := 0
var _last := 0
var _worst := 0
var _proc := 0.0                     # summed Performance.TIME_PROCESS (ms), the whole frame's CPU
var _phys := 0.0                     # summed Performance.TIME_PHYSICS_PROCESS (ms), one physics tick
var zaps := 0
var glues := 0
var calm_at := -1.0                  # --soak-calm=<s>: stop stirring the yard at this time
var calm := false
var calm_reset := false              # --soak-calm-reset: Reset Yard at the calm


static func calm_from_args(args: PackedStringArray) -> float:
	for a in args:
		if a.begins_with("--soak-calm="):
			return float(a.trim_prefix("--soak-calm="))
	return -1.0


func _ready() -> void:
	_rng.seed = 20261110
	calm_at = calm_from_args(OS.get_cmdline_user_args())
	calm_reset = OS.get_cmdline_user_args().has("--soak-calm-reset")
	_last = Time.get_ticks_usec()
	_line()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	_usec += now - _last
	_worst = maxi(_worst, now - _last)
	_last = now
	_proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_frames += 1
	_t += delta
	_stress += delta
	_log += delta
	if not calm and calm_at >= 0.0 and _t >= calm_at:
		go_calm()
	if _stress >= STRESS_EVERY and not calm:
		_stress = 0.0
		_poke()
	if _log >= (CALM_LOG_EVERY if calm else LOG_EVERY):
		_log = 0.0
		_line()


## Nobody touches the yard from now on: no more stress zaps, the demo bots leave and let go of the pads.
func go_calm() -> void:
	calm = true
	for b in get_parent().get_children():
		if b is DemoBot:
			var z := (b as DemoBot).zapper
			if is_instance_valid(z):
				z.input_override = {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false,
						"next": false, "prev": false}
			b.queue_free()
	if calm_reset and level:
		level.reset_yard()
	print("soak: calm at t=%.1f (stress and bots stopped%s)" % [_t, ", yard reset" if calm_reset else ""])


## Physics objects not asleep, and the names of a few of them.
func awake() -> Array:
	var out := []
	for o in _objects():
		if not (o as PhysicsObject).sleeping:
			out.append(o)
	return out


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
	var n := maxf(_frames, 1)
	var up := awake()
	var names := PackedStringArray()
	for o in up.slice(0, 12):
		names.append(String((o as Node).name))
	var fx := 0
	for o in up:
		var st = (o as PhysicsObject).stack
		if st and (not st.effects.is_empty() or st.glued_group().size() > 1):
			fx += 1
	var who := PackedStringArray()
	for z in get_tree().get_nodes_in_group(Zapper.GROUP):
		who.append("P%d@x%.1f" % [(z as Zapper).player, (z as Node3D).global_position.x])
	print("soak: t=%5.1f%s awake=%d plain=%d fx=%d bodies=%d [%s] players %s" % [_t, " calm" if calm else "",
			up.size(), up.size() - fx, fx, _objects().size(), ",".join(names), " ".join(who)])
	print("soak: t=%5.1f objects=%d nodes=%d orphans=%d objs_db=%d joints=%d effects_on=%d zaps=%d glues=%d recalls=%d frame_ms=%.2f worst_ms=%.1f process_ms=%.2f physics_ms=%.2f voices=%d mem_mb=%.1f" % [
			_t, _objects().size(), Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
			get_tree().get_nodes_in_group(&"glue_joints").size(), on, zaps, glues, Yard.recalls, ms,
			_worst / 1000.0, _proc / n, _phys / n, Audio.active_voices(), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	_frames = 0
	_usec = 0
	_worst = 0
	_proc = 0.0
	_phys = 0.0
