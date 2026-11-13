## S-18 "sleep when still" (GAME.md: the sim sleeps objects when still). Gravity is the yard's own
## (PhysicsObject._integrate_forces writes the velocity every step, and a write wakes a Jolt body), so
## before gap-close-5 nothing in the yard ever slept: 55 of 55 bodies awake in a quiet yard. A body the
## solver holds still for PhysicsObject.REST_STEPS steps now puts itself to sleep. These prove: a quiet
## yard falls asleep; a sleeping body wakes and moves when pushed; a body never sleeps in mid-air, falling
## or when what holds it up is knocked away. Staged on open ground, so no pile decides the outcome.
class_name TestSleepWhenStill
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
const Stage := preload("res://tests/fixtures/stage.gd")
var _clock := Clock.new()   # 60 Hz, time scale 1

const OPEN_X := 30.0   # open ground once the bodies around it are benched

var world: Node3D


func before() -> void:
	_clock.pin()


func after() -> void:
	_clock.restore()


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


## Awake bodies, not counting the loose balloons: they bob at their spot and never sleep, by design
## (Y-11; test_balloons.gd shows they keep nothing else awake).
func _awake(l: YardLevel) -> Array:
	var out := []
	for o: PhysicsObject in l.objects.values():
		if o is LooseBalloon:
			continue
		if is_instance_valid(o) and o.is_in_group(PhysicsObject.GROUP) and not o.sleeping:
			out.append(String(o.name))
	return out


## Puts `o` on open ground at x, standing on the floor (or on `under`), still.
func _place(o: PhysicsObject, x: float, under: PhysicsObject = null) -> void:
	var y := o.half_extent_along(Vector3.UP) + 0.02
	if under:
		y += under.global_position.y + under.half_extent_along(Vector3.UP)
	o.global_transform = Transform3D(Basis.IDENTITY, Vector3(x, y, 0.0))
	o.linear_velocity = Vector3.ZERO
	o.angular_velocity = Vector3.ZERO
	o.sleeping = false


func _until_asleep(o: PhysicsObject, frames: int) -> int:
	for f in frames:
		await get_tree().physics_frame
		if o.sleeping:
			return f
	return -1


func test_a_quiet_yard_falls_asleep() -> void:
	var l := level()
	var first_all := -1
	for f in 720:   # 12 s with nobody touching anything
		await get_tree().physics_frame
		if _awake(l).is_empty():
			first_all = f
			break
	var up := _awake(l)
	print("S-18 quiet yard: all %d (but the 3 balloons) asleep at frame %d, awake now %s" % [
			l.objects.size(), first_all, up])
	assert_int(first_all).override_failure_message("still awake after 12 s: %s" % [up]).is_not_equal(-1)
	await step(120)   # and it stays asleep: nothing wakes a still pile by itself
	assert_array(_awake(l)).is_empty()


func test_a_resting_body_sleeps_and_wakes_when_pushed() -> void:
	var l := level()
	var crate := l.object(&"crate")
	Stage.clear_all(l, [crate])
	_place(crate, OPEN_X)
	var slept := await _until_asleep(crate, 180)
	assert_int(slept).override_failure_message("a lone crate on the floor never slept in 3 s").is_not_equal(-1)
	var x0 := crate.global_position.x
	crate.linear_velocity = Vector3(4.0, 3.0, 0.0)   # what a zap or a bonk does
	await step(30)
	assert_bool(crate.sleeping).is_false()
	assert_float(crate.global_position.x - x0).is_greater(0.5)
	var settled := await _until_asleep(crate, 300)   # and it lands and sleeps again
	assert_int(settled).is_not_equal(-1)
	assert_float(crate.global_position.y).is_less(crate.half_extent_along(Vector3.UP) + 0.15)


func test_a_falling_body_never_sleeps_in_mid_air() -> void:
	var l := level()
	var crate := l.object(&"crate")
	Stage.clear_all(l, [crate])
	var rest_y := crate.half_extent_along(Vector3.UP)
	crate.global_transform = Transform3D(Basis.IDENTITY, Vector3(OPEN_X, 5.0, 0.0))
	crate.linear_velocity = Vector3(0.0, 2.0, 0.0)   # up first, so it passes through a still apex
	crate.sleeping = false
	var slept_high := false
	for f in 180:
		await get_tree().physics_frame
		if crate.sleeping and crate.global_position.y > rest_y + 0.2:
			slept_high = true
	assert_bool(slept_high).override_failure_message("slept in mid-air").is_false()
	assert_float(crate.global_position.y).is_less(rest_y + 0.15)


func test_a_sleeping_body_falls_when_what_holds_it_up_is_knocked_away() -> void:
	var l := level()
	var bottom := l.object(&"crate")
	var top := l.object(&"crate_2")
	Stage.clear_all(l, [bottom, top])
	_place(bottom, OPEN_X)
	await step(20)
	_place(top, OPEN_X, bottom)
	await step(240)
	assert_bool(bottom.sleeping and top.sleeping).override_failure_message(
			"the stack never slept: bottom %s top %s" % [bottom.sleeping, top.sleeping]).is_true()
	var high := top.global_position.y
	bottom.linear_velocity = Vector3(9.0, 0.0, 0.0)   # knocked out from under it
	await step(150)
	var rest_y := top.half_extent_along(Vector3.UP)
	print("S-18 stack: top was at %.2f, now %.2f (floor rest %.2f)" % [high, top.global_position.y, rest_y])
	assert_float(top.global_position.y).override_failure_message(
			"top crate hovering at %.2f" % top.global_position.y).is_less(rest_y + 0.15)
