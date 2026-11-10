## A round pink pig with a snout, floppy ears and a curly tail. Front is +x.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var pink := K.c("pink")
	var by := -d.size.y * 0.5
	A.part(root, K.rbox(Vector3(1.0, 0.72, 0.76), 0.3), pink, Vector3(-0.1, by + 0.5, 0))
	for lx in [-0.4, 0.2]:
		for lz in [-0.22, 0.22]:
			A.part(root, K.cyl(0.11, 0.25), pink.darkened(0.08), Vector3(lx, by + 0.12, lz))
			A.detail(root, K.cyl(0.115, 0.07), K.c("rust_dark"), Vector3(lx, by + 0.04, lz))
	var head := K.group(root, Vector3(0.52, by + 0.58, 0))
	A.part(head, K.sphere(0.34), pink, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.95, 1.05))
	A.part(head, K.cyl(0.16, 0.2), pink.darkened(0.12), Vector3(0.3, -0.06, 0), Vector3(0, 0, 90))
	A.detail(head, K.cyl(0.155, 0.04), pink.darkened(0.25), Vector3(0.41, -0.06, 0), Vector3(0, 0, 90))
	for nz in [-0.06, 0.06]:
		A.detail(head, K.sphere(0.03, 8), K.c("ink"), Vector3(0.435, -0.06, nz))
	for ez in [-0.2, 0.2]:
		A.part(head, K.sphere(0.14), pink.darkened(0.1), Vector3(-0.05, 0.3, ez), Vector3(ez * 100, 0, 0), Vector3(0.6, 1.0, 0.45))
	# curly tail
	A.part(root, K.torus(0.05, 0.08), pink.darkened(0.2), Vector3(-0.62, by + 0.62, 0))
	K.rod(root, Vector3(-0.58, by + 0.55, 0), Vector3(-0.64, by + 0.6, 0), 0.03, pink.darkened(0.2))
