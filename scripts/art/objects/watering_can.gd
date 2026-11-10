## A teal watering can: round body, long spout to the right with a rose, arched handle.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var teal := d.color
	var bw := s.x * 0.5
	A.part(root, K.rbox(Vector3(bw, s.y * 0.95, s.z * 0.98), 0.14), teal, Vector3(-s.x * 0.15, 0, 0))
	A.detail(root, K.cyl(bw * 0.4, 0.02), teal.darkened(0.45), Vector3(-s.x * 0.15, s.y * 0.48, 0))
	A.part(root, K.rbox(Vector3(bw * 1.04, s.y * 0.08, s.z * 1.0), 0.03), teal.lightened(0.15), Vector3(-s.x * 0.15, s.y * 0.44, 0))
	K.rod(root, Vector3(-s.x * 0.02, -s.y * 0.3, 0), Vector3(s.x * 0.38, s.y * 0.25, 0), 0.07, teal.lightened(0.05))
	A.part(root, K.cyl(0.13, 0.12, 0.17), teal.lightened(0.12), Vector3(s.x * 0.42, s.y * 0.3, 0), Vector3(0, 0, -62))
	for dz in [-0.04, 0.04]:
		A.detail(root, K.sphere(0.02, 6), K.c("ink"), Vector3(s.x * 0.455, s.y * 0.34, dz), Vector3.ZERO, Vector3(0.5, 1, 1))
	A.part(root, K.torus(s.x * 0.17, s.x * 0.22), teal.darkened(0.15), Vector3(-s.x * 0.38, s.y * 0.05, 0), Vector3(90, 0, 0), Vector3(1, s.z * 0.36 / (s.x * 0.05), 1))
