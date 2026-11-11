## Generated textures stay out of res://. Godot's glTF importer used to extract every Jarling
## .glb's embedded images next to it (assets/characters/chuck/chuck_chuck_face.png, ...,
## assets/models/patience/cow_cow_face.png) on import, so each import, test run or shot left
## about 45 untracked PNGs and exports saw different files from a clean checkout.
## project.godot's [importer_defaults] now keeps them embedded in the imported scene
## (.godot/imported/, Godot's own cache). Same fix as the-hill PR 23.
## If test_every_glb_imported_with_embedded_images fails on your machine, your *.glb.import files
## predate the fix: delete .godot/ and assets/**/*.glb.import, then re-import.
class_name TestGeneratedTextures
extends GdUnitTestSuite

const CHARACTERS := "res://assets/characters/"
const COW := "res://assets/models/patience/cow.glb"
const EMBED_UNCOMPRESSED := 3  # GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED


func _glbs() -> PackedStringArray:
	var out := PackedStringArray()
	for id in DirAccess.get_directories_at(CHARACTERS):
		var glb := CHARACTERS + id + "/" + id + ".glb"
		if FileAccess.file_exists(glb):
			out.append(glb)
	out.append(COW)
	return out


## Every file under res://assets/characters (and the cow's folder), recursively.
func _listing() -> PackedStringArray:
	var out := PackedStringArray()
	for dir: String in [CHARACTERS.trim_suffix("/"), COW.get_base_dir()]:
		_walk(dir, out)
	out.sort()
	return out


func _walk(dir: String, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_walk(dir + "/" + d, out)


func _textures_of(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var m := mi.get_active_material(s) as BaseMaterial3D
				if m and m.albedo_texture:
					out.append(m.albedo_texture)
	for c in node.get_children():
		_textures_of(c, out)


func test_project_default_embeds_gltf_images() -> void:
	var d: Dictionary = ProjectSettings.get_setting("importer_defaults/scene", {})
	assert_int(int(d.get("gltf/embedded_image_handling", -1))).is_equal(EMBED_UNCOMPRESSED)


func test_every_glb_imported_with_embedded_images() -> void:
	var glbs := _glbs()
	assert_int(glbs.size()).is_greater(1)
	for glb in glbs:
		var cfg := ConfigFile.new()
		if cfg.load(glb + ".import") != OK:
			continue  # not imported yet on this machine; the project default covers it
		assert_int(int(cfg.get_value("params", "gltf/embedded_image_handling", -1))) \
			.override_failure_message("%s.import extracts textures into res:// (stale import: delete it and .godot/, re-import)" % glb) \
			.is_equal(EMBED_UNCOMPRESSED)


func test_no_extracted_textures_beside_glbs() -> void:
	for glb in _glbs():
		var dir := glb.get_base_dir()
		var stem := glb.get_file().get_basename()   # "chuck" -> chuck_chuck_face.png, "cow" -> cow_cow_face.png
		for f in DirAccess.get_files_at(dir):
			assert_bool(f.begins_with(stem + "_") and f.ends_with(".png")) \
				.override_failure_message("generated texture in res://: %s/%s" % [dir, f]) \
				.is_false()


## Loads every character (and the cow), instantiates the yard with two players on it, and
## fails if anything new appeared under res://assets/characters or the cow's folder.
func test_a_run_writes_nothing_into_res_assets_characters() -> void:
	var before := _listing()
	for glb in _glbs():
		var model: Node = (load(glb) as PackedScene).instantiate()
		var texs: Array = []
		_textures_of(model, texs)
		model.free()
		assert_int(texs.size()).override_failure_message("%s has no textures" % glb).is_greater(0)
		for t: Texture2D in texs:
			assert_int(t.get_width()).is_greater(0)
			# Embedded: a sub-resource of the imported scene ("jeff.glb::ImageTexture_..."),
			# not a standalone extracted .png file.
			assert_bool(t.resource_path.ends_with(".png")) \
				.override_failure_message("%s texture is a file in res://: %s" % [glb, t.resource_path]) \
				.is_false()
	var runner := scene_runner("res://scenes/main.tscn")
	await runner.simulate_frames(10)
	var after := _listing()
	var added: Array = []
	for f in after:
		if not before.has(f):
			added.append(f)
	assert_array(added).override_failure_message("a run wrote into res://: %s" % [added]).is_empty()
