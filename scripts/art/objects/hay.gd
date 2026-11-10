## A hay bale: a golden rounded block with straw texture bands, two twine loops and a few stray
## straws poking out.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var hay := K.c("hay")
	A.part(root, K.rbox(s * Vector3(1.0, 1.0, 1.0), 0.13), hay)
	# Straw bands: thin light and dark strips wrapping front, top and back.
	var bands := [[-0.3, 0.12], [-0.12, -0.1], [0.06, 0.1], [0.24, -0.08], [0.38, 0.12]]
	for b in bands:
		var col := hay.lightened(b[1]) if b[1] > 0.0 else hay.darkened(-b[1])
		A.detail(root, K.rbox(Vector3(s.x * 0.97, s.y * 0.05, s.z + 0.012), 0.012), col, Vector3(0, b[0] * s.y, 0))
	A.detail(root, K.rbox(Vector3(s.x * 0.97, s.y + 0.012, s.z * 0.05), 0.012), hay.darkened(0.08), Vector3(0, 0, -s.z * 0.2))
	A.detail(root, K.rbox(Vector3(s.x * 0.97, s.y + 0.012, s.z * 0.05), 0.012), hay.lightened(0.1), Vector3(0, 0, s.z * 0.12))
	# Twine.
	var twine := Color("#8a5a2b")
	for x in [-0.33, 0.33]:
		A.detail(root, K.rbox(Vector3(0.045, s.y + 0.03, s.z + 0.03), 0.03), twine, Vector3(x * s.x, 0, 0))
	# Stray straws.
	var straw := hay.lightened(0.2)
	K.rod(root, Vector3(-s.x * 0.5, s.y * 0.3, 0.1), Vector3(-s.x * 0.5 - 0.12, s.y * 0.38, 0.14), 0.012, straw)
	K.rod(root, Vector3(s.x * 0.5, -s.y * 0.1, 0.0), Vector3(s.x * 0.5 + 0.1, -s.y * 0.02, 0.1), 0.012, straw)
	K.rod(root, Vector3(-s.x * 0.2, s.y * 0.5, 0.0), Vector3(-s.x * 0.24, s.y * 0.5 + 0.1, 0.05), 0.012, straw)
