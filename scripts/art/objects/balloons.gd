## A bunch of three party balloons (mustard, teal, denim: clear of P1 green, P2 red and the
## balloon gun's magenta) on ink strings, tied to a little cream sandbag that keeps them hovering.
## The face goes on the front balloon.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var h := d.size.y * 0.5
	var w := d.size.x * 0.5
	var r := minf(w * 0.62, d.size.z * 0.5)
	var knot := Vector3(0, -h + 0.26, 0.02)
	# Back two first, the front one last and nearest the camera (it wears the face).
	var balls := [
		[Vector3(-w + r, h - r * 1.25, -0.04), K.c("teal")],
		[Vector3(w - r, h - r * 1.15, -0.03), K.c("denim")],
		[Vector3(0, h - r, d.size.z * 0.5 - r), K.c("mustard")],
	]
	for b in balls:
		var at: Vector3 = b[0]
		A.part(root, K.sphere(r), b[1], at, Vector3.ZERO, Vector3(1.0, 1.12, 1.0))
		# the little tied neck under each balloon
		A.detail(root, K.cyl(r * 0.08, r * 0.18, r * 0.16), (b[1] as Color).darkened(0.2), at + Vector3(0, -r * 1.16, 0))
		K.rod(root, at + Vector3(0, -r * 1.22, 0), knot, 0.012, K.c("ink"))
		# a shine, so they read as shiny rubber from the sofa
		A.detail(root, K.sphere(r * 0.2), Color(1, 1, 1, 0.9), at + Vector3(-r * 0.38, r * 0.45, r * 0.72), Vector3.ZERO, Vector3(0.7, 1.0, 0.4))
	A.detail(root, K.sphere(0.05), K.c("ink"), knot)
	K.rod(root, knot, Vector3(0, -h + 0.16, 0.02), 0.012, K.c("ink"))
	# the sandbag weight, sitting on the collision floor
	A.part(root, K.rbox(Vector3(0.3, 0.2, 0.26), 0.07, 3), K.c("cream"), Vector3(0, -h + 0.1, 0))
	A.detail(root, K.cyl(0.035, 0.06), K.c("wood"), Vector3(0, -h + 0.21, 0))
