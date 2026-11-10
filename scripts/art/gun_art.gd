## The seven junk-built guns (GAME.md Art direction "Guns"): a hair-dryer body and grip from the
## junk pile, the player's tape wrapped round it (Jeff green, Chuck red), and one signature nozzle in
## the gun's colour so each reads by silhouette alone: grow = dish, grab = cone, bouncy = bellows,
## balloon = funnel, freeze = snow globe, glue = glue bottle, magnet = horseshoe.
## Built as a packed scene so JarlingRig wears it on `hand_r` through the equipment system. The gun
## points along +z from the grip; a node named "tip" marks the muzzle (the beam starts there) and
## the tape bands are named "tape".
class_name GunArt
extends RefCounted

const KINDS: Array[StringName] = [&"size", &"grab", &"bouncy", &"balloon", &"freeze", &"glue", &"magnet"]
## Body junk per gun, so the belt isn't seven of the same can.
const BODY := {&"size": "enamel", &"grab": "metal", &"bouncy": "rust", &"balloon": "enamel",
		&"freeze": "metal", &"glue": "crate", &"magnet": "rust"}

static var _packs := {}


## A packed gun for gear: cached per gun and tape colour.
static func packed(kind: StringName, tape: Color) -> PackedScene:
	var key := "%s|%s" % [kind, tape.to_html()]
	if _packs.has(key):
		return _packs[key]
	var root := build(kind, tape)
	for n in root.find_children("*", "", true, false):
		n.owner = root
	var pack := PackedScene.new()
	pack.pack(root)
	root.free()
	_packs[key] = pack
	return pack


static func build(kind: StringName, tape: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "gun_%s" % kind
	var col := ArtKit.gun(kind if kind != &"grab" else &"grab")
	var body_col := ArtKit.c(BODY.get(kind, "metal"))
	var dark := ArtKit.c("rubber")
	# Grip and trigger.
	ArtKit.put(root, ArtKit.rbox(Vector3(0.075, 0.17, 0.09), 0.03, 2), dark, Vector3(0, -0.07, -0.01), Vector3(-14, 0, 0))
	ArtKit.put(root, ArtKit.rbox(Vector3(0.03, 0.06, 0.03), 0.012, 2), ArtKit.c("metal"), Vector3(0, -0.03, 0.06), Vector3(-25, 0, 0))
	# The hair-dryer body, with a vent cap at the back.
	ArtKit.put(root, ArtKit.cyl(0.075, 0.26, -1.0, 16), body_col, Vector3(0, 0.05, 0.05), Vector3(90, 0, 0))
	ArtKit.put(root, ArtKit.cyl(0.082, 0.04, -1.0, 16), dark, Vector3(0, 0.05, -0.085), Vector3(90, 0, 0))
	ArtKit.put(root, ArtKit.sphere(0.02, 8), ArtKit.c("metal"), Vector3(0.07, 0.1, 0.0))
	# The player's tape: two bands round the body and one on the grip.
	for z in [-0.03, 0.11]:
		var t := ArtKit.put(root, ArtKit.cyl(0.081, 0.035, -1.0, 16), tape, Vector3(0, 0.05, z), Vector3(90, 0, 0))
		t.name = "tape" if z < 0 else "tape2"
	ArtKit.put(root, ArtKit.rbox(Vector3(0.082, 0.04, 0.097), 0.015, 2), tape, Vector3(0, -0.1, -0.018), Vector3(-14, 0, 0)).name = "tape3"
	var front := Vector3(0, 0.05, 0.18)
	var tip_at := front
	match kind:
		&"size":   # a satellite dish on a stalk
			ArtKit.put(root, ArtKit.cyl(0.02, 0.06, -1.0, 8), ArtKit.c("metal"), front + Vector3(0, 0, 0.03), Vector3(90, 0, 0))
			ArtKit.put(root, ArtKit.cyl(0.03, 0.07, 0.17, 20), col, front + Vector3(0, 0, 0.09), Vector3(90, 0, 0))
			ArtKit.put(root, ArtKit.sphere(0.03, 10), ArtKit.c("cream"), front + Vector3(0, 0, 0.1))
			ArtKit.put(root, ArtKit.cyl(0.006, 0.12, -1.0, 6), ArtKit.c("metal"), front + Vector3(0, 0, 0.16), Vector3(90, 0, 0))
			ArtKit.put(root, ArtKit.sphere(0.018, 8), col, front + Vector3(0, 0, 0.22))
			tip_at = front + Vector3(0, 0, 0.22)
		&"grab":   # a leaf-blower cone
			ArtKit.put(root, ArtKit.cyl(0.05, 0.12, -1.0, 12), ArtKit.c("metal"), front + Vector3(0, 0, 0.05), Vector3(90, 0, 0))
			ArtKit.put(root, ArtKit.cyl(0.05, 0.18, 0.13, 20), col, front + Vector3(0, 0, 0.19), Vector3(90, 0, 0))
			ArtKit.put(root, ArtKit.torus(0.12, 0.145, 20), ArtKit.c("metal"), front + Vector3(0, 0, 0.28), Vector3(90, 0, 0))
			tip_at = front + Vector3(0, 0, 0.29)
		&"bouncy":   # an accordion bellows with a spring on the end
			for k in 4:
				ArtKit.put(root, ArtKit.torus(0.035, 0.085 - k * 0.008, 16), col, front + Vector3(0, 0, 0.02 + k * 0.045), Vector3(90, 0, 0))
			for k in 5:
				ArtKit.put(root, ArtKit.torus(0.025, 0.04, 12), ArtKit.c("metal"), front + Vector3(0, 0, 0.21 + k * 0.022), Vector3(90, 0, 0))
			ArtKit.put(root, ArtKit.sphere(0.04, 10), col, front + Vector3(0, 0, 0.32))
			tip_at = front + Vector3(0, 0, 0.34)
		&"balloon":   # a funnel, and a little balloon tied on top
			ArtKit.put(root, ArtKit.cyl(0.03, 0.08, -1.0, 10), ArtKit.c("metal"), front + Vector3(0, 0, 0.03), Vector3(90, 0, 0))
			ArtKit.put(root, ArtKit.cyl(0.03, 0.12, 0.12, 20), col, front + Vector3(0, 0, 0.13), Vector3(90, 0, 0))
			ArtKit.put(root, ArtKit.cyl(0.004, 0.12, -1.0, 6), ArtKit.c("ink"), Vector3(0, 0.18, 0.02))
			var b := ArtKit.put(root, ArtKit.sphere(0.06, 14), col, Vector3(0, 0.28, 0.02), Vector3.ZERO, Vector3(1, 1.2, 1), ArtKit.EMIT)
			b.name = "balloon"
			tip_at = front + Vector3(0, 0, 0.19)
		&"freeze":   # a snow globe on a stand
			ArtKit.put(root, ArtKit.cyl(0.07, 0.05, 0.06, 16), ArtKit.c("wood"), front + Vector3(0, 0, 0.03), Vector3(90, 0, 0))
			ArtKit.put_mat(root, ArtKit.sphere(0.1, 18), ArtKit.glass(Color(col.lightened(0.4), 0.45), 0.2), front + Vector3(0, 0, 0.14))
			for k in 6:
				var a := TAU * k / 6.0
				ArtKit.put(root, ArtKit.sphere(0.012, 6), Color(1, 1, 1), front + Vector3(cos(a) * 0.05, sin(a) * 0.05, 0.14 + sin(a * 2.0) * 0.03))
			ArtKit.put(root, ArtKit.cyl(0.0, 0.07, 0.03, 8), col, front + Vector3(0, -0.02, 0.14))
			tip_at = front + Vector3(0, 0, 0.25)
		&"glue":   # a squeezy glue bottle riding on top, nozzle forward
			ArtKit.put(root, ArtKit.rbox(Vector3(0.09, 0.15, 0.09), 0.035, 3), col, Vector3(0, 0.19, 0.04))
			ArtKit.put(root, ArtKit.cyl(0.03, 0.04, -1.0, 10), ArtKit.c("cream"), Vector3(0, 0.28, 0.04))
			ArtKit.put(root, ArtKit.cyl(0.035, 0.09, 0.008, 12), col.darkened(0.1), front + Vector3(0, 0, 0.05), Vector3(90, 0, 0))
			ArtKit.put(root, ArtKit.sphere(0.022, 8), col, front + Vector3(0, -0.02, 0.1), Vector3.ZERO, Vector3(1, 1.4, 1))
			tip_at = front + Vector3(0, 0, 0.1)
		&"magnet":   # a horseshoe facing forward, standing up so it reads from the side
			var hold := ArtKit.group(root, front + Vector3(0, 0, 0.08))
			for k in 7:
				var a := PI * k / 6.0
				ArtKit.put(hold, ArtKit.rbox(Vector3(0.05, 0.05, 0.05), 0.015, 2), col, Vector3(0, cos(a) * 0.07, -sin(a) * 0.07), Vector3(-rad_to_deg(a), 0, 0))
			for s in [-1.0, 1.0]:
				ArtKit.put(hold, ArtKit.rbox(Vector3(0.05, 0.05, 0.07), 0.015, 2), col, Vector3(0, s * 0.07, 0.035))
				ArtKit.put(hold, ArtKit.rbox(Vector3(0.052, 0.052, 0.04), 0.012, 2), Color(0.88, 0.9, 0.94), Vector3(0, s * 0.07, 0.09))
			tip_at = front + Vector3(0, 0, 0.19)
	var tip := Node3D.new()
	tip.name = "tip"
	tip.position = tip_at
	root.add_child(tip)
	ArtKit.no_shadow(root)   # small, and the hand shadows it anyway
	return root
