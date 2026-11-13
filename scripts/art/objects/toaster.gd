## A chrome-and-cream retro toaster: rounded body, two slots with bread peeking out, side lever.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var chrome := d.color
	A.part(root, K.rbox(Vector3(s.x, s.y * 0.86, s.z), 0.16), chrome, Vector3(0, s.y * 0.04, 0))
	A.part(root, K.rbox(Vector3(s.x * 0.98, s.y * 0.28, s.z * 0.98), 0.1), K.c("cream"), Vector3(0, -s.y * 0.2, 0))
	# The toast pops up when it's zapped and drops back in (ObjectArt.gag).
	var toast := A.gag(root, &"pop", Vector3(0, s.y * 0.5, 0), Vector3.UP, s.y * 0.75)
	for dz in [-0.1, 0.1]:
		A.detail(root, K.rbox(Vector3(s.x * 0.62, 0.03, 0.06), 0.015, 2), K.c("ink"), Vector3(0, s.y * 0.47, dz))
		A.part(toast, K.rbox(Vector3(s.x * 0.5, 0.22, 0.04), 0.03, 2), K.c("wood_light"), Vector3(0, s.y * 0.43, dz))
		A.detail(toast, K.rbox(Vector3(s.x * 0.44, 0.16, 0.042), 0.03, 2), K.c("cream"), Vector3(0, s.y * 0.42, dz))
	A.part(root, K.rbox(Vector3(0.05, 0.05, 0.1), 0.02), K.c("rubber"), Vector3(s.x * 0.5 + 0.02, s.y * 0.1, 0))
	A.detail(root, K.sphere(0.03, 8), K.c("teal"), Vector3(s.x * 0.36, -s.y * 0.3, s.z * 0.5), Vector3.ZERO, Vector3(1, 1, 0.5))
	A.detail(root, K.rbox(Vector3(s.x * 0.5, 0.03, 0.02), 0.01, 2), Color(1, 1, 1), Vector3(-s.x * 0.12, s.y * 0.3, s.z * 0.49), Vector3(0, 0, 4))
	for x in [-1.0, 1.0]:
		A.part(root, K.sphere(0.05, 10), K.c("rubber"), Vector3(x * s.x * 0.38, -s.y * 0.5 + 0.04, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
