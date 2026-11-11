## Vehicle faces lane (jyz-vehicle-faces-1): no faces on vehicles or machines (Kaden, 2026-11-10).
## Data-checked, not by eye: the yard is built and walked for ObjectFace nodes, and the 2D pictograms
## (Pictos, used by the live goal cards, the fence card and the trophy shelf) follow the same flag.
## Own settings file and save profile: never the family's.
class_name TestVehicleFaces
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
var _clock := Clock.new()   # 60 Hz, time scale 1: frame counts below mean the same seconds everywhere

## Every vehicle and machine object type. A new vehicle or machine goes here AND gets has_face = false.
const VEHICLES_AND_MACHINES := [&"car", &"tractor", &"boat", &"wheelbarrow", &"washing_machine", &"tv",
		&"toaster", &"fridge", &"cannon"]
## Characters, animals and props with personality that must keep their faces (a sample of the 39).
const KEEP_FACES := [&"cow", &"chicken", &"duck", &"pig", &"sheep", &"ball", &"crate", &"egg", &"piano",
		&"tire", &"cannonball", &"garden_gnome", &"bathtub"]

var _world: Node3D
var _real_settings := ""
var _real_profile := ""


func before() -> void:
	_clock.pin()
	_real_profile = Save.profile
	Save.profile = "gdunit_vehicle_faces"
	Save.wipe()
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_vehicle_faces.json"
	Save.wipe_settings()


func after() -> void:
	_clock.restore()
	Save.wipe()
	Save.profile = _real_profile
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()


func after_test() -> void:
	if is_instance_valid(_world):
		_world.free()
	Yard.reset_world()


func _all_objects() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at("res://data/objects/"):
		if f.ends_with(".tres"):
			var d := load("res://data/objects/" + f) as ObjectData
			out[d.id] = d
	return out


func _faces_under(n: Node, out: Array) -> void:
	if n is ObjectFace:
		out.append(n)
	for c in n.get_children():
		_faces_under(c, out)


func _owner_object(n: Node) -> PhysicsObject:
	while n and not n is PhysicsObject:
		n = n.get_parent()
	return n as PhysicsObject


func _yard() -> YardLevel:
	_world = Node3D.new()
	add_child(_world)
	var level := YardLevel.new()
	level.use_save = false
	level.layout = load(YardLevel.LAYOUT)
	_world.add_child(level)
	return level


func test_vehicle_and_machine_data_has_no_face_and_the_rest_keep_theirs() -> void:
	var all := _all_objects()
	for id in VEHICLES_AND_MACHINES:
		assert_bool(all.has(id)).override_failure_message("%s is missing from data/objects" % id).is_true()
		assert_bool((all[id] as ObjectData).has_face).override_failure_message("%s has a face" % id).is_false()
	var faced := 0
	for id in all:
		if not VEHICLES_AND_MACHINES.has(id):
			assert_bool((all[id] as ObjectData).has_face).override_failure_message("%s lost its face" % id).is_true()
			faced += 1
	assert_int(faced).is_greater_equal(39)
	for id in KEEP_FACES:
		assert_bool((all[id] as ObjectData).has_face).override_failure_message("%s lost its face" % id).is_true()


func test_the_built_yard_has_no_face_on_any_vehicle_or_machine() -> void:
	var level := _yard()
	await get_tree().physics_frame
	var faces: Array = []
	_faces_under(level, faces)
	assert_int(faces.size()).is_greater(0)
	# Every face in the yard belongs to an object whose data wants one. None on a vehicle, a machine,
	# the crane hook, the conveyor, the fan, the belt button or the yard dressing.
	for f in faces:
		var o := _owner_object(f)
		assert_object(o).override_failure_message("a face outside any yard object: %s" % f.get_path()).is_not_null()
		assert_bool(VEHICLES_AND_MACHINES.has(o.data.id)).override_failure_message("%s has a face" % o.data.id).is_false()
		assert_bool(o.data.has_face).is_true()
	var vehicles_seen := {}
	var faced := 0
	for key in level.objects:
		var o: PhysicsObject = level.objects[key]
		if VEHICLES_AND_MACHINES.has(o.data.id):
			vehicles_seen[o.data.id] = true
			assert_object(o.face).override_failure_message("%s has a face" % o.data.id).is_null()
			var under: Array = []
			_faces_under(o, under)
			assert_int(under.size()).override_failure_message("%s has a face node" % o.data.id).is_equal(0)
		elif o.data.has_face:
			assert_object(o.face).override_failure_message("%s lost its face" % o.data.id).is_not_null()
			faced += 1
	# The rest of the yard's faces are unchanged: one per faced object, and the vehicles are all placed.
	assert_int(vehicles_seen.size()).override_failure_message("vehicles placed: " + str(vehicles_seen.keys())).is_equal(VEHICLES_AND_MACHINES.size())
	assert_int(faced).is_greater(0)
	var c: Contraptions = level.contraptions
	assert_object(c).is_not_null()
	var machine_faces: Array = []
	_faces_under(c, machine_faces)
	assert_int(machine_faces.size()).override_failure_message("a contraption has a face").is_equal(0)
	assert_object(c.hook.face).is_null()


func test_pictograms_draw_no_face_on_vehicles_and_machines() -> void:
	# Pictos (live goal cards, fence card, trophy shelf) and CardArt's fallback draw from the same flag.
	var all := _all_objects()
	for id in all:
		assert_bool(Pictos.draws_face(id)).override_failure_message("Pictos %s face" % id) \
				.is_equal((all[id] as ObjectData).has_face)
	for id in VEHICLES_AND_MACHINES:
		assert_bool(Pictos.draws_face(id)).override_failure_message("Pictos draws a face on %s" % id).is_false()
	for id in KEEP_FACES:
		assert_bool(Pictos.draws_face(id)).override_failure_message("Pictos lost the %s face" % id).is_true()
	assert_bool(Pictos.draws_face(&"any")).is_true()   # the "anything" stand-in is a prop with a face


func test_the_pictos_car_still_draws_without_errors() -> void:
	# Headless has no renderer, so the look is checked in frames (handoff/shots/); this only proves the
	# car's own silhouette path (body, cab, windows, headlight, wheels) runs clean at card sizes.
	var ci := Control.new()
	add_child(ci)
	ci.draw.connect(func() -> void:
		Pictos.object(ci, &"car", Vector2(100, 100), 40.0)
		Pictos.object(ci, &"tractor", Vector2(200, 100), 40.0, 0.5))
	ci.queue_redraw()
	await get_tree().process_frame
	ci.free()
