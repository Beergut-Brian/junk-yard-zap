## More yard objects (feature/more-objects): every ObjectData type is placed, each zone has 6-11 things
## to zap, the eight new types have art, a face and a voice file, survive every effect stacking and
## undoing (any order), and a stress run of the whole yard keeps every body clean.
class_name TestMoreObjects
extends GdUnitTestSuite

const OBJECTS := "res://data/objects/"
const NEW := [&"rubber_chicken", &"garden_gnome", &"kiddie_pool", &"trampoline", &"tire_swing",
		&"swim_ring", &"lawn_flamingo", &"surfboard"]
const TOGGLES := [&"bouncy", &"balloon", &"magnet", &"freeze"]

var world: Node3D


func before_test() -> void:
	Game.demo = false
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func level() -> YardLevel:
	var l := YardLevel.new()
	l.use_save = false
	l.layout = load(YardLevel.LAYOUT)
	world.add_child(l)
	var players := Node3D.new()
	players.name = "Players"
	l.add_child(players)
	return l


func _ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for f in DirAccess.get_files_at(OBJECTS):
		var f2 := f.trim_suffix(".remap")
		if f2.ends_with(".tres"):
			out.append((load(OBJECTS + f2) as ObjectData).id)
	return out


func _props(o: PhysicsObject) -> Array:
	return [snappedf(o.mass, 0.001), o.effective_gravity_scale, o.physics_material_override.bounce,
			o.physics_material_override.friction, o.freeze, o.target_scale, o.linear_damp, o.angular_damp]


func test_every_type_is_placed_and_each_zone_has_six_to_eleven() -> void:
	var layout := load(YardLevel.LAYOUT) as YardLayout
	var used := {}
	var keys := {}
	var per_zone := {}
	for e in layout.entries:
		used[e.object.id] = int(used.get(e.object.id, 0)) + 1
		assert_bool(keys.has(e.key)).override_failure_message("duplicate key %s" % e.key).is_false()
		keys[e.key] = true
		for z in YardLevel.ZONES:
			if e.position.x >= z[1] and e.position.x < z[2]:
				per_zone[z[0]] = int(per_zone.get(z[0], 0)) + 1
	var ids := _ids()
	assert_int(ids.size()).is_greater_equal(48)
	for id in ids:
		assert_bool(used.has(id)).override_failure_message("%s is not in the yard" % id).is_true()
	for id in NEW:
		assert_bool(ids.has(id)).override_failure_message("%s has no ObjectData" % id).is_true()
	for z in YardLevel.ZONES:
		assert_int(int(per_zone.get(z[0], 0))).override_failure_message("%s has %d things" % [z[0], per_zone.get(z[0], 0)]) \
				.is_between(6, 11)


func test_new_types_have_art_a_face_and_their_own_voice() -> void:
	for id in NEW:
		var d := load(OBJECTS + String(id) + ".tres") as ObjectData
		assert_bool(ObjectArt.has_art(id)).override_failure_message("no art for %s" % id).is_true()
		assert_bool(d.has_face).is_true()
		assert_bool(Audio.has_cue(d.voice_cue())).override_failure_message("no voice file for %s" % id).is_true()
		assert_float(d.mass).is_between(0.05, 8.0)
		assert_bool(d.min_step >= -4 and d.max_step <= 4).is_true()


## Every new type spawns in the real yard, settles, and stacks every effect (grow, the four toggles,
## glue, grab) then undoes them in another order back to exactly how it started.
func test_new_types_stack_every_effect_and_undo_cleanly() -> void:
	var l := level()
	var hand := Node3D.new()
	hand.set_script(load("res://tests/fixtures/hand.gd"))
	hand.position = Vector3(-30, 2, 0)
	world.add_child(hand)
	await step(60)
	for k in NEW:
		var o := l.object(k)
		assert_object(o).override_failure_message("%s missing" % k).is_not_null()
		var before := _props(o)
		var mate := l.object(&"crate")
		Effects.zap(&"grow", o)
		await step(20)
		for e in TOGGLES:
			assert_bool(Effects.zap(e, o)).override_failure_message("%s %s on" % [k, e]).is_true()
		var g := Effects.glue(o, mate)
		var grab := Effects.grab(o, hand, Players.COLOR[Players.P1])
		await step(5)
		for e in TOGGLES:
			assert_bool(o.stack.has(e)).override_failure_message("%s %s stacked" % [k, e]).is_true()
		assert_bool(o.global_position.is_finite()).is_true()
		if grab:
			Effects.release(o)
		if g:
			g.undo(null)
		for e in [&"freeze", &"magnet", &"bouncy", &"balloon"]:
			if o.stack.has(e):
				Effects.zap(e, o)
		var sz: Effects.Size = o.stack.get_effect(&"size")
		if sz:
			for i in absi(sz.steps):
				Effects.zap(&"shrink" if sz.steps > 0 else &"grow", o)
		await step(30)
		assert_int(o.stack.effects.size()).override_failure_message("%s left %s" % [k, o.stack.effects]).is_equal(0)
		assert_array(_props(o)).override_failure_message("%s props" % k).is_equal(before)


## Each new type, alone: every pair of effects in both orders gives the same result and undoes exactly,
## and the giant and tiny caps hold.
func test_new_types_every_pair_composes_and_caps_hold() -> void:
	var kinds := [&"grow", &"shrink", &"bouncy", &"balloon", &"freeze", &"magnet"]
	for id in NEW:
		var d := load(OBJECTS + String(id) + ".tres") as ObjectData
		for i in kinds.size():
			for j in kinds.size():
				if i == j:
					continue
				var o := PhysicsObject.new(d)
				var q := PhysicsObject.new(d)
				o.position = Vector3(-20, 12, 0)
				q.position = Vector3(20, 12, 0)
				world.add_child(o)
				world.add_child(q)
				var base := o.stack.compute().to_dict()
				Effects.zap(kinds[i], o)
				Effects.zap(kinds[j], o)
				Effects.zap(kinds[j], q)
				Effects.zap(kinds[i], q)
				assert_dict(q.stack.compute().to_dict()).override_failure_message(
						"%s: %s+%s order matters" % [id, kinds[i], kinds[j]]).is_equal(o.stack.compute().to_dict())
				for k in [kinds[j], kinds[i]]:
					var undo: StringName = k
					if k == &"grow":
						undo = &"shrink"
					elif k == &"shrink":
						undo = &"grow"
					Effects.zap(undo, o)
				assert_dict(o.stack.compute().to_dict()).override_failure_message(
						"%s: undo %s+%s" % [id, kinds[i], kinds[j]]).is_equal(base)
				o.free()
				q.free()
		var big := PhysicsObject.new(d)
		big.position = Vector3(0, 12, 0)
		world.add_child(big)
		for n in 8:
			Effects.zap(&"grow", big)
		assert_float(big.target_scale).is_less_equal(d.scale_for_step(d.max_step) + 0.001)
		for n in 16:
			Effects.zap(&"shrink", big)
		assert_float(big.target_scale).is_greater_equal(d.scale_for_step(d.min_step) - 0.001)
		big.free()


## The whole yard (every placed body) under a fixed-seed storm of random zaps, glues and throws for
## ten seconds of physics: nothing NaN, nothing over the speed cap, nothing in the floor, and every body
## still inside the yard or recalled to the gate.
func test_stress_whole_yard_stays_clean() -> void:
	var l := level()
	await step(30)
	var bodies: Array = l.objects.values()
	assert_int(bodies.size()).is_greater_equal(51)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261110
	var zaps := [&"grow", &"grow", &"shrink", &"bouncy", &"balloon", &"freeze", &"magnet"]
	var bad := PackedStringArray()
	for frame in 600:
		if frame % 6 == 0:
			var o: PhysicsObject = bodies[rng.randi() % bodies.size()]
			var r := rng.randf()
			if r < 0.1:
				var p: PhysicsObject = bodies[rng.randi() % bodies.size()]
				if p != o:
					Effects.glue(o, p)
			elif r < 0.2 and not o.freeze:
				o.linear_velocity = Vector3(rng.randf_range(-14, 14), rng.randf_range(2, 14), 0)
			else:
				Effects.zap(zaps[rng.randi() % zaps.size()], o)
		await get_tree().physics_frame
		if frame % 30 == 29:
			for o: PhysicsObject in bodies:
				if not (o.global_position.is_finite() and o.linear_velocity.is_finite()):
					bad.append("%s NaN at %d" % [o.key, frame])
				elif o.linear_velocity.length() > Yard.MAX_SPEED + 1.0:
					bad.append("%s %.1f m/s at %d" % [o.key, o.linear_velocity.length(), frame])
				elif o.global_position.y < YardLevel.POND_FLOOR - 0.3:
					bad.append("%s in the floor at %s" % [o.key, o.global_position])
				elif not Yard.BOUNDS.grow(1.0).has_point(o.global_position):
					bad.append("%s out at %s" % [o.key, o.global_position])
	assert_array(bad).override_failure_message("\n".join(bad)).is_empty()
