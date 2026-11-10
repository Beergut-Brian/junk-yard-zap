## An invented garden gnome statue: a stone plinth, chunky boots, a denim smock with a belt, a fat
## white beard, a button nose and a tall teal hat that flops over at the tip. Face on the head.
extends RefCounted

const K = preload("res://scripts/art/art_kit.gd")
const A = preload("res://scripts/art/object_art.gd")

const STONE := Color("#b3aca0")
const SKIN := Color("#f2c9a0")


static func build(root: Node3D, d: ObjectData) -> void:
	var s := d.size
	var bot := -s.y * 0.5
	var smock := d.color
	A.part(root, K.rbox(Vector3(s.x * 0.92, 0.1, s.z * 0.9), 0.03), STONE, Vector3(0, bot + 0.05, 0))
	for x in [-0.08, 0.08]:
		A.part(root, K.sphere(0.07, 12), K.c("wood").darkened(0.3), Vector3(x, bot + 0.14, 0.07), Vector3.ZERO, Vector3(0.9, 0.7, 1.3))
	var body_y := bot + 0.32
	A.part(root, K.cyl(0.2, 0.4, 0.14), smock, Vector3(0, body_y, 0))
	A.detail(root, K.cyl(0.18, 0.05, 0.175), K.c("rubber"), Vector3(0, body_y - 0.02, 0))
	A.detail(root, K.rbox(Vector3(0.07, 0.06, 0.02), 0.01), K.c("mustard"), Vector3(0, body_y - 0.02, 0.18))
	for x in [-1.0, 1.0]:
		A.part(root, K.sphere(0.07, 12), smock.darkened(0.1), Vector3(x * 0.19, body_y + 0.06, 0.03), Vector3(0, 0, x * 20.0), Vector3(0.8, 1.4, 0.8))
		A.part(root, K.sphere(0.045, 10), SKIN, Vector3(x * 0.2, body_y - 0.06, 0.06))
	var head := Vector3(0, s.y * 0.1, 0.08)
	A.part(root, K.sphere(0.15, 20), SKIN, head)
	A.part(root, K.sphere(0.15, 18), K.c("cream"), head + Vector3(0, -0.15, -0.01), Vector3.ZERO, Vector3(1.05, 0.95, 0.75))
	A.detail(root, K.sphere(0.042, 10), K.c("pink"), head + Vector3(0, -0.02, 0.14))
	var hat := K.c("teal")
	A.part(root, K.torus(0.11, 0.17), hat.darkened(0.12), head + Vector3(0, 0.07, -0.03), Vector3(-8, 0, 0), Vector3(1, 1.4, 1))
	A.part(root, K.cyl(0.155, 0.3, 0.05), hat, head + Vector3(0, 0.22, -0.04), Vector3(0, 0, -6))
	A.part(root, K.sphere(0.06, 10), hat, head + Vector3(0.06, 0.38, -0.04), Vector3(0, 0, -40), Vector3(1.5, 0.9, 1.0))
