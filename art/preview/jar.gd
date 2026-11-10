## Jar check: loads store/jar.glb the way the launcher does (GLTFDocument at runtime) and shows it
## from the front and the side under the yard light. Not game content.
##   godot-render --path . --resolution 1280x720 res://art/preview/jar.tscn -- --out=/abs/x.png
extends Node3D


func _ready() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	YardLight.add(self, 20.0)
	ArtKit.put(self, ArtKit.quad(Vector2(40, 20)), ArtKit.c("room"), Vector3(0, 2, -3)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 2:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		doc.append_from_file(ProjectSettings.globalize_path("res://store/jar.glb"), state)
		var jar := doc.generate_scene(state) as Node3D
		jar.position = Vector3(-1.0 + i * 2.0, 0, 0)
		jar.rotation_degrees.y = [0.0, 90.0][i]
		add_child(jar)
	var cam := Camera3D.new()
	cam.fov = 40
	cam.position = Vector3(0, 1.3, 4.6)
	add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0))
	if out != "":
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out)
		print("frame: ", out)
		get_tree().quit()
