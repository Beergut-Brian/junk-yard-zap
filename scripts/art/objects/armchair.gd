## A squashy old armchair: teal fabric, plump back and arms, saggy cushion, a plum patch, stubby feet.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var teal := d.color
	var z := s.z * 0.5
	A.part(root, K.rbox(Vector3(s.x * 0.94, s.y * 0.5, s.z * 0.9), 0.22), teal.darkened(0.08), Vector3(0, -s.y * 0.22, 0))
	A.part(root, K.rbox(Vector3(s.x * 0.94, s.y * 0.72, s.z * 0.3), 0.2), teal, Vector3(0, s.y * 0.12, -z * 0.7))
	for x in [-1.0, 1.0]:
		A.part(root, K.rbox(Vector3(s.x * 0.2, s.y * 0.55, s.z * 0.96), 0.12), teal.lightened(0.03), Vector3(x * s.x * 0.4, -s.y * 0.1, 0))
	A.part(root, K.rbox(Vector3(s.x * 0.55, s.y * 0.2, s.z * 0.62), 0.1), teal.lightened(0.1), Vector3(0, -s.y * 0.0, z * 0.1))
	A.detail(root, K.rbox(Vector3(s.x * 0.2, s.y * 0.2, 0.03), 0.04), K.c("plum"), Vector3(s.x * 0.12, -s.y * 0.2, z * 0.99), Vector3(0, 0, 8))
	for i in 5:
		A.detail(root, K.rbox(Vector3(0.03, 0.012, 0.01), 0.004, 2), K.c("cream"), Vector3(s.x * 0.02 + i * 0.03, -s.y * 0.2 + (i % 2) * 0.03, z * 0.99 + 0.02), Vector3(0, 0, 0))
	for x in [-1.0, 1.0]:
		A.part(root, K.cyl(0.07, 0.12, 0.05), K.c("wood"), Vector3(x * s.x * 0.38, -s.y * 0.5 + 0.06, z * 0.7))
		A.part(root, K.cyl(0.07, 0.12, 0.05), K.c("wood"), Vector3(x * s.x * 0.38, -s.y * 0.5 + 0.06, -z * 0.7))
	A.detail(root, K.sphere(0.04, 8), K.c("cream"), Vector3(0, s.y * 0.2, -z * 0.5 + 0.17))
