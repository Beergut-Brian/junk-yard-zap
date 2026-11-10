## A wooden crate: a light pine box with darker slats and corner posts.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var wood := K.c("crate")
	var slat := wood.darkened(0.2)
	A.part(root, K.rbox(s * 0.96, 0.08), wood)
	for y in [-0.3, 0.0, 0.3]:
		A.detail(root, K.rbox(Vector3(s.x * 1.0, s.y * 0.1, s.z * 1.0), 0.03), slat, Vector3(0, y * s.y, 0))
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			A.part(root, K.rbox(Vector3(s.x * 0.14, s.y * 1.02, s.z * 0.14), 0.035), slat.darkened(0.1), Vector3(x * s.x * 0.94, 0, z * s.z * 0.94))
	for x in [-0.36, 0.36]:
		A.detail(root, K.sphere(0.03, 8), K.c("metal"), Vector3(x * s.x, 0.3 * s.y, s.z * 0.51))
		A.detail(root, K.sphere(0.03, 8), K.c("metal"), Vector3(x * s.x, -0.3 * s.y, s.z * 0.51))
