## The side-view yard strip for the risk prototype: ground, two fence walls, an invisible lid (so
## balloons and launches stay in the yard), a key light and an environment. Built in code so tests
## can drop a strip into any tree.
class_name YardStrip
extends Node3D

const WIDTH := 56.0      # fence to fence
const DEPTH := 8.0
const FENCE_H := 4.0     # the visible fence
const LID_Y := 18.0      # invisible ceiling and fence extensions up to here


func _ready() -> void:
	var ground_mat := _mat(Color(0.55, 0.42, 0.3))
	_box("Ground", Vector3(0, -2.0, 0), Vector3(WIDTH + 4, 4, DEPTH), ground_mat)
	var fence_mat := _mat(Color(0.5, 0.5, 0.55))
	for side in [-1, 1]:
		var x: float = side * WIDTH * 0.5
		_box("Fence%s" % ("L" if side < 0 else "R"), Vector3(x + side * 0.25, FENCE_H * 0.5, 0), Vector3(0.5, FENCE_H, DEPTH), fence_mat)
		_box("Wall%s" % ("L" if side < 0 else "R"), Vector3(x + side * 0.25, (FENCE_H + LID_Y) * 0.5, 0), Vector3(0.5, LID_Y - FENCE_H, DEPTH), null)
	_box("Lid", Vector3(0, LID_Y + 0.25, 0), Vector3(WIDTH + 4, 0.5, DEPTH), null)
	# A back wall for looks only (no collision), so the strip reads as a diorama.
	var back := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(WIDTH + 4, 10, 0.2)
	back.mesh = bm
	back.material_override = _mat(Color(0.55, 0.75, 0.9))
	back.position = Vector3(0, 4.5, -DEPTH * 0.5)
	add_child(back)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.8, 0.95)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.5
	add_child(env)


func _box(n: String, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	if mat:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		b.add_child(mi)
	add_child(b)
	return b


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
