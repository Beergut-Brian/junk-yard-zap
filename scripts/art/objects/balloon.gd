## A loose balloon: a round, slightly tall party balloon with a shine, a tied knot and a curly
## string hanging down. The string is visual only (the body is the round part).
## LooseBalloon recolours "Body" and "Knot" per balloon (BalloonData.tints).
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var r := d.size.x * 0.5
	A.part(root, K.sphere(r, 28), d.color, Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1.0, 1.1, 1.0)).name = "Body"
	# Shine: a soft cream dot up and to the left, clear of the face.
	A.detail(root, K.sphere(r * 0.16, 12), K.c("cream"), Vector3(-r * 0.5, r * 0.62, r * 0.55), Vector3.ZERO,
			Vector3(1.0, 1.4, 0.4))
	# Knot: a little cone under the balloon, same colour, a touch darker.
	var knot := d.color.darkened(0.2)
	A.detail(root, K.cyl(r * 0.05, r * 0.2, r * 0.16, 12), knot, Vector3(0, -r * 1.1 - r * 0.08, 0)).name = "Knot"
	# String: a few short rods that wiggle down, so it reads as a string at TV distance.
	var ink := K.c("ink")
	var p := Vector3(0, -r * 1.25, 0)
	for i in 5:
		var q := p + Vector3((0.06 if i % 2 == 0 else -0.06), -0.17, 0)
		K.rod(root, p, q, 0.018, ink)
		p = q
