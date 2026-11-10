## A dark iron anvil: horn, face, waist and base.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var iron := K.c("rubber").lerp(K.c("metal"), 0.18)
	var by := -d.size.y * 0.5
	A.part(root, K.rbox(Vector3(0.85, 0.18, 0.46), 0.06), iron.darkened(0.1), Vector3(0, by + 0.09, 0))
	A.part(root, K.rbox(Vector3(0.6, 0.28, 0.4), 0.1), iron, Vector3(0, by + 0.3, 0))
	A.part(root, K.rbox(Vector3(0.9, 0.24, 0.5), 0.07), iron.lightened(0.05), Vector3(-0.05, by + 0.56, 0))
	A.part(root, K.cyl(0.25, 0.4, 0.04), iron.lightened(0.05), Vector3(0.7, by + 0.62, 0), Vector3(0, 0, -90))
	A.detail(root, K.rbox(Vector3(0.88, 0.03, 0.46), 0.01, 2), K.c("metal"), Vector3(-0.05, by + 0.69, 0))
	A.detail(root, K.cyl(0.04, 0.52), K.c("ink"), Vector3(-0.3, by + 0.5, 0), Vector3(90, 0, 0))
