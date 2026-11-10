## A light beach ball: cream with teal, mustard and plum wedges.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var r := d.size.x * 0.5
	A.part(root, K.sphere(r), K.c("cream"))
	var cols := [K.c("teal"), K.c("mustard"), K.c("plum")]
	# Wedges: flattened spheres hugging the surface, spread around the front axis.
	for i in 6:
		var a := TAU * i / 6.0
		var dir := Vector3(cos(a) * 0.62, sin(a) * 0.62, 0.78).normalized()
		var m := A.detail(root, K.sphere(r * 0.34), cols[i % 3], dir * r * 0.9)
		m.basis = K.basis_y(dir) * Basis.from_scale(Vector3(1.0, 0.28, 1.0))
		m.position = dir * r * 0.93
	A.detail(root, K.cyl(r * 0.12, r * 0.06), K.c("mustard"), Vector3(0, r * 0.97, 0))
