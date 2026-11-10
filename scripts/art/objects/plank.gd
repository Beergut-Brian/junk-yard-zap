## A long sun-bleached plank: one wide weathered board with a split down the top, faint grain, a knot and rows of
## nail heads at the ends and the middle.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var wood := Color("#d6c4a0")
	var grain := wood.darkened(0.18)
	A.part(root, K.rbox(s, 0.07), wood)
	A.detail(root, K.rbox(Vector3(s.x * 0.985, 0.02, 0.03), 0.008), grain.darkened(0.2), Vector3(0, s.y * 0.5, -s.z * 0.04))
	for x in [-1.0, 1.0]:
		A.detail(root, K.rbox(Vector3(0.02, s.y * 0.8, s.z * 0.9), 0.01), grain, Vector3(x * s.x * 0.5, 0, 0))
	# Grain lines on the top and the front edge.
	for g in [[-0.9, 0.2, 1.2], [0.5, 0.32, 1.6], [-0.2, -0.3, 1.4], [1.1, -0.18, 0.9]]:
		A.detail(root, K.rbox(Vector3(g[2], 0.012, 0.02), 0.005), grain, Vector3(g[0], s.y * 0.5, g[1] * s.z))
	A.detail(root, K.rbox(Vector3(1.6, 0.02, 0.012), 0.005), grain, Vector3(-0.8, 0.03, s.z * 0.5))
	A.detail(root, K.rbox(Vector3(1.0, 0.02, 0.012), 0.005), grain, Vector3(0.3, -0.04, s.z * 0.5))
	A.detail(root, K.sphere(0.07, 10), grain.darkened(0.15), Vector3(-0.4, s.y * 0.5, 0.18), Vector3.ZERO, Vector3(1.5, 0.15, 1.0))
	# Nail heads in pairs at the ends and the middle.
	var nail := K.c("metal").darkened(0.1)
	for x in [-0.46, 0.0, 0.46]:
		for z in [-0.3, -0.18, 0.18, 0.3]:
			A.detail(root, K.sphere(0.028, 8), nail, Vector3(x * s.x, s.y * 0.5, z * s.z), Vector3.ZERO, Vector3(1, 0.4, 1))
