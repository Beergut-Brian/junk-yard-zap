## A blow-up paddling pool: three fat inflatable rings stacked (teal, cream, teal) on a flat floor,
## a little water inside, mustard spots on the rings and a valve nub. Face on the front ring.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var bot := -s.y * 0.5
	var hz := s.z * 0.5
	var sx := s.x / s.z
	var tube := s.y / 3.0
	var cols := [d.color, K.c("cream"), d.color]
	A.part(root, K.cyl(hz - 0.04, 0.04), d.color.darkened(0.2), Vector3(0, bot + 0.02, 0), Vector3.ZERO, Vector3(sx, 1, 1))
	A.detail(root, K.cyl(hz - 0.12, 0.02), K.c("pond"), Vector3(0, bot + tube * 1.2, 0), Vector3.ZERO, Vector3(sx, 1, 1))
	for i in 3:
		var y := bot + tube * (i + 0.5)
		A.part(root, K.torus(hz - tube, hz), cols[i], Vector3(0, y, 0), Vector3.ZERO, Vector3(sx, 1, 1))
	for k in 6:
		var a := TAU * (k + 0.5) / 6.0
		var at := Vector3(cos(a) * (hz - tube * 0.5) * sx, bot + tube * 0.5, sin(a) * (hz - tube * 0.5))
		if at.z > -0.1:
			A.detail(root, K.sphere(0.045, 8), K.c("mustard"), at + Vector3(0, 0, tube * 0.45), Vector3.ZERO, Vector3(1, 1, 0.4))
	A.detail(root, K.cyl(0.03, 0.06), K.c("cream"), Vector3(-s.x * 0.36, bot + tube * 2.5 + 0.06, 0.1))
