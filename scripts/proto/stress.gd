## Stress run for the risk prototype. Fixed seed, 60 s of physics time: random guns on random objects
## (and the odd hard throw, standing in for gravity-grab flicks), logging anything that would break a
## kid's yard. Run headless and deterministic:
##   godot --headless --path . --fixed-fps 60 res://scenes/proto/risk_proto.tscn -- --stress
##   ... -- --stress=40      (spawn copies up to 40 bodies)
## Exits 0 when the summary is clean, 1 otherwise.
extends Node

const SEED := 20261109
const SECONDS := 60.0
const ACTION_EVERY := 0.2         # seconds of physics time between random zaps
const THROW_CHANCE := 0.12
const SPEED_MARGIN := 1.0         # contacts can add a little after our clamp; this is "over the cap"
const SPIKE_MS := 16.0
const SINK_Y := -0.05             # a centre below the ground surface = tunnelled into the floor

var count := 0
var rng := RandomNumberGenerator.new()
var proto: Node
var frames := 0
var t := 0.0
var next_action := 0.5
var actions := {}
var log_lines: PackedStringArray = []
var nan_count := 0
var over_cap := 0
var max_speed := 0.0
var max_z := 0.0
var sunk := 0
var escapes := 0
var spikes := 0
var max_phys_ms := 0.0
var phys_ms: PackedFloat32Array = []
var glue_rest := {}               # Glue -> b's position in a's local frame at creation
var max_glue_drift := 0.0
var _sinking := {}
var _last_usec := 0
var _drifting := {}


func _ready() -> void:
	rng.seed = SEED
	proto = get_parent()
	process_physics_priority = 100   # after every object has moved this frame
	await get_tree().process_frame
	var roster: Array = proto.ROSTER
	while proto.objects.size() < count:
		var r: Array = roster[rng.randi_range(0, roster.size() - 1)]
		var d := ObjectData.make(r[0], r[1], r[2], r[3], r[4])
		proto.spawn(d, Vector3(rng.randf_range(-24, 24), rng.randf_range(2, 10), 0))
	for o: PhysicsObject in proto.objects:
		o.recalled.connect(func(obj): _note("escape: %s recalled from bounds" % obj.name))
	print("stress: seed %d, %d bodies, %.0f s of physics" % [SEED, proto.objects.size(), SECONDS])


func _physics_process(delta: float) -> void:
	frames += 1
	t += delta
	# Wall time of the whole previous frame (physics step + every script); headless, so no rendering.
	var now := Time.get_ticks_usec()
	var ms := (now - _last_usec) / 1000.0
	_last_usec = now
	if frames > 5:
		phys_ms.append(ms)
		max_phys_ms = maxf(max_phys_ms, ms)
		if ms > SPIKE_MS:
			spikes += 1
			_note("spike: physics frame %.1f ms at t=%.2f" % [ms, t])
	if t >= next_action:
		next_action += ACTION_EVERY
		_random_action()
	_check()
	if t >= SECONDS:
		_finish()


func _random_action() -> void:
	var objs: Array[PhysicsObject] = proto.objects
	var a: PhysicsObject = objs[rng.randi_range(0, objs.size() - 1)]
	if rng.randf() < THROW_CHANCE:
		if not a.freeze:
			a.linear_velocity = Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1), 0).normalized() * rng.randf_range(10, 25)
		_count(&"throw")
		return
	var gun: StringName = Effects.GUNS[rng.randi_range(0, Effects.GUNS.size() - 1)]
	if gun == &"glue":
		var joints := get_tree().get_nodes_in_group(&"glue_joints")
		if not joints.is_empty() and rng.randf() < 0.35:
			(joints[rng.randi_range(0, joints.size() - 1)].get_meta(&"glue") as Effects.Glue).undo(null)
			_count(&"unglue")
			return
		var b: PhysicsObject = objs[rng.randi_range(0, objs.size() - 1)]
		var g := Effects.glue(a, b)
		if g:
			glue_rest[g] = a.global_transform.affine_inverse() * b.global_position
		_count(&"glue" if g else &"glue_refused")
		return
	var ok := Effects.zap(gun, a)
	if OS.get_cmdline_user_args().has("--trace"):
		print("t=%.2f %s -> %s %s" % [t, gun, a.name, ok])
	_count(gun if ok else StringName("%s_refused" % gun))


func _count(k: StringName) -> void:
	actions[k] = actions.get(k, 0) + 1


func _check() -> void:
	for o: PhysicsObject in proto.objects:
		var p := o.global_position
		var v := o.linear_velocity
		if not (p.is_finite() and v.is_finite() and o.angular_velocity.is_finite()):
			nan_count += 1
			_note("nan: %s at t=%.2f" % [o.name, t])
			continue
		var s := v.length()
		max_speed = maxf(max_speed, s)
		if s > Yard.MAX_SPEED + SPEED_MARGIN:
			over_cap += 1
			_note("speed: %s %.1f m/s at t=%.2f" % [o.name, s, t])
		max_z = maxf(max_z, absf(p.z))
		if p.y < SINK_Y:
			sunk += 1
			if not _sinking.has(o):
				_sinking[o] = true
				_note("sunk: %s y=%.2f at t=%.2f %s" % [o.name, p.y, t, describe(o)])
		else:
			_sinking.erase(o)
		nan_count += o.nan_events
		o.nan_events = 0
	for g in glue_rest.keys():
		if not is_instance_valid(g.joint):
			glue_rest.erase(g)
			continue
		var drift: float = (g.a.global_transform * glue_rest[g]).distance_to(g.b.global_position)
		max_glue_drift = maxf(max_glue_drift, drift)
		if drift > 0.25 and not _drifting.has(g):
			_drifting[g] = true
			_note("glue drift %.2f m at t=%.2f: A %s | B %s" % [drift, t, describe(g.a), describe(g.b)])


func describe(o: PhysicsObject) -> String:
	return "%s pos %s scale %.2f mass %.2f effects %s group %d" % [o.name, o.global_position.snapped(Vector3.ONE * 0.01), o.current_scale, o.mass, o.stack.ids(), o.stack.glued_group().size()]


func _note(line: String) -> void:
	if line.begins_with("escape"):
		escapes += 1
	if log_lines.size() < 60:
		log_lines.append(line)
		print("stress: ", line)


func _finish() -> void:
	set_physics_process(false)
	var sorted := phys_ms.duplicate()
	sorted.sort()
	var p50 := sorted[sorted.size() / 2] if sorted.size() > 0 else 0.0
	var p99 := sorted[int(sorted.size() * 0.99)] if sorted.size() > 0 else 0.0
	var clean := nan_count == 0 and escapes == 0 and spikes == 0 and over_cap == 0 and sunk == 0
	var lines := PackedStringArray([
		"=== stress summary (seed %d) ===" % SEED,
		"physics time %.1f s, %d frames, %d bodies, glue joints alive at end %d" % [t, frames, proto.objects.size(), get_tree().get_nodes_in_group(&"glue_joints").size()],
		"actions: %s" % JSON.stringify(actions),
		"NaN events: %d" % nan_count,
		"escapes (recalled to gate): %d" % escapes,
		"sunk into floor: %d" % sunk,
		"speed over cap (%.0f m/s + %.0f): %d   max speed seen %.1f m/s" % [Yard.MAX_SPEED, SPEED_MARGIN, over_cap, max_speed],
		"max |z| off the play plane: %.3f m" % max_z,
		"max glue drift (B from where A's frame says it should be): %.3f m" % max_glue_drift,
		"frame ms (wall, physics + scripts): p50 %.2f  p99 %.2f  max %.2f  spikes over %.0f ms: %d" % [p50, p99, max_phys_ms, SPIKE_MS, spikes],
		"result: %s" % ("CLEAN" if clean else "PROBLEMS"),
	])
	print("\n".join(lines))
	get_tree().quit(0 if clean else 1)
