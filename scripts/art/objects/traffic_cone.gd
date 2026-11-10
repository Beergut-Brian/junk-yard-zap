## A generic road cone: square foot, stacked cream and amber stripes, no text.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var amber := d.color
	var cream := K.c("cream")
	A.part(root, K.rbox(Vector3(s.x, s.y * 0.1, s.z), 0.04), K.c("rubber"), Vector3(0, -s.y * 0.45, 0))
	A.part(root, K.cyl(s.x * 0.44, s.y * 0.88, s.x * 0.1), amber, Vector3(0, s.y * 0.01, 0))
	A.part(root, K.cyl(s.x * 0.33, s.y * 0.17, s.x * 0.25), cream, Vector3(0, s.y * 0.07, 0))
	A.part(root, K.cyl(s.x * 0.23, s.y * 0.12, s.x * 0.17), cream, Vector3(0, s.y * 0.30, 0))
	A.part(root, K.cyl(s.x * 0.11, s.y * 0.07, s.x * 0.08), K.c("rubber"), Vector3(0, s.y * 0.46, 0))
