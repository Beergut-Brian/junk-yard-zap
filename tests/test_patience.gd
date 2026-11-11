## Y-17 (D53 a): the barn cow is Patience, the library cow. Only her look changed: the goal cards
## still point at the id `cow`, the physics body is the old one, she stands in the barn, and she has
## a face (her own face atlas, driven by the yard's face rig).
class_name TestPatience
extends GdUnitTestSuite

const COW := "res://data/objects/cow.tres"
const LAYOUT := "res://data/yard_layout.tres"

var world: Node3D


func before_test() -> void:
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()


func _entry() -> YardLayoutEntry:
	for e in (load(LAYOUT) as YardLayout).entries:
		if e.key == &"cow":
			return e
	return null


func _barn_cow() -> ObjectData:
	var e := _entry()
	return e.object if e else null


func test_the_barn_cow_keeps_her_id_and_body() -> void:
	var d := _barn_cow()
	assert_object(d).override_failure_message("no `cow` in the yard layout").is_not_null()
	assert_str(d.resource_path).is_equal(COW)
	assert_str(String(d.id)).is_equal("cow")   # the goal cards say `cow`
	assert_int(d.shape).is_equal(ObjectData.Shape.BOX)
	assert_vector(d.size).is_equal_approx(Vector3(1.9, 1.0, 0.8), Vector3.ONE * 0.0001)
	assert_float(d.mass).is_equal_approx(6.0, 0.0001)
	assert_bool(d.has_face).is_true()
	# Still where the layout put her, in the barn zone (YardLevel ZONES: barn x 9..29).
	assert_vector(_entry().position).is_equal(Vector3(12.5, 1, 0))


func test_the_barn_cow_is_patience_from_the_library() -> void:
	var o := PhysicsObject.new(load(COW))
	world.add_child(o)
	var model := o.find_child("Patience", true, false) as Node3D
	assert_object(model).override_failure_message("the cow is not built from Patience's glb").is_not_null()
	assert_str(model.scene_file_path).is_equal("res://assets/models/patience/cow.glb")
	# Her library colours (proposals/cow/look.md): the coat is the data colour too.
	assert_str((load(COW) as ObjectData).color.to_html(false)).is_equal(Color("#F4F1EA").to_html(false))
	# Never stretched: one scale on every axis.
	assert_float(model.scale.x).is_equal_approx(model.scale.y, 0.0001)
	assert_float(model.scale.x).is_equal_approx(model.scale.z, 0.0001)
	# The collision is still the one box of ObjectData's size.
	var shapes := o.find_children("*", "CollisionShape3D", true, false).filter(
			func(c: Node) -> bool: return not (c as CollisionShape3D).disabled)
	assert_int(shapes.size()).is_equal(1)
	assert_vector(((shapes[0] as CollisionShape3D).shape as BoxShape3D).size).is_equal_approx(
			Vector3(1.9, 1.0, 0.8), Vector3.ONE * 0.0001)
	# Same body mass as a grey-box object of the same data (the art never touches the physics).
	var plain := (load(COW) as ObjectData).duplicate() as ObjectData
	plain.id = &"plain_box_no_art"
	var g := PhysicsObject.new(plain)
	g.position = Vector3(5, 0, 0)
	world.add_child(g)
	assert_object(g.find_child("Patience", true, false)).is_null()
	assert_float(o.mass).is_equal_approx(g.mass, 0.0001)


func test_she_has_a_face_that_follows_the_face_rig() -> void:
	var o := PhysicsObject.new(load(COW))
	world.add_child(o)
	assert_object(o.face).is_not_null()
	var pf := o.find_child("PatienceFace", true, false)
	assert_object(pf).is_not_null()
	assert_object(pf.face_mat).override_failure_message("no face atlas material on Patience").is_not_null()
	await await_idle_frame()
	# Her own painted face shows; the googly eyes of the rig stay hidden.
	assert_bool(o.face.visible).is_false()
	assert_vector(pf.cell()).is_equal(Vector3.ZERO)   # neutral: her resting half-lidded face
	o.face.set_base(ObjectFace.Mood.PANIC)
	await await_idle_frame()
	assert_vector(pf.cell()).is_equal_approx(Vector3(2.0 / 3.0, 0.5, 0.0), Vector3.ONE * 0.0001)
	o.face.set_base(ObjectFace.Mood.NEUTRAL)
	await await_idle_frame()
	assert_vector(pf.cell()).is_equal(Vector3.ZERO)
	# A real zap goes through the rig like on every other object: the balloon asks for the panicked
	# face (base mood) and the zap flashes a reaction; she always shows the rig's current mood.
	Effects.zap(&"balloon", o)
	await await_idle_frame()
	assert_int(o.face.base_mood).is_equal(ObjectFace.Mood.PANIC)
	assert_vector(pf.cell()).is_equal(pf.CELL[o.face.mood])


func test_two_cows_do_not_share_a_face() -> void:
	var a := PhysicsObject.new(load(COW))
	var b := PhysicsObject.new(load(COW))
	b.position = Vector3(4, 0, 0)
	world.add_child(a)
	world.add_child(b)
	a.face.set_base(ObjectFace.Mood.HAPPY)
	await await_idle_frame()
	var fa = a.find_child("PatienceFace", true, false)
	var fb = b.find_child("PatienceFace", true, false)
	assert_vector(fa.cell()).is_not_equal(fb.cell())
