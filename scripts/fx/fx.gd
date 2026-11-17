## Juice, generic enough to lift into openjar-addons: camera shake scaled to impact mass, dust,
## zap rings, sparkles and fireworks. Static, so any node can call it; one-shot CPU particles that
## free themselves. The camera registers itself as `Fx.camera` (anything with shake(amount)).
class_name Fx
extends RefCounted

static var camera: Node
## Tests and the stress run: count bursts instead of drawing.
static var bursts := 0
## S-18: burst meshes (with their flat colour) and the ring torus, made once and shared, so a burst or a
## zap ring builds no mesh and no material during play. Same shapes, same colours: only reused.
static var _burst_meshes := {}
static var _torus: TorusMesh
const BURST_CACHE_MAX := 256
## Meshes built because the cache had none (tests).
static var meshes_made := 0


## amount 0..1. Respects the Settings "screen shake" switch.
static func shake(amount: float) -> void:
	if is_instance_valid(camera) and SettingsPanel.screen_shake():
		camera.shake(clampf(amount, 0.0, 1.0))


## Impact juice from a logical mass (kg) and a landing speed: dust, shake, impact cue band.
static func impact(tree: SceneTree, at: Vector3, mass: float, speed: float) -> void:
	var size := clampf(pow(mass, 0.33) * 0.4, 0.3, 3.0)
	burst(tree, at, Color(0.75, 0.65, 0.5, 0.8), int(6 + size * 6), size, 0.5)
	shake(clampf(mass * speed / 600.0, 0.0, 1.0))


static func burst(tree: SceneTree, at: Vector3, color: Color, amount := 16, spread := 0.6, life := 0.6) -> CPUParticles3D:
	bursts += 1
	if tree == null or tree.current_scene == null:
		return null
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = spread * 2.0
	p.initial_velocity_max = spread * 4.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.mesh = burst_mesh(0.06 * clampf(spread, 0.5, 3.0), color)
	tree.current_scene.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## The burst's dot: a low-poly sphere of radius r in a flat colour, shared by every burst that asks for the
## same pair.
static func burst_mesh(r: float, color: Color) -> SphereMesh:
	var key := "%.4f|%s" % [r, color.to_html(true)]
	var m: SphereMesh = _burst_meshes.get(key)
	if m:
		return m
	m = SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = flat_mat(color)
	_remember(key, m)
	return m


## Unshaded flat colour (alpha blended when see-through), as every burst uses.
static func flat_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


## A shared mesh by key (GunHits keeps its particle meshes here too). Bounded: fireworks pick random hues.
static func cached_mesh(key: String) -> Mesh:
	return _burst_meshes.get(key)


static func _remember(key: String, m: Mesh) -> void:
	if _burst_meshes.size() >= BURST_CACHE_MAX:
		_burst_meshes.clear()
	_burst_meshes[key] = m
	meshes_made += 1


static func remember_mesh(key: String, m: Mesh) -> void:
	_remember(key, m)


## The zap ring's torus (inner 0.85, outer 1), one for every ring.
static func torus() -> TorusMesh:
	if _torus == null:
		_torus = TorusMesh.new()
		_torus.inner_radius = 0.85
		_torus.outer_radius = 1.0
		meshes_made += 1
	return _torus


## Zap ring in the gun's colour.
static func ring(tree: SceneTree, at: Vector3, color: Color, radius := 1.0) -> void:
	bursts += 1
	if tree == null or tree.current_scene == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = torus()
	var mat := StandardMaterial3D.new()   # its own: the ring fades its alpha
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mi.material_override = mat
	mi.rotation_degrees.x = 90
	tree.current_scene.add_child(mi)
	mi.global_position = at + Vector3(0, 0, 0.6)
	mi.scale = Vector3.ONE * radius * 0.3
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 1.6, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(mi.queue_free)


static func sparkle(tree: SceneTree, at: Vector3) -> void:
	burst(tree, at, Color(1, 1, 0.8), 10, 0.5, 0.4)


static func fireworks(tree: SceneTree, at: Vector3) -> void:
	for i in 6:
		var c := Color.from_hsv(randf_range(0.09, 0.15) if randf() < 0.4 else randf_range(0.5, 0.88), 0.7, 1.0)   # never green or red
		burst(tree, at + Vector3(randf_range(-3, 3), randf_range(2, 5), 0), c, 30, 1.6, 1.2)
