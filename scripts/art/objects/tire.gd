## An old tyre on its side to the camera: a fat rubber ring with tread bumps and a dull hub.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var r := d.size.x * 0.5
	var w := d.size.z
	var tube := w * 0.5
	var ring := r - tube * 0.5
	var rubber := K.c("rubber")
	A.part(root, K.torus(ring - tube * 0.5, r), rubber, Vector3.ZERO, Vector3(90, 0, 0), Vector3(1, w / (r - (ring - tube * 0.5)), 1))
	for k in 12:
		var a := TAU * k / 12.0
		A.detail(root, K.rbox(Vector3(0.1, 0.08, w * 0.9), 0.03, 2), rubber.lightened(0.08), Vector3(cos(a), sin(a), 0) * (r - 0.02), Vector3(0, 0, rad_to_deg(a)))
	A.detail(root, K.cyl(r * 0.5, w * 0.6), K.c("metal"), Vector3.ZERO, Vector3(90, 0, 0))
	A.detail(root, K.cyl(r * 0.22, w * 0.7), K.c("metal").darkened(0.2), Vector3.ZERO, Vector3(90, 0, 0))
