## The cow: chunky white body, brown spots, pink snout, stubby legs. Body fills the box; the head pokes
## out in front (+x) where the face sits.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, _d: ObjectData) -> void:
	var white := K.c("cow")
	var spot := K.c("cow_spot")
	A.part(root, K.rbox(Vector3(1.75, 0.82, 0.82), 0.32), white, Vector3(-0.12, 0.1, 0))
	A.detail(root, K.sphere(0.26), spot, Vector3(-0.55, 0.22, 0.33), Vector3.ZERO, Vector3(1.3, 1.0, 0.45))
	A.detail(root, K.sphere(0.2), spot, Vector3(0.2, -0.05, 0.35), Vector3.ZERO, Vector3(1.2, 0.9, 0.4))
	A.detail(root, K.sphere(0.18), spot, Vector3(-0.2, 0.42, -0.1), Vector3.ZERO, Vector3(1.4, 0.5, 1.2))
	A.detail(root, K.sphere(0.12), K.c("pink"), Vector3(-0.15, -0.3, 0.0), Vector3.ZERO, Vector3(1.3, 0.8, 1.2))
	for lx in [-0.62, 0.42]:
		for lz in [-0.24, 0.24]:
			A.part(root, K.cyl(0.12, 0.42), white, Vector3(lx, -0.3, lz))
			A.detail(root, K.cyl(0.135, 0.12), spot, Vector3(lx, -0.44, lz))
	K.rod(root, Vector3(-0.98, 0.3, 0), Vector3(-1.12, -0.05, 0.05), 0.035, white)
	A.detail(root, K.sphere(0.07), spot, Vector3(-1.13, -0.08, 0.05), Vector3.ZERO, Vector3(1, 1.4, 1))
	var head := K.group(root, Vector3(1.0, 0.32, 0))
	A.part(head, K.rbox(Vector3(0.66, 0.66, 0.78), 0.26), white)
	A.part(head, K.rbox(Vector3(0.5, 0.3, 0.72), 0.13), K.c("enamel").lerp(K.gun(&"glue"), 0.45), Vector3(0.24, -0.2, 0.06))
	for nz in [0.13, 0.33]:
		A.detail(head, K.sphere(0.04, 8), K.c("ink"), Vector3(0.49, -0.17, nz))
	for hz in [-0.26, 0.26]:
		A.part(head, K.cyl(0.06, 0.22, 0.015), K.c("enamel").darkened(0.08), Vector3(-0.05, 0.42, hz), Vector3(hz * 50, 0, 0))
		A.part(head, K.sphere(0.13), white, Vector3(-0.22, 0.22, hz * 1.65), Vector3.ZERO, Vector3(0.6, 0.45, 1.0))
		A.detail(head, K.sphere(0.09), K.c("pink"), Vector3(-0.2, 0.22, hz * 1.75), Vector3.ZERO, Vector3(0.5, 0.35, 0.9))
	A.detail(head, K.sphere(0.14), spot, Vector3(0.0, 0.2, 0.33), Vector3.ZERO, Vector3(1.0, 0.8, 0.4))
