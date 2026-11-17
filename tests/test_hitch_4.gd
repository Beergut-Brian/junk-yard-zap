## S-18 steady 1%-low (jyz-hitch-4). On the 2026-11-17 GTX 1060 bench of v0.1.7-dev.4 the warm high runs
## averaged 69-72 fps with a 1%-low of 41-44, and hitch-3's merged meshes moved the 1%-low only 1-2 fps.
## A per-frame CPU probe on the bench route (.scratch/hitch4-findings.md) found the yard re-sending
## render instances it hadn't moved: Godot sends a transform notification down a node's subtree on every
## position / scale / rotation write, same value or not, and every VisualInstance3D in it re-sends its
## transform to the renderer (new bounds, cull tree and light pairing). PhysicsObject wrote its art's scale
## every physics step and ObjectFace wrote its 13 parts every frame, asleep or not: 1154 instances on a
## frame with a physics step, 694 on one without, in a yard whose bodies were all still. Now both write
## only when the value changes. These pin it: a still object and a still face re-send nothing, a quiet
## yard's sleeping objects re-send nothing, and a real change still moves them (the counter isn't blind).
## The crate is staged alone on open ground, so no pile decides the outcome.
class_name TestHitch4
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
const Stage := preload("res://tests/fixtures/stage.gd")
var _clock := Clock.new()

const OPEN_X := 30.0

var world: Node3D


## Counts the transform notifications that reach it (the ones that make a VisualInstance3D re-send).
class Watch extends Node3D:
	var hits := 0
	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSFORM_CHANGED:
			hits += 1


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


## Call settle() once after adding watches: entering the tree counts once.
func watch(n: Node3D) -> Watch:
	var w := Watch.new()
	w.set_notify_transform(true)
	n.add_child(w)
	return w


func settle(ws: Array) -> void:
	await get_tree().physics_frame
	for w: Watch in ws:
		w.hits = 0


## The crate alone on open ground, asleep.
func _lone_crate() -> PhysicsObject:
	var l := level()
	var crate := l.object(&"crate")
	Stage.clear_all(l, [crate])
	crate.global_transform = Transform3D(Basis.IDENTITY, Vector3(OPEN_X, crate.half_extent_along(Vector3.UP) + 0.02, 0.0))
	crate.linear_velocity = Vector3.ZERO
	crate.angular_velocity = Vector3.ZERO
	crate.sleeping = false
	for f in 240:
		await get_tree().physics_frame
		if crate.sleeping:
			break
	assert_bool(crate.sleeping).override_failure_message("a lone crate on the floor never slept in 4 s").is_true()
	return crate


func test_a_still_object_resends_nothing() -> void:
	var crate := await _lone_crate()
	var art := watch(crate._visual)
	await settle([art])
	await step(60)   # 60 physics steps, as many frames
	assert_int(art.hits).override_failure_message(
			"a sleeping crate's art got %d transform updates in 60 steps" % art.hits).is_equal(0)
	# The counter isn't blind: a squash (what a grow or shrink does) reaches the same node.
	crate.squash = Vector3(1.25, 0.75, 1.25)
	await step(2)
	assert_int(art.hits).is_greater(0)


func test_a_still_face_resends_nothing() -> void:
	var crate := await _lone_crate()
	assert_object(crate.face).is_not_null()
	var mouth: Array[Watch] = []
	for m in crate.face._mouth:
		mouth.append(watch(m))
	var root := watch(crate.face)
	await settle(mouth + [root])
	await step(60)   # long enough for the eyes' look to settle; the mouth doesn't blink
	var sum := func() -> int:
		var t := root.hits
		for w in mouth:
			t += w.hits
		return t
	assert_int(sum.call()).override_failure_message(
			"a calm face's mouth got %d transform updates in 60 frames" % sum.call()).is_equal(0)
	crate.face.react(ObjectFace.Mood.WIDE)   # a mood change moves the mouth into an O
	await step(3)
	assert_int(sum.call()).is_greater(0)


## Every object asleep for the whole window re-sends nothing: not its art, not its face (whatever the
## pile does, only the bodies that stayed asleep are counted).
func test_sleeping_objects_in_a_quiet_yard_resend_nothing() -> void:
	var l := level()
	await step(480)   # 8 s with nobody touching anything (the quiet yard sleeps by ~8.3 s, test_sleep_when_still)
	var watched := {}
	for o: PhysicsObject in l.objects.values():
		if is_instance_valid(o) and o.sleeping and not o is LooseBalloon:
			var ws: Array[Watch] = [watch(o._visual)]
			if o.face:
				for m in o.face._mouth:
					ws.append(watch(m))
			watched[o] = ws
	var all: Array = []
	for o in watched:
		all.append_array(watched[o])
	await settle(all)
	var woke := {}
	for f in 30:
		await get_tree().physics_frame
		for o in watched:
			if not o.sleeping:
				woke[o] = true
	var resent := 0
	var who := PackedStringArray()
	var counted := 0
	for o in watched:
		if woke.has(o):
			continue
		counted += 1
		var hits := 0
		for w: Watch in watched[o]:
			hits += w.hits
		if hits > 0:
			resent += hits
			who.append("%s=%d" % [o.name, hits])
	print("S-18 hitch-4: %d objects asleep for 30 steps, %d transform updates among them %s" % [counted, resent, who])
	assert_int(counted).is_greater(4)
	assert_int(resent).override_failure_message("sleeping objects re-sent: %s" % [who]).is_equal(0)
