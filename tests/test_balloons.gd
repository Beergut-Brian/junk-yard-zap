## Loose balloons in the yard (Y-11): float at their spot and stay in their zone, pop on a hard hit or
## a sharp poke (never on a light touch), come back after a short while, keep each zone at 6-11 things,
## react to every gun and float again after undo, wear three party colours, and stay cheap in physics.
class_name TestBalloons
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
var _clock := Clock.new()   # 60 Hz, time scale 1: frame counts below mean the same seconds everywhere

const KEYS := [&"balloon", &"balloon_2", &"balloon_3"]

var world: Node3D
var _real_settings := ""


func before() -> void:
	_clock.pin()


func before_test() -> void:
	Game.demo = false
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_balloons.json"
	world = Node3D.new()
	add_child(world)


func after() -> void:
	_clock.restore()


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


## Every gun gets a voice (the beach-ball squeak set) and a face from a balloon, never pops it, and
## once the effect is undone it floats back at its hover height. Glue is undone by ungluing.
func test_balloon_reacts_to_every_gun_and_floats_again_after_undo() -> void:
	var l := level()
	var hand := Node3D.new()
	hand.set_script(load("res://tests/fixtures/hand.gd"))
	world.add_child(hand)
	await step(30)
	var o := l.object(&"balloon") as LooseBalloon
	var buddy := l.object(&"bucket") if l.objects.has(&"bucket") else l.object(&"crate")
	assert_str(o.data.voice_cue()).is_equal("voice_beach_ball")
	var clock := 5000.0
	for gun in [&"grow", &"shrink", &"bouncy", &"balloon", &"freeze", &"magnet", &"grab", &"glue"]:
		clock += 100.0
		o.face.react(ObjectFace.Mood.NEUTRAL, 0.0)
		o.face.set_base(ObjectFace.Mood.NEUTRAL)
		Audio.history.clear()
		Audio.clock = clock   # clear of the voice rate cap
		var ok := false
		match gun:
			&"grab":
				hand.position = o.global_position + Vector3(0.5, 0, 0)
				ok = Effects.grab(o, hand, Players.COLOR[Players.P1]) != null
			&"glue":
				buddy.global_position = o.global_position + Vector3(-1.0, 0, 0)
				buddy.linear_velocity = Vector3.ZERO
				ok = Effects.glue(o, buddy) != null
			_:
				ok = Effects.zap(gun, o)
		o.speak()   # what the Zapper does after any hit
		Audio.clock = -1.0
		assert_bool(ok).override_failure_message("%s did not take" % gun).is_true()
		assert_bool(Audio.played("voice_beach_ball_react")).override_failure_message("%s: no voice" % gun).is_true()
		assert_int(o.face.mood).override_failure_message("%s: no face" % gun).is_not_equal(ObjectFace.Mood.NEUTRAL)
		await step(40)
		# Undo: the same gun again (size: the other way), let go, or unglue.
		match gun:
			&"grow": Effects.zap(&"shrink", o)
			&"shrink": Effects.zap(&"grow", o)
			&"grab": Effects.release(o)
			&"glue": o.stack.get_effect(&"glue").undo(o)
			_: Effects.zap(gun, o)
		await step(240)
		assert_bool(o.is_popped).override_failure_message("%s popped it" % gun).is_false()
		assert_int(o.pops).override_failure_message("%s popped it" % gun).is_equal(0)
		assert_bool(o.stack.has(gun)).override_failure_message("%s still on" % gun).is_false()
		assert_float(o.global_position.y).override_failure_message("%s: y %.2f vs hover %.2f" % [gun, o.global_position.y, o.hover_y()]) \
				.is_between(o.hover_y() - 0.6, o.hover_y() + 0.6)
		assert_bool(Yard.in_bounds(o.global_position)).is_true()


func test_the_three_balloons_wear_three_party_colours() -> void:
	var l := level()
	await step(2)
	var seen := {}
	for k in KEYS:
		var o := l.object(k) as LooseBalloon
		var body := o.find_child("Body", true, false) as MeshInstance3D
		assert_object(body).is_not_null()
		var c := (body.material_override as StandardMaterial3D).albedo_color
		assert_str(c.to_html()).is_equal(o.tint().to_html())
		# clear of P1 green and P2 red
		assert_float(absf(c.h - Players.COLOR[Players.P1].h)).is_greater(0.08)
		assert_float(minf(c.h, 1.0 - c.h)).is_greater(0.05)
		seen[c.to_html()] = k
	assert_int(seen.size()).is_equal(3)


## Awake bodies per frame, with the same launches on the same non-balloon bodies.
func _awake_per_frame(layout: YardLayout) -> float:
	var l := level(layout)
	await step(30)
	var keys: Array = l.objects.keys().filter(func(k: StringName) -> bool: return not String(k).begins_with("balloon"))
	keys.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var awake := 0
	for frame in 240:
		if frame % 6 == 0:
			var o: PhysicsObject = l.object(keys[rng.randi() % keys.size()])
			o.linear_velocity = Vector3(rng.randf_range(-8, 8), rng.randf_range(2, 8), 0)
		await get_tree().physics_frame
		for o: PhysicsObject in l.objects.values():
			if not o.sleeping:
				awake += 1
	l.free()
	Yard.reset_world()
	return awake / 240.0


## Physics cost, measured in ways a busy box can't fake (the producer box runs other lanes' Godot at
## the same time: a wall-clock A/B of the whole yard swung from 5 to 11 ms either way). 1) The
## balloons keep nothing else awake: at most their own 3 extra awake bodies per frame. 2) A balloon's
## own per-frame work (the sharp-poke scan; the hover is a few multiplies, no rays) stays far under
## 0.25 ms. S-18 measures the real frame on the GTX 1060.
func test_stress_frame_time_within_budget() -> void:
	var full := load(YardLevel.LAYOUT) as YardLayout
	var without := YardLayout.new()
	for e in full.entries:
		if not (e.object is BalloonData):
			without.entries.append(e)
	var base := await _awake_per_frame(without)
	var with := await _awake_per_frame(full)
	print("balloons awake per frame: without %.1f, with %.1f" % [base, with])
	assert_float(with).override_failure_message("%.1f awake with vs %.1f without" % [with, base]) \
			.is_less_equal(base + KEYS.size() + 0.5)
	var l := level()
	await step(10)
	var o := l.object(&"balloon") as LooseBalloon
	var best := INF
	for round in 5:
		var t0 := Time.get_ticks_usec()
		for i in 200:
			o.call(&"_check_pokes")
		best = minf(best, (Time.get_ticks_usec() - t0) / 200.0)
	print("balloon poke scan: %.1f us" % best)
	assert_float(best).override_failure_message("poke scan %.1f us" % best).is_less(250.0)
