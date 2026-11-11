## The cow is Patience, the library cow (openjar-characters v0.5.1 `proposals/cow`, D53 a). Her look is
## the library's own 3D master (assets/models/patience/cow.glb, copied unchanged): white barrel body,
## black patches, the patch over her right eye, pink muzzle, cream horn nubs, dark hooves, tufted tail.
## Standing side-on with her head at +x like the old grey-box cow, turned a little toward the couch so
## her face reads. Her own face atlas carries the moods (PatienceFace mirrors the yard's face rig).
## The physics body is untouched: ObjectData size 1.9 x 1.0 x 0.8, mass 6.
extends RefCounted

const GLB := "res://assets/models/patience/cow.glb"
const PatienceFace = preload("res://scripts/art/patience_face.gd")
## The glb is the library's cow (1.07 m to the horns, 1.4 m nose to tail tuft). At this scale and turn
## her body fills the box (rump to chest along its 1.9 m, back at its top) and her head pokes up past
## its front corner like the grey-box cow's did. Never stretched: her proportions stay the library's.
const SCALE := 1.45
## Facing +x (head toward the right of the yard), turned this far toward the camera (+z) so her face
## (eye patch, lashes, muzzle) reads from the couch; 0 is a flat side view. 40 reads a bit better but
## leaves ~0.25 m of invisible box at each end; 22 fills the box but loses the face (frames in handoff/).
const TURN_TO_CAMERA := 30.0
## Her bounds' centre along x at that turn is 0.1 m (glb units) toward the head: shift back to centre.
const CENTRE_X := -0.1


static func build(root: Node3D, d: ObjectData) -> void:
	var model := (load(GLB) as PackedScene).instantiate() as Node3D
	model.name = "Patience"
	model.scale = Vector3.ONE * SCALE
	model.rotation_degrees.y = 90.0 - TURN_TO_CAMERA
	# Hooves on the bottom of the box; her middle on the body's centre.
	model.position = Vector3(CENTRE_X * SCALE, -d.size.y * 0.5, 0.0)
	root.add_child(model)
	var face := PatienceFace.new()
	face.name = "PatienceFace"
	root.add_child(face)
	face.setup(model)
