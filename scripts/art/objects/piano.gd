## An upright piano: a dark wood cabinet with a lighter front panel (the face sits on it), a lid,
## cream keys with black keys poking out in front, two legs and brass pedals.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var bot := -s.y * 0.5
	var top := s.y * 0.5
	var fz := s.z * 0.5
	var dark := Color("#4f2c1f")
	var panel := Color("#9a6239")
	var key_y := bot + 0.66
	# Cabinet, lid, front panels.
	A.part(root, K.rbox(Vector3(s.x - 0.06, s.y - 0.06, s.z - 0.04), 0.1), dark, Vector3(0, -0.03, -0.02))
	A.part(root, K.rbox(Vector3(s.x, 0.08, s.z), 0.04), dark.lightened(0.06), Vector3(0, top - 0.04, 0))
	A.detail(root, K.rbox(Vector3(s.x * 0.8, top - key_y - 0.22, 0.03), 0.04), panel, Vector3(0, (top + key_y) * 0.5 + 0.05, fz - 0.03))
	A.detail(root, K.rbox(Vector3(s.x * 0.74, key_y - bot - 0.28, 0.03), 0.04), dark.lightened(0.12), Vector3(0, (key_y + bot) * 0.5 - 0.02, fz - 0.03))
	# Keybed and keys, poking out in front of the box.
	var kd := 0.26
	A.part(root, K.rbox(Vector3(s.x * 0.94, 0.1, kd + 0.04), 0.03), dark, Vector3(0, key_y - 0.05, fz + kd * 0.5 - 0.02))
	var kw := s.x * 0.8
	A.part(root, K.rbox(Vector3(kw, 0.05, kd - 0.03), 0.015), K.c("cream"), Vector3(0, key_y + 0.02, fz + kd * 0.5 - 0.01))
	for x in [-0.5, 0.5]:
		A.part(root, K.rbox(Vector3(0.08, 0.14, kd + 0.04), 0.03), dark, Vector3(x * (kw + 0.08), key_y + 0.03, fz + kd * 0.5 - 0.02))
	var pattern := [1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1, 1]
	var step := kw / (pattern.size() + 1)
	for i in pattern.size():
		if pattern[i] == 1:
			A.detail(root, K.rbox(Vector3(step * 0.55, 0.04, kd * 0.55), 0.01), K.c("ink"), Vector3(-kw * 0.5 + step * (i + 1), key_y + 0.06, fz + kd * 0.3))
	# Legs (toe blocks) and pedals.
	for x in [-1.0, 1.0]:
		A.part(root, K.rbox(Vector3(0.1, key_y - bot - 0.1, 0.12), 0.04), dark, Vector3(x * s.x * 0.42, (key_y + bot) * 0.5 - 0.05, fz + kd - 0.1))
		A.detail(root, K.rbox(Vector3(0.14, 0.06, 0.16), 0.02), dark.darkened(0.2), Vector3(x * s.x * 0.42, bot + 0.03, fz + kd - 0.1))
	for x in [-0.1, 0.1]:
		A.detail(root, K.rbox(Vector3(0.07, 0.03, 0.14), 0.012), K.c("mustard"), Vector3(x, bot + 0.07, fz + 0.06))
