## A chunky old surfboard: a long denim-blue pod with a cream stripe down the middle, a cream
## rail all round and two mustard bands near the nose. Face on its rail.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var hx := s.x * 0.5
	var sy := s.y * 0.5 / hx
	var sz := s.z * 0.5 / hx
	A.part(root, K.sphere(hx, 32), d.color, Vector3.ZERO, Vector3.ZERO, Vector3(1, sy, sz))
	A.detail(root, K.sphere(hx * 0.98, 24), K.c("cream"), Vector3(0, 0.004, 0), Vector3.ZERO, Vector3(1, sy * 1.03, sz * 0.22))
	A.detail(root, K.sphere(hx * 0.97, 32), K.c("cream"), Vector3.ZERO, Vector3.ZERO, Vector3(1, sy * 0.3, sz * 1.04))
	for x in [0.5, 0.62]:
		A.detail(root, K.sphere(hx, 24), K.c("mustard"), Vector3(hx * x, 0, 0), Vector3.ZERO,
				Vector3(0.03, sy * 1.02 * sqrt(1.0 - x * x), sz * 1.02 * sqrt(1.0 - x * x)))
