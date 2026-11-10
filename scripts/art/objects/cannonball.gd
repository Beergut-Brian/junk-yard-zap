## A cannonball: a heavy slate-iron ball with a riveted band, a brass fuse plug and a short
## twine fuse with a glowing ember tip. Slate (not black) so the ink face still reads.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var r := d.size.x * 0.5
	var iron := Color("#59616d")
	A.part(root, K.sphere(r, 32), iron)
	A.detail(root, K.sphere(r * 0.32, 12), iron.lightened(0.25), Vector3(-r * 0.42, r * 0.5, r * 0.62), Vector3.ZERO, Vector3(1, 0.7, 0.3))
	A.part(root, K.cyl(r * 0.2, r * 0.22), K.c("mustard").darkened(0.15), Vector3(0, r * 0.97, 0))
	A.detail(root, K.cyl(r * 0.24, r * 0.06), iron.darkened(0.3), Vector3(0, r * 0.9, 0))
	var a := Vector3(0, r * 1.05, 0)
	var b := Vector3(r * 0.12, r * 1.32, 0.0)
	var c := Vector3(r * 0.3, r * 1.45, 0.0)
	var twine := K.c("wood_light")
	K.rod(root, a, b, r * 0.08, twine)
	K.rod(root, b, c, r * 0.08, twine)
	A.detail(root, K.sphere(r * 0.1, 10), Color("#ffb347"), c).material_override = K.glow(Color("#ffb347"), 1.2)
