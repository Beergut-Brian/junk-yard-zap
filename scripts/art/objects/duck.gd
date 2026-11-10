## A rubber bath duck: a fat yellow body, a round head (the face sits on it), an orange bill
## sticking out to the side, a little wing and a perky tail.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var r := d.size.x * 0.5
	var yellow := Color("#f7cd45")
	A.part(root, K.sphere(0.24, 24), yellow, Vector3(-0.02, -r + 0.2, 0), Vector3.ZERO, Vector3(1.22, 0.85, 1.0))
	A.part(root, K.cyl(0.07, 0.16, 0.0, 12), yellow, Vector3(-0.29, -r + 0.3, 0), Vector3(0, 0, 55))
	A.detail(root, K.sphere(0.12, 14), yellow.darkened(0.08), Vector3(-0.06, -r + 0.22, 0.2), Vector3(0, 0, -12), Vector3(1.2, 0.7, 0.35))
	var head := Vector3(0.12, 0.16, 0.0)
	A.part(root, K.sphere(0.15, 24), yellow, head)
	A.part(root, K.sphere(0.07, 14), K.c("beak"), head + Vector3(0.15, -0.035, 0.03), Vector3(0, 0, -8), Vector3(1.4, 0.45, 1.05))
	A.detail(root, K.sphere(0.04, 10), K.c("pink"), head + Vector3(0.1, -0.06, 0.1), Vector3.ZERO, Vector3(1, 0.6, 0.5))
