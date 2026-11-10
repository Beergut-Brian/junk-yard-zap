## A blow-up swim ring standing on its edge: a fat pink ring with four cream bands and a valve nub.
## Face on the top of the ring.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var r := d.size.x * 0.5
	var w := d.size.z
	var r_in := r * 0.44
	var mid := (r + r_in) * 0.5
	A.part(root, K.torus(r_in, r), d.color, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, w / (r - r_in), 1))
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		A.detail(root, K.rbox(Vector3(0.1, r - r_in + 0.02, w + 0.02), 0.045, 3), K.c("cream"),
				Vector3(cos(a), sin(a), 0) * mid, Vector3(0, 0, rad_to_deg(a) - 90.0))
	A.detail(root, K.cyl(0.025, 0.05), K.c("cream"), Vector3(-mid * 0.98, 0.04, w * 0.48), Vector3(90, 0, 0))
