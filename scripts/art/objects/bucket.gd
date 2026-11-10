## A battered metal pail: tapered body, rolled rim, swing handle. Open top (TUB).
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var m := d.color
	A.part(root, K.cyl(s.x * 0.5, s.y * 1.0, s.x * 0.44), m)
	A.detail(root, K.cyl(s.x * 0.4, 0.02), m.darkened(0.4), Vector3(0, s.y * 0.49, 0))
	A.part(root, K.torus(s.x * 0.43, s.x * 0.5), m.lightened(0.1), Vector3(0, s.y * 0.5, 0), Vector3.ZERO, Vector3(1, 1.2, 1))
	A.part(root, K.cyl(s.x * 0.51, s.y * 0.06), m.darkened(0.2), Vector3(0, -s.y * 0.2, 0))
	A.part(root, K.torus(s.x * 0.42, s.x * 0.455), K.c("rust_dark"), Vector3(0, s.y * 0.58, 0), Vector3(90, 0, 0), Vector3(1, 1, 0.5))
	for x in [-1.0, 1.0]:
		A.detail(root, K.sphere(0.03, 8), K.c("rust_dark"), Vector3(x * s.x * 0.47, s.y * 0.48, 0))
