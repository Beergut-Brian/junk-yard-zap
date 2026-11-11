## PT10-2: every gun's hit looks like what the gun does, so a kid sees which gun did what from the
## sofa. One-shot CPU particles and a ring, in the gun's beam colour, that free themselves:
##   size     two rings pushing out and sparks floating up (it got bigger)
##   grab     a ring that sucks in and sparkles swirling to the middle (got hold of it)
##   bouncy   a squashy ring and little balls that bounce away high
##   balloon  bubbles that grow as they float up
##   freeze   ice shards and a frosty white ring, slow and glinting
##   glue     fat goo blobs that drip and a flat splat
##   magnet   fast electric sparks streaking out, a buzzing double ring
class_name GunHits
extends RefCounted

## Tests: the last kind played.
static var last_kind := -1


static func play(tree: SceneTree, kind: GunData.Kind, at: Vector3, col: Color, radius := 1.0) -> void:
	last_kind = kind
	Fx.bursts += 1
	if tree == null or tree.current_scene == null:
		return
	var r := clampf(radius, 0.4, 3.0)
	match kind:
		GunData.Kind.SIZE:
			Fx.ring(tree, at, col, r)
			_ring(tree, at, col.lightened(0.4), r * 0.6, r * 2.2, 0.45)
			_burst(tree, at, _sphere(0.07 * r), col.lightened(0.3), 14, 0.8, 1.0, 2.5, Vector3(0, 3, 0), Vector3.UP, 60.0)
		GunData.Kind.GRAB:
			_ring(tree, at, col, r * 2.2, r * 0.3, 0.35)
			var p := _burst(tree, at, _sphere(0.06 * r), col.lightened(0.35), 18, 0.5, 2.0, 3.0, Vector3.ZERO, Vector3.UP, 180.0)
			if p:
				p.radial_accel_min = -12.0
				p.radial_accel_max = -9.0
				p.tangential_accel_min = 8.0
				p.tangential_accel_max = 10.0
		GunData.Kind.BOUNCY:
			_ring(tree, at, col, r * 0.4, r * 1.8, 0.4, Vector3(1.0, 1.0, 0.55))
			_burst(tree, at, _sphere(0.12 * r), col, 7, 1.1, 5.0, 8.0, Vector3(0, -16, 0), Vector3.UP, 35.0)
		GunData.Kind.BALLOON:
			var p := _burst(tree, at, _sphere(0.11 * r), Color(col.lightened(0.45), 0.75), 12, 1.4, 0.4, 1.2, Vector3(0, 3.5, 0), Vector3.UP, 70.0)
			if p:
				var c := Curve.new()
				c.add_point(Vector2(0, 0.3))
				c.add_point(Vector2(0.7, 1.3))
				c.add_point(Vector2(1, 0.0))
				p.scale_amount_curve = c
			Fx.ring(tree, at, col, r)
		GunData.Kind.FREEZE:
			_ring(tree, at, Color(0.92, 0.98, 1.0), r * 0.4, r * 1.7, 0.6)
			var b := BoxMesh.new()
			b.size = Vector3(0.05, 0.22, 0.05) * r
			var p := _burst(tree, at, b, col.lightened(0.5), 16, 0.9, 1.5, 3.2, Vector3(0, -3, 0), Vector3.UP, 180.0)
			if p:
				p.particle_flag_align_y = true
		GunData.Kind.GLUE:
			_ring(tree, at, col, r * 0.5, r * 1.4, 0.5, Vector3(1.0, 1.0, 0.3))
			_burst(tree, at + Vector3(0, 0.3 * r, 0), _sphere(0.13 * r), col, 9, 0.9, 1.0, 2.2, Vector3(0, -14, 0), Vector3.UP, 50.0)
		GunData.Kind.MAGNET:
			Fx.ring(tree, at, col, r)
			_ring(tree, at, Color(1, 1, 1, 0.9), r * 0.3, r * 1.3, 0.2)
			var b := BoxMesh.new()
			b.size = Vector3(0.03, 0.3, 0.03) * r
			var p := _burst(tree, at, b, col.lightened(0.6), 20, 0.25, 6.0, 10.0, Vector3.ZERO, Vector3.UP, 180.0)
			if p:
				p.particle_flag_align_y = true


static func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 8
	m.rings = 4
	return m


static func _mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	if col.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func _burst(tree: SceneTree, at: Vector3, mesh: PrimitiveMesh, col: Color, amount: int, life: float, vmin: float, vmax: float,
		gravity: Vector3, dir: Vector3, spread: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.9
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = gravity
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	(mesh as PrimitiveMesh).material = _mat(col)
	p.mesh = mesh
	tree.current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## A flat ring in the play plane from radius a to b over secs, fading (squash: per-axis scale).
static func _ring(tree: SceneTree, at: Vector3, col: Color, a: float, b: float, secs: float, squash := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.82
	t.outer_radius = 1.0
	mi.mesh = t
	var mat := _mat(Color(col, col.a))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.rotation_degrees.x = 90
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.current_scene.add_child(mi)
	mi.global_position = at + Vector3(0, 0, 0.65)
	mi.scale = Vector3.ONE * a * squash
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * b * squash, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, secs).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)
