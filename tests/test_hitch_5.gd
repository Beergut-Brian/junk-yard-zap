## S-18 steady hitches on the render side (jyz-hitch-5). The 2026-11-17 GTX 1060 bench of v0.1.7-dev.5 still
## had 35-41 ms worst frames. A per-frame renderer probe on the bench route (lavapipe, warm cache) found one
## frame with 24-25 ms of render-thread CPU (median 2.3) where an object's grab look first showed, with a
## surface + a specialization pipeline compile in it. A pipeline is per material kind AND per vertex format:
## RenderPrewarm drew every play-made kind on a sphere (positions, normals, UVs, tangents), but the looks'
## rounded-box shells and ObjectArt's merged art (where the tint overlay goes) carry positions and normals
## only. These pin that every play-made kind, and the overlay, is prewarmed on every format play draws it on.
class_name TestHitch5
extends GdUnitTestSuite

const OBJECTS := "res://data/objects/"
## The vertex attributes (what picks the vertex format of a pipeline). Index and flags don't.
const ATTRS := Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT \
		| Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2 \
		| Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1 | Mesh.ARRAY_FORMAT_CUSTOM2 \
		| Mesh.ARRAY_FORMAT_CUSTOM3 | Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS
const LOOKS: Array[StringName] = [&"bouncy", &"balloon", &"freeze", &"magnet", &"splat", &"grab"]

var world: Node3D
var cam: Camera3D


func before_test() -> void:
	Game.demo = false
	world = Node3D.new()
	add_child(world)
	cam = Camera3D.new()
	world.add_child(cam)
	cam.global_position = Vector3(3, 4, 20)


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()


## The vertex attributes surface 0 carries, as Mesh.ARRAY_FORMAT_* bits (any Mesh, primitives included).
static func fmt(m: Mesh) -> int:
	var a := m.surface_get_arrays(0)
	var bits := 0
	for i in Mesh.ARRAY_INDEX:   # every array before the index is a vertex attribute
		if a[i] != null and (a[i] is Array or a[i].size() > 0):
			bits |= 1 << i
	return bits & ATTRS


## {format: {material signature: true}} for every MeshInstance3D the kit draws with a material_override.
func _kit_draws() -> Dictionary:
	var kit := RenderPrewarm.run(world, cam)
	var out := {}
	for c in kit.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override:
			var mi := c as MeshInstance3D
			var f := fmt(mi.mesh)
			if not out.has(f):
				out[f] = {}
			out[f][TestHitch2.sig(mi.material_override)] = true
	return out


func test_every_look_part_is_prewarmed_on_its_own_vertex_format() -> void:
	var draws := _kit_draws()
	var checked := 0
	for kind in LOOKS:
		var l := EffectLook.new()
		l.size = Vector3(1.1, 0.9, 0.8)
		var root := l._build(kind, Color(0.3, 0.8, 0.4))
		assert_object(root).override_failure_message("no look for %s" % kind).is_not_null()
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var f := fmt(m.mesh)
			var s := TestHitch2.sig(m.material_override)
			assert_bool(draws.has(f) and (draws[f] as Dictionary).has(s)) \
					.override_failure_message("%s: %s on format %d not prewarmed (kit formats %s)" % [kind, s, f, draws.keys()]).is_true()
			checked += 1
		root.free()
		l.free()
	assert_int(checked).is_greater(20)


func test_rounded_boxes_and_merged_art_share_the_flat_format() -> void:
	var flat := fmt(RenderPrewarm.flat_mesh())
	assert_int(fmt(ArtKit.rbox(Vector3(0.5, 0.4, 0.3), 0.05, 2))).is_equal(flat)
	assert_int(flat & Mesh.ARRAY_FORMAT_TEX_UV).is_equal(0)
	assert_int(flat).is_not_equal(fmt(ArtKit.sphere(0.3)))   # the two formats really differ
	# A merged object (ObjectArt.merge_static): the crate's baked parts.
	var d := load(OBJECTS + "crate.tres") as ObjectData
	var holder := Node3D.new()
	world.add_child(holder)
	ObjectArt.build(d, holder)
	var merged := 0
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).has_meta(&"parts_aabb"):
			merged += 1
			assert_int(fmt((mi as MeshInstance3D).mesh)).is_equal(flat)
	assert_int(merged).is_greater(0)


func test_the_tint_overlay_is_prewarmed_on_both_formats() -> void:
	var kit := RenderPrewarm.run(world, cam)
	var formats := {}
	for c in kit.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_overlay:
			formats[fmt((c as MeshInstance3D).mesh)] = true
	assert_bool(formats.has(fmt(RenderPrewarm.flat_mesh()))).is_true()
	assert_bool(formats.has(fmt(ArtKit.sphere(0.3)))).is_true()
