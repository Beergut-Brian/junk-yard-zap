## A two-tone play ball: teal top half, mustard bottom half, a cream seam and a cream cap button,
## tilted so it reads as a ball, not a planet. The face sits on the teal half.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")

static var _halves := {}


static func build(root: Node3D, d: ObjectData) -> void:
	var r := d.size.x * 0.5
	var cream := K.c("cream")
	var g := K.group(root, Vector3.ZERO, Vector3(30, 0, -18))
	A.part(g, K.sphere(r, 32), K.c("mustard"))
	A.part(g, _half(r * 1.008), K.c("teal"))
	A.detail(g, K.torus(r * 0.975, r * 1.035, 40), cream)
	A.detail(g, K.sphere(r * 0.22, 16), cream, Vector3(0, r * 0.97, 0), Vector3.ZERO, Vector3(1, 0.25, 1))
	A.detail(g, K.sphere(r * 0.2, 16), cream, Vector3(0, -r * 0.97, 0), Vector3.ZERO, Vector3(1, 0.25, 1))


## Upper half sphere (cached per radius).
static func _half(r: float) -> SphereMesh:
	var key := "%.3f" % r
	if not _halves.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r
		m.is_hemisphere = true
		m.radial_segments = 32
		m.rings = 10
		_halves[key] = m
	return _halves[key]
