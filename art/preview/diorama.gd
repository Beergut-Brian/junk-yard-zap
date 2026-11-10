## Art-direction sample frame: a bit of the front gate as a toy diorama on a table, built in code from
## art/direction/palettes.json so every option renders the same scene. Not game content; excluded from exports.
##   godot-render --path . --resolution 1920x1080 res://art/preview/diorama.tscn -- --palette=a [--style=flat] [--out=/abs/x.png]
## art/tools/render_frames.sh renders all four.
extends Node3D

const PALETTES := "res://art/direction/palettes.json"

var pal: Dictionary
var flat := false
var out_path := ""
var _rng := RandomNumberGenerator.new()
var _flat_shader: Shader
var _jeff: JarlingRig
var _chuck: JarlingRig
var _cow: Node3D
var ARM_X := -75.0
var ARM_Z := 0.0


func _ready() -> void:
	var key := "a"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--palette="):
			key = arg.trim_prefix("--palette=")
		elif arg == "--style=flat":
			flat = true
		elif arg.begins_with("--arm="):
			ARM_X = float(arg.split("=")[1].split(",")[0])
			ARM_Z = float(arg.split("=")[1].split(",")[1])
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	pal = JSON.parse_string(FileAccess.get_file_as_string(PALETTES))[key]
	_rng.seed = 7
	_flat_shader = load("res://art/preview/flat.gdshader")
	_build_world()
	_build_table()
	_build_fence()
	_build_heap()
	_build_props()
	_build_players()
	await get_tree().process_frame
	await get_tree().process_frame
	_build_beam()
	if flat:
		_flatten_jarlings()
	if out_path != "":
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_path)
		print("frame: ", out_path)
		get_tree().quit()


func c(k: String) -> Color:
	return Color(pal[k])


func gun(k: String) -> Color:
	return Color(pal["guns"][k])


# --- materials and meshes ---------------------------------------------------------------------------

func mat(col: Color, emit := 0.0, rough := 0.6) -> Material:
	if flat:
		var sm := ShaderMaterial.new()
		sm.shader = _flat_shader
		sm.set_shader_parameter("albedo", col)
		sm.set_shader_parameter("emit", col * emit)
		sm.next_pass = _outline()
		return sm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.5
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


func _outline(w := 0.035) -> StandardMaterial3D:
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = w
	o.albedo_color = c("ink")
	return o


func seg(smooth_n: int, flat_n: int) -> int:
	return flat_n if flat else smooth_n


## A box with rounded edges and smooth normals (k rows per rounded edge). In the flat style k=1 gives a bevel.
func rbox(size: Vector3, r: float) -> ArrayMesh:
	var k := seg(5, 1)
	var h := size * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.98)
	var inner := h - Vector3.ONE * r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		for s in [-1.0, 1.0]:
			var u_ax := (axis + 1) % 3
			var v_ax := (axis + 2) % 3
			var us := _samples(h[u_ax], r, k)
			var vs := _samples(h[v_ax], r, k)
			var grid := []
			for ui in us.size():
				var row := []
				for vi in vs.size():
					var p := Vector3.ZERO
					p[axis] = h[axis] * s
					p[u_ax] = us[ui]
					p[v_ax] = vs[vi]
					var cl := p.clamp(-inner, inner)
					var n := (p - cl).normalized()
					row.append([cl + n * r, n])
				grid.append(row)
			for ui in us.size() - 1:
				for vi in vs.size() - 1:
					_quad(st, grid[ui][vi], grid[ui + 1][vi], grid[ui + 1][vi + 1], grid[ui][vi + 1])
	return st.commit()


func _samples(hh: float, r: float, k: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in k + 1:
		out.append(-hh + r * float(i) / k)
	for i in k + 1:
		out.append(hh - r + r * float(i) / k)
	return out


func _quad(st: SurfaceTool, a: Array, b: Array, cc: Array, d: Array) -> void:
	for tri in [[a, b, cc], [a, cc, d]]:
		var p0: Vector3 = tri[0][0]
		var p1: Vector3 = tri[1][0]
		var p2: Vector3 = tri[2][0]
		var n: Vector3 = tri[0][1] + tri[1][1] + tri[2][1]
		if (p1 - p0).cross(p2 - p0).dot(n) > 0.0:  # Godot front faces wind clockwise
			tri = [tri[0], tri[2], tri[1]]
		for v in tri:
			st.set_normal(v[1])
			st.add_vertex(v[0])


func sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg(32, 8)
	m.rings = seg(16, 5)
	return m


func cyl(r: float, hgt: float, r_top := -1.0) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r if r_top < 0.0 else r_top
	m.bottom_radius = r
	m.height = hgt
	m.radial_segments = seg(32, 8)
	m.rings = 1
	return m


func torus(r_in: float, r_out: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = r_in
	m.outer_radius = r_out
	m.rings = seg(48, 12)
	m.ring_segments = seg(20, 6)
	return m


func put(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(col, emit)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func group(pos: Vector3, rot := Vector3.ZERO, scl := 1.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	n.scale = Vector3.ONE * scl
	add_child(n)
	return n


## Two googly eyes and a mouth on the +Z side of parent. mood: happy, smug, wow, sleepy.
func face(parent: Node3D, at: Vector3, s: float, mood: String, look := Vector2(0.0, 0.0)) -> void:
	var ink := c("ink")
	for side in [-1.0, 1.0]:
		var e := at + Vector3(side * 0.16 * s, 0.06 * s, 0)
		if mood == "sleepy":
			put(parent, rbox(Vector3(0.2, 0.045, 0.04) * s, 0.02 * s), ink, e + Vector3(0, 0, 0.02 * s))
			continue
		var er := 0.13 * s if mood == "wow" else 0.11 * s
		put(parent, sphere(er), Color.WHITE, e, Vector3.ZERO, Vector3(1, 1.15, 0.55))
		var pr := er * (0.42 if mood == "wow" else 0.55)
		var pupil := e + Vector3(look.x * er * 0.35, look.y * er * 0.35, er * 0.45)
		put(parent, sphere(pr), ink, pupil, Vector3.ZERO, Vector3(1, 1, 0.6))
		put(parent, sphere(pr * 0.3), Color.WHITE, pupil + Vector3(pr * 0.35, pr * 0.4, pr * 0.5))
		if mood == "smug":
			put(parent, rbox(Vector3(0.26, 0.05, 0.12) * s, 0.02 * s), parent_tint(parent), e + Vector3(0, er * 0.75, 0.01 * s), Vector3(0, 0, -side * 8))
	var m := at + Vector3(0, -0.17 * s, 0.02 * s)
	match mood:
		"wow":
			put(parent, sphere(0.07 * s), ink, m + Vector3(0, -0.02 * s, 0), Vector3.ZERO, Vector3(0.9, 1.2, 0.5))
		"smug":
			for i in 5:
				var t := -0.5 + i / 4.0
				put(parent, sphere(0.025 * s), ink, m + Vector3(t * 0.2 * s, -t * 0.04 * s + 0.02 * s - absf(t) * 0.0, 0))
		_:
			for i in 7:
				var t := -0.5 + i / 6.0
				put(parent, sphere(0.026 * s), ink, m + Vector3(t * 0.24 * s, (t * t - 0.25) * 0.22 * s, 0))


var _tints := {}
func parent_tint(p: Node3D) -> Color:
	return _tints.get(p, c("ink"))


# --- the set ----------------------------------------------------------------------------------------

func _build_world() -> void:
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(0.0, 3.1, 13.2)
	add_child(cam)
	cam.look_at(Vector3(0.0, 1.95, 0))

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(pal["key_pitch"], pal["key_yaw"], 0)
	sun.light_color = c("key")
	sun.light_energy = pal["key_energy"]
	sun.shadow_enabled = true
	sun.light_angular_distance = 2.5
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = c("room")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = c("ambient")
	env.ambient_light_energy = pal["ambient_energy"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.2
	env.glow_enabled = pal["glow"] > 0.0
	env.glow_intensity = pal["glow"]
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Painted sky backdrop: a curved card behind the set, gradient + painted clouds in the shader.
	var sky := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(60, 13)
	sky.mesh = q
	sky.position = Vector3(0, 6.0, -16)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://art/preview/sky.gdshader")
	sm.set_shader_parameter("top", c("sky_top"))
	sm.set_shader_parameter("horizon", c("sky_horizon"))
	sm.set_shader_parameter("cloud", c("cloud"))
	sm.set_shader_parameter("sun", c("sun"))
	sm.set_shader_parameter("sun_pos", Vector2(0.68, 0.6) if pal["key_pitch"] < -35 else Vector2(0.74, 0.3))
	sky.material_override = sm
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky)

	# Parallax cotton clouds on wires, between the heap and the sky.
	for cl in [Vector3(-7.0, 6.3, -10), Vector3(2.5, 7.0, -11), Vector3(9.0, 5.6, -9.5)]:
		var g := group(cl)
		for p in [Vector3(-0.9, 0, 0), Vector3(0, 0.35, 0), Vector3(0.9, 0.05, 0), Vector3(0.3, -0.15, 0.3)]:
			var mi := put(g, sphere(0.85), c("cloud"), p, Vector3.ZERO, Vector3(1, 0.8, 0.7), 0.15)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		put(g, cyl(0.01, 6.0), c("ink").lerp(c("sky_top"), 0.5), Vector3(0, 3.5, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_table() -> void:
	# The diorama: a slab of yard dirt sitting on a wooden table.
	# Dirt on top, a cut-away of darker soil, a wooden plinth, then the table it all stands on.
	put(self, rbox(Vector3(27, 0.4, 8.2), 0.15), c("ground"), Vector3(0, -0.2, -2.3))
	put(self, rbox(Vector3(26.9, 0.45, 8.1), 0.05), c("ground_dark"), Vector3(0, -0.55, -2.3))
	put(self, rbox(Vector3(27.4, 0.22, 8.5), 0.06), c("fence_dark"), Vector3(0, -0.86, -2.3))
	put(self, rbox(Vector3(40, 1.0, 16), 0.12), c("table"), Vector3(0, -1.47, 2))
	# A few pebbles and bolts scattered in the dirt so the ground is not a void.
	for i in 26:
		var p := Vector3(_rng.randf_range(-9, 9), 0.02, _rng.randf_range(-2.5, 1.5))
		var col := c("ground_dark") if i % 3 else c("metal")
		put(self, sphere(_rng.randf_range(0.06, 0.14)), col, p, Vector3.ZERO, Vector3(1.3, 0.5, 1.0))
	# Puddle of pond water at the front right.
	var pud := put(self, cyl(0.9, 0.04), c("pond"), Vector3(-4.0, 0.01, 1.2), Vector3.ZERO, Vector3(1.4, 1, 0.5))
	if not flat:
		(pud.material_override as BaseMaterial3D).roughness = 0.1


func _build_fence() -> void:
	var z := -2.8
	put(self, rbox(Vector3(24, 0.18, 0.1), 0.04), c("fence_dark"), Vector3(0, 0.6, z - 0.12))
	put(self, rbox(Vector3(24, 0.18, 0.1), 0.04), c("fence_dark"), Vector3(0, 1.9, z - 0.12))
	var x := -12.0
	var i := 0
	while x < 12.0:
		i += 1
		if i % 7 == 3:
			# A sheet of rusty corrugated metal patched into the fence.
			var w := 1.6
			var sheet := group(Vector3(x + w * 0.5, 1.15, z), Vector3(0, 0, _rng.randf_range(-3, 3)))
			for r in 6:
				put(sheet, cyl(0.14, 2.3), c("rust") if r % 2 else c("rust_dark"), Vector3(-w * 0.5 + 0.14 + r * 0.265, 0, 0), Vector3.ZERO, Vector3(1, 1, 0.45))
			x += w + 0.06
			continue
		var w := _rng.randf_range(0.42, 0.58)
		var hgt := _rng.randf_range(2.3, 2.7)
		var col := c("fence").lerp(c("fence_dark"), _rng.randf_range(0.0, 0.35))
		put(self, rbox(Vector3(w, hgt, 0.12), 0.08), col, Vector3(x + w * 0.5, hgt * 0.5 - 0.05, z), Vector3(0, 0, _rng.randf_range(-2.5, 2.5)))
		# A pointy top on every plank.
		put(self, cyl(w * 0.36, 0.18, 0.02), col, Vector3(x + w * 0.5, hgt + 0.02, z), Vector3.ZERO, Vector3(1, 1, 0.3))
		x += w + 0.05
	_build_card(Vector3(-3.75, 1.4, z + 0.14))


func _build_card(at: Vector3) -> void:
	var g := group(at, Vector3(0, 0, -3))
	# The stack: two cards peeking out behind the top one.
	put(g, rbox(Vector3(1.2, 1.5, 0.04), 0.08), c("card").darkened(0.15), Vector3(0.08, -0.06, -0.06), Vector3(0, 0, 4))
	put(g, rbox(Vector3(1.2, 1.5, 0.04), 0.08), c("card").darkened(0.08), Vector3(-0.06, -0.03, -0.03), Vector3(0, 0, -3))
	put(g, rbox(Vector3(1.2, 1.5, 0.05), 0.08), c("card"), Vector3.ZERO)
	put(g, rbox(Vector3(0.4, 0.14, 0.12), 0.04), c("metal"), Vector3(0, 0.72, 0.03))
	# Pictogram: ball -> arrow -> bathtub ("get the ball in the bathtub").
	var ink := c("ink")
	put(g, sphere(0.15), gun("grow").lerp(Color.WHITE, 0.1), Vector3(-0.3, 0.32, 0.06), Vector3.ZERO, Vector3(1, 1, 0.35))
	put(g, rbox(Vector3(0.06, 0.38, 0.03), 0.02), ink, Vector3(-0.1, 0.12, 0.05), Vector3(0, 0, 38))
	put(g, cyl(0.07, 0.12, 0.0), ink, Vector3(0.03, -0.04, 0.05), Vector3(0, 0, 142), Vector3(1, 1, 0.4))
	put(g, rbox(Vector3(0.66, 0.34, 0.05), 0.14), gun("magnet").lerp(c("ink"), 0.35), Vector3(0.12, -0.38, 0.05))
	put(g, rbox(Vector3(0.56, 0.1, 0.06), 0.04), c("pond").lightened(0.2), Vector3(0.12, -0.25, 0.06))
	for fx in [-0.12, 0.36]:
		put(g, sphere(0.045), ink, Vector3(fx, -0.56, 0.05), Vector3.ZERO, Vector3(1, 1, 0.4))


func _build_heap() -> void:
	# The scrap heap behind the fence: a soft, slightly hazy pile so the gate reads as a junk yard.
	var cols := [c("rust"), c("rust_dark"), c("metal"), c("car"), c("rubber"), c("crate")]
	for i in 34:
		var x := _rng.randf_range(-13, 13)
		var hump := 2.4 * exp(-pow((x - 4.0) / 5.0, 2)) + 1.6 * exp(-pow((x + 8.0) / 3.5, 2))
		var p := Vector3(x, _rng.randf_range(0.2, hump + 0.6), _rng.randf_range(-6.5, -4.2))
		var col: Color = cols[i % cols.size()].lerp(c("sky_horizon"), 0.18)
		var sz := Vector3(_rng.randf_range(0.8, 2.0), _rng.randf_range(0.6, 1.4), _rng.randf_range(0.8, 1.6))
		var rot := Vector3(_rng.randf_range(-15, 15), _rng.randf_range(-40, 40), _rng.randf_range(-25, 25))
		if i % 5 == 4:
			put(self, torus(0.3, 0.62), c("rubber").lerp(c("sky_horizon"), 0.15), p, rot + Vector3(80, 0, 0))
		else:
			put(self, rbox(sz, 0.18), col, p, rot)
	# A crane arm peeking over the heap, with its hook.
	var crane := group(Vector3(9.0, -1.2, -6.5))
	put(crane, rbox(Vector3(0.5, 7.0, 0.5), 0.1), c("rust").lerp(c("metal"), 0.3), Vector3(0, 3.5, 0))
	put(crane, rbox(Vector3(6.0, 0.4, 0.4), 0.1), c("rust").lerp(c("metal"), 0.3), Vector3(-2.2, 6.9, 0), Vector3(0, 0, -6))
	put(crane, cyl(0.02, 2.4), c("ink"), Vector3(-4.6, 6.0, 0))
	put(crane, torus(0.18, 0.3), c("metal"), Vector3(-4.6, 4.75, 0), Vector3(90, 0, 0))


func _build_props() -> void:
	# Crate (sleepy) with the chicken (wow) on top, left.
	var crate := group(Vector3(3.95, 2.3, 0.15), Vector3(0, -14, 6), 0.68)
	put(crate, rbox(Vector3(1.25, 1.2, 1.2), 0.1), c("crate"), Vector3.ZERO)
	for y in [-0.35, 0.0, 0.35]:
		put(crate, rbox(Vector3(1.3, 0.12, 1.25), 0.04), c("crate").darkened(0.18), Vector3(0, y, 0))
	face(crate, Vector3(0, 0.0, 0.64), 1.5, "sleepy")
	_chicken(Vector3(-4.95, 0.95, 0.25), true)

	# Bouncy tyre, smug, standing under the floating cow, with bouncy stripes.
	var tyre := group(Vector3(0.3, 0.75, 0.2), Vector3(0, -8, 0))
	put(tyre, torus(0.3, 0.75), c("rubber"), Vector3.ZERO, Vector3(90, 0, 0))
	put(tyre, cyl(0.36, 0.2), c("metal"), Vector3.ZERO, Vector3(90, 0, 0))
	var bounce := gun("bouncy")
	for k in 10:
		var a := TAU * k / 10.0
		var ring := MeshInstance3D.new()
		ring.mesh = torus(0.225, 0.26)
		ring.material_override = mat(bounce, pal["emit"])
		ring.basis = _basis_y(Vector3(-sin(a), cos(a), 0))
		ring.position = Vector3(cos(a), sin(a), 0) * 0.525
		tyre.add_child(ring)
	face(tyre, Vector3(0, 0.0, 0.12), 0.95, "smug", Vector2(0.5, 0.2))

	# Car (rusty, smug-happy) right of centre.
	_car(Vector3(4.3, 0, 0.1))
	# Bathtub (happy) far right, slightly back, with clawed feet.
	var tub := group(Vector3(-5.1, 0.55, 0.0), Vector3(0, 12, 0), 0.9)
	put(tub, rbox(Vector3(2.4, 1.0, 1.15), 0.4), c("enamel"), Vector3.ZERO)
	put(tub, rbox(Vector3(2.5, 0.16, 1.25), 0.08), c("enamel").darkened(0.06), Vector3(0, 0.48, 0))
	put(tub, rbox(Vector3(2.1, 0.06, 0.85), 0.05), c("pond"), Vector3(0, 0.5, 0))
	put(tub, cyl(0.06, 0.5), c("metal"), Vector3(-1.0, 0.85, -0.3))
	for fx in [-0.85, 0.85]:
		put(tub, sphere(0.16), c("metal"), Vector3(fx, -0.55, 0.35))
		put(tub, sphere(0.16), c("metal"), Vector3(fx, -0.55, -0.35))
	face(tub, Vector3(0.2, -0.02, 0.6), 1.3, "happy", Vector2(0.6, 0.2))

	# The cow, ballooned: floating above the tyre, panicked-delighted.
	_cow = group(Vector3(0.1, 2.5, 0.3), Vector3(0, 0, 8), 0.95)
	put(_cow, rbox(Vector3(2.0, 1.05, 1.0), 0.42), c("cow"), Vector3.ZERO)
	put(_cow, sphere(0.32), c("cow_spot"), Vector3(-0.45, 0.2, 0.36), Vector3.ZERO, Vector3(1.3, 1, 0.5))
	put(_cow, sphere(0.25), c("cow_spot"), Vector3(0.35, -0.15, 0.42), Vector3.ZERO, Vector3(1.2, 1, 0.4))
	for lx in [-0.65, 0.6]:
		for lz in [-0.3, 0.3]:
			put(_cow, cyl(0.13, 0.55), c("cow"), Vector3(lx, -0.65, lz), Vector3(0, 0, 10 if lx < 0 else -10))
			put(_cow, cyl(0.15, 0.14), c("cow_spot"), Vector3(lx + (0.05 if lx < 0 else -0.05), -0.95, lz), Vector3(0, 0, 10 if lx < 0 else -10))
	var head := Node3D.new()
	head.position = Vector3(1.15, 0.3, 0.12)
	head.rotation_degrees = Vector3(0, -28, -8)
	_cow.add_child(head)
	put(head, rbox(Vector3(0.85, 0.8, 0.8), 0.32), c("cow"), Vector3.ZERO)
	put(head, rbox(Vector3(0.75, 0.38, 0.5), 0.17), c("enamel").lerp(gun("glue"), 0.45), Vector3(0.12, -0.3, 0.22))
	put(head, sphere(0.045), c("ink"), Vector3(0.0, -0.28, 0.48))
	put(head, sphere(0.045), c("ink"), Vector3(0.24, -0.28, 0.48))
	for hz in [-0.25, 0.25]:
		put(head, cyl(0.07, 0.3, 0.02), c("enamel").darkened(0.1), Vector3(-0.05, 0.5, hz), Vector3(hz * 60, 0, 0))
		put(head, sphere(0.16), c("cow_spot"), Vector3(-0.2, 0.25, hz * 1.9), Vector3.ZERO, Vector3(0.5, 0.9, 1.3))
	face(head, Vector3(0.0, 0.1, 0.42), 1.25, "wow", Vector2(-0.3, 0.5))
	put(_cow, cyl(0.04, 0.6), c("cow_spot"), Vector3(-1.1, 0.0, 0), Vector3(0, 0, -30))
	_balloon(_cow, Vector3(-0.1, 0.55, 0))


func _chicken(at: Vector3, flip := false) -> void:
	var g := group(at, Vector3(0, 18, -6), 1.0)
	put(g, sphere(0.36), c("chicken"), Vector3(0, 0.38, 0), Vector3.ZERO, Vector3(1.15, 1, 1))
	put(g, sphere(0.25), c("chicken"), Vector3(0.18, 0.78, 0.05))
	put(g, cyl(0.08, 0.2, 0.0), c("beak"), Vector3(0.18, 0.72, 0.32), Vector3(90, 0, 0))
	for k in 3:
		put(g, sphere(0.07), gun("grow").lerp(c("beak"), 0.5), Vector3(0.1 + k * 0.08, 1.02 - absf(k - 1) * 0.03, 0.04))
	put(g, sphere(0.2), c("chicken").darkened(0.06), Vector3(-0.38, 0.5, 0.02), Vector3(0, 0, 40), Vector3(1.2, 0.6, 0.8))
	for lx in [-0.08, 0.12]:
		put(g, cyl(0.025, 0.25), c("beak"), Vector3(lx, 0.08, 0.05))
	face(g, Vector3(0.2, 0.86, 0.27), 0.6, "wow", Vector2(0.4, 0.3))
	if flip:
		g.scale = Vector3(-1, 1, 1)
		g.rotation_degrees = Vector3(0, -18, 6)


func _car(at: Vector3) -> void:
	var g := group(at, Vector3(0, -6, 0), 0.85)
	_tints[g] = c("car")
	put(g, rbox(Vector3(3.2, 0.95, 1.6), 0.38), c("car"), Vector3(0, 0.9, 0))
	put(g, rbox(Vector3(1.8, 0.85, 1.4), 0.34), c("car").lerp(c("enamel"), 0.15), Vector3(-0.25, 1.65, 0))
	put(g, rbox(Vector3(1.5, 0.55, 1.42), 0.22), c("sky_horizon").lerp(c("pond"), 0.4), Vector3(-0.25, 1.68, 0.02))
	# Rust patches.
	put(g, sphere(0.3), c("rust_dark"), Vector3(-1.0, 0.75, 0.66), Vector3.ZERO, Vector3(1.4, 0.8, 0.35))
	put(g, sphere(0.22), c("rust"), Vector3(1.15, 1.1, 0.68), Vector3.ZERO, Vector3(1.2, 0.8, 0.3))
	put(g, rbox(Vector3(0.3, 0.3, 1.7), 0.12), c("metal"), Vector3(1.6, 0.62, 0))
	for wx in [-1.05, 1.05]:
		for wz in [-0.72, 0.72]:
			put(g, cyl(0.42, 0.32), c("rubber"), Vector3(wx, 0.42, wz), Vector3(90, 0, 0))
			put(g, cyl(0.2, 0.34), c("metal"), Vector3(wx, 0.42, wz), Vector3(90, 0, 0))
	# The face sits on the bonnet front: headlights are the eyes.
	var front := Node3D.new()
	front.position = Vector3(1.62, 0.95, 0.0)
	front.rotation_degrees = Vector3(0, 90, 0)
	g.add_child(front)
	_tints[front] = c("car")
	put(front, rbox(Vector3(1.5, 0.3, 0.1), 0.05), c("metal"), Vector3(0, -0.3, 0))
		# A side face too, so it reads from the camera.
	face(g, Vector3(0.55, 1.0, 0.82), 1.35, "smug", Vector2(-0.8, 0.2))


func _balloon(parent: Node3D, tie: Vector3) -> void:
	var col := gun("balloon")
	var b := put(parent, sphere(0.62), col, tie + Vector3(-0.25, 1.75, 0), Vector3(0, 0, -8), Vector3(1, 1.18, 1), pal["emit"])
	if not flat:
		(b.material_override as StandardMaterial3D).roughness = 0.25
	put(parent, sphere(0.16), Color.WHITE, tie + Vector3(-0.42, 2.1, 0.45), Vector3.ZERO, Vector3(0.7, 1.0, 0.4), 0.4)
	put(parent, cyl(0.1, 0.16, 0.02), col, tie + Vector3(-0.15, 1.0, 0), Vector3(0, 0, 172), Vector3.ONE, pal["emit"])
	put(parent, cyl(0.012, 0.95), c("ink"), tie + Vector3(-0.08, 0.5, 0), Vector3(0, 0, 9))
	put(parent, torus(0.06, 0.12), col, tie + Vector3(0, 0.03, 0), Vector3.ZERO, Vector3.ONE, pal["emit"])


func _build_players() -> void:
	_jeff = JarlingRig.new()
	_jeff.character = &"jeff"
	_jeff.position = Vector3(-2.5, 0, 0.8)
	add_child(_jeff)
	_jeff.equip_gun(Players.COLOR[Players.P1])
	_jeff.model.rotation.y = deg_to_rad(35)
	_jeff.set_expression("determined")
	_jeff.play("idle", 0.0)
	_raise_arm(_jeff)
	_jeff.recolor_gun(gun("balloon"))
	_ring(_jeff.position, Players.COLOR[Players.P1])

	_chuck = JarlingRig.new()
	_chuck.character = &"chuck"
	_chuck.position = Vector3(1.9, 0, 0.9)
	add_child(_chuck)
	_chuck.equip_gun(Players.COLOR[Players.P2])
	_chuck.model.rotation.y = deg_to_rad(-40)
	_chuck.set_expression("happy")
	_chuck.recolor_gun(gun("bouncy"))
	if _chuck.anim and _chuck.anim.has_animation("cheer"):
		_chuck.play("cheer")
		_chuck.anim.seek(0.35, true)
		_chuck.anim.pause()
	_ring(_chuck.position, Players.COLOR[Players.P2])


## Point the gun arm up toward the target (the rig has no aim pose yet).
func _raise_arm(rig: JarlingRig) -> void:
	var sk := rig.model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var b := sk.find_bone("arm.R")
	rig.anim.stop()
	var q := sk.get_bone_rest(b).basis.get_rotation_quaternion()
	sk.set_bone_pose_rotation(b, q * Quaternion(Vector3.RIGHT, deg_to_rad(ARM_X)) * Quaternion(Vector3.FORWARD, deg_to_rad(ARM_Z)))


func _ring(at: Vector3, col: Color) -> void:
	var r := put(self, torus(0.62, 0.74), col, at + Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1, 0.4, 1), 0.35)
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The balloon gun's beam from Jeff's gun tip to the cow: a glowing core, rings along it, sparkles at the end.
func _build_beam() -> void:
	var from: Vector3 = _jeff.gun_tip_position()
	var to: Vector3 = _cow.global_position + Vector3(-0.6, -0.3, 0)
	var col := gun("balloon")
	var d: Vector3 = to - from
	var mid: Vector3 = from + d * 0.5
	var core := MeshInstance3D.new()
	core.mesh = cyl(0.06, d.length())
	core.material_override = mat(col.lerp(Color.WHITE, 0.35), 1.2 + pal["emit"])
	add_child(core)
	core.global_position = mid
	core.global_basis = _basis_y(d.normalized())
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 4:
		var t := 0.2 + k * 0.2
		var ring := MeshInstance3D.new()
		ring.mesh = torus(0.12 + k * 0.03, 0.17 + k * 0.03)
		ring.material_override = mat(col, 0.6 + pal["emit"])
		add_child(ring)
		ring.global_position = from + d * t
		ring.global_basis = _basis_y(d.normalized())
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 7:
		var a := TAU * k / 7.0
		var p := to + Vector3(cos(a), sin(a), 0.4) * _rng.randf_range(0.35, 0.6)
		var star := put(self, sphere(0.07), col.lerp(Color.WHITE, 0.5), p, Vector3.ZERO, Vector3.ONE, 1.5 + pal["emit"])
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _basis_y(up: Vector3) -> Basis:
	var x := up.cross(Vector3(0, 0, 1)).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)


## Flat style: give the Jarlings the same faceted shading and ink outline as the props.
func _flatten_jarlings() -> void:
	for rig in [_jeff, _chuck]:
		for mi in (rig as Node3D).find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.material_override:
				var src := m.material_override as StandardMaterial3D
				if src:
					m.material_override = mat(src.albedo_color)
				continue
			for s in m.mesh.get_surface_count():
				var src := m.get_active_material(s) as StandardMaterial3D
				if src == null:
					continue
				var sm := ShaderMaterial.new()
				sm.shader = _flat_shader
				sm.set_shader_parameter("albedo", src.albedo_color)
				sm.set_shader_parameter("emit", Color.BLACK)
				if src.albedo_texture:
					sm.set_shader_parameter("tex", src.albedo_texture)
				sm.set_shader_parameter("uv_off", Vector2(src.uv1_offset.x, src.uv1_offset.y))
				if not src.resource_name.ends_with("_face"):
					sm.next_pass = _outline(0.012)
				m.set_surface_override_material(s, sm)
