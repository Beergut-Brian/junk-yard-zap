## Store art (GAME.md "Store art") rendered from the real yard, with no HUD:
##   grid (600x900): Jeff zapping a cow to giant size while Chuck rides a ballooned bathtub.
##   hero (920x430): the whole yard at golden hour.
## Frames render at 1920x1080 (godot-render's size); art/tools/render_store.sh crops and scales them. Not game content; art/preview/ is excluded from exports.
extends Node3D

var level: YardLevel


func _ready() -> void:
	var shot := "grid"
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.trim_prefix("--shot=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	level = (load("res://scenes/levels/yard.tscn") as PackedScene).instantiate() as YardLevel
	level.use_save = false
	add_child(level)
	var cam := Camera3D.new()
	cam.fov = 34.0
	add_child(cam)
	cam.make_current()
	if shot == "hero":
		_hero(cam)
	else:
		await _grid(cam)
	if out != "":
		for i in 24:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out)
		print("frame: ", out)
		get_tree().quit()


func _rig(who: StringName, p: int, at: Vector3, face: float, gun: StringName, ring_on := true) -> JarlingRig:
	var rig := JarlingRig.new()
	rig.character = who
	rig.position = at
	add_child(rig)
	rig.equip_gun(Players.COLOR[p], gun)
	rig.model.rotation.y = deg_to_rad(65.0 * face)
	if not ring_on:
		return rig
	var ring := ArtKit.put(self, ArtKit.torus(0.62, 0.74), Players.COLOR[p], at + Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1, 0.4, 1), 0.35)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return rig


func _grid(cam: Camera3D) -> void:
	# Barn side: the giant cow mid-grow by the barn, the ballooned bathtub with Chuck in it above.
	var cow := level.object(&"cow")
	var tub := level.object(&"bathtub")
	for k in [&"hay", &"chicken", &"pumpkin", &"pig"]:
		var o := level.object(k)
		if o:
			o.queue_free()
	var plank := level.get_node_or_null("Static/SeesawPlank")
	if plank:
		plank.queue_free()   # out of the cow's way while it grows
	cow.global_transform = Transform3D(Basis.IDENTITY, Vector3(13.4, 1.2, 0))
	tub.global_transform = Transform3D(Basis.IDENTITY, Vector3(11.0, 8.6, 0))
	for i in 4:
		Effects.zap(&"grow", cow)
		for f in 25:
			await get_tree().physics_frame
	Effects.zap(&"balloon", tub)
	for i in 30:   # let the grow finish
		await get_tree().physics_frame
	tub.global_transform = Transform3D(Basis.IDENTITY, Vector3(11.0, 8.6, 0))
	for o in [cow, tub]:
		o.freeze = true
		o.set_physics_process(false)
	var jeff := _rig(&"jeff", Players.P1, Vector3(9.6, 0.0, 1.0), 1.0, &"size")
	jeff.set_expression("determined")
	jeff.play("idle", 0.0)
	var chuck := _rig(&"chuck", Players.P2, Vector3(11.0, 8.3, 0.05), 1.0, &"balloon", false)
	chuck.set_expression("happy")
	if chuck.anim and chuck.anim.has_animation("cheer"):
		chuck.play("cheer")
	await get_tree().process_frame
	if cow.face:
		cow.face.react(ObjectFace.Mood.WIDE, 100.0)
	if tub.face:
		tub.face.react(ObjectFace.Mood.HAPPY, 100.0)
	_beam(jeff.gun_tip_position(), cow.global_position + Vector3(-cow.size_now().x * 0.45, 0.0, 0.3), ArtKit.gun(&"size"))
	cam.position = Vector3(13.0, 6.6, 20.6)
	cam.look_at(Vector3(13.0, 5.6, 0))
	cam.fov = 40.0


func _hero(cam: Camera3D) -> void:
	# The whole yard, front gate (x -48) to the junk tower (x 48), at golden hour (V-11).
	_rig(&"jeff", Players.P1, Vector3(-6.4, 0.45, 0.3), 1.0, &"size")
	_rig(&"chuck", Players.P2, Vector3(11.0, 0.0, 0.4), -1.0, &"bouncy")
	Effects.zap(&"balloon", level.object(&"cow"))
	Effects.zap(&"bouncy", level.object(&"tire"))
	_golden_hour()
	cam.position = Vector3(0.0, 12.0, 106.0)
	cam.look_at(Vector3(0.0, 9.4, 0))
	cam.fov = 30.0


## Store shot only: re-grade this instance's own light, environment and sky card (all built fresh per
## level by YardDressing/YardLight) to a low warm sun. The playable yard's lighting is untouched.
func _golden_hour() -> void:
	var sun := level.find_child("KeyLight", true, false) as DirectionalLight3D
	if sun:
		sun.rotation_degrees = Vector3(-17.0, 32.0, 0)
		sun.light_color = Color("#ffb46a")
		sun.light_energy = 1.75
		sun.directional_shadow_max_distance = 240.0
	var we := level.find_child("Environment", true, false) as WorldEnvironment
	if we:
		var env := we.environment
		env.background_color = Color("#ffc58a")
		env.ambient_light_color = Color("#c7a9c4")
		env.ambient_light_energy = 0.5
		env.adjustment_saturation = 1.15
	var sky := level.find_child("Sky", true, false) as MeshInstance3D
	if sky and sky.material_override is ShaderMaterial:
		var sm := sky.material_override as ShaderMaterial
		sm.set_shader_parameter("top", Color("#6488c4"))
		sm.set_shader_parameter("horizon", Color("#ffb877"))
		sm.set_shader_parameter("cloud", Color("#ffd9b8"))
		sm.set_shader_parameter("sun", Color("#ffd889"))
		sm.set_shader_parameter("sun_at", Vector2(0.63, 0.34))


## The grow gun's beam: a glowing core with rings along it and sparkles at the end.
func _beam(from: Vector3, to: Vector3, col: Color) -> void:
	var d := to - from
	var core := ArtKit.put_mat(self, ArtKit.cyl(0.07, d.length(), -1.0, 12), ArtKit.glow(col.lerp(Color.WHITE, 0.35), 1.4), from + d * 0.5)
	core.basis = ArtKit.basis_y(d.normalized())
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 4:
		var ring := ArtKit.put_mat(self, ArtKit.torus(0.14 + k * 0.04, 0.2 + k * 0.04, 24), ArtKit.glow(col, 1.2), from + d * (0.2 + k * 0.2))
		ring.basis = ArtKit.basis_y(d.normalized())
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 8:
		var a := TAU * k / 8.0
		var s := ArtKit.put_mat(self, ArtKit.sphere(0.08, 8), ArtKit.glow(col.lerp(Color.WHITE, 0.5), 1.6), to + Vector3(cos(a), sin(a), 0.3) * 0.55)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
