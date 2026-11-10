## A tyre swing someone cut down: a fat tyre painted mustard with cream daisies, a plank seat across
## the hole, and the old rope knotted round the top and flopped down the side. Face on the seat.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")

const ROPE := Color("#d8b57a")


static func build(root: Node3D, d: ObjectData) -> void:
	var r := d.size.x * 0.5
	var w := d.size.z
	var tube := w * 0.5
	var r_in := r - tube
	var paint := d.color
	A.part(root, K.torus(r_in, r), paint, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, w / (r - r_in), 1))
	for k in 5:
		var a := TAU * (k + 0.3) / 5.0
		var at := Vector3(cos(a), sin(a), 0) * (r - tube * 0.5) + Vector3(0, 0, w * 0.5 - 0.02)
		for p in 5:
			var b := TAU * p / 5.0
			A.detail(root, K.sphere(0.03, 6), K.c("cream"), at + Vector3(cos(b), sin(b), 0) * 0.04, Vector3.ZERO, Vector3(1, 1, 0.4))
		A.detail(root, K.sphere(0.022, 6), K.c("mustard").lightened(0.3), at + Vector3(0, 0, 0.01))
	A.part(root, K.rbox(Vector3(r_in * 2.1, 0.12, w * 0.7), 0.03), K.c("wood_light"), Vector3(0, -0.02, -0.02))
	for x in [-0.09, 0.09]:
		A.part(root, K.torus(0.12, 0.165), ROPE, Vector3(x, r - tube * 0.45, 0), Vector3(0, 0, 90), Vector3(1, 0.5, 1.25))
	A.part(root, K.sphere(0.07, 10), ROPE, Vector3(0, r + 0.02, 0.05))
	var pts := [Vector3(0.02, r + 0.05, 0.08), Vector3(0.3, r + 0.08, 0.12), Vector3(r + 0.08, 0.15, 0.12),
			Vector3(r + 0.1, -r + 0.05, 0.1)]
	for i in pts.size() - 1:
		K.rod(root, pts[i], pts[i + 1], 0.03, ROPE)
	A.detail(root, K.sphere(0.04, 8), ROPE.lightened(0.2), pts[-1], Vector3.ZERO, Vector3(1.2, 0.7, 1.2))
