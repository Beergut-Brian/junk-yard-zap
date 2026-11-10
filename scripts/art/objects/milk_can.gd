## A metal milk churn with lid, neck ring and two side handles.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var m := K.c("metal")
	var by := -d.size.y * 0.5
	A.part(root, K.cyl(0.24, 0.62, 0.3), m, Vector3(0, by + 0.34, 0))
	A.part(root, K.cyl(0.3, 0.14, 0.3), m.lightened(0.1), Vector3(0, by + 0.07, 0))
	A.part(root, K.cyl(0.3, 0.14), m.darkened(0.1), Vector3(0, by + 0.64, 0), Vector3.ZERO, Vector3(1, 1, 1))
	A.part(root, K.cyl(0.17, 0.2, 0.2), m, Vector3(0, by + 0.78, 0))
	A.part(root, K.cyl(0.22, 0.1, 0.14), K.c("rust"), Vector3(0, by + 0.9, 0))
	A.detail(root, K.sphere(0.06), K.c("rust_dark"), Vector3(0, by + 0.97, 0))
	A.detail(root, K.cyl(0.285, 0.05), K.c("teal"), Vector3(0, by + 0.34, 0))
	for sx in [-1, 1]:
		A.part(root, K.torus(0.07, 0.09), m.darkened(0.2), Vector3(sx * 0.3, by + 0.66, 0), Vector3(90, 0, 0))
