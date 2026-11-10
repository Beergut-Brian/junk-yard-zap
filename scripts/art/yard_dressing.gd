## Everything you see in the yard that isn't an object or a player: the Golden Afternoon toy diorama
## (art/direction/frame_a.png, D44). A slab of yard dirt on a wooden table, a picket fence with rusty
## patches, the five zones' landmarks, a painted sky with cotton clouds on wires, the key light.
## Looks only: YardLevel owns every collision and gameplay node and this never adds a body. Repeated
## bits (planks, pebbles, junk) go into MultiMeshes so the whole yard is a few hundred draw calls.
class_name YardDressing
extends Node3D


const FENCE_Z := -4.75
const SOIL := 3.4         # depth of the cut-away dirt under the yard surface
const TABLE_Y := -3.75

var level: YardLevel
var fan: Node3D
var _sky: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _batches := {}        # kind -> [mesh, transforms, colours, casts shadow]
var _vc_mat: StandardMaterial3D


static func build(p_level: YardLevel) -> YardDressing:
	var d := YardDressing.new()
	d.name = "Dressing"
	d.level = p_level
	p_level.add_child(d)
	d._build()
	return d


func _build() -> void:
	_rng.seed = 44   # D44: the same yard every boot
	YardLight.add(self, 140.0)
	_build_sky()
	_build_ground()
	_build_pond()
	_build_back_fence()
	_build_end_fences()
	_build_backdrop()
	_build_front_gate()
	_build_scrap_heap()
	_build_pond_props()
	_build_barn()
	_build_tower()
	_scatter()
	_flush()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and _sky:
		_sky.global_position.x = cam.global_position.x
	if fan:
		fan.rotate_z(-delta * 5.0)


# --- helpers ----------------------------------------------------------------------------------------

func c(k: String) -> Color:
	return ArtKit.c(k)


func put(parent: Node3D, mesh: Mesh, col: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	return ArtKit.put(parent, mesh, col, pos, rot, scl)


func box(parent: Node3D, size: Vector3, r: float, col: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return ArtKit.put(parent, ArtKit.rbox(size, r), col, pos, rot)


func xf(pos: Vector3, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	var r := rot_deg * (PI / 180.0)
	return Transform3D(Basis.from_euler(r) * Basis.from_scale(scl), pos)


## Queue an instance into a MultiMesh of `kind` (one draw call per kind).
func add(kind: String, mesh: Mesh, t: Transform3D, col: Color, shadow := true) -> void:
	if not _batches.has(kind):
		_batches[kind] = [mesh, [], [], shadow]
	_batches[kind][1].append(t)
	_batches[kind][2].append(col)


func _flush() -> void:
	_vc_mat = StandardMaterial3D.new()
	_vc_mat.vertex_color_use_as_albedo = true
	_vc_mat.vertex_color_is_srgb = true
	_vc_mat.roughness = 0.7
	_vc_mat.rim_enabled = true
	_vc_mat.rim = 0.2
	_vc_mat.rim_tint = 0.5
	for k in _batches:
		var b: Array = _batches[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = b[0]
		mm.instance_count = b[1].size()
		for i in b[1].size():
			mm.set_instance_transform(i, b[1][i])
			mm.set_instance_color(i, b[2][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_%s" % k
		mmi.multimesh = mm
		mmi.material_override = _vc_mat
		if not b[3]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_batches.clear()


func group(pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null) -> Node3D:
	return ArtKit.group(parent if parent else self, pos, rot)


func haze(col: Color, k: float) -> Color:
	return col.lerp(c("sky_horizon"), k)


# --- sky ---------------------------------------------------------------------------------------------

func _build_sky() -> void:
	_sky = MeshInstance3D.new()
	_sky.name = "Sky"
	_sky.mesh = ArtKit.quad(Vector2(520, 260))
	_sky.position = Vector3(0, 40, -95)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://scripts/art/sky.gdshader")
	sm.set_shader_parameter("top", c("sky_top"))
	sm.set_shader_parameter("horizon", c("sky_horizon"))
	sm.set_shader_parameter("cloud", c("cloud"))
	sm.set_shader_parameter("sun", c("sun"))
	sm.set_shader_parameter("horizon_y", -4.0)
	sm.set_shader_parameter("top_y", 60.0)
	sm.set_shader_parameter("sun_at", Vector2(0.62, 0.66))
	_sky.material_override = sm
	_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sky)
	# Cotton clouds on wires, at a few depths so they slide past at different speeds.
	var puff := ArtKit.sphere(1.0, 20)
	var x := YardLevel.LEFT - 18.0
	while x < YardLevel.RIGHT + 18.0:
		var z := _rng.randf_range(-34.0, -22.0)
		var y := _rng.randf_range(13.0, 19.0)
		var s := _rng.randf_range(1.6, 2.6)
		var at := Vector3(x, y, z)
		for p in [Vector3(-0.9, 0, 0), Vector3(0, 0.4, 0.1), Vector3(0.95, 0.05, 0), Vector3(0.3, -0.2, 0.35), Vector3(-0.35, -0.15, 0.3)]:
			add("cloud", puff, xf(at + p * s, Vector3.ZERO, Vector3(1.0, 0.8, 0.7) * s * 0.95), c("cloud"), false)
		add("wire", ArtKit.cyl(1.0, 1.0, -1.0, 6), xf(at + Vector3(0, 22, 0), Vector3.ZERO, Vector3(0.025, 44, 0.025)), haze(c("ink"), 0.55), false)
		x += _rng.randf_range(15.0, 22.0)


# --- the slab and the table --------------------------------------------------------------------------

func _build_ground() -> void:
	var front := YardLevel.DEPTH * 0.5 + 0.05
	var back := FENCE_Z - 6.0
	var depth := front - back
	var zc := (front + back) * 0.5
	for side in [[YardLevel.LEFT - 6.0, YardLevel.POND.x], [YardLevel.POND.y, YardLevel.RIGHT + 6.0]]:
		var w: float = side[1] - side[0]
		var x: float = (side[0] + side[1]) * 0.5
		box(self, Vector3(w, 0.5, depth), 0.12, c("ground"), Vector3(x, -0.25, zc))
		box(self, Vector3(w - 0.04, SOIL - 0.45, depth - 0.1), 0.05, c("ground_dark"), Vector3(x, -0.45 - (SOIL - 0.45) * 0.5, zc))
		box(self, Vector3(w - 0.02, 0.12, 0.08), 0.03, c("ground_dark").darkened(0.18), Vector3(x, -1.6, front - 0.04))
	# Behind the pond: a bank so the fence has ground to stand on.
	var bank_d := FENCE_Z - back + 0.6
	box(self, Vector3(YardLevel.POND.y - YardLevel.POND.x + 0.2, 0.5, bank_d), 0.12, c("ground"), Vector3(0, -0.25, back + bank_d * 0.5))
	box(self, Vector3(YardLevel.POND.y - YardLevel.POND.x, SOIL - 0.45, bank_d - 0.1), 0.05, c("ground_dark"), Vector3(0, -0.45 - (SOIL - 0.45) * 0.5, back + bank_d * 0.5))
	# Under the pond: soil below the basin floor.
	var under := SOIL - absf(YardLevel.POND_FLOOR) - 0.2
	box(self, Vector3(YardLevel.POND.y - YardLevel.POND.x, under, YardLevel.DEPTH + 0.1), 0.05, c("ground_dark"), Vector3(0, YardLevel.POND_FLOOR - 0.2 - under * 0.5, 0))
	# The plinth trim and the table it all stands on.
	box(self, Vector3(YardLevel.RIGHT - YardLevel.LEFT + 12.4, 0.3, depth + 0.4), 0.08, c("fence_dark"), Vector3(0, -SOIL - 0.15, zc))
	box(self, Vector3(YardLevel.RIGHT - YardLevel.LEFT + 120.0, 1.4, 40.0), 0.2, c("table"), Vector3(0, TABLE_Y - 0.7, -11.0))
	# Below the table edge: the dim room the diorama sits in (only the yard-wide shot sees it).
	var room := put(self, ArtKit.quad(Vector2(600, 120)), c("room"), Vector3(0, TABLE_Y - 61.0, 8.0))
	room.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Wood grain on the table: long faint stripes.
	for i in 5:
		var z := 5.0 + i * 0.8 + _rng.randf_range(-0.2, 0.2)
		add("grain", ArtKit.rbox(Vector3(1, 1, 1), 0.3, 2), xf(Vector3(_rng.randf_range(-20, 20), TABLE_Y + 0.005, z), Vector3.ZERO, Vector3(150, 0.02, _rng.randf_range(0.15, 0.4))), c("table").darkened(0.12), false)


func _build_pond() -> void:
	var w := YardLevel.POND.y - YardLevel.POND.x
	box(self, Vector3(w, 0.3, YardLevel.DEPTH + 0.1), 0.08, c("ground").lerp(c("crate"), 0.4), Vector3(0, YardLevel.POND_FLOOR - 0.15, 0))
	for s in [-1.0, 1.0]:
		var x: float = (YardLevel.POND.x + 1.3) if s < 0 else (YardLevel.POND.y - 1.3)
		box(self, Vector3(3.6, 0.5, YardLevel.DEPTH + 0.1), 0.15, c("ground").darkened(0.06), Vector3(x, YardLevel.POND_FLOOR * 0.5 - 0.3, 0), Vector3(0, 0, -38.0 * s))
		# Soil wedge under each ramp so the cut-away has no gap.
		var wedge := PrismMesh.new()
		wedge.left_to_right = 0.0 if s < 0 else 1.0
		wedge.size = Vector3(2.9, absf(YardLevel.POND_FLOOR), YardLevel.DEPTH)
		put(self, wedge, c("ground_dark"), Vector3(s * (absf(YardLevel.POND.x) - 1.45), YardLevel.POND_FLOOR * 0.5, 0))
	# Basin back wall.
	box(self, Vector3(w, absf(YardLevel.POND_FLOOR) + 0.4, 0.3), 0.05, c("ground_dark"), Vector3(0, YardLevel.POND_FLOOR * 0.5, FENCE_Z + 0.35))
	# The water: a see-through block (the front is a glass cut-away so you watch things float and sink).
	var water_h := YardLevel.WATER_Y - YardLevel.POND_FLOOR
	var wmi := ArtKit.put_mat(self, ArtKit.rbox(Vector3(w - 0.1, water_h, 8.25), 0.05, 2),
			ArtKit.glass(Color(c("pond"), 0.55)), Vector3(0, YardLevel.POND_FLOOR + water_h * 0.5, -0.1))
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wmi.name = "Water"
	var top := ArtKit.put_mat(self, ArtKit.quad(Vector2(w - 0.1, YardLevel.DEPTH)), ArtKit.glass(Color(c("pond").lightened(0.35), 0.35), 0.1),
			Vector3(0, YardLevel.WATER_Y + 0.01, -0.3), Vector3(-90, 0, 0))
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Glass frame posts at the cut-away corners.
	for x in [YardLevel.POND.x + 0.05, YardLevel.POND.y - 0.05]:
		box(self, Vector3(0.18, SOIL, 0.18), 0.05, c("fence_dark"), Vector3(x, -SOIL * 0.5, YardLevel.DEPTH * 0.5 + 0.05))
	box(self, Vector3(w, 0.14, 0.16), 0.05, c("fence_dark"), Vector3(0, 0.02, YardLevel.DEPTH * 0.5 + 0.05))


# --- fences -----------------------------------------------------------------------------------------

func _build_back_fence() -> void:
	var plank := ArtKit.rbox(Vector3(1, 1, 1), 0.16, 3)
	var tip := ArtKit.cyl(1.0, 1.0, 0.05, 8)
	var corr := ArtKit.cyl(1.0, 1.0, -1.0, 12)
	var x := YardLevel.LEFT
	var i := 0
	while x < YardLevel.RIGHT:
		i += 1
		if x > 14.5 and x < 29.5:   # the barn's front wall is the backdrop here
			x = 29.5
			continue
		if i % 11 == 6:
			var sw := 1.7
			for r in 6:
				var col := c("rust") if r % 2 else c("rust_dark")
				add("corr", corr, xf(Vector3(x + 0.15 + r * 0.28, 1.25, FENCE_Z), Vector3(0, 0, _rng.randf_range(-2, 2)), Vector3(0.15, 2.5, 0.07)), haze(col, 0.12))
			x += sw + 0.05
			continue
		var w := _rng.randf_range(0.42, 0.6)
		var h := _rng.randf_range(2.35, 2.85)
		var col := c("fence").lerp(c("fence_dark"), _rng.randf_range(0.0, 0.35))
		var roll := _rng.randf_range(-2.5, 2.5)
		add("plank", plank, xf(Vector3(x + w * 0.5, h * 0.5 - 0.05, FENCE_Z), Vector3(0, 0, roll), Vector3(w, h, 0.12)), col)
		add("tip", tip, xf(Vector3(x + w * 0.5 - sin(deg_to_rad(roll)) * h * 0.5, h - 0.04, FENCE_Z), Vector3(0, 0, roll), Vector3(w * 0.36, 0.2, 0.06)), col)
		x += w + 0.05
	for y in [0.6, 1.95]:
		for seg in [[YardLevel.LEFT, 14.5], [29.5, YardLevel.RIGHT]]:
			var len: float = seg[1] - seg[0]
			add("rail", plank, xf(Vector3((seg[0] + seg[1]) * 0.5, y, FENCE_Z - 0.12), Vector3.ZERO, Vector3(len, 0.18, 0.1)), c("fence_dark"))


## The fences at each end: taller pickets running back to front (the gate on the left).
func _build_end_fences() -> void:
	var plank := ArtKit.rbox(Vector3(1, 1, 1), 0.16, 3)
	for side in [-1.0, 1.0]:
		var x: float = (YardLevel.LEFT - 0.25) if side < 0 else (YardLevel.RIGHT + 0.25)
		var z := FENCE_Z
		while z < YardLevel.DEPTH * 0.5 - 0.2:
			var w := _rng.randf_range(0.45, 0.6)
			var h := _rng.randf_range(4.1, 4.5)
			add("plank", plank, xf(Vector3(x, h * 0.5 - 0.05, z + w * 0.5), Vector3(_rng.randf_range(-2, 2), 0, 0), Vector3(0.14, h, w)), c("fence").lerp(c("fence_dark"), _rng.randf_range(0.1, 0.4)))
			z += w + 0.06
		for y in [0.8, 3.0]:
			add("rail", plank, xf(Vector3(x + side * 0.12, y, (FENCE_Z + YardLevel.DEPTH * 0.5) * 0.5), Vector3.ZERO, Vector3(0.1, 0.2, YardLevel.DEPTH * 0.5 - FENCE_Z)), c("fence_dark"))
	# The front gate: two posts and an arch with a zap bolt, over the left end.
	var g := group(Vector3(YardLevel.LEFT - 0.3, 0, (FENCE_Z + YardLevel.DEPTH * 0.5) * 0.5))
	for z in [-4.4, 4.4]:
		box(g, Vector3(0.5, 6.2, 0.5), 0.12, c("fence_dark"), Vector3(0, 3.1, z))
		put(g, ArtKit.sphere(0.32), c("mustard"), Vector3(0, 6.35, z))
	box(g, Vector3(0.4, 0.9, 9.2), 0.2, c("wood"), Vector3(0, 5.4, 0))
	var bolt := group(Vector3(0.3, 5.45, 0), Vector3(0, 90, 0), g)
	for p in [[Vector3(-0.35, 0.18, 0), 30.0], [Vector3(0.0, 0.0, 0), -30.0], [Vector3(0.35, -0.18, 0), 30.0]]:
		box(bolt, Vector3(0.55, 0.16, 0.12), 0.05, ArtKit.gun(&"bouncy"), p[0], Vector3(0, 0, p[1]))


# --- far away ---------------------------------------------------------------------------------------

func _build_backdrop() -> void:
	# Rolling hazy hills.
	var hill := ArtKit.sphere(1.0, 24)
	var x := YardLevel.LEFT - 40.0
	while x < YardLevel.RIGHT + 40.0:
		var s := _rng.randf_range(9.0, 16.0)
		add("hill", hill, xf(Vector3(x, -2.0, _rng.randf_range(-62.0, -50.0)), Vector3.ZERO, Vector3(s * 1.6, s * 0.45, s)), haze(c("ground").lerp(c("leaf"), 0.25), 0.45), false)
		x += s * 1.6
	# Round trees behind the fence in the pond and barn stretches.
	for tx in [-6.0, 2.5, 7.0, 31.0, -44.0]:
		var at := Vector3(tx + _rng.randf_range(-1, 1), 0, _rng.randf_range(-11.0, -8.0))
		var hgt := _rng.randf_range(3.5, 5.0)
		add("trunk", ArtKit.cyl(1.0, 1.0, 0.7, 10), xf(at + Vector3(0, hgt * 0.5, 0), Vector3.ZERO, Vector3(0.28, hgt, 0.28)), c("wood").darkened(0.15))
		for k in 4:
			var p := at + Vector3(_rng.randf_range(-1.2, 1.2), hgt + _rng.randf_range(0.2, 1.4), _rng.randf_range(-0.6, 0.6))
			add("leaves", hill, xf(p, Vector3.ZERO, Vector3.ONE * _rng.randf_range(1.2, 1.7)), haze(c("leaf"), 0.12))
	# The junk piles behind the fence: rusty humps over the front gate and the scrap heap, smaller by the tower.
	var cols := [c("rust"), c("rust_dark"), c("metal"), c("car"), c("rubber"), c("crate"), c("enamel"), c("denim")]
	var junk := ArtKit.rbox(Vector3(1, 1, 1), 0.18, 3)
	var tyre := ArtKit.torus(0.55, 1.0, 20)
	var hump_at := func(jx: float) -> float:
		return 4.2 * exp(-pow((jx + 19.0) / 7.0, 2)) + 2.6 * exp(-pow((jx + 40.0) / 5.0, 2)) + 2.2 * exp(-pow((jx - 40.0) / 6.0, 2)) + 0.9
	# Dirt-and-rust mounds under the junk so the piles are solid, not floating.
	var mound := ArtKit.sphere(1.0, 20)
	for mx in [-44.0, -38.0, -27.0, -21.0, -15.0, -9.0, 36.0, 44.0]:
		var hh: float = hump_at.call(mx)
		add("mound", mound, xf(Vector3(mx, 0.0, -10.0), Vector3.ZERO, Vector3(5.5, hh * 0.85, 3.5)), haze(c("rust_dark").lerp(c("ground_dark"), 0.5), 0.2))
	for i in 240:
		var jx := _rng.randf_range(YardLevel.LEFT - 4.0, YardLevel.RIGHT + 4.0)
		if jx > 13.0 and jx < 30.5 or (jx > -3.0 and jx < 12.0 and i % 3):
			continue   # the barn; thinner behind the pond
		var hump: float = hump_at.call(jx)
		var p := Vector3(jx, hump * pow(_rng.randf(), 0.7) * 0.95, _rng.randf_range(-12.5, -7.0))
		var hz := remap(p.z, -6.0, -13.0, 0.1, 0.32)
		var rot := Vector3(_rng.randf_range(-20, 20), _rng.randf_range(-40, 40), _rng.randf_range(-30, 30))
		if i % 6 == 5:
			add("junk_tyre", tyre, xf(p, rot + Vector3(80, 0, 0), Vector3.ONE * 0.7), haze(c("rubber"), hz))
		else:
			var sz := Vector3(_rng.randf_range(0.8, 2.2), _rng.randf_range(0.6, 1.5), _rng.randf_range(0.8, 1.8))
			add("junk", junk, xf(p, rot, sz), haze(cols[i % cols.size()], hz))


# --- zones ------------------------------------------------------------------------------------------

func _build_front_gate() -> void:
	# The notice board the goal cards hang on.
	var b := group(Vector3(-45.5, 0, -1.3))
	for x in [-1.25, 1.25]:
		box(b, Vector3(0.22, 4.4, 0.22), 0.06, c("fence_dark"), Vector3(x, 2.2, 0))
	box(b, Vector3(2.9, 3.0, 0.16), 0.08, c("wood"), Vector3(0, 2.55, 0))
	box(b, Vector3(3.3, 0.22, 0.6), 0.08, c("rust_dark"), Vector3(0, 4.15, 0.1), Vector3(-12, 0, 0))
	for y in [1.2, 3.9]:
		box(b, Vector3(3.1, 0.14, 0.2), 0.04, c("fence_dark"), Vector3(0, y, 0.02))
	# The Reset Yard sign: a yellow board with a round "start again" arrow.
	var s := level.reset_sign
	box(s, Vector3(0.16, 1.7, 0.16), 0.05, c("fence_dark"), Vector3(0, 0.85, 0))
	box(s, Vector3(1.35, 0.95, 0.12), 0.12, ArtKit.gun(&"bouncy").lerp(c("cream"), 0.25), Vector3(0, 1.75, 0))
	box(s, Vector3(1.45, 1.05, 0.08), 0.12, c("ink"), Vector3(0, 1.75, -0.03))
	var arrow := group(Vector3(0, 1.75, 0.08), Vector3.ZERO, s)
	var ring := put(arrow, ArtKit.torus(0.2, 0.3, 24), c("ink"), Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, 0.5, 1))
	ring.name = "Swirl"
	put(arrow, ArtKit.cyl(0.14, 0.2, 0.0, 12), c("ink"), Vector3(0.25, 0.08, 0), Vector3(0, 0, 180), Vector3(1, 1, 0.5))
	box(arrow, Vector3(0.14, 0.14, 0.06), 0.03, ArtKit.gun(&"bouncy").lerp(c("cream"), 0.25), Vector3(0.25, 0.2, 0.02))
	# The tire pile Chuck naps in.
	var tp := level.tire_pile
	var tyre := ArtKit.torus(0.3, 0.62, 28)
	for p in [Vector3(-0.6, 0.2, 0), Vector3(0.6, 0.2, 0.05), Vector3(0.0, 0.6, -0.05), Vector3(1.5, 0.2, -0.1), Vector3(0.1, 1.0, 0.0)]:
		put(tp, tyre, c("rubber"), p, Vector3(_rng.randf_range(-6, 6), _rng.randf_range(0, 90), _rng.randf_range(-6, 6)), Vector3(1, 1.2, 1))
	# A wheel-less old pram and a pair of oil cans by the gate (scenery, behind the play line).
	for k in 3:
		add("can", ArtKit.cyl(1.0, 1.0, -1.0, 14), xf(Vector3(-29.5 + k * 0.55, 0.35, -3.7 + k * 0.1), Vector3.ZERO, Vector3(0.24, 0.7, 0.24)), [c("teal"), c("mustard"), c("rust")][k])


func _build_scrap_heap() -> void:
	# The climbable mound: a block of crushed scrap with a bent metal ramp up its left side.
	var m := group(Vector3(-21.0, 0, 0))
	box(m, Vector3(5.0, 1.6, 4.8), 0.18, c("metal").lerp(c("rust"), 0.35), Vector3(0, 0, 0))
	var bits := [c("car"), c("enamel"), c("rust_dark"), c("denim"), c("metal"), c("mustard")]
	for i in 16:
		var p := Vector3(_rng.randf_range(-2.3, 2.3), _rng.randf_range(-0.6, 0.6), 2.42)
		add("scrap", ArtKit.rbox(Vector3(1, 1, 1), 0.2, 2), xf(m.position + p, Vector3(0, 0, _rng.randf_range(-30, 30)), Vector3(_rng.randf_range(0.4, 1.1), _rng.randf_range(0.2, 0.45), 0.12)), bits[i % bits.size()])
	var ramp := group(Vector3(-24.0, 0.3, 0), Vector3(0, 0, 22))
	for r in 9:
		put(ramp, ArtKit.cyl(0.14, 2.4, -1.0, 10), c("rust") if r % 2 else c("rust").lerp(c("metal"), 0.4), Vector3(0, 0.12, -2.25 + r * 0.56), Vector3(0, 0, 90), Vector3(1, 1, 0.5))
	# The crane, with its hook hanging over the heap.
	var cr := group(Vector3(-13.0, 0, -2.6))
	var paint := c("mustard")
	box(cr, Vector3(2.2, 0.5, 2.0), 0.12, c("rubber"), Vector3(0, 0.25, 0))
	box(cr, Vector3(1.4, 1.4, 1.4), 0.25, paint, Vector3(0.3, 1.2, 0))
	box(cr, Vector3(0.7, 0.6, 1.42), 0.12, c("sky_horizon").lerp(c("pond"), 0.4), Vector3(0.55, 1.35, 0))
	for z in [-0.3, 0.3]:
		for x in [-0.3, 0.3]:
			ArtKit.rod(cr, Vector3(x, 1.8, z), Vector3(x * 0.6, 9.0, z * 0.6), 0.07, paint)
	for k in 9:
		var y := 2.2 + k * 0.8
		ArtKit.rod(cr, Vector3(-0.28, y, 0.28), Vector3(0.28, y + 0.6, 0.28), 0.035, paint.darkened(0.1))
	box(cr, Vector3(6.6, 0.45, 0.5), 0.12, paint, Vector3(-2.3, 9.1, 0))
	box(cr, Vector3(1.2, 0.9, 0.8), 0.15, c("metal").darkened(0.2), Vector3(1.2, 8.75, 0))
	ArtKit.rod(cr, Vector3(-4.8, 8.9, 0), Vector3(-4.8, 5.6, 0), 0.025, c("ink"))
	var hook := group(Vector3(-4.8, 5.4, 0), Vector3.ZERO, cr)
	box(hook, Vector3(0.45, 0.4, 0.3), 0.1, c("metal"), Vector3(0, 0.1, 0))
	put(hook, ArtKit.torus(0.16, 0.26, 20), c("metal").darkened(0.15), Vector3(0, -0.3, 0), Vector3(90, 0, 0))
	# The conveyor belt by the car (looks only for now: no gameplay node yet).
	var cv := group(Vector3(-25.0, 0, -3.1))
	box(cv, Vector3(4.4, 0.18, 1.1), 0.06, c("rubber"), Vector3(0, 1.15, 0), Vector3(0, 0, -6))
	for x in [-2.2, 2.2]:
		put(cv, ArtKit.cyl(0.18, 1.2, -1.0, 14), c("metal"), Vector3(x, 1.15 - x * 0.105, 0), Vector3(90, 0, 0))
	for x in [-1.8, 0.0, 1.8]:
		for z in [-0.45, 0.45]:
			box(cv, Vector3(0.12, 1.1 - x * 0.1, 0.12), 0.04, c("rust_dark"), Vector3(x, (1.1 - x * 0.1) * 0.5, z))
	box(cv, Vector3(0.35, 0.9, 0.35), 0.06, c("metal").darkened(0.2), Vector3(2.8, 0.45, 0.4))
	put(cv, ArtKit.cyl(0.2, 0.12, -1.0, 16), c("teal"), Vector3(2.8, 0.95, 0.4))


func _build_pond_props() -> void:
	# The dock: planks across on stilts.
	var d := group(Vector3(-6.5, 0.15, 0))
	for i in 10:
		var x := -2.25 + i * 0.5
		add("dock", ArtKit.rbox(Vector3(1, 1, 1), 0.12, 2), xf(d.position + Vector3(x, 0, 0), Vector3(0, _rng.randf_range(-1.5, 1.5), 0), Vector3(0.46, 0.3, 2.1)), c("wood_light").lerp(c("fence_dark"), _rng.randf_range(0, 0.3)))
	for x in [-1.0, 1.0, 2.4]:
		for z in [-0.9, 0.9]:
			add("stilt", ArtKit.cyl(1.0, 1.0, -1.0, 10), xf(Vector3(-6.5 + x, (YardLevel.POND_FLOOR + 0.3) * 0.5, z), Vector3.ZERO, Vector3(0.14, absf(YardLevel.POND_FLOOR) + 0.3, 0.14)), c("fence_dark"))
	put(self, ArtKit.cyl(0.16, 0.5, -1.0, 12), c("rubber"), Vector3(-4.3, 0.55, -0.75))
	# Lily pads and reeds at the back of the pond.
	for i in 6:
		var p := Vector3(_rng.randf_range(-6.5, 7.0), YardLevel.WATER_Y + 0.03, _rng.randf_range(-3.8, -2.6))
		add("pad", ArtKit.cyl(1.0, 1.0, -1.0, 14), xf(p, Vector3(0, _rng.randf_range(0, 360), 0), Vector3(0.45, 0.04, 0.45) * _rng.randf_range(0.8, 1.3)), c("leaf").darkened(0.05), false)
	for i in 22:
		var side := -1.0 if i % 2 else 1.0
		var x := side * _rng.randf_range(7.0, 9.4)
		var h := _rng.randf_range(1.0, 2.0)
		var p := Vector3(x, h * 0.5 - 0.1, _rng.randf_range(-4.4, -3.4))
		add("reed", ArtKit.cyl(1.0, 1.0, 0.4, 6), xf(p, Vector3(_rng.randf_range(-8, 8), 0, _rng.randf_range(-8, 8)), Vector3(0.05, h, 0.05)), c("leaf").lerp(c("ground"), 0.35), false)
		if i % 3 == 0:
			add("cattail", ArtKit.sphere(1.0, 8), xf(p + Vector3(0, h * 0.42, 0), Vector3.ZERO, Vector3(0.08, 0.24, 0.08)), c("wood").darkened(0.2), false)


func _build_barn() -> void:
	# A faded teal barn with cream trim and a rusty roof (teal, not red: red is Chuck's).
	var b := group(Vector3(22.0, 0, -8.5))
	var wall := c("teal").lerp(c("enamel"), 0.2)
	var w := 15.0
	var dpt := 7.0
	box(b, Vector3(w, 7.0, dpt), 0.15, wall, Vector3(0, 3.5, 0))
	# Board seams.
	for i in 25:
		add("seam", ArtKit.rbox(Vector3(1, 1, 1), 0.3, 2), xf(b.position + Vector3(-w * 0.5 + 0.3 + i * 0.6, 3.5, dpt * 0.5 + 0.01), Vector3.ZERO, Vector3(0.05, 6.9, 0.04)), wall.darkened(0.12), false)
	# Gable and roof.
	var gable := PrismMesh.new()
	gable.size = Vector3(w, 3.2, dpt - 0.2)
	put(b, gable, wall, Vector3(0, 8.6, 0))
	for s in [-1.0, 1.0]:
		box(b, Vector3(w * 0.5 + 0.6, 0.3, dpt + 0.8), 0.1, c("rust"), Vector3(s * w * 0.27, 8.75, 0), Vector3(0, 0, -s * 23.1))
	# Trim and the big X doors.
	box(b, Vector3(w + 0.2, 0.25, 0.2), 0.06, c("barn_trim"), Vector3(0, 7.0, dpt * 0.5 + 0.05))
	var door := group(Vector3(-2.0, 0, dpt * 0.5 + 0.1), Vector3.ZERO, b)
	box(door, Vector3(4.6, 4.6, 0.2), 0.08, c("barn_trim"), Vector3(0, 2.3, 0))
	box(door, Vector3(4.0, 4.0, 0.22), 0.08, wall.darkened(0.12), Vector3(0, 2.3, 0.02))
	for s in [-1.0, 1.0]:
		box(door, Vector3(5.4, 0.22, 0.26), 0.06, c("barn_trim"), Vector3(0, 2.3, 0.05), Vector3(0, 0, s * 45))
	# Loft door, with the hay hoist beam poking out over the loft.
	box(b, Vector3(2.2, 2.0, 0.2), 0.06, c("barn_trim"), Vector3(4.0, 5.4, dpt * 0.5 + 0.1))
	box(b, Vector3(1.8, 1.6, 0.22), 0.06, c("ink").lerp(wall, 0.4), Vector3(4.0, 5.4, dpt * 0.5 + 0.12))
	box(b, Vector3(0.3, 0.3, 4.0), 0.06, c("wood"), Vector3(4.0, 7.3, dpt * 0.5 + 2.0))
	# The hayloft platform: planks on posts.
	var lf := group(Vector3(26.0, 4.0, 0))
	for i in 9:
		add("loft", ArtKit.rbox(Vector3(1, 1, 1), 0.1, 2), xf(lf.position + Vector3(-2.25 + i * 0.56, 0, 0), Vector3(0, _rng.randf_range(-1, 1), 0), Vector3(0.54, 0.4, 4.85)), c("wood_light").lerp(c("fence_dark"), _rng.randf_range(0.0, 0.3)))
	for x in [-2.35, 2.35]:
		box(lf, Vector3(0.28, 4.0, 0.28), 0.06, c("fence_dark"), Vector3(x, -2.0, -2.2))
		ArtKit.rod(lf, Vector3(x, -0.2, -2.2), Vector3(x * 0.5, -0.2, -0.2), 0.08, c("fence_dark"))
	for i in 7:
		add("straw", ArtKit.cyl(1.0, 1.0, 0.2, 5), xf(lf.position + Vector3(_rng.randf_range(-2.3, 2.3), -0.35, 2.3), Vector3(0, 0, _rng.randf_range(-15, 15)), Vector3(0.04, _rng.randf_range(0.3, 0.6), 0.04)), c("hay"), false)
	# Steps up to the loft: planks on posts.
	for i in 3:
		var at := Vector3(21.2 + i * 0.8, 1.0 + i * 1.0, 0)
		box(self, Vector3(0.95, 0.3, 2.05), 0.08, c("wood_light"), at)
		box(self, Vector3(0.16, at.y, 0.16), 0.04, c("fence_dark"), Vector3(at.x, at.y * 0.5, -0.9))
	# See-saw: a painted board on a wooden wedge.
	var wedge := PrismMesh.new()
	wedge.size = Vector3(1.0, 0.95, 1.2)
	put(self, wedge, c("wood"), Vector3(18.0, 0.47, 0))
	var plank := level.get_node_or_null("Static/SeesawPlank") as Node3D
	if plank:
		var pm := ArtKit.put(plank, ArtKit.rbox(Vector3(5.0, 0.22, 1.2), 0.1), c("mustard"), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.0, true)
		pm.name = "Board"
		for s in [-1.0, 1.0]:
			box(plank, Vector3(0.6, 0.24, 1.22), 0.08, c("teal"), Vector3(s * 2.2, 0, 0))
			ArtKit.rod(plank, Vector3(s * 1.7, 0.1, -0.4), Vector3(s * 1.7, 0.45, -0.4), 0.04, c("metal"))
			ArtKit.rod(plank, Vector3(s * 1.7, 0.45, -0.55), Vector3(s * 1.7, 0.45, -0.25), 0.04, c("metal"))
	# Trampoline by the barn wall (scenery for now: no gameplay node yet).
	var t := group(Vector3(11.5, 0, -3.4))
	put(t, ArtKit.torus(1.15, 1.3, 32), c("teal"), Vector3(0, 0.75, 0))
	put(t, ArtKit.cyl(1.15, 0.04, -1.0, 28), c("rubber"), Vector3(0, 0.74, 0))
	for k in 6:
		var a := TAU * k / 6.0
		ArtKit.rod(t, Vector3(cos(a) * 1.2, 0.75, sin(a) * 1.2), Vector3(cos(a) * 1.25, 0.0, sin(a) * 1.25), 0.05, c("metal"))
	# Hay bales stacked by the barn door.
	for p in [Vector3(16.6, 0.4, -4.0), Vector3(17.9, 0.4, -4.1), Vector3(17.2, 1.2, -4.05)]:
		box(self, Vector3(1.2, 0.8, 0.8), 0.15, c("hay"), p)
		box(self, Vector3(0.06, 0.82, 0.82), 0.02, c("wood").darkened(0.2), p + Vector3(-0.3, 0, 0))
		box(self, Vector3(0.06, 0.82, 0.82), 0.02, c("wood").darkened(0.2), p + Vector3(0.3, 0, 0))


func _build_tower() -> void:
	# The junk tower: scaffold poles holding grated decks, with a stack of junk behind.
	var pole := c("rust").lerp(c("metal"), 0.45)
	for i in 3:
		var y := 3.0 + i * 3.0
		var at := Vector3(41.0 + (i % 2) * 1.5, y, 0)
		box(self, Vector3(4.05, 0.4, 4.85), 0.08, c("metal"), at)
		box(self, Vector3(4.1, 0.12, 0.14), 0.04, c("mustard"), at + Vector3(0, 0.2, 2.45))
		for x in [-1.85, 1.85]:
			add("pole", ArtKit.cyl(1.0, 1.0, -1.0, 10), xf(Vector3(at.x + x, y * 0.5, -2.25), Vector3.ZERO, Vector3(0.12, y, 0.12)), pole)
		var step := Vector3(45.5 - (i % 2) * 8.0, y - 1.5, 0)
		box(self, Vector3(1.45, 0.3, 2.05), 0.06, c("metal").darkened(0.08), step)
		add("pole", ArtKit.cyl(1.0, 1.0, -1.0, 10), xf(Vector3(step.x, step.y * 0.5, -0.9), Vector3.ZERO, Vector3(0.1, step.y, 0.1)), pole)
	var cols := [c("rust"), c("crate"), c("enamel"), c("denim"), c("rust_dark"), c("mustard")]
	var y := 0.0
	var k := 0
	while y < 12.0:
		var h := _rng.randf_range(1.0, 1.8)
		var w := _rng.randf_range(2.5, 4.5)
		add("tower_junk", ArtKit.rbox(Vector3(1, 1, 1), 0.15, 3), xf(Vector3(41.5 + _rng.randf_range(-0.8, 0.8), y + h * 0.5, -3.6), Vector3(0, 0, _rng.randf_range(-4, 4)), Vector3(w, h, 1.4)), cols[k % cols.size()])
		y += h
		k += 1
	# The fan on top (looks only for now: zap-on wind needs a gameplay node).
	var f := group(Vector3(41.5, 13.4, -3.1))
	put(f, ArtKit.torus(1.1, 1.25, 32), c("metal"), Vector3.ZERO, Vector3(90, 0, 0))
	put(f, ArtKit.cyl(0.25, 0.4, -1.0, 16), c("metal").darkened(0.2), Vector3.ZERO, Vector3(90, 0, 0))
	fan = group(Vector3(0, 0, 0.12), Vector3.ZERO, f)
	for a in 4:
		box(fan, Vector3(0.38, 1.0, 0.06), 0.15, c("teal"), Vector3(0, 0.55, 0).rotated(Vector3.BACK, a * PI * 0.5), Vector3(0, 0, a * 90))
	box(f, Vector3(0.3, 1.4, 0.3), 0.06, pole, Vector3(0, -1.3, -0.2))
	# The pipe: a see-through tube along the pipe's floor and roof, with metal bands.
	var dir := Vector3(cos(deg_to_rad(32.0)), sin(deg_to_rad(32.0)), 0)
	var n := Vector3(-dir.y, dir.x, 0)
	var mid := Vector3(35.0, 5.0, 0) + n * 0.57 + dir * 0.6
	var tube := ArtKit.put_mat(self, ArtKit.cyl(0.78, 9.6, -1.0, 28), ArtKit.glass(Color(c("pond").lightened(0.3), 0.28)), mid)
	tube.basis = ArtKit.basis_y(dir)
	tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var floor_mi := box(self, Vector3(9.0, 0.25, 1.5), 0.08, c("metal"), Vector3(35.0, 5.0, 0), Vector3(0, 0, 32))
	floor_mi.name = "PipeFloorLook"
	for t in [-4.7, -2.4, 0.0, 2.4, 4.7]:
		var band := put(self, ArtKit.torus(0.76, 0.88, 28), c("rust").lerp(c("metal"), 0.3), mid + dir * t)
		band.basis = ArtKit.basis_y(dir)
	for t in [-1.8, 2.6]:
		ArtKit.rod(self, mid + dir * t - n * 0.8, Vector3((mid + dir * t).x, 0.0, -0.6), 0.08, pole)


# --- little things on the ground ---------------------------------------------------------------------

func _scatter() -> void:
	var pebble := ArtKit.sphere(1.0, 8)
	for i in 260:
		var x := _rng.randf_range(YardLevel.LEFT + 0.5, YardLevel.RIGHT - 0.5)
		if x > YardLevel.POND.x - 0.5 and x < YardLevel.POND.y + 0.5:
			continue
		var p := Vector3(x, 0.01, _rng.randf_range(-4.5, 3.8))
		var s := _rng.randf_range(0.05, 0.14)
		var col := c("ground_dark") if i % 4 else (c("metal") if i % 8 else c("rust"))
		add("pebble", pebble, xf(p, Vector3(0, _rng.randf_range(0, 360), 0), Vector3(1.3, 0.5, 1.0) * s), col, false)
	var tuft := ArtKit.cyl(1.0, 1.0, 0.1, 5)
	for i in 120:
		var x := _rng.randf_range(YardLevel.LEFT + 0.5, YardLevel.RIGHT - 0.5)
		if (x > YardLevel.POND.x - 0.5 and x < YardLevel.POND.y + 0.5) or (x > 14.5 and x < 29.5):
			continue
		var base := Vector3(x, 0.0, FENCE_Z + _rng.randf_range(0.15, 0.6))
		for k in 3:
			add("tuft", tuft, xf(base + Vector3(k * 0.06, 0.15, 0), Vector3(0, 0, (k - 1) * 18.0), Vector3(0.035, 0.35, 0.035)), c("leaf").lerp(c("hay"), 0.5), false)
	# A few dark smudges of oil and shade on the dirt.
	for i in 30:
		var x := _rng.randf_range(YardLevel.LEFT + 1, YardLevel.RIGHT - 1)
		if x > YardLevel.POND.x - 1 and x < YardLevel.POND.y + 1:
			continue
		add("smudge", ArtKit.cyl(1.0, 1.0, -1.0, 16), xf(Vector3(x, 0.003, _rng.randf_range(-3.5, 3.0)), Vector3.ZERO, Vector3(_rng.randf_range(0.6, 1.4), 0.01, _rng.randf_range(0.3, 0.7))), c("ground").darkened(0.08), false)
