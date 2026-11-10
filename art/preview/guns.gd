## Gun sheet: the seven junk guns big (Jeff's green tape on top, Chuck's red below), and Jeff and
## Chuck holding two of them. Not game content; art/preview/ is excluded from exports.
##   godot-render --path . --resolution 1920x1080 res://art/preview/guns.tscn -- --out=/abs/x.png
extends Node3D


func _ready() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	YardLight.add(self, 40.0)
	ArtKit.put(self, ArtKit.quad(Vector2(80, 40)), ArtKit.c("sky_horizon"), Vector3(0, 5, -4)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ArtKit.put(self, ArtKit.rbox(Vector3(30, 0.4, 6), 0.1), ArtKit.c("ground"), Vector3(0, -0.2, 0))
	for row in 2:
		var tape: Color = Players.COLOR[row]
		for i in GunArt.KINDS.size():
			var g := GunArt.build(GunArt.KINDS[i], tape)
			g.scale = Vector3.ONE * 3.2
			g.rotation_degrees.y = 90
			g.position = Vector3(-9.2 + i * 2.3, 4.2 - row * 1.9, 0)
			add_child(g)
	for p in 2:
		var rig := JarlingRig.new()
		rig.character = [&"jeff", &"chuck"][p]
		rig.position = Vector3(8.0 + p * 2.2, 0, 0.5)
		add_child(rig)
		rig.equip_gun(Players.COLOR[p], [&"size", &"magnet"][p])
		rig.face_dir(1.0 if p == 0 else -1.0)
	var cam := Camera3D.new()
	cam.fov = 34
	cam.position = Vector3(0, 3.2, 17)
	add_child(cam)
	cam.make_current()
	if out != "":
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out)
		print("frame: ", out)
		get_tree().quit()
