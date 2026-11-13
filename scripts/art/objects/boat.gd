## A small wooden rowing boat: hull, plank lines, seat, an oar. Open top (TUB), floats.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var wood := d.color
	var dark := wood.darkened(0.25)
	A.part(root, K.rbox(Vector3(s.x * 0.8, s.y * 0.8, s.z), 0.2), wood, Vector3(0, -s.y * 0.1, 0))
	A.part(root, K.rbox(Vector3(s.x * 0.3, s.y * 0.62, s.z * 0.92), 0.14), wood, Vector3(s.x * 0.42, s.y * 0.0, 0), Vector3(0, 0, -20))
	A.part(root, K.rbox(Vector3(s.x * 0.26, s.y * 0.6, s.z * 0.92), 0.14), wood, Vector3(-s.x * 0.42, -s.y * 0.0, 0), Vector3(0, 0, 14))
	A.part(root, K.rbox(Vector3(s.x * 0.98, 0.06, 0.07), 0.025), dark.lightened(0.1), Vector3(0, s.y * 0.3, s.z * 0.5 - 0.02))
	A.part(root, K.rbox(Vector3(s.x * 0.8, 0.06, 0.07), 0.025), dark.lightened(0.1), Vector3(0, s.y * 0.3, -s.z * 0.5 + 0.02))
	A.detail(root, K.rbox(Vector3(s.x * 0.82, 0.025, 0.02), 0.01, 2), dark, Vector3(0, -s.y * 0.28, s.z * 0.5 + 0.005))
	A.detail(root, K.rbox(Vector3(s.x * 0.82, 0.025, 0.02), 0.01, 2), dark, Vector3(0, -s.y * 0.05, s.z * 0.5 + 0.005))
	A.detail(root, K.rbox(Vector3(s.x * 0.8, 0.05, 0.02), 0.01, 2), K.c("teal"), Vector3(0, s.y * 0.2, s.z * 0.5 + 0.005))
	A.part(root, K.rbox(Vector3(0.16, 0.05, s.z * 0.9), 0.02), dark, Vector3(s.x * 0.12, s.y * 0.1, 0))
	# The oar rows a few strokes when it's zapped (ObjectArt.gag).
	var oar := A.gag(root, &"wiggle", Vector3(0.1, s.y * 0.3, -0.35), Vector3.BACK, 0.45)
	K.rod(oar, Vector3(-0.5, s.y * 0.4, -0.25), Vector3(0.1, s.y * 0.3, -0.35), 0.03, dark)
	A.part(oar, K.rbox(Vector3(0.12, 0.05, 0.26), 0.02), dark.lightened(0.1), Vector3(0.1, s.y * 0.3, -0.35))
