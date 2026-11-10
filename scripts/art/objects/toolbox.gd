## A mustard toolbox: rounded metal case, lid seam, latch and a carry handle on top.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var m := d.color
	A.part(root, K.rbox(Vector3(s.x, s.y * 0.62, s.z), 0.07), m, Vector3(0, -s.y * 0.19, 0))
	A.part(root, K.rbox(Vector3(s.x * 1.01, s.y * 0.34, s.z * 1.01), 0.09), m.lightened(0.06), Vector3(0, s.y * 0.17, 0))
	A.detail(root, K.rbox(Vector3(s.x * 1.02, 0.025, s.z * 1.02), 0.01, 2), m.darkened(0.45), Vector3(0, -s.y * 0.01, 0))
	A.part(root, K.rbox(Vector3(0.12, 0.2, 0.05), 0.02), K.c("metal"), Vector3(0, 0.0, s.z * 0.5 + 0.005))
	A.detail(root, K.sphere(0.025, 8), K.c("ink"), Vector3(0, -0.02, s.z * 0.53))
	for x in [-1.0, 1.0]:
		A.detail(root, K.sphere(0.04, 8), K.c("metal"), Vector3(x * s.x * 0.44, -s.y * 0.3, s.z * 0.5))
		K.rod(root, Vector3(x * s.x * 0.2, s.y * 0.34, 0), Vector3(x * s.x * 0.17, s.y * 0.5 + 0.1, 0), 0.04, K.c("metal").darkened(0.2))
	K.rod(root, Vector3(-s.x * 0.17, s.y * 0.5 + 0.1, 0), Vector3(s.x * 0.17, s.y * 0.5 + 0.1, 0), 0.05, K.c("rubber"))
