## An old striped mattress with buttons and one poking spring.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var sx := d.size.x
	var sz := d.size.z
	var by := -d.size.y * 0.5
	A.part(root, K.rbox(Vector3(sx, d.size.y, sz), 0.12), K.c("cream"), Vector3.ZERO)
	for i in 5:
		var x := -sx * 0.4 + i * sx * 0.2
		if i % 2 == 0:
			A.detail(root, K.rbox(Vector3(sx * 0.2, d.size.y * 1.02, sz * 1.02), 0.05, 2), K.c("denim"), Vector3(x, 0, 0))
	for i in 4:
		A.detail(root, K.sphere(0.05, 8), K.c("plum"), Vector3(-sx * 0.3 + i * sx * 0.2, d.size.y * 0.5, 0.0), Vector3.ZERO, Vector3(1, 0.5, 1))
		A.detail(root, K.sphere(0.04, 8), K.c("plum"), Vector3(-sx * 0.3 + i * sx * 0.2, 0.0, sz * 0.5 + 0.0), Vector3.ZERO, Vector3(1, 1, 0.5))
	for k in 4:
		A.detail(root, K.torus(0.055 - k * 0.006, 0.07 - k * 0.006), K.c("metal"), Vector3(sx * 0.32, d.size.y * 0.5 + 0.04 + k * 0.06, -sz * 0.2), Vector3(0, 0, 0))
	A.detail(root, K.sphere(0.12), K.c("rust_dark"), Vector3(-sx * 0.2, d.size.y * 0.5, sz * 0.25), Vector3.ZERO, Vector3(1.6, 0.2, 1.0))
