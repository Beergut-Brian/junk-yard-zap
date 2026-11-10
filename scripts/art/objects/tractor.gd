## A chunky farm tractor: big back wheels, small front wheels, exhaust stack. Front is +x.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var body := K.c("mustard")
	var by := -d.size.y * 0.5
	A.part(root, K.rbox(Vector3(1.1, 0.5, 0.7), 0.18), body, Vector3(0.5, by + 0.55, 0))
	A.part(root, K.rbox(Vector3(0.7, 0.5, 0.75), 0.15), body, Vector3(-0.35, by + 0.7, 0))
	A.part(root, K.rbox(Vector3(0.6, 0.42, 0.62), 0.14), K.c("teal"), Vector3(-0.4, by + 1.1, 0))
	A.detail(root, K.rbox(Vector3(0.5, 0.22, 0.64), 0.06), K.c("sky_horizon"), Vector3(-0.4, by + 1.12, 0.01))
	A.part(root, K.rbox(Vector3(0.75, 0.06, 0.8), 0.03), K.c("teal"), Vector3(-0.4, by + 1.35, 0))
	# grille and bonnet trim
	A.detail(root, K.rbox(Vector3(0.06, 0.34, 0.5), 0.02), K.c("rust_dark"), Vector3(1.07, by + 0.58, 0))
	A.part(root, K.cyl(0.07, 0.45), K.c("rust_dark"), Vector3(0.75, by + 1.0, 0.2))
	A.detail(root, K.cyl(0.1, 0.05), K.c("ink"), Vector3(0.75, by + 1.25, 0.2))
	# axles and wheels (two per side, so it reads from either end)
	for z in [-0.5, 0.5]:
		A.wheel(root, 0.55, 0.22, Vector3(-0.65, by + 0.55, z))
		A.wheel(root, 0.3, 0.2, Vector3(0.85, by + 0.3, z * 0.9))
	A.part(root, K.cyl(0.06, 1.0), K.c("metal"), Vector3(-0.65, by + 0.55, 0), Vector3(90, 0, 0))
	A.detail(root, K.sphere(0.1), K.c("hay"), Vector3(1.1, by + 0.78, 0.25), Vector3.ZERO, Vector3(0.5, 1, 1))
