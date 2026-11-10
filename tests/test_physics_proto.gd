## Phase 1 risk prototype: EffectStack, grow/shrink, glue, composition, plane spring, gravity, recall.
class_name TestPhysicsProto
extends GdUnitTestSuite

const KINDS: Array[StringName] = [&"grow", &"shrink", &"bouncy", &"balloon", &"freeze", &"magnet", &"glue"]

var world: Node3D


func before_test() -> void:
	world = Node3D.new()
	add_child(world)
	world.add_child(YardStrip.new())
	Yard.reset_stats()


func after_test() -> void:
	world.free()


func box(pos: Vector3, size := Vector3.ONE, mass := 1.0) -> PhysicsObject:
	var o := PhysicsObject.new(ObjectData.make(&"box", ObjectData.Shape.BOX, size, mass, Color.TAN))
	o.position = pos
	world.add_child(o)
	return o


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


## Apply a gun the way the player does; glue uses (and creates if needed) a partner.
func zap(kind: StringName, o: PhysicsObject, partner: PhysicsObject) -> void:
	if kind == &"glue":
		Effects.glue(o, partner)
	else:
		Effects.zap(kind, o)


func undo(kind: StringName, o: PhysicsObject) -> void:
	if kind == &"glue":
		o.stack.get_effect(&"glue").undo(o)
	elif kind == &"grow":
		Effects.zap(&"shrink", o)
	elif kind == &"shrink":
		Effects.zap(&"grow", o)
	else:
		Effects.zap(kind, o)


func test_jolt_is_the_3d_physics_engine() -> void:
	assert_str(ProjectSettings.get_setting("physics/3d/physics_engine")).is_equal("Jolt Physics")


func test_grow_shrink_limits_and_mass_by_volume() -> void:
	var o := box(Vector3(0, 0.5, 0))
	await step(2)
	for i in 4:
		assert_bool(Effects.zap(&"grow", o)).is_true()
	assert_bool(Effects.zap(&"grow", o)).is_false()   # 5th step refused
	assert_int(o.stack.props.scale_step).is_equal(4)
	await step(75)   # 4 steps x 0.25 s
	var s := pow(1.3, 4)
	assert_float(o.current_scale).is_equal_approx(s, 0.0001)
	assert_float(o.mass).is_equal_approx(s * s * s, 0.001)
	var shape := o.get_node("Shape").shape as BoxShape3D
	assert_vector(shape.size).is_equal_approx(Vector3.ONE * s, Vector3.ONE * 0.0001)
	for i in 8:
		assert_bool(Effects.zap(&"shrink", o)).is_true()
	assert_bool(Effects.zap(&"shrink", o)).is_false()
	await step(140)
	var t := pow(1.3, -4)
	assert_float(o.current_scale).is_equal_approx(t, 0.0001)
	assert_float(o.mass).is_equal_approx(maxf(t * t * t, Yard.MASS_MIN), 0.001)
	assert_float(o.global_position.y).is_greater(0.0)   # not sunk into the floor


func test_undo_restores_exactly() -> void:
	var o := box(Vector3(0, 0.5, 0))
	var p := box(Vector3(3, 0.5, 0))
	await step(5)
	var base := o.stack.compute().to_dict()
	var base_mass := o.mass
	for k in KINDS:
		zap(k, o, p)
	zap(&"grow", o, p)
	await step(30)
	assert_int(o.stack.effects.size()).is_greater(4)
	var order := KINDS.duplicate()
	order.reverse()
	order.push_front(&"grow")
	for k in order:
		if k != &"magnet" or o.stack.has(&"magnet"):
			undo(k, o)
	await step(90)
	assert_array(o.stack.effects).is_empty()
	assert_dict(o.stack.props.to_dict()).is_equal(base)
	assert_float(o.current_scale).is_equal(1.0)
	assert_float(o.mass).is_equal(base_mass)
	assert_bool(o.freeze).is_false()
	assert_float(o.effective_gravity_scale).is_equal(1.0)
	assert_array(get_tree().get_nodes_in_group(&"glue_joints")).is_empty()


func test_magnet_switches_itself_off() -> void:
	var o := box(Vector3(0, 0.5, 0))
	Effects.zap(&"magnet", o)
	var m: Effects.Magnet = o.stack.get_effect(&"magnet")
	m.time_left = 0.1
	await step(12)
	assert_bool(o.stack.has(&"magnet")).is_false()


func test_glue_and_split() -> void:
	var a := box(Vector3(0, 0.5, 0))
	var b := box(Vector3(1.0, 0.5, 0))
	await step(3)
	assert_object(Effects.glue(a, a)).is_null()
	var g := Effects.glue(a, b)
	assert_object(g).is_not_null()
	assert_object(Effects.glue(b, a)).is_null()   # already glued
	assert_bool(a.stack.has(&"glue") and b.stack.has(&"glue")).is_true()
	assert_object(g.joint).is_instanceof(Generic6DOFJoint3D)
	assert_int(get_tree().get_nodes_in_group(&"glue_joints").size()).is_equal(1)
	assert_int(a.stack.glued_group().size()).is_equal(2)
	# Lift A: B must come with it.
	a.linear_velocity = Vector3(0, 6, 0)
	await step(20)
	assert_float(b.global_position.y).is_greater(0.6)
	assert_float(a.global_position.distance_to(b.global_position)).is_equal_approx(1.0, 0.05)
	g.undo(b)
	await step(1)
	assert_bool(a.stack.has(&"glue") or b.stack.has(&"glue")).is_false()
	assert_array(get_tree().get_nodes_in_group(&"glue_joints")).is_empty()


func test_glue_pulls_distant_objects_together() -> void:
	var a := box(Vector3(-3, 0.5, 0))
	var b := box(Vector3(3, 0.5, 0))
	await step(3)
	var g := Effects.glue(a, b)
	assert_bool(g.joined()).is_false()
	await step(150)
	assert_bool(g.joined()).is_true()
	assert_float(g.gap()).is_less(0.3)
	# Can't meet (one frozen far away behind a fence of nothing to push against): gives up cleanly.
	var c := box(Vector3(-20, 0.5, 0))
	var d := box(Vector3(20, 0.5, 0))
	Effects.zap(&"freeze", c)
	Effects.zap(&"freeze", d)
	var g2 := Effects.glue(c, d)
	await step(200)
	assert_bool(c.stack.has(&"glue") or d.stack.has(&"glue")).is_false()


func test_grow_on_frozen_object_does_not_crush_through_floor() -> void:
	var crate := box(Vector3(0, 0.5, 0))
	var tall := box(Vector3(0, 1.8, 0), Vector3(0.8, 1.6, 0.8), 1.5)
	await step(30)
	Effects.zap(&"freeze", tall)
	for i in 4:
		Effects.zap(&"grow", tall)
	await step(90)
	Effects.zap(&"freeze", tall)
	await step(60)
	assert_float(crate.global_position.y).is_greater(0.3)
	assert_float(tall.global_position.y).is_greater(crate.global_position.y)


func test_grow_with_no_room_is_refused() -> void:
	var o := box(Vector3(0, 0.5, 0))
	var lid := box(Vector3(0, 1.6, 0), Vector3(3, 0.2, 1))
	Effects.zap(&"freeze", lid)   # a frozen shelf 1 m above the box
	await step(20)
	assert_bool(Effects.zap(&"grow", o)).is_true()   # 1.3 m fits under a lid at 1.5 m
	await step(30)
	Effects.zap(&"grow", o)                            # 1.69 m does not: refused, boings back
	await step(60)
	assert_int(o.stack.props.scale_step).is_equal(1)
	assert_float(o.current_scale).is_equal_approx(1.3, 0.001)
	assert_float(o.global_position.y).is_greater(0.3)


func test_glue_stable_across_mass_and_scale_and_grow() -> void:
	var car := box(Vector3(0, 0.6, 0), Vector3(2.4, 1.1, 1.3), 12.0)
	var chick := box(Vector3(1.6, 0.3, 0), Vector3(0.5, 0.6, 0.4), 0.3)
	for i in 4:
		Effects.zap(&"grow", car)
		Effects.zap(&"shrink", chick)
	await step(70)
	var g := Effects.glue(car, chick)
	assert_object(g).is_not_null()
	var rest := car.global_transform.affine_inverse() * chick.global_position
	for i in 6:
		Effects.zap(&"grow", chick)   # grow the small half after gluing
	car.linear_velocity = Vector3(3, 8, 0)
	await step(150)
	var drift := (car.global_transform * rest).distance_to(chick.global_position)
	assert_float(drift).is_less(0.15)
	for o in [car, chick]:
		assert_bool(o.global_position.is_finite() and o.linear_velocity.is_finite()).is_true()
		assert_float(o.linear_velocity.length()).is_less(Yard.MAX_SPEED + 1.0)
		assert_float(o.global_position.y).is_greater(0.0)


func test_grow_in_a_stack_is_stable() -> void:
	var bottom := box(Vector3(0, 0.5, 0))
	var mid := box(Vector3(0, 1.5, 0))
	var top := box(Vector3(0, 2.5, 0))
	await step(30)
	for i in 4:
		Effects.zap(&"grow", mid)
	var worst := 0.0
	for f in 120:
		await get_tree().physics_frame
		for o in [bottom, mid, top]:
			worst = maxf(worst, o.linear_velocity.length())
	assert_float(worst).is_less(Yard.SCALE_CHANGE_MAX_SPEED + 3.0)   # no explosion
	for o in [bottom, mid, top]:
		assert_float(o.global_position.y).is_greater(0.0)
	assert_float(mid.global_position.y).is_greater(bottom.global_position.y)
	# And shrink it right back: the stack settles, nothing falls through.
	for i in 4:
		Effects.zap(&"shrink", mid)
	await step(120)
	for o in [bottom, mid, top]:
		assert_float(o.global_position.y).is_greater(0.0)


## Every pair of effects composes: both orders give the same body, undo gets back to the start, and a
## short sim with all pairs live has no NaN, no sinking, nothing over the cap.
func test_every_pair_of_effects_composes() -> void:
	var live: Array[PhysicsObject] = []
	var n := 0
	for i in KINDS.size():
		for j in KINDS.size():
			if i == j:
				continue
			var e1 := KINDS[i]
			var e2 := KINDS[j]
			var x := -26.0 + (n % 21) * 2.5
			var y := 0.5 + (n / 21) * 3.0
			n += 1
			var o := box(Vector3(x, 12 + y, 0))   # undo check, freed before any physics step
			var p := box(Vector3(x + 1.0, 12 + y, 0))
			var q := box(Vector3(x, y, 0))        # reversed-order twin, left live for the sim
			var r := box(Vector3(x + 1.0, y, 0))
			var base := o.stack.compute().to_dict()
			zap(e1, o, p)
			zap(e2, o, p)
			zap(e2, q, r)
			zap(e1, q, r)
			var ab := o.stack.compute().to_dict()
			assert_dict(q.stack.compute().to_dict()).override_failure_message(
				"%s+%s differs from %s+%s" % [e1, e2, e2, e1]).is_equal(ab)
			if not ((e1 == &"grow" and e2 == &"shrink") or (e1 == &"shrink" and e2 == &"grow")):
				for k in [e1, e2]:
					var id: StringName = &"size" if k in [&"grow", &"shrink"] else k
					assert_bool(o.stack.has(id)).override_failure_message("%s missing after %s+%s" % [id, e1, e2]).is_true()
			undo(e2, o)
			undo(e1, o)
			assert_dict(o.stack.compute().to_dict()).override_failure_message(
				"undo %s+%s not exact" % [e1, e2]).is_equal(base)
			live.append_array([q, r])
			o.free()
			p.free()
	await step(60)
	for o in live:
		assert_bool(o.global_position.is_finite() and o.linear_velocity.is_finite()).is_true()
		assert_float(o.global_position.y).is_greater(-0.05)
		assert_float(o.linear_velocity.length()).is_less(Yard.MAX_SPEED + 1.0)


func test_plane_spring_keeps_z_small() -> void:
	var o := box(Vector3(0, 2, 2.0))
	o.linear_velocity = Vector3(2, 3, 4)
	o.angular_velocity = Vector3(5, 3, 2)
	var worst := 0.0
	for f in 300:
		await get_tree().physics_frame
		worst = maxf(worst, absf(o.global_position.z))
	assert_float(worst).is_less(2.05)                         # never drifts further out
	assert_float(absf(o.global_position.z)).is_less(0.03)     # and ends on the plane


func test_gravity_comes_from_yard_gravity_at() -> void:
	var o := box(Vector3(0, 5, 0))
	assert_float(o.gravity_scale).is_equal(0.0)   # engine gravity off; Yard.gravity_at drives the body
	Yard.reset_stats()
	await step(10)
	assert_int(Yard.gravity_queries).is_greater(5)
	assert_float(o.global_position.y).is_less(5.0)
	# Balloon flips it: the same body now rises.
	var b := box(Vector3(4, 0.5, 0))
	await step(5)
	Effects.zap(&"balloon", b)
	await step(40)
	assert_float(b.global_position.y).is_greater(0.8)
	assert_vector(Yard.radial_gravity(Yard.center + Vector3(0, 10, 0))).is_equal_approx(Vector3(0, -Yard.G, 0), Vector3.ONE * 0.001)


func test_recall_when_out_of_bounds() -> void:
	var o := box(Vector3(0, 0.5, 0))
	var p := box(Vector3(1.0, 0.5, 0))
	await step(3)
	Effects.glue(o, p)
	var offset := p.global_position - o.global_position
	o.global_position = Vector3(0, -20, 0)
	p.global_position = o.global_position + offset
	await step(2)
	assert_int(Yard.recalls).is_greater_equal(1)
	assert_float(o.global_position.distance_to(Yard.GATE)).is_less(1.0)
	assert_float((p.global_position - o.global_position).distance_to(offset)).is_less(0.1)


func test_aim_cone_snaps_to_nearest() -> void:
	var near := box(Vector3(3, 2.0, 0))     # ~34 degrees off a flat aim, inside the cone
	var far := box(Vector3(9, 0.5, 0))      # dead centre but further
	var behind := box(Vector3(-3, 0.5, 0))
	await step(1)
	var cands: Array = [near, far, behind]
	assert_object(Aim.pick(Vector3(0, 0.5, 0), Vector2.RIGHT, cands)).is_same(near)
	assert_object(Aim.pick(Vector3(0, 0.5, 0), Vector2.LEFT, cands)).is_same(behind)
	assert_object(Aim.pick(Vector3(0, 0.5, 0), Vector2.DOWN, cands)).is_null()
	assert_object(Aim.pick(Vector3(0, 0.5, 0), Vector2.ZERO, cands)).is_null()


func test_proto_scene_loads() -> void:
	var scene := load("res://scenes/proto/risk_proto.tscn") as PackedScene
	assert_object(scene).is_not_null()
