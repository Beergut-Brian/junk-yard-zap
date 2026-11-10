## A flat diamond kite with cross sticks and a tail of bows. Thin in z.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var h := d.size.y * 0.5
	var t := d.size.z
	var w := d.size.x * 0.5
	var s := 0.7071
	# the diamond: a square turned 45 degrees, stretched tall
	A.part(root, K.rbox(Vector3(2.0 * w * s, 2.0 * w * s, t), t * 0.4, 2), K.c("teal"), Vector3(0, h * 0.15, 0), Vector3(0, 0, 45), Vector3(1.0, (h * 0.85) / w, 1.0))
	A.detail(root, K.rbox(Vector3(1.1 * w * s, 1.1 * w * s, t * 1.4), t * 0.4, 2), K.c("mustard"), Vector3(0, h * 0.15, 0), Vector3(0, 0, 45), Vector3(1.0, (h * 0.85) / w, 1.0))
	A.detail(root, K.rbox(Vector3(0.5 * w * s, 0.5 * w * s, t * 1.8), t * 0.4, 2), K.c("plum"), Vector3(0, h * 0.15, 0), Vector3(0, 0, 45), Vector3(1.0, (h * 0.85) / w, 1.0))
	A.detail(root, K.rbox(Vector3(0.04, h * 1.7, t * 2.2), 0.015, 2), K.c("wood"), Vector3(0, h * 0.15, 0))
	A.detail(root, K.rbox(Vector3(w * 1.9, 0.04, t * 2.2), 0.015, 2), K.c("wood"), Vector3(0, h * 0.15, 0))
	K.rod(root, Vector3(0, -h * 0.7, -0.01), Vector3(0, -h * 1.7, -0.01), 0.01, K.c("ink"))
	var cols := [K.c("plum"), K.c("mustard"), K.c("teal")]
	for i in 3:
		var y := -h * (0.95 + 0.25 * i)
		for sx in [-1, 1]:
			A.detail(root, K.sphere(0.07), cols[i], Vector3(sx * 0.07, y, 0), Vector3.ZERO, Vector3(1.5, 0.8, 0.5))
		A.detail(root, K.sphere(0.035), K.c("ink"), Vector3(0, y, 0.01))
