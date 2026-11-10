## A chicken: plump white egg body, a round head leaning toward the camera (the face sits on it),
## orange beak and comb, a pink wattle, a tuft tail and little orange legs.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var bot := -d.size.y * 0.5
	var white := K.c("chicken")
	var beak := K.c("beak")
	var leg := beak.darkened(0.1)
	for z in [-0.06, 0.06]:
		K.rod(root, Vector3(0.0, bot + 0.1, z), Vector3(0.0, bot + 0.01, z), 0.012, leg)
		A.detail(root, K.sphere(0.035, 8), leg, Vector3(0.025, bot + 0.012, z), Vector3.ZERO, Vector3(1.4, 0.35, 0.9))
	A.part(root, K.sphere(0.17, 20), white, Vector3(-0.03, bot + 0.24, 0), Vector3(0, 0, -10), Vector3(1.25, 0.95, 1.0))
	A.part(root, K.sphere(0.1, 14), white, Vector3(-0.21, bot + 0.33, 0), Vector3(0, 0, 30), Vector3(0.7, 1.1, 0.75))
	A.detail(root, K.sphere(0.1, 14), white.darkened(0.06), Vector3(-0.05, bot + 0.22, 0.14), Vector3(0, 0, -15), Vector3(1.2, 0.75, 0.35))
	var head := Vector3(0.11, bot + 0.38, 0.045)
	A.part(root, K.sphere(0.125, 18), white, head)
	for k in 3:
		A.detail(root, K.sphere(0.035, 8), beak, head + Vector3(-0.04 + k * 0.04, 0.12 - absf(k - 1) * 0.015, 0))
	A.part(root, K.cyl(0.035, 0.08, 0.0, 10), beak, head + Vector3(0.14, -0.01, 0.04), Vector3(0, 0, -90))
	A.detail(root, K.sphere(0.025, 8), K.c("pink"), head + Vector3(0.115, -0.06, 0.05), Vector3.ZERO, Vector3(0.8, 1.3, 0.8))
