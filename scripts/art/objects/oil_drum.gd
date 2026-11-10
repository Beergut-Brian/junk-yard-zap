## An upright rusty oil drum: dented rust body, darker rolled rings, grey lid and bung.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var body := d.color
	var ring := body.darkened(0.22)
	A.part(root, K.cyl(s.x * 0.5, s.y * 0.94), body)
	for y in [-0.36, 0.0, 0.36]:
		A.part(root, K.cyl(s.x * 0.515, s.y * 0.07), ring, Vector3(0, y * s.y, 0))
	A.part(root, K.cyl(s.x * 0.5, s.y * 0.06, s.x * 0.44), K.c("metal"), Vector3(0, s.y * 0.48, 0))
	A.detail(root, K.cyl(s.x * 0.08, s.y * 0.05), K.c("metal").darkened(0.3), Vector3(s.x * 0.2, s.y * 0.52, -s.z * 0.1))
	A.detail(root, K.sphere(0.12), K.c("rust_dark"), Vector3(-s.x * 0.28, -s.y * 0.2, s.z * 0.4), Vector3.ZERO, Vector3(1.2, 1.5, 0.3))
	A.detail(root, K.sphere(0.09), K.c("rust_dark"), Vector3(s.x * 0.3, s.y * 0.22, s.z * 0.42), Vector3.ZERO, Vector3(1.4, 0.9, 0.3))
