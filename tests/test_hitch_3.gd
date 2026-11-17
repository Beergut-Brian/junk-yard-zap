## S-18 steady 1%-low (jyz-hitch-3). On the 2026-11-17 GTX 1060 bench of v0.1.7-dev.3 the warm high runs
## averaged 66-69 fps with a 1%-low of 39-43. A per-frame RenderingServer probe on the bench route (renderer
## on) put the extra work in the "yard wide" third: every object in view at once, 2092 objects and 1055
## draw calls in the colour pass (follow: 516 / 257) plus ~600 in the shadow pass, with render-thread CPU
## doubling. Each yard object was 10-50 separate ArtKit parts. ObjectArt.merge_static now bakes an object's
## still parts into one mesh per material at build time. These pin it: the same triangles in the same
## places with the same material and shadow setting, the parts code moves or finds stay parts, the effect
## look wraps the same box, and the yard's draw count stays under a ceiling.
class_name TestHitch3
extends GdUnitTestSuite

const OBJECTS := "res://data/objects/"
## Drawn instances in the whole yard (objects, dressing, contraptions; outline passes count twice).
## jyz-hitch-3 measured it before and after (see the test); the ceiling leaves a little room for new art.
const YARD_DRAW_CEILING := 1600

var world: Node3D


func before_test() -> void:
	Game.demo = false
	ObjectArt.merge_parts = true
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	ObjectArt.merge_parts = true
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()


func _datas() -> Array[ObjectData]:
	var out: Array[ObjectData] = []
	for f in DirAccess.get_files_at(OBJECTS):
		var path := OBJECTS + f.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var d := load(path) as ObjectData
		if d and d.mesh == null and ObjectArt.has_art(d.id):
			out.append(d)
	return out


func _build(d: ObjectData, merge: bool) -> Node3D:
	ObjectArt.merge_parts = merge
	var holder := Node3D.new()
	world.add_child(holder)
	ObjectArt.build(d, holder)
	ObjectArt.merge_parts = true
	return holder


## Per material + shadow setting: triangle count, the sum of every triangle corner and of every normal
## (in the holder's space), and how many draws (instances, outline passes counted).
func _geometry(holder: Node3D) -> Dictionary:
	var out := {}
	var inv := holder.global_transform.affine_inverse()
	for n in holder.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null or mi.material_override == null:
			continue
		var t: Transform3D = inv * mi.global_transform
		var nb := t.basis.inverse().transposed()
		var key := "%d|%d" % [mi.material_override.get_instance_id(), mi.cast_shadow]
		var g: Dictionary = out.get(key, {"tris": 0, "pos": Vector3.ZERO, "nrm": Vector3.ZERO})
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nn = a[Mesh.ARRAY_NORMAL]
			var ii = a[Mesh.ARRAY_INDEX]
			var corners: Array = range(v.size()) if ii == null or (ii as PackedInt32Array).is_empty() else Array(ii)
			g.tris += corners.size() / 3
			for k in corners:
				g.pos += t * v[k]
				g.nrm += (nb * nn[k]).normalized()
		out[key] = g
	return out


func _draws(root: Node) -> int:
	var n := 0
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		n += 1
		if gi.material_override and gi.material_override.next_pass:
			n += 1
	return n


func test_every_object_keeps_its_triangles_where_they_were() -> void:
	var before := 0
	var after := 0
	for d in _datas():
		var off := _build(d, false)
		var on := _build(d, true)
		var a := _geometry(off)
		var b := _geometry(on)
		assert_array(b.keys()).override_failure_message("%s: materials changed" % d.id).contains_exactly_in_any_order(a.keys())
		for k in a:
			var ga: Dictionary = a[k]
			var gb: Dictionary = b.get(k, {"tris": -1, "pos": Vector3.INF, "nrm": Vector3.INF})
			assert_int(gb.tris).override_failure_message("%s: triangles in %s" % [d.id, k]).is_equal(ga.tris)
			var tol := 0.0005 * maxf(1.0, ga.tris)
			assert_bool((gb.pos - ga.pos).length() < tol).override_failure_message(
					"%s: positions moved in %s (%s vs %s)" % [d.id, k, gb.pos, ga.pos]).is_true()
			assert_bool((gb.nrm - ga.nrm).length() < tol).override_failure_message(
					"%s: normals changed in %s (%s vs %s)" % [d.id, k, gb.nrm, ga.nrm]).is_true()
		before += _draws(off)
		after += _draws(on)
		off.free()
		on.free()
	print("hitch-3: object draws as parts %d, merged %d" % [before, after])
	assert_int(after).override_failure_message("merging saved too little: %d -> %d" % [before, after]) \
			.is_less(before * 7 / 10)


func test_parts_that_move_or_are_found_by_name_stay_parts() -> void:
	for d in _datas():
		var off := _build(d, false)
		var on := _build(d, true)
		# Gag pivots (Y-19) keep every moving part.
		var ga := ObjectArt.gags_in(off)
		var gb := ObjectArt.gags_in(on)
		assert_int(gb.size()).is_equal(ga.size())
		for i in ga.size():
			assert_int(gb[i].find_children("*", "MeshInstance3D", true, false).size()) \
					.override_failure_message("%s: a gag lost a part" % d.id) \
					.is_equal(ga[i].find_children("*", "MeshInstance3D", true, false).size())
		# Named parts (a balloon's Body and Knot) and instanced models (the cow) are untouched.
		for n in off.find_children("*", "Node3D", true, false):
			if not String(n.name).begins_with("@") and n.name != &"Merged":
				assert_object(on.find_child(n.name, true, false)) \
						.override_failure_message("%s: %s went missing" % [d.id, n.name]).is_not_null()
		off.free()
		on.free()


func test_outlined_parts_with_a_scale_are_not_baked() -> void:
	# The outline grows along the mesh's own normals before the part's scale applies: baking a scaled
	# outlined part would change its ink line's width, so those stay parts.
	var root := Node3D.new()
	world.add_child(root)
	var col := Color(0.3, 0.6, 0.9)
	ObjectArt.part(root, ArtKit.sphere(1.0), col, Vector3(0, 0, 0), Vector3.ZERO, Vector3.ONE * 0.2)
	ObjectArt.part(root, ArtKit.sphere(1.0), col, Vector3(1, 0, 0), Vector3.ZERO, Vector3.ONE * 0.3)
	ObjectArt.part(root, ArtKit.rbox(Vector3.ONE, 0.1), col, Vector3(2, 0, 0))
	ObjectArt.part(root, ArtKit.rbox(Vector3.ONE, 0.1), col, Vector3(3, 0, 0), Vector3(0, 30, 0))
	ObjectArt.detail(root, ArtKit.sphere(1.0), col, Vector3(4, 0, 0), Vector3.ZERO, Vector3.ONE * 0.1)
	ObjectArt.detail(root, ArtKit.sphere(1.0), col, Vector3(5, 0, 0), Vector3.ZERO, Vector3(0.1, 0.2, 0.1))
	assert_int(ObjectArt.merge_static(root)).is_equal(2)   # 2 unscaled outlined -> 1, 2 details -> 1
	var scaled := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if not n.basis.is_equal_approx(Basis.IDENTITY) and (n as MeshInstance3D).material_override.next_pass:
			scaled += 1
	assert_int(scaled).is_equal(2)


func test_the_effect_look_wraps_the_same_box() -> void:
	for d in _datas():
		ObjectArt.merge_parts = false
		var a := PhysicsObject.new(d)
		world.add_child(a)
		ObjectArt.merge_parts = true
		var b := PhysicsObject.new(d)
		world.add_child(b)
		assert_bool(a.look.size.is_equal_approx(b.look.size) and a.look.position.is_equal_approx(b.look.position)) \
				.override_failure_message("%s: look %s @ %s became %s @ %s" % [d.id, a.look.size, a.look.position,
				b.look.size, b.look.position]).is_true()
		a.free()
		b.free()


func test_the_yard_stays_under_its_draw_ceiling() -> void:
	ObjectArt.merge_parts = false
	var l1 := _level()
	var before := _draws(l1)
	l1.free()
	Yard.reset_world()
	ObjectArt.merge_parts = true
	var l2 := _level()
	var after := _draws(l2)
	print("hitch-3: yard draws as parts %d, merged %d" % [before, after])
	assert_int(after).override_failure_message("yard draws %d (ceiling %d)" % [after, YARD_DRAW_CEILING]) \
			.is_less_equal(YARD_DRAW_CEILING)
	assert_int(after).is_less(before)


func _level() -> YardLevel:
	var l := YardLevel.new()
	l.use_save = false
	l.layout = load(YardLevel.LAYOUT)
	world.add_child(l)
	var players := Node3D.new()
	players.name = "Players"
	l.add_child(players)
	return l


func test_a_second_build_reuses_the_merged_meshes() -> void:
	# Reset Yard and recalls rebuild objects: they share the first build's meshes, nothing new is baked.
	for d in _datas():
		_build(d, true).free()
	var size := ObjectArt._merged.size()
	for d in _datas():
		_build(d, true).free()
	assert_int(ObjectArt._merged.size()).is_equal(size)
