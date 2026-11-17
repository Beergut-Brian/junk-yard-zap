## S-18 cold-start stalls (jyz-hitch-2). On the 2026-11-17 GTX 1060 bench the first run of a fresh build
## stalled 2-4 s in single frames, and warm runs still had 45-57 ms frames. A per-frame probe (renderer
## on, cold then warm cache) put the stalls on the first frame each kind of play-made material was drawn:
## the first burst particles (a multimesh), the first ring, glue, tint overlay, puff: their shader and
## pipelines compiled in that frame ("draw" pipeline compilations). RenderPrewarm draws one of each, as a
## mesh and as particles, behind the lobby at boot and keeps the materials for the session. These pin it:
## it runs at boot, it covers every play-made material's flags, it is drawn (in view), it leaves.
class_name TestHitch2
extends GdUnitTestSuite

var world: Node3D
var cam: Camera3D


func before_test() -> void:
	world = Node3D.new()
	add_child(world)
	cam = Camera3D.new()
	world.add_child(cam)
	cam.global_position = Vector3(3, 4, 20)
	cam.look_at(Vector3(3, 2, 0))


func after_test() -> void:
	if is_instance_valid(world):
		world.free()


## The flags that pick a StandardMaterial3D's shader and its pipelines (colour doesn't).
static func sig(m: Material) -> String:
	var s := m as StandardMaterial3D
	if s == null:
		return m.get_class()
	return "%d|%d|%d|%s|%s|%d|%d|%s|%s|%s" % [s.shading_mode, s.transparency, s.blend_mode, s.no_depth_test,
			s.emission_enabled, s.billboard_mode, s.cull_mode, s.albedo_texture != null, s.rim_enabled,
			s.metallic_specular]


## What play itself builds during a session, from the code that builds it.
func _play_made() -> Array[Material]:
	var out: Array[Material] = []
	out.append(Fx.burst_mesh(0.06, Color(1, 0.8, 0.2)).material)            # sparkles
	out.append(Fx.burst_mesh(0.06, Color(0.75, 0.65, 0.5, 0.8)).material)   # landing dust
	out.append(GunHits._mat(Color.RED))
	out.append(GunHits._mat(Color(1, 1, 1, 0.9)))
	out.append(Fx.ring_mat(Color.GREEN))
	out.append(Effects.Glue.glow_mat(Color.YELLOW, 0.6))
	out.append(Effects.Glue.glow_mat(Color.YELLOW, 0.8))
	out.append(Refusal.strand_mat(Color.WHITE))
	out.append(Refusal.flat_mat(Color.WHITE, 2))
	out.append(PhysicsObject.overlay_mat())
	out.append(LooseBalloon.puff_mat())
	# EffectLook's kinds (scripts/physics/effect_look.gd _build)
	out.append(ArtKit.mat(Color.ORANGE, ArtKit.EMIT, 0.3))
	out.append(ArtKit.mat(Color.ORANGE, ArtKit.EMIT, 0.15))
	out.append(ArtKit.mat(ArtKit.c("ink")))
	out.append(ArtKit.mat(Color(0.88, 0.9, 0.94), 0.0, 0.2))
	out.append(ArtKit.glow(Color(1, 1, 1), 1.0))
	out.append(ArtKit.glow(Color(Color.CYAN, 0.22), 1.3))
	out.append(ArtKit.glow(Color.CYAN, 1.4))
	out.append(ArtKit.glass(Color(0.7, 0.9, 1.0, 0.42), 0.15))   # freeze ice and frost
	out.append(ArtKit.glass(Color(0.92, 0.98, 1.0, 0.85), 0.25))
	return out


func test_prewarm_covers_every_material_play_makes() -> void:
	var warmed := {}
	for m in RenderPrewarm.materials():
		warmed[sig(m)] = true
	for m in _play_made():
		assert_bool(warmed.has(sig(m))).override_failure_message("not prewarmed: %s" % sig(m)).is_true()


func test_each_kind_is_drawn_as_a_mesh_and_as_particles_in_view() -> void:
	var kit := RenderPrewarm.run(world, cam)
	var n := RenderPrewarm.materials().size()
	var meshes := 0
	var parts := 0
	for c in kit.get_children():
		assert_bool(cam.is_position_in_frustum((c as Node3D).global_position)).is_true()
		if c is CPUParticles3D:
			parts += 1
			assert_bool((c as CPUParticles3D).emitting).is_true()
			assert_object((c as CPUParticles3D).mesh.surface_get_material(0)).is_not_null()
		elif c is MeshInstance3D:
			meshes += 1
			var mi := c as MeshInstance3D
			assert_bool(mi.material_override != null or mi.material_overlay != null).is_true()
			assert_float(mi.get_aabb().size.length()).is_less(0.01)   # 1 mm: nothing shows
	assert_int(parts).is_equal(n)
	assert_int(meshes).is_equal(2 * n + 2)   # each kind on both vertex formats (jyz-hitch-5), + the tint overlay on both


func test_kit_leaves_after_a_few_frames_and_the_materials_stay() -> void:
	var kit := RenderPrewarm.run(world, cam)
	for i in RenderPrewarm.FRAMES + 2:
		await get_tree().process_frame
	assert_bool(is_instance_valid(kit)).is_false()
	assert_int(RenderPrewarm.keep.size()).is_equal(RenderPrewarm.materials().size() + 1)
	RenderPrewarm.run(world, cam)   # a second boot replaces the set, it doesn't grow it
	assert_int(RenderPrewarm.keep.size()).is_equal(RenderPrewarm.materials().size() + 1)


func test_boot_scene_prewarms_before_play() -> void:
	var before := RenderPrewarm.runs
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	assert_int(RenderPrewarm.runs).is_equal(before + 1)
	assert_object(main.get_node_or_null("RenderPrewarm")).is_not_null()
	main.free()
