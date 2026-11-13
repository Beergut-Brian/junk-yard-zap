## Faceless audit lane (jyz-faceless-audit-1): vehicles and machines never get faces or eyes (Kaden,
## standing rule). The vehicle and machine list is not typed here: it is read from the code. A yard
## object is a vehicle or machine when its data says has_face = false, or when its art builds a
## moving part (ObjectArt.gag, Y-19: every vehicle and machine has one, nothing else does). Each one
## is built as the game builds it and checked for a face node (ObjectFace, PatienceFace, any node
## named *face*) and a face texture (a material or image whose name or path holds "face").
## The cow is the control: the same scan must find her face, or the scan is broken.
class_name TestFacelessAudit
extends GdUnitTestSuite

var _world: Node3D


func after_test() -> void:
	if is_instance_valid(_world):
		_world.free()
	Yard.reset_world()


static func _all_objects() -> Array[ObjectData]:
	var out: Array[ObjectData] = []
	for f in DirAccess.get_files_at("res://data/objects/"):
		if f.ends_with(".tres"):
			out.append(load("res://data/objects/" + f) as ObjectData)
	return out


## True when the object's art has a moving part (the code's own mark of a vehicle or machine).
static func _art_has_gag(d: ObjectData) -> bool:
	var root := Node3D.new()
	var built := ObjectArt.build(d, root)
	var has := built and not ObjectArt.gags_in(root).is_empty()
	root.free()
	return has


## The vehicle and machine list, from the data flag and the art's moving parts.
static func _vehicles_and_machines() -> Dictionary:
	var out := {}
	for d in _all_objects():
		if not d.has_face or _art_has_gag(d):
			out[d.id] = d
	return out


static func _facey(s: String) -> bool:
	return s.to_lower().contains("face")


static func _material_is_face(m: Material) -> bool:
	if m == null:
		return false
	if _facey(m.resource_name) or _facey(m.resource_path):
		return true
	if m is BaseMaterial3D:
		var t: Texture2D = (m as BaseMaterial3D).albedo_texture
		if t and (_facey(t.resource_name) or _facey(t.resource_path)):
			return true
	return false


## Every face part under n, as readable strings (empty when there is none).
static func _face_parts(n: Node, out: PackedStringArray) -> void:
	var scr: Script = n.get_script()
	if n is ObjectFace or _facey(String(n.name)) or (scr and _facey(scr.resource_path)):
		out.append("node " + String(n.name))
	if n is GeometryInstance3D and _material_is_face((n as GeometryInstance3D).material_override):
		out.append("material_override on " + String(n.name))
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				if _material_is_face(mi.get_active_material(i)):
					out.append("face material on " + String(n.name))
	for c in n.get_children():
		_face_parts(c, out)


func _built(d: ObjectData) -> PhysicsObject:
	if not is_instance_valid(_world):
		_world = Node3D.new()
		add_child(_world)
	var o := PhysicsObject.new(d)
	o.freeze = true
	_world.add_child(o)
	return o


func test_the_vehicle_and_machine_list_comes_from_the_code_and_agrees_with_itself() -> void:
	var vm := _vehicles_and_machines()
	# The yard has at least the 9 from the vehicle-faces lane; a shrinking list means the read broke.
	assert_int(vm.size()).override_failure_message("vehicles and machines: " + str(vm.keys())).is_greater_equal(9)
	for id in [&"car", &"tractor", &"fridge"]:
		assert_bool(vm.has(id)).override_failure_message("%s missing from the derived list" % id).is_true()
	# A moving part means a machine, and a machine has has_face = false (and the other way round).
	for id in vm:
		var d: ObjectData = vm[id]
		assert_bool(d.has_face).override_failure_message("%s has a moving part but has_face = true" % id).is_false()
		assert_bool(_art_has_gag(d)).override_failure_message("%s is faceless but has no moving part (Y-19)" % id).is_true()
	# The cow and the Jarlings' kind (characters, animals, props with personality) are not on it.
	for id in [&"cow", &"chicken", &"piano", &"kettle"]:
		assert_bool(vm.has(id)).override_failure_message("%s is on the machine list" % id).is_false()


func test_no_vehicle_or_machine_has_a_face_node_or_face_texture() -> void:
	var vm := _vehicles_and_machines()
	for id in vm:
		var o := _built(vm[id])
		await get_tree().process_frame
		var parts := PackedStringArray()
		_face_parts(o, parts)
		assert_array(Array(parts)).override_failure_message("%s has a face: %s" % [id, ", ".join(parts)]).is_empty()
		assert_object(o.face).override_failure_message("%s has o.face" % id).is_null()
		assert_bool(Pictos.draws_face(id)).override_failure_message("%s face in the pictogram" % id).is_false()
		o.free()


func test_the_scan_finds_the_cows_face() -> void:
	var cow := load("res://data/objects/cow.tres") as ObjectData
	var o := _built(cow)
	await get_tree().process_frame
	var parts := PackedStringArray()
	_face_parts(o, parts)
	assert_array(Array(parts)).override_failure_message("the scan missed the cow's face").is_not_empty()
	var chicken := _built(load("res://data/objects/chicken.tres") as ObjectData)
	await get_tree().process_frame
	parts = PackedStringArray()
	_face_parts(chicken, parts)
	assert_array(Array(parts)).override_failure_message("the scan missed the chicken's face").is_not_empty()


func test_the_crane_hook_contraption_has_no_face() -> void:
	_world = Node3D.new()
	add_child(_world)
	var level := YardLevel.new()
	level.use_save = false
	level.layout = load(YardLevel.LAYOUT)
	_world.add_child(level)
	await get_tree().physics_frame
	var hook: Node = level.contraptions.hook
	assert_object(hook).is_not_null()
	var parts := PackedStringArray()
	_face_parts(hook, parts)
	assert_array(Array(parts)).override_failure_message("crane hook has a face: " + ", ".join(parts)).is_empty()
