## A clawfoot bathtub: a rounded cream enamel tub on four metal claw feet, a rolled rim, a line of
## bath water with a couple of bubbles, and a tap at the back-left end.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var enamel := K.c("enamel")
	var metal := K.c("metal")
	var bot := -s.y * 0.5
	var top := s.y * 0.5
	var foot_h := 0.13
	var body_h := s.y - foot_h - 0.04
	A.part(root, K.rbox(Vector3(s.x * 0.94, body_h, s.z * 0.98), 0.3), enamel, Vector3(0, bot + foot_h + body_h * 0.5, 0))
	# Rolled rim: four bars round the top so the water shows inside.
	var ry := top - 0.06
	for z in [-1.0, 1.0]:
		A.part(root, K.rbox(Vector3(s.x, 0.12, 0.16), 0.06), enamel, Vector3(0, ry, z * (s.z * 0.5 - 0.06)))
	for x in [-1.0, 1.0]:
		A.part(root, K.rbox(Vector3(0.2, 0.12, s.z), 0.06), enamel, Vector3(x * (s.x * 0.5 - 0.08), ry, 0))
	K.put_mat(root, K.rbox(Vector3(s.x - 0.3, 0.05, s.z - 0.28), 0.02), K.glass(Color(K.c("pond"), 0.9)), Vector3(0, ry - 0.02, 0))
	for b in [[0.45, -0.15, 0.07], [0.6, 0.05, 0.05], [-0.4, 0.12, 0.06]]:
		A.detail(root, K.sphere(b[2], 10), K.c("cloud"), Vector3(b[0], ry + 0.01, b[1]))
	# Claw feet: a ball with three toes, splayed out.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var p := Vector3(x * s.x * 0.36, bot + 0.08, z * s.z * 0.34)
			A.part(root, K.sphere(0.075, 12), metal, p + Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1, 1.3, 1))
			A.detail(root, K.sphere(0.06, 10), metal.darkened(0.15), Vector3(p.x + x * 0.05, bot + 0.045, p.z + z * 0.03), Vector3.ZERO, Vector3(1.4, 0.75, 1.4))
	# Tap: a pipe up the left end and a spout over the water.
	var tx := -s.x * 0.5 + 0.08
	K.rod(root, Vector3(tx, ry, -s.z * 0.2), Vector3(tx, top + 0.28, -s.z * 0.2), 0.035, metal)
	K.rod(root, Vector3(tx, top + 0.28, -s.z * 0.2), Vector3(tx + 0.2, top + 0.2, -s.z * 0.2), 0.03, metal)
	A.detail(root, K.cyl(0.07, 0.04), metal.darkened(0.2), Vector3(tx, top + 0.3, -s.z * 0.2))
