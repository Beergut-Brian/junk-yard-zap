## A mini backyard trampoline: a plum safety skirt with mustard stars, a black mat, a metal rim and a
## fat teal pad on top, stubby legs with rubber feet. Face on the skirt.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var bot := -s.y * 0.5
	var hz := s.z * 0.5
	var sx := s.x / s.z
	var metal := K.c("metal")
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var foot := Vector3(x * s.x * 0.36, bot + 0.02, z * hz * 0.6)
			K.rod(root, foot, foot + Vector3(-x * 0.03, 0.12, 0), 0.03, metal)
			A.detail(root, K.sphere(0.045, 8), K.c("rubber"), foot, Vector3.ZERO, Vector3(1.2, 0.5, 1.2))
	var skirt_y := bot + 0.25
	A.part(root, K.cyl(hz - 0.04, 0.24), d.color, Vector3(0, skirt_y, 0), Vector3.ZERO, Vector3(sx, 1, 1))
	for k in 5:
		var a := PI * (0.15 + 0.175 * k)
		var at := Vector3(cos(a) * (hz - 0.035) * sx, skirt_y, sin(a) * (hz - 0.035))
		A.detail(root, K.sphere(0.035, 8), K.c("mustard"), at, Vector3.ZERO, Vector3(1, 1, 0.4))
	var top := s.y * 0.5
	A.part(root, K.torus(hz - 0.07, hz - 0.02), metal, Vector3(0, top - 0.07, 0), Vector3.ZERO, Vector3(sx, 1, 1))
	A.detail(root, K.cyl(hz - 0.08, 0.03), K.c("rubber"), Vector3(0, top - 0.05, 0), Vector3.ZERO, Vector3(sx, 1, 1))
	A.part(root, K.torus(hz - 0.13, hz - 0.01), K.c("teal"), Vector3(0, top - 0.045, 0), Vector3.ZERO, Vector3(sx, 0.75, 1))
