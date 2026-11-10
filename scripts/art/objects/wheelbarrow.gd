## A wheelbarrow: a teal metal tray (open top) with a rolled rim and a rust patch, one wheel at the
## front (+x), wooden handles with rubber grips and two legs at the back. Face on the tray side.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var bot := -s.y * 0.5
	var tray := K.c("teal")
	var metal := K.c("metal")
	var hz := s.z * 0.5
	var wr := 0.17
	var wheel := Vector3(s.x * 0.5 - wr - 0.02, bot + wr, 0)
	A.wheel(root, wr, 0.1, wheel)
	for z in [-0.07, 0.07]:
		K.rod(root, wheel + Vector3(0, 0, z), Vector3(wheel.x - 0.32, bot + 0.27, z * 3.0), 0.018, metal)
	# Tray: floor and four walls leaning out.
	var fy := bot + 0.2
	A.part(root, K.rbox(Vector3(0.8, 0.05, 0.55), 0.02), tray.darkened(0.1), Vector3(-0.08, fy, 0))
	var wy := fy + 0.19
	for z in [-1.0, 1.0]:
		A.part(root, K.rbox(Vector3(1.0, 0.38, 0.04), 0.02), tray, Vector3(-0.06, wy, z * (hz - 0.08)), Vector3(z * 16.0, 0, 0))
		A.part(root, K.rbox(Vector3(1.1, 0.05, 0.06), 0.025), tray.lightened(0.15), Vector3(-0.06, wy + 0.19, z * (hz - 0.03)))
	A.part(root, K.rbox(Vector3(0.04, 0.38, s.z * 0.84), 0.02), tray, Vector3(0.36, wy, 0), Vector3(0, 0, -30))
	A.part(root, K.rbox(Vector3(0.04, 0.38, s.z * 0.84), 0.02), tray, Vector3(-0.5, wy, 0), Vector3(0, 0, 10))
	A.detail(root, K.sphere(0.08, 10), K.c("rust"), Vector3(-0.38, wy - 0.08, hz - 0.03), Vector3(0, 0, 0), Vector3(1.3, 0.8, 0.2))
	A.detail(root, K.sphere(0.05, 10), K.c("rust_dark"), Vector3(0.22, wy + 0.1, hz - 0.01), Vector3(0, 0, 0), Vector3(1.2, 0.8, 0.2))
	# Handles, grips and legs.
	var wood := K.c("wood")
	for z in [-1.0, 1.0]:
		var hz2: float = z * (hz - 0.12)
		K.rod(root, Vector3(0.3, fy - 0.03, z * 0.12), Vector3(-s.x * 0.5 - 0.05, fy + 0.12, hz2), 0.028, wood)
		A.part(root, K.cyl(0.036, 0.16), K.c("rubber"), Vector3(-s.x * 0.5 - 0.1, fy + 0.13, hz2), Vector3(0, 0, 80))
		K.rod(root, Vector3(-0.38, fy - 0.01, z * 0.2), Vector3(-0.42, bot + 0.02, z * 0.24), 0.02, metal)
		A.detail(root, K.rbox(Vector3(0.1, 0.03, 0.06), 0.012), K.c("rubber"), Vector3(-0.42, bot + 0.015, z * 0.24))
