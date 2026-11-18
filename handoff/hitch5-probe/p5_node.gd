extends Node
## jyz-hitch-5 render-side probe: one CSV row per frame.
var f := 0
var start := 30
var leg := 60
var out: FileAccess
var vp_rid: RID
var cam: Node
var last_mats := {}   # instance_id -> [mat_override_id, mesh_id, visible]
var added := 0
var names := PackedStringArray()
var rnames := PackedStringArray()
var stop := 100000
var log2: FileAccess
var removed := 0
var steps := 0
var last_usec := 0
var last_info := {}
const INFO := {"pc_canvas": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS,
	"pc_mesh": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH,
	"pc_surf": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,
	"pc_draw": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW,
	"pc_spec": RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION,
	"tex_mem": RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED,
	"buf_mem": RenderingServer.RENDERING_INFO_BUFFER_MEM_USED}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--probe-start="): start = int(a.split("=")[1])
		if a.begins_with("--probe-leg="): leg = int(a.split("=")[1])
		if a.begins_with("--probe-stop="): stop = int(a.split("=")[1])
		if a.begins_with("--probe-out="): out = FileAccess.open(a.split("=")[1], FileAccess.WRITE)
	process_priority = 100000
	process_physics_priority = -100000
	vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is VisualInstance3D:
			added += 1
			if names.size() < 40:
				var m := ""
				if n is MeshInstance3D and (n as MeshInstance3D).mesh:
					var mm := (n as MeshInstance3D).mesh
					m = "%s#%d" % [mm.get_class(), mm.get_instance_id() % 100000]
				names.append("%s:%s/%s[%s]" % [n.get_class(), n.get_parent().name if n.get_parent() else "", n.name, m]))
	get_tree().node_removed.connect(func(n: Node) -> void:
		if n is VisualInstance3D:
			removed += 1
			if rnames.size() < 40:
				var mat := ""
				if n is GeometryInstance3D and (n as GeometryInstance3D).material_override:
					var mo := (n as GeometryInstance3D).material_override
					mat = "%s#%d" % [mo.resource_name if mo.resource_name != "" else mo.get_class(), mo.get_instance_id() % 100000]
				rnames.append("%s:%s/%s{%s}" % [n.get_class(), n.get_parent().name if n.get_parent() else "", n.name, mat]))
	out.store_line("f,phase,wall_ms,setup_ms,rcpu_ms,rgpu_ms,steps,obj,draws,prims,sobj,sdraws,sprims,pc_canvas,pc_mesh,pc_surf,pc_draw,pc_spec,dtex_kb,dbuf_kb,vi_add,vi_rem,mat_chg,mesh_chg,vis_chg,geo,emit,emit_amt,lights,shadow_lights,fx_nodes")
	_boot.call_deferred()

func _physics_process(_d: float) -> void:
	steps += 1

func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	var wall := (now - last_usec) / 1000.0
	last_usec = now
	f += 1
	var main := get_tree().current_scene
	if cam == null and main and "camera" in main:
		cam = main.get("camera")
	var phase := "warm"
	var k := f - start
	if k >= 0:
		phase = "follow" if (k < leg or k >= 2 * leg) else "wide"
		if cam: cam.set("overview", phase == "wide")
	if k >= 3 * leg:
		out.flush()
		get_tree().quit(0)
		return
	var row := [f, phase, "%.1f" % wall, "%.3f" % RenderingServer.get_frame_setup_time_cpu(),
		"%.3f" % RenderingServer.viewport_get_measured_render_time_cpu(vp_rid),
		"%.3f" % RenderingServer.viewport_get_measured_render_time_gpu(vp_rid), steps]
	steps = 0
	var V := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var S := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW
	for t in [V, S]:
		for w in [RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME]:
			row.append(RenderingServer.viewport_get_render_info(vp_rid, t, w))
	for key in INFO:
		var v := RenderingServer.get_rendering_info(INFO[key])
		var d: int = v - int(last_info.get(key, v))
		last_info[key] = v
		row.append(d / 1024 if key.ends_with("mem") else d)
	row.append(added); row.append(removed); added = 0; removed = 0
	var mc := 0; var mec := 0; var vc := 0; var geo := 0; var emit := 0; var emit_amt := 0; var lights := 0; var sl := 0; var fxn := 0
	var seen := {}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children(): stack.append(c)
		if n is GeometryInstance3D:
			geo += 1
			var g := n as GeometryInstance3D
			var mid := g.material_override.get_instance_id() if g.material_override else 0
			var meid := 0
			if g is MeshInstance3D and (g as MeshInstance3D).mesh: meid = (g as MeshInstance3D).mesh.get_instance_id()
			var vis := g.is_visible_in_tree()
			var id := g.get_instance_id()
			seen[id] = true
			var prev = last_mats.get(id)
			if prev != null:
				if prev[0] != mid: mc += 1
				if prev[1] != meid: mec += 1
				if prev[2] != vis: vc += 1
			last_mats[id] = [mid, meid, vis]
			if g is CPUParticles3D and (g as CPUParticles3D).emitting:
				emit += 1; emit_amt += (g as CPUParticles3D).amount
			if g is GPUParticles3D and (g as GPUParticles3D).emitting:
				emit += 1; emit_amt += (g as GPUParticles3D).amount
		elif n is Light3D and (n as Light3D).is_visible_in_tree() and not (n is DirectionalLight3D):
			lights += 1
			if (n as Light3D).shadow_enabled: sl += 1
	for id in last_mats.keys():
		if not seen.has(id): last_mats.erase(id)
	row.append_array([mc, mec, vc, geo, emit, emit_amt, lights, sl, get_tree().get_node_count()])
	if out: out.store_line(",".join(row.map(func(x): return str(x))))
	if log2 == null: log2 = FileAccess.open(ProjectSettings.globalize_path("res://.scratch/p5_names.txt"), FileAccess.WRITE)
	if rnames.size() > 0:
		log2.store_line("f=%d rcpu=%s pc_surf=%s pc_spec=%s REM: %s" % [f, row[4], row[15], row[17], " ".join(rnames)])
	rnames = PackedStringArray()
	if f >= stop:
		log2.flush(); out.flush(); get_tree().quit(0); return
	if names.size() > 0:
		log2.store_line("f=%d rcpu=%s dbuf=%s add: %s" % [f, row[4], row[19], " ".join(names)])
	names = PackedStringArray()
	if vc > 40:
		log2.store_line("f=%d vis_chg=%d" % [f, vc])


func _boot() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(m)
	get_tree().current_scene = m
