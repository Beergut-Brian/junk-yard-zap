## A fluffy sheep: cream wool from clustered spheres, dark face and legs. Front is +x.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var wool := K.c("cream")
	var dark := K.c("cow_spot")
	var by := -d.size.y * 0.5
	for lx in [-0.3, 0.25]:
		for lz in [-0.2, 0.2]:
			A.part(root, K.cyl(0.07, 0.35), dark, Vector3(lx, by + 0.17, lz))
	A.part(root, K.rbox(Vector3(0.9, 0.5, 0.6), 0.22), wool, Vector3(-0.08, by + 0.52, 0))
	var puffs := [Vector3(-0.35, 0.78, 0.05), Vector3(-0.05, 0.85, -0.1), Vector3(0.2, 0.8, 0.0),
		Vector3(-0.4, 0.55, -0.25), Vector3(-0.5, 0.5, 0.12), Vector3(0.3, 0.55, -0.28),
		Vector3(0.28, 0.5, -0.28), Vector3(-0.1, 0.3, -0.3), Vector3(0.0, 0.85, 0.05),
		Vector3(-0.58, 0.6, 0.0)]
	for p in puffs:
		A.part(root, K.sphere(0.24), wool.darkened(0.03 * fmod(p.x * 10.0, 3.0)), Vector3(p.x, by + p.y, p.z))
	var head := K.group(root, Vector3(0.5, by + 0.66, 0))
	A.part(head, K.rbox(Vector3(0.38, 0.46, 0.4), 0.15), dark, Vector3(0.1, 0, 0))
	A.detail(head, K.sphere(0.2), wool, Vector3(0.0, 0.28, 0), Vector3.ZERO, Vector3(1, 0.7, 1.1))
	for ez in [-0.24, 0.24]:
		A.part(head, K.sphere(0.12), dark, Vector3(-0.02, 0.1, ez), Vector3.ZERO, Vector3(0.6, 0.4, 1.2))
