## A cream front-loader washing machine: enamel box, round glass door with a teal rim, knobs and a dented top.
## Zapped, the porthole door swings open on the drum (a red sock inside) and shuts (ObjectArt.gag).
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var white := d.color
	A.part(root, K.rbox(s * 0.97, 0.12), white)
	A.part(root, K.rbox(Vector3(s.x, s.y * 0.08, s.z), 0.05), white.darkened(0.08), Vector3(0, s.y * 0.46, 0))
	A.detail(root, K.rbox(Vector3(s.x * 0.9, 0.02, 0.04), 0.01, 2), white.darkened(0.3), Vector3(0, s.y * 0.3, s.z * 0.5))
	var dz := s.z * 0.5
	# The drum behind the door (a red sock going round), then the porthole door on its left hinge.
	A.detail(root, K.cyl(s.x * 0.27, 0.02), K.c("ink").lightened(0.25), Vector3(0, -s.y * 0.1, dz - 0.005), Vector3(90, 0, 0))
	A.detail(root, K.rbox(Vector3(0.16, 0.07, 0.03), 0.03), Color("#e0533d"), Vector3(0.04, -s.y * 0.16, dz + 0.008), Vector3(0, 0, -25))
	var door := A.gag(root, &"swing", Vector3(-s.x * 0.36, -s.y * 0.1, dz + 0.03), Vector3.UP, deg_to_rad(-100.0))
	A.part(door, K.torus(s.x * 0.24, s.x * 0.36), K.c("teal"), Vector3(0, -s.y * 0.1, dz + 0.03), Vector3(90, 0, 0), Vector3(1, 1.6, 1))
	K.put_mat(door, K.cyl(s.x * 0.27, 0.03), K.glass(Color(0.55, 0.85, 0.92, 0.75)), Vector3(0, -s.y * 0.1, dz + 0.035), Vector3(90, 0, 0))
	A.detail(root, K.sphere(0.1), K.c("cream").darkened(0.15), Vector3(0, -s.y * 0.1, dz - 0.03), Vector3.ZERO, Vector3(1.3, 1, 0.3))
	A.detail(root, K.sphere(0.04, 8), K.c("mustard"), Vector3(-s.x * 0.34, s.y * 0.4, dz), Vector3.ZERO, Vector3(1, 1, 0.5))
	A.detail(root, K.sphere(0.04, 8), K.c("teal"), Vector3(s.x * 0.28, s.y * 0.4, dz), Vector3.ZERO, Vector3(1, 1, 0.5))
	A.detail(root, K.sphere(0.04, 8), K.c("teal"), Vector3(s.x * 0.38, s.y * 0.4, dz), Vector3.ZERO, Vector3(1, 1, 0.5))
	for x in [-1.0, 1.0]:
		A.part(root, K.rbox(Vector3(0.12, 0.06, 0.12), 0.02), K.c("rubber"), Vector3(x * s.x * 0.38, -s.y * 0.5 + 0.03, s.z * 0.35))
