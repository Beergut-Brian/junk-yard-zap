## A chunky cartoon fish: round teal body, cream belly, tail and fins, facing +x. Light, floats.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var teal := d.color
	A.part(root, K.sphere(0.5), teal, Vector3(s.x * 0.06, 0, 0), Vector3.ZERO, Vector3(s.x * 0.76 / 1.0, s.y * 1.0 / 1.0, s.z * 0.96 / 1.0))
	A.detail(root, K.sphere(0.5), K.c("cream"), Vector3(s.x * 0.1, -s.y * 0.15, s.z * 0.06), Vector3.ZERO, Vector3(s.x * 0.62, s.y * 0.6, s.z * 0.86))
	A.part(root, K.sphere(0.3), K.c("mustard"), Vector3(-s.x * 0.5, 0, 0), Vector3(0, 0, 0), Vector3(0.6, 1.0, 0.22))
	A.part(root, K.sphere(0.3), K.c("mustard"), Vector3(-s.x * 0.4, 0, 0), Vector3.ZERO, Vector3(0.8, 0.6, 0.22))
	A.part(root, K.sphere(0.3), K.c("mustard"), Vector3(s.x * 0.0, s.y * 0.48, 0), Vector3(0, 0, 10), Vector3(1.0, 0.5, 0.2))
	A.part(root, K.sphere(0.13), K.c("mustard"), Vector3(s.x * 0.0, -s.y * 0.25, s.z * 0.42), Vector3(0, 0, -35), Vector3(0.9, 0.5, 0.25))
	A.detail(root, K.sphere(0.03, 8), K.c("ink"), Vector3(s.x * 0.5 - 0.02, -s.y * 0.05, 0.0), Vector3.ZERO, Vector3(0.7, 1.2, 1))
