## An old teal enamel kettle with spout, bail handle, lid knob and a rust chip. Spout +x.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var e := K.c("teal")
	var by := -d.size.y * 0.5
	A.part(root, K.cyl(0.3, 0.45, 0.25), e, Vector3(0, by + 0.25, 0))
	A.part(root, K.sphere(0.27), e, Vector3(0, by + 0.45, 0), Vector3.ZERO, Vector3(1, 0.4, 1))
	A.part(root, K.cyl(0.18, 0.06), K.c("cream"), Vector3(0, by + 0.57, 0))
	A.part(root, K.sphere(0.06), K.c("rust"), Vector3(0, by + 0.64, 0))
	A.part(root, K.cyl(0.06, 0.4, 0.11), e, Vector3(0.38, by + 0.38, 0), Vector3(0, 0, -40))
	A.part(root, K.torus(0.25, 0.28), K.c("wood"), Vector3(0, by + 0.5, 0), Vector3(90, 0, 0), Vector3(1, 1, 1))
	A.detail(root, K.torus(0.025, 0.05), K.c("cream"), Vector3(-0.27, by + 0.3, 0), Vector3(90, 0, 0))
	A.detail(root, K.cyl(0.305, 0.05, 0.285), K.c("cream"), Vector3(0, by + 0.1, 0))
	A.detail(root, K.sphere(0.06), K.c("rust"), Vector3(-0.1, by + 0.25, 0.24), Vector3.ZERO, Vector3(1.2, 0.8, 0.3))
