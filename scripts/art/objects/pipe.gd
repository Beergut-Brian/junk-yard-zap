## A short drain pipe lying on its side: rusty tube, flanged ends, dark openings, mossy patches.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var rust := d.color
	var r := s.y * 0.5
	A.part(root, K.cyl(r, s.x * 0.86), rust, Vector3.ZERO, Vector3(0, 0, 90))
	for x in [-1.0, 1.0]:
		A.part(root, K.cyl(r, s.x * 0.13), rust.darkened(0.2), Vector3(x * s.x * 0.435, 0, 0), Vector3(0, 0, 90), Vector3(1.0, 1.0, 1.0))
		A.detail(root, K.cyl(r * 0.68, 0.02), K.c("ink"), Vector3(x * (s.x * 0.5 + 0.0), 0, 0), Vector3(0, 0, 90))
	A.detail(root, K.sphere(0.14), K.c("rust_dark"), Vector3(-s.x * 0.2, r * 0.3, r * 0.92), Vector3.ZERO, Vector3(1.4, 0.8, 0.3))
	A.detail(root, K.sphere(0.1), K.c("leaf"), Vector3(s.x * 0.27, r * 0.5, r * 0.85), Vector3.ZERO, Vector3(1.4, 0.7, 0.4))
	A.detail(root, K.sphere(0.08), K.c("leaf").darkened(0.1), Vector3(s.x * 0.3, -r * 0.1, r * 0.95), Vector3.ZERO, Vector3(1.2, 0.8, 0.3))
