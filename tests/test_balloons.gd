## Loose balloons in the yard (Y-11): float at their spot and stay in their zone, pop on a hard hit or
## a sharp poke (never on a light touch), come back after a short while, keep each zone at 6-11 things,
## and the yard's physics frame time stays within budget with them in.
class_name TestBalloons
extends GdUnitTestSuite

const KEYS := [&"balloon", &"balloon_2", &"balloon_3"]
## Headless physics budget (Performance.TIME_PHYSICS_PROCESS per frame): test_more_objects.gd sets no
## number of its own, so the balloons must cost at most 25% (or 1 ms) over the same yard without them.
## (No absolute number: the producer box runs physics on a slow CPU; S-18 measures the GTX 1060.)

var world: Node3D
var _real_settings := ""


func before_test() -> void:
	Game.demo = false
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_balloons.json"
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func level(layout: YardLayout = null) -> YardLevel:
	var l := YardLevel.new()
	l.use_save = false
	l.layout = layout if layout else load(YardLevel.LAYOUT)
	world.add_child(l)
	var players := Node3D.new()
	players.name = "Players"
	l.add_child(players)
	return l


func _zone_of(x: float) -> Array:
	for z in YardLevel.ZONES:
		if x >= z[1] and x < z[2]:
			return z
	return []


func test_settings_file_is_not_the_real_one() -> void:
	assert_str(Save.settings_path).is_not_equal("user://settings.json")
	assert_str(_real_settings).is_equal("user://settings.json")


func test_balloon_is_object_data_with_art_face_and_a_voice_from_the_set() -> void:
	var d := load("res://data/objects/balloon.tres") as BalloonData
	assert_object(d).is_not_null()
	assert_bool(d is ObjectData).is_true()
	assert_bool(ObjectArt.has_art(&"balloon")).is_true()
	assert_bool(d.has_face).is_true()
	assert_bool(Audio.has_cue(d.voice_cue())).override_failure_message("voice %s" % d.voice_cue()).is_true()
	assert_bool(Audio.has_cue(String(d.pop_cue))).override_failure_message("pop %s" % d.pop_cue).is_true()


func test_balloons_placed_and_zones_stay_six_to_eleven() -> void:
	var layout := load(YardLevel.LAYOUT) as YardLayout
	var per_zone := {}
	var zones_with := {}
	for e in layout.entries:
		var z := _zone_of(e.position.x)
		per_zone[z[0]] = int(per_zone.get(z[0], 0)) + 1
		if e.object is BalloonData:
			zones_with[z[0]] = true
	assert_int(zones_with.size()).is_greater_equal(2)
	for z in YardLevel.ZONES:
		assert_int(int(per_zone.get(z[0], 0))).override_failure_message("%s has %d" % [z[0], per_zone.get(z[0], 0)]) \
				.is_between(6, 11)


func test_balloon_floats_within_its_zone() -> void:
	var l := level()
	await step(30)
	for k in KEYS:
		var o := l.object(k) as LooseBalloon
		assert_object(o).override_failure_message("%s is not a LooseBalloon" % k).is_not_null()
		o.linear_velocity = Vector3(9.0 if k != &"balloon_3" else -9.0, 6.0, 0)
	var lowest := {}
	for i in 360:
		await get_tree().physics_frame
		for k in KEYS:
			var o := l.object(k) as LooseBalloon
			if o.is_popped:
				continue
			lowest[k] = minf(float(lowest.get(k, INF)), o.global_position.y)
	for k in KEYS:
		var o := l.object(k) as LooseBalloon
		var z := _zone_of(o.home.x)
		assert_bool(o.is_popped).is_false()
		assert_float(o.global_position.x).override_failure_message("%s x %.2f" % [k, o.global_position.x]) \
				.is_between(z[1], z[2])
		# Afloat: near its hover height, never dropped to the ground, never rising off.
		assert_float(o.global_position.y).is_between(o.hover_y() - 0.5, o.hover_y() + 0.5)
		assert_float(float(lowest[k])).is_greater(o.home.y - 1.2)
		assert_float(o.linear_velocity.length()).is_less(1.0)


func test_balloon_can_be_grabbed_and_thrown_without_popping() -> void:
	var l := level()
	var hand := Node3D.new()
	hand.set_script(load("res://tests/fixtures/hand.gd"))
	hand.position = Vector3(-36, 2.5, 0)
	world.add_child(hand)
	await step(20)
	var o := l.object(&"balloon") as LooseBalloon
	assert_object(Effects.grab(o, hand, Players.COLOR[Players.P1])).is_not_null()
	await step(40)
	assert_float(o.global_position.distance_to(hand.hold_point(o))).is_less(0.6)
	Effects.release(o, Vector3(6, 3, 0))
	await step(90)
	assert_bool(o.is_popped).is_false()
	assert_int(o.pops).is_equal(0)


func test_light_touch_does_not_pop() -> void:
	var l := level()
	await step(30)
	var o := l.object(&"balloon_2") as LooseBalloon
	o.linear_velocity = Vector3(2.0, 0.5, 0)   # a nudge
	await step(60)
	var c := l.object(&"crate")
	c.global_position = o.global_position + Vector3(-1.2, 0, 0)
	c.linear_velocity = Vector3(2.0, 0, 0)    # a soft bump from a crate
	await step(60)
	assert_int(o.pops).is_equal(0)


func test_hard_hit_pops_into_a_puff_then_respawns() -> void:
	var l := level()
	await step(30)
	var o := l.object(&"balloon") as LooseBalloon
	Audio.history.clear()
	# Thrown hard into the fence: a big bite out of its speed.
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 6, 4)
	cs.shape = box
	wall.add_child(cs)
	world.add_child(wall)
	wall.global_position = o.global_position + Vector3(1.6, 0, 0)
	await step(2)
	o.linear_velocity = Vector3(20, 0, 0)
	o.set(&"_last_v", o.linear_velocity)
	var popped := false
	for i in 30:
		await get_tree().physics_frame
		if o.is_popped:
			popped = true
			break
	assert_bool(popped).override_failure_message("hard hit did not pop").is_true()
	assert_bool(Audio.played(String((o.data as BalloonData).pop_cue))).is_true()
	assert_bool(o.is_in_group(PhysicsObject.GROUP)).is_false()
	assert_int(world.find_children("BalloonPuff", "", true, false).size()).is_greater_equal(1)
	assert_bool(Yard.in_bounds(o.global_position)).is_true()
	wall.free()
	await step(int((o.data as BalloonData).respawn_time * 60.0) + 10)
	assert_bool(o.is_popped).override_failure_message("did not respawn").is_false()
	assert_bool(o.is_in_group(PhysicsObject.GROUP)).is_true()
	assert_float(o.global_position.distance_to(o.home)).is_less(1.0)
	await step(60)
	assert_int(o.pops).is_equal(1)
	assert_float(o.global_position.y).is_between(o.home.y, o.hover_y() + 0.5)


func test_sharp_poke_pops() -> void:
	var l := level()
	await step(30)
	var o := l.object(&"balloon") as LooseBalloon
	var cone := l.object(&"traffic_cone")
	Effects.zap(&"freeze", cone)   # hold it still beside the balloon, then thaw and push it in
	cone.global_position = o.global_position + Vector3(-0.9, 0, 0)
	Effects.zap(&"freeze", cone)
	cone.linear_velocity = Vector3(3.0, 0, 0)
	var popped := false
	for i in 30:
		await get_tree().physics_frame
		if o.is_popped:
			popped = true
			break
	assert_bool(popped).override_failure_message("sharp poke did not pop").is_true()


## Median physics step (ms) over 240 frames, with the same launches on the same non-balloon bodies.
func _mean_frame_ms(layout: YardLayout) -> float:
	var l := level(layout)
	await step(30)
	var keys: Array = l.objects.keys().filter(func(k: StringName) -> bool: return not String(k).begins_with("balloon"))
	keys.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var times := PackedFloat64Array()
	for frame in 240:
		if frame % 6 == 0:
			var o: PhysicsObject = l.object(keys[rng.randi() % keys.size()])
			o.linear_velocity = Vector3(rng.randf_range(-8, 8), rng.randf_range(2, 8), 0)
		await get_tree().physics_frame
		times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	l.free()
	Yard.reset_world()
	times.sort()
	return times[times.size() / 2]


func test_stress_frame_time_within_budget() -> void:
	var full := load(YardLevel.LAYOUT) as YardLayout
	var without := YardLayout.new()
	for e in full.entries:
		if not (e.object is BalloonData):
			without.entries.append(e)
	await _mean_frame_ms(full)   # warm-up: first build pays for shader and mesh caches
	# Best of three each, alternating: the box may be busy with other work, and load only adds time.
	var base := INF
	var with := INF
	for i in 3:
		base = minf(base, await _mean_frame_ms(without))
		with = minf(with, await _mean_frame_ms(full))
	print("balloons frame ms: without %.2f, with %.2f" % [base, with])
	assert_float(with).override_failure_message("%.2f ms with vs %.2f without" % [with, base]) \
			.is_less(base * 1.25 + 1.0)
