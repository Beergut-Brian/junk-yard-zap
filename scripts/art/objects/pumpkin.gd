## A ribbed orange pumpkin with a green stalk and curly vine.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var r := d.size.x * 0.5
	var o := K.c("rust").lerp(K.c("mustard"), 0.5)
	A.part(root, K.sphere(r * 0.9), o, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.88, 1.0))
	for i in 6:
		var a := TAU * i / 6.0
		A.part(root, K.sphere(r * 0.62), o.lerp(K.c("rust"), 0.25 * float(i % 2)), Vector3(cos(a) * r * 0.45, 0, sin(a) * r * 0.45), Vector3.ZERO, Vector3(0.8, 1.55, 0.8))
	A.part(root, K.cyl(0.06, 0.2, 0.09), K.c("leaf").darkened(0.2), Vector3(0, r * 0.88, 0), Vector3(0, 0, 12))
	A.detail(root, K.torus(0.045, 0.06), K.c("leaf"), Vector3(0.12, r * 0.7, 0.2), Vector3(70, 0, 0))
	A.detail(root, K.sphere(0.07), K.c("leaf"), Vector3(-0.15, r * 0.82, 0.1), Vector3.ZERO, Vector3(1.8, 0.3, 0.9))
