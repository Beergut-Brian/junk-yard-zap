## A plastic lawn flamingo on a little round stand: wire legs, a plump pink body with a darker wing,
## an S neck and a small head with a cream beak dipped in ink. Face on the head.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var bot := -s.y * 0.5
	var pink := d.color
	A.part(root, K.cyl(0.15, 0.04), K.c("rubber"), Vector3(-0.04, bot + 0.02, 0))
	for z in [-0.03, 0.03]:
		K.rod(root, Vector3(-0.04, bot + 0.03, z), Vector3(-0.05, -0.1, z), 0.014, K.c("metal"))
	A.detail(root, K.sphere(0.025, 8), K.c("metal"), Vector3(-0.045, -0.3, 0.03))
	var body := Vector3(-0.06, 0.02, 0)
	A.part(root, K.sphere(0.16, 20), pink, body, Vector3(0, 0, 12), Vector3(1.4, 0.95, 0.72))
	A.detail(root, K.sphere(0.11, 14), pink.darkened(0.15), body + Vector3(-0.03, 0.02, 0.08), Vector3(0, 0, 18), Vector3(1.4, 0.7, 0.4))
	A.part(root, K.cyl(0.06, 0.14, 0.0, 10), pink.darkened(0.08), body + Vector3(-0.26, 0.06, 0), Vector3(0, 0, 70))
	var head := Vector3(s.x * 0.25, s.y * 0.36, 0)
	var pts := [body + Vector3(0.14, 0.06, 0), Vector3(0.19, 0.17, 0), Vector3(0.1, 0.26, 0), head + Vector3(-0.03, -0.04, 0)]
	for i in pts.size() - 1:
		K.rod(root, pts[i], pts[i + 1], 0.032, pink)
		A.detail(root, K.sphere(0.032, 8), pink, pts[i + 1])
	A.part(root, K.sphere(0.07, 16), pink, head, Vector3.ZERO, Vector3(1.1, 1.0, 1.6))
	A.part(root, K.cyl(0.03, 0.1, 0.012, 10), K.c("cream"), head + Vector3(0.1, -0.03, 0), Vector3(0, 0, -115))
	A.detail(root, K.sphere(0.016, 6), K.c("ink"), head + Vector3(0.145, -0.055, 0))
