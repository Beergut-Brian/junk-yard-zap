## A retro fridge: tall, very rounded cream enamel, a freezer door seam, chrome handles, a chrome
## kick grille and four stubby feet.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var bot := -s.y * 0.5
	var cream := Color("#f6e4bf")
	var chrome := K.c("metal").lightened(0.2)
	var feet := 0.07
	var bh := s.y - feet
	A.part(root, K.rbox(Vector3(s.x, bh, s.z), 0.24, 6), cream, Vector3(0, bot + feet + bh * 0.5, 0))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			A.detail(root, K.cyl(0.05, feet + 0.02), K.c("rubber"), Vector3(x * s.x * 0.36, bot + feet * 0.5, z * s.z * 0.34))
	var fz := s.z * 0.5
	var seam := bot + s.y * 0.74
	A.detail(root, K.rbox(Vector3(s.x * 0.9, 0.025, 0.03), 0.01), cream.darkened(0.3), Vector3(0, seam, fz))
	# Chrome handles: freezer (short) and main door (long), on standoffs.
	var hx := s.x * 0.36
	A.part(root, K.rbox(Vector3(0.06, 0.4, 0.06), 0.03), chrome, Vector3(hx, seam - 0.32, fz + 0.06))
	A.part(root, K.rbox(Vector3(0.06, 0.2, 0.06), 0.03), chrome, Vector3(hx, seam + 0.18, fz + 0.06))
	for y in [seam - 0.48, seam - 0.16, seam + 0.1, seam + 0.26]:
		A.detail(root, K.cyl(0.02, 0.06), chrome, Vector3(hx, y, fz + 0.02), Vector3(90, 0, 0))
	# Kick grille.
	A.part(root, K.rbox(Vector3(s.x * 0.7, 0.12, 0.04), 0.02), chrome, Vector3(0, bot + feet + 0.12, fz))
	for k in 4:
		A.detail(root, K.rbox(Vector3(s.x * 0.62, 0.012, 0.02), 0.004), chrome.darkened(0.35), Vector3(0, bot + feet + 0.08 + k * 0.025, fz + 0.02))
