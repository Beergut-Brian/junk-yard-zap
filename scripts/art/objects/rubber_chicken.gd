## A squeaky rubber chicken, flopped on its side: a long limp yellow body, a skinny neck, a little
## head with a rust comb and an orange beak, stiff legs sticking out the back. Face on the head.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var bot := -s.y * 0.5
	var yellow := d.color
	var body := Vector3(-0.08, bot + 0.15, 0)
	A.part(root, K.sphere(0.15, 20), yellow, body, Vector3(0, 0, -6), Vector3(1.7, 1.0, 1.0))
	A.detail(root, K.sphere(0.1, 12), yellow.darkened(0.1), body + Vector3(-0.02, 0.03, 0.12), Vector3(0, 0, 15), Vector3(1.6, 0.7, 0.45))
	A.part(root, K.cyl(0.05, 0.14, 0.0, 10), yellow, body + Vector3(-0.29, 0.05, 0), Vector3(0, 0, 62))
	var head := Vector3(s.x * 0.36, s.y * 0.22, 0)
	K.rod(root, body + Vector3(0.18, 0.04, 0), head + Vector3(-0.04, -0.03, 0), 0.045, yellow)
	A.part(root, K.sphere(0.1, 18), yellow, head, Vector3.ZERO, Vector3(1.0, 1.0, 1.65))
	for i in 3:
		A.detail(root, K.sphere(0.035, 8), K.c("rust"), head + Vector3(-0.04 + i * 0.04, 0.1 - absf(i - 1) * 0.015, 0))
	A.part(root, K.cyl(0.035, 0.1, 0.0, 10), K.c("beak"), head + Vector3(0.12, -0.01, 0), Vector3(0, 0, -90))
	A.detail(root, K.sphere(0.03, 8), K.c("rust"), head + Vector3(0.07, -0.08, 0.02), Vector3.ZERO, Vector3(0.8, 1.3, 0.8))
	for z in [-0.06, 0.06]:
		var hip := body + Vector3(-0.18, -0.06, z)
		var foot := Vector3(-s.x * 0.5 + 0.04, bot + 0.05, z * 1.4)
		K.rod(root, hip, foot, 0.022, K.c("beak"))
		A.detail(root, K.sphere(0.04, 8), K.c("beak"), foot, Vector3.ZERO, Vector3(0.7, 1.0, 1.3))
