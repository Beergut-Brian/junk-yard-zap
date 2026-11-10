## The junk car: a rounded rusty-orange body, a cabin with sky-glass windows, four chunky wheels,
## chrome bumpers, a cream headlight and rust patches. Faces right (+x); the face sits on the side
## of the hood, above the front wheel. The cabin pokes a little above the collision box.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var body := K.c("car")
	var rust := K.c("rust_dark")
	var hx := s.x * 0.5
	var hz := s.z * 0.5
	var bot := -s.y * 0.5
	var wr := 0.29
	var wy := bot + wr
	# Wheels first so the body's arches sit over them.
	for wx in [-hx + 0.62, hx - 0.62]:
		for wz in [-hz + 0.14, hz - 0.14]:
			A.wheel(root, wr, 0.26, Vector3(wx, wy, wz))
	A.part(root, K.rbox(Vector3(s.x, 0.6, s.z - 0.14), 0.24), body, Vector3(0, bot + 0.5, 0))
	# Cabin + roof.
	A.part(root, K.rbox(Vector3(1.35, 0.52, s.z - 0.3), 0.2), body.lightened(0.05), Vector3(-0.25, bot + 0.98, 0))
	var sky := K.c("sky_horizon")
	for wz in [-1.0, 1.0]:
		A.detail(root, K.rbox(Vector3(0.5, 0.28, 0.04), 0.06), sky, Vector3(-0.53, bot + 1.0, wz * (hz - 0.15)))
		A.detail(root, K.rbox(Vector3(0.5, 0.28, 0.04), 0.06), sky, Vector3(0.03, bot + 1.0, wz * (hz - 0.15)))
	A.detail(root, K.rbox(Vector3(0.04, 0.3, s.z - 0.5), 0.05), sky, Vector3(0.43, bot + 1.0, 0), Vector3(0, 0, -8))
	# Bumpers and lights.
	for bx in [-1.0, 1.0]:
		A.part(root, K.rbox(Vector3(0.14, 0.14, s.z - 0.2), 0.06), K.c("metal"), Vector3(bx * (hx + 0.02), bot + 0.32, 0))
	A.detail(root, K.sphere(0.09, 12), K.c("cream"), Vector3(hx - 0.02, bot + 0.6, hz - 0.3), Vector3.ZERO, Vector3(0.6, 1, 1))
	A.detail(root, K.sphere(0.07, 12), K.c("mustard"), Vector3(-hx + 0.01, bot + 0.6, hz - 0.3), Vector3.ZERO, Vector3(0.6, 1, 1))
	# Rust patches on the side facing the camera, and one on the roof.
	A.detail(root, K.sphere(0.16, 12), rust, Vector3(-0.95, bot + 0.62, hz - 0.08), Vector3.ZERO, Vector3(1.3, 0.8, 0.2))
	A.detail(root, K.sphere(0.1, 12), K.c("rust"), Vector3(-0.3, bot + 0.42, hz - 0.08), Vector3.ZERO, Vector3(1.2, 0.7, 0.2))
	A.detail(root, K.sphere(0.12, 12), rust, Vector3(-0.5, bot + 1.24, 0.1), Vector3.ZERO, Vector3(1.4, 0.15, 1.0))
	# Door seam and handle.
	A.detail(root, K.rbox(Vector3(0.03, 0.42, 0.03), 0.01), body.darkened(0.3), Vector3(0.28, bot + 0.55, hz - 0.06))
	A.detail(root, K.rbox(Vector3(0.14, 0.04, 0.04), 0.015), K.c("metal"), Vector3(0.12, bot + 0.68, hz - 0.05))
