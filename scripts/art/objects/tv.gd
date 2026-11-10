## An old chunky TV: wood-grain cabinet, rounded glass screen, dial panel, two antennae, no logos.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var wood := d.color
	var z := s.z * 0.5
	A.part(root, K.rbox(Vector3(s.x, s.y * 0.92, s.z), 0.12), wood, Vector3(0, -s.y * 0.04, 0))
	A.part(root, K.rbox(Vector3(s.x * 0.66, s.y * 0.7, 0.05), 0.12), K.c("cream").darkened(0.1), Vector3(-s.x * 0.12, -s.y * 0.04, z))
	K.put_mat(root, K.rbox(Vector3(s.x * 0.58, s.y * 0.6, 0.06), 0.14), K.glass(Color(0.35, 0.55, 0.6, 0.9)), Vector3(-s.x * 0.12, -s.y * 0.04, z + 0.02))
	A.detail(root, K.rbox(Vector3(s.x * 0.2, s.y * 0.08, 0.02), 0.02), Color(1, 1, 1, 1), Vector3(-s.x * 0.22, s.y * 0.17, z + 0.06), Vector3(0, 0, 20))
	for y in [0.18, -0.12]:
		A.part(root, K.cyl(0.07, 0.06), K.c("rubber"), Vector3(s.x * 0.36, y * s.y, z + 0.0), Vector3(90, 0, 0))
		A.detail(root, K.rbox(Vector3(0.015, 0.07, 0.01), 0.005, 2), K.c("cream"), Vector3(s.x * 0.36, y * s.y + 0.01, z + 0.035))
	for i in 4:
		A.detail(root, K.rbox(Vector3(s.x * 0.12, 0.015, 0.01), 0.005, 2), K.c("ink"), Vector3(s.x * 0.36, -s.y * 0.32 - i * 0.03, z + 0.01))
	A.part(root, K.cyl(s.x * 0.12, 0.08, s.x * 0.1), K.c("rubber"), Vector3(0, s.y * 0.46 + 0.02, 0))
	K.rod(root, Vector3(0, s.y * 0.5, 0), Vector3(-s.x * 0.28, s.y * 0.5 + 0.34, -0.03), 0.018, K.c("metal"))
	K.rod(root, Vector3(0, s.y * 0.5, 0), Vector3(s.x * 0.24, s.y * 0.5 + 0.3, 0.03), 0.018, K.c("metal"))
	A.detail(root, K.sphere(0.04, 8), K.c("metal"), Vector3(-s.x * 0.28, s.y * 0.5 + 0.34, -0.03))
	A.detail(root, K.sphere(0.04, 8), K.c("metal"), Vector3(s.x * 0.24, s.y * 0.5 + 0.3, 0.03))
	for x in [-1.0, 1.0]:
		A.part(root, K.rbox(Vector3(0.12, 0.06, 0.12), 0.02), K.c("rubber"), Vector3(x * s.x * 0.38, -s.y * 0.5 + 0.03, 0))
