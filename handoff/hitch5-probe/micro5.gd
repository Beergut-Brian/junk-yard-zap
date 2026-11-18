extends Node3D
## jyz-hitch-5 micro: render CPU of the frame a kind of thing is first drawn.
var f := 0
var vp: RID
var plan := []   # [frame, label, callable]
var res := {}
var pending := ""
var n_new := 0
var out := PackedStringArray()
var _gun: Node3D
var _grp: Node3D
var win := {}

func _ready() -> void:
	YardLight.add(self)
	var cam := Camera3D.new(); cam.position = Vector3(0, 2, 8); add_child(cam); cam.make_current()
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); floor.mesh = pm; add_child(floor)
	vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	RenderPrewarm.run(self, cam)
	var kinds := ["gun_swap", "free_group17", "look_freeze_new_size", "look_grab_new_size", "bursts", "nothing"]
	var fr := 40
	for rep in 5:
		for k in kinds:
			plan.append([fr, k]); fr += 10
	set_meta("end", fr + 6)

func _add(k: String) -> void:
	var root := Node3D.new(); add_child(root); root.position = Vector3(randf_range(-2, 2), 1, 0)
	n_new += 1
	var s := 0.3 + n_new * 0.013
	match k:
		"new_prim_glass":
			for i in 9: _mi(root, ArtKit.cyl(s * 0.2 + i * 0.001, s, 0.0, 6), ArtKit.glass(Color(0.92, 0.98, 1.0, 0.85), 0.25))
		"same_prim_glass":
			for i in 9: _mi(root, ArtKit.cyl(0.1, 0.5, 0.0, 6), ArtKit.glass(Color(0.92, 0.98, 1.0, 0.85), 0.25))
		"new_prim_opaque":
			for i in 9: _mi(root, ArtKit.cyl(s * 0.2 + i * 0.001, s, 0.0, 6), ArtKit.mat(Color(0.5, 0.6, 0.7)))
		"new_material_same_flags":
			for i in 9: _mi(root, ArtKit.cyl(0.1, 0.5, 0.0, 6), ArtKit.mat(Color(randf(), randf(), randf()), ArtKit.EMIT, 0.3))
		"look_freeze_new_size", "look_freeze_same_size":
			var l := EffectLook.new()
			l.size = Vector3(1.0 + (n_new * 0.01 if k == "look_freeze_new_size" else 0.0), 0.8, 0.9)
			root.add_child(l)
			var e := Effect.new(); e.id = &"freeze"; e.color = Color(0.6, 0.85, 1.0)
			var arr: Array[Effect] = [e]
			l.sync(arr)
		"gun_swap":
			var kk: Array = GunArt.KINDS if GunArt.KINDS is Array else Array(GunArt.KINDS)
			var g: Node3D = GunArt.packed(kk[n_new % kk.size()], Color(0.2, 0.8, 0.3)).instantiate()
			root.add_child(g)
			if _gun and is_instance_valid(_gun): _gun.queue_free()
			_gun = g
			return
		"free_group17":
			if _grp and is_instance_valid(_grp): _grp.queue_free()
			_grp = Node3D.new(); add_child(_grp)
			for i in 17: _mi(_grp, ArtKit.cyl(0.1, 0.5, 0.0, 6), ArtKit.mat(Color(0.5, 0.6, 0.7)))
			return
		"look_grab_new_size":
			var l := EffectLook.new()
			l.size = Vector3(1.0 + n_new * 0.01, 0.8, 0.9)
			root.add_child(l)
			var e := Effect.new(); e.id = &"grab"; e.color = Color(0.3, 0.9, 0.3)
			var arr: Array[Effect] = [e]
			l.sync(arr)
		"bursts":
			for i in 3: Fx.burst(get_tree(), root.position, Color(0.9, 0.4, 0.2))
		"nothing":
			pass
	get_tree().create_timer(0.15).timeout.connect(root.queue_free)

func _mi(p: Node3D, m: Mesh, mat: Material) -> void:
	var mi := MeshInstance3D.new(); mi.mesh = m; mi.material_override = mat; mi.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)); p.add_child(mi)

func _process(_d: float) -> void:
	f += 1
	var t := RenderingServer.viewport_get_measured_render_time_cpu(vp)
	for k in win.keys():
		win[k][1] = maxf(win[k][1], t); win[k][0] -= 1
		if win[k][0] <= 0:
			res[k.split("@")[0]] = res.get(k.split("@")[0], []) + [win[k][1]]
			var pc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE) + RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW) + RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)
			print("EV %s max=%.2f pc_total=%d" % [k, win[k][1], pc]); win.erase(k)
	for p in plan:
		if p[0] == f:
			_add(p[1]); win["%s@%d" % [p[1], f]] = [5, 0.0]

	if f >= int(get_meta("end")):
		for k in res:
			var v: Array = res[k].duplicate(); v.sort()
			print("MICRO %-26s n=%d median=%.2f max=%.2f all=%s" % [k, v.size(), v[v.size() / 2], v[-1], str(v.map(func(x): return snappedf(x, 0.01)))])
		get_tree().quit()
