## A cream egg: tiny and smooth.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var r := d.size.x * 0.5
	A.part(root, K.sphere(r), K.c("cream"), Vector3(0, -r * 0.05, 0), Vector3.ZERO, Vector3(0.9, 1.0, 0.9))
	A.part(root, K.sphere(r * 0.7), K.c("cream"), Vector3(0, r * 0.3, 0), Vector3.ZERO, Vector3(0.9, 0.8, 0.9))
	A.detail(root, K.sphere(r * 0.12), K.c("hay"), Vector3(-r * 0.4, r * 0.45, r * 0.55), Vector3.ZERO, Vector3(1, 1, 0.4))
	A.detail(root, K.sphere(r * 0.1), K.c("hay"), Vector3(r * 0.5, -r * 0.5, r * 0.6), Vector3.ZERO, Vector3(1, 1, 0.4))
