## A stubby iron cannon on a wooden carriage with two wheels. Muzzle points +x.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var iron := K.c("rubber").lerp(K.c("metal"), 0.25)
	var by := -d.size.y * 0.5
	A.part(root, K.rbox(Vector3(0.9, 0.34, 0.4), 0.1), K.c("wood"), Vector3(0.0, by + 0.38, 0))
	A.part(root, K.cyl(0.28, 1.2, 0.2), iron, Vector3(0.1, by + 0.75, 0), Vector3(0, 0, -78))
	A.part(root, K.sphere(0.2), iron, Vector3(-0.55, by + 0.7, 0))
	A.part(root, K.torus(0.16, 0.2), iron.lightened(0.1), Vector3(0.45, by + 0.83, 0), Vector3(0, 0, 12))
	A.detail(root, K.cyl(0.2, 0.04), K.c("ink"), Vector3(0.7, by + 0.82, 0), Vector3(0, 0, -78))
	for z in [-0.36, 0.36]:
		A.part(root, K.cyl(0.27, 0.12), K.c("wood_light"), Vector3(0, by + 0.27, z), Vector3(90, 0, 0))
		A.detail(root, K.cyl(0.27, 0.04), iron, Vector3(0, by + 0.27, z + signf(z) * 0.07), Vector3(90, 0, 0))
		A.detail(root, K.sphere(0.07, 10), iron, Vector3(0, by + 0.27, z + signf(z) * 0.09))
	A.part(root, K.rbox(Vector3(0.6, 0.12, 0.2), 0.04), K.c("wood"), Vector3(-0.55, by + 0.1, 0), Vector3(0, 0, 8))
	A.detail(root, K.sphere(0.04), K.c("mustard"), Vector3(0.1, by + 0.95, 0.14))
