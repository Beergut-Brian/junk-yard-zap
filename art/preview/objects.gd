## Object gallery: every data/objects/*.tres as a real PhysicsObject (frozen, no gravity) in a grid under
## the Golden Afternoon light, so the Art lane can look at meshes and faces without playing.
##   godot-render --path . --resolution 1920x1080 res://art/preview/objects.tscn -- --out=/abs/x.png
##     [--only=cow,car] [--mood=neutral|happy|wide|dizzy|smug|panic|shut|sad] [--fx=bouncy,balloon,...] [--cols=6]
## Not game content; art/preview/ is excluded from exports.
extends Node3D

const DIR := "res://data/objects/"

var _pins := {}   # object -> where it stays


func _ready() -> void:
	var out := ""
	var only: PackedStringArray = []
	var mood := ""
	var fx: PackedStringArray = []
	var cols := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
		elif a.begins_with("--mood="):
			mood = a.trim_prefix("--mood=")
		elif a.begins_with("--fx="):
			fx = a.trim_prefix("--fx=").split(",")
		elif a.begins_with("--cols="):
			cols = int(a.trim_prefix("--cols="))
	YardLight.add(self, 80.0)
	var datas: Array[ObjectData] = []
	for f in DirAccess.get_files_at(DIR):
		var f2 := f.trim_suffix(".remap")
		if not f2.ends_with(".tres"):
			continue
		var d := load(DIR + f2) as ObjectData
		if d and (only.is_empty() or only.has(String(d.id))):
			datas.append(d)
	datas.sort_custom(func(a, b) -> bool: return String(a.id) < String(b.id))
	if cols <= 0:
		cols = clampi(ceili(sqrt(datas.size() * 1.8)), 1, 8)
	var rows := ceili(float(datas.size()) / cols)
	var cell := Vector2(3.6, 3.0)
	var floor_mi := ArtKit.put(self, ArtKit.rbox(Vector3(cols * cell.x + 4, 0.4, 6), 0.1), ArtKit.c("ground"), Vector3(0, -0.2, -1))
	floor_mi.name = "Floor"
	var back := ArtKit.put(self, ArtKit.quad(Vector2(cols * cell.x + 40, rows * cell.y + 30)), ArtKit.c("sky_horizon"), Vector3(0, 5, -6))
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in datas.size():
		var d := datas[i]
		var row := i / cols
		var col := i % cols
		var shelf_y := (rows - 1 - row) * cell.y
		var x := (col - (cols - 1) * 0.5) * cell.x
		var o := PhysicsObject.new(d)
		o.position = Vector3(x, shelf_y + d.size.y * 0.5 + 0.05, 0)
		add_child(o)
		_pins[o] = o.position
		if mood != "" and o.face:
			o.face.set_base(ObjectFace.Mood.get(mood.to_upper(), 0))
		for k in fx:
			Effects.zap(StringName(k), o)
		var lbl := Label3D.new()
		lbl.text = String(d.id)
		lbl.font_size = 40
		lbl.outline_size = 8
		lbl.position = Vector3(x, shelf_y - 0.25, 1.2)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(lbl)
	var cam := Camera3D.new()
	cam.fov = 34.0
	var w := cols * cell.x
	var h := rows * cell.y
	var dist := maxf(w * 0.5 / (tan(deg_to_rad(17)) * 16.0 / 9.0), h * 0.5 / tan(deg_to_rad(17))) + 3.0
	cam.position = Vector3(0, h * 0.5 + dist * 0.09, dist)
	cam.rotation_degrees.x = -5.0
	add_child(cam)
	cam.make_current()
	if out != "":
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out)
		print("frame: ", out)
		get_tree().quit()


func _physics_process(_delta: float) -> void:
	for o in _pins:
		o.position = _pins[o]
		o.rotation = Vector3.ZERO
		o.linear_velocity = Vector3.ZERO
		o.angular_velocity = Vector3.ZERO
