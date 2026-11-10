## The Golden Afternoon art (D44): every object type has art that sits on its collision floor and a
## face, the yard dressing is looks only, every gun is wearable gear with a muzzle, and the gun hues
## stay clear of the players' green and red.
class_name TestArt
extends GdUnitTestSuite

const OBJECTS := "res://data/objects/"

var world: Node3D


func before_test() -> void:
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()


func _datas() -> Array[ObjectData]:
	var out: Array[ObjectData] = []
	for f in DirAccess.get_files_at(OBJECTS):
		var f2 := f.trim_suffix(".remap")
		if f2.ends_with(".tres"):
			out.append(load(OBJECTS + f2) as ObjectData)
	return out


func test_about_forty_object_types_all_with_art_and_faces() -> void:
	var datas := _datas()
	assert_int(datas.size()).is_greater_equal(40)
	for d in datas:
		assert_bool(ObjectArt.has_art(d.id)).override_failure_message("no art for %s" % d.id).is_true()
		var o := PhysicsObject.new(d)
		o.position = Vector3(0, 5, 0)
		world.add_child(o)
		assert_object(o.face).override_failure_message("no face on %s" % d.id).is_not_null()
		var art := o.get_node("Visual/Art") as Node3D
		assert_object(art).is_not_null()
		var floor_y := -d.size.y * 0.5 if d.shape != ObjectData.Shape.SPHERE else -d.size.x * 0.5
		var low := _lowest(art, o.get_node("Visual"))
		# Sits on its collision floor: not floating, not sunk (a little give for rounded feet). The
		# kite's tail of bows and the balloon's string drape below them on purpose.
		if d.id not in [&"kite", &"balloon"]:
			assert_float(low).override_failure_message("%s art bottom %.2f vs floor %.2f" % [d.id, low, floor_y]) \
					.is_between(floor_y - 0.1, floor_y + 0.1)
		o.free()


## Lowest vertex of the art, in the object's visual space.
func _lowest(art: Node3D, space: Node3D) -> float:
	var low := INF
	for mi: MeshInstance3D in art.find_children("*", "MeshInstance3D", true, false):
		var xf := space.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				low = minf(low, (xf * v).y)
	return low


func test_layout_uses_every_object_type() -> void:
	var layout := load("res://data/yard_layout.tres") as YardLayout
	var used := {}
	for e in layout.entries:
		used[e.object.id] = true
	for d in _datas():
		assert_bool(used.has(d.id)).override_failure_message("%s is not in the yard" % d.id).is_true()


func test_dressing_is_looks_only() -> void:
	var level := YardLevel.new()
	level.use_save = false
	world.add_child(level)
	var dressing := level.get_node("Dressing")
	assert_object(dressing).is_not_null()
	assert_int(dressing.find_children("*", "CollisionObject3D", true, false).size()).is_equal(0)
	# The grey-box collision is all still there.
	for n in ["Static/GroundL", "Static/GroundR", "Static/Mound", "Static/Dock", "Static/Loft", "Static/PipeFloor", "Static/SeesawPlank"]:
		assert_object(level.get_node_or_null(n)).override_failure_message(n).is_not_null()
	assert_int(level.reset_sign.get_child_count()).is_greater(0)
	assert_int(level.tire_pile.get_child_count()).is_greater(0)


func test_every_gun_is_gear_with_a_muzzle_and_player_tape() -> void:
	for k in GunArt.KINDS:
		var g := GunArt.packed(k, Players.COLOR[Players.P1]).instantiate() as Node3D
		assert_object(g.find_child("tip", true, false)).override_failure_message(String(k)).is_not_null()
		var tape := g.find_child("tape", true, false) as MeshInstance3D
		assert_object(tape).is_not_null()
		assert_that((tape.material_override as StandardMaterial3D).albedo_color).is_equal(Players.COLOR[Players.P1])
		g.free()


func test_gun_hues_stay_clear_of_the_players() -> void:
	for k in ArtKit.GUN:
		var c: Color = ArtKit.GUN[k]
		for p in [Players.P1, Players.P2]:
			var pc: Color = Players.COLOR[p]
			var dh := absf(c.h - pc.h)
			dh = minf(dh, 1.0 - dh)
			assert_float(dh * 360.0).override_failure_message("%s too close to player %d" % [k, p]).is_greater(25.0)
	for g in Zapper.load_guns():
		var want := ArtKit.gun(g.effect_id())
		assert_float(Vector3(want.r - g.beam_color.r, want.g - g.beam_color.g, want.b - g.beam_color.b).length()) \
				.override_failure_message(String(g.id)).is_less(0.02)
