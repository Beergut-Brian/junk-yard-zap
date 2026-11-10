## A log lying along x: rough brown bark with ridges and a knot, a broken branch stub, and pale cut
## ends with growth rings.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var r := s.y * 0.5
	var hx := s.x * 0.5
	var bark := Color("#7a4f30")
	var ridge := bark.darkened(0.25)
	A.part(root, K.cyl(r, s.x - 0.04, -1.0, 28), bark, Vector3.ZERO, Vector3(0, 0, 90))
	# Bark ridges at angles round the log, kept clear of the face (front right).
	var ridges := [[-0.55, 95.0, 0.9], [-0.1, 30.0, 0.6], [0.35, 150.0, 0.8], [-0.6, -40.0, 0.7], [0.1, 200.0, 1.0], [0.6, 60.0, 0.4], [-0.35, 250.0, 0.6]]
	for g in ridges:
		var a := deg_to_rad(g[1])
		A.detail(root, K.rbox(Vector3(s.x * 0.5 * g[2], 0.05, 0.05), 0.02), ridge, Vector3(g[0] * s.x * 0.5, sin(a) * r * 0.97, cos(a) * r * 0.97))
	A.detail(root, K.sphere(0.07, 10), ridge, Vector3(-0.2, r * 0.25, r * 0.93), Vector3.ZERO, Vector3(1.2, 1.0, 0.4))
	A.part(root, K.cyl(0.08, 0.2, 0.06, 10), bark, Vector3(-0.45, r + 0.06, -0.04), Vector3(0, 0, 25))
	A.detail(root, K.cyl(0.062, 0.02, -1.0, 10), K.c("wood_light"), Vector3(-0.49, r + 0.15, -0.04), Vector3(0, 0, 25))
	# Cut ends.
	var pale := K.c("wood_light")
	for x in [-1.0, 1.0]:
		var p := Vector3(x * (hx - 0.01), 0, 0)
		A.part(root, K.cyl(r * 0.88, 0.03, -1.0, 24), pale, p, Vector3(0, 0, 90))
		for k in 2:
			var ri := r * (0.32 + k * 0.28)
			A.detail(root, K.torus(ri - 0.012, ri + 0.012, 24), pale.darkened(0.25), p + Vector3(x * 0.012, 0, 0), Vector3(0, 0, 90))
		A.detail(root, K.sphere(0.03, 8), pale.darkened(0.35), p + Vector3(x * 0.012, 0, 0), Vector3.ZERO, Vector3(0.3, 1, 1))
