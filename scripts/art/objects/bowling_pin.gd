## A cream bowling pin with a teal stripe, built as stacked spheres and a cylinder.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var by := -d.size.y * 0.5
	var cr := K.c("cream")
	A.part(root, K.cyl(0.14, 0.2, 0.17), cr, Vector3(0, by + 0.1, 0))
	A.part(root, K.sphere(0.17), cr, Vector3(0, by + 0.3, 0), Vector3.ZERO, Vector3(1, 1.15, 1))
	A.part(root, K.cyl(0.075, 0.4, 0.09), cr, Vector3(0, by + 0.55, 0))
	A.part(root, K.sphere(0.11), cr, Vector3(0, by + 0.8, 0))
	A.part(root, K.sphere(0.085), cr, Vector3(0, by + 0.92, 0))
	A.detail(root, K.torus(0.08, 0.105), K.c("teal"), Vector3(0, by + 0.72, 0))
	A.detail(root, K.torus(0.075, 0.1), K.c("teal"), Vector3(0, by + 0.67, 0))
