## Patience's face on the yard's face rig. PhysicsObject still builds the ObjectFace (the rig: moods
## from the effects, reaction flashes, so the gameplay and the tests see the same face as on every
## other object), but on Patience its googly eyes are hidden and its mood picks the cell of her own
## face atlas instead (library look.md: six expressions, the yard's reaction list; the atlas is
## 3 x 2: neutral, happy, wide_eyed / dizzy, smug, panicked). She also chews (her idle loop).
extends Node

## ObjectFace.Mood -> her atlas cell (uv1 offset). Frozen keeps her resting face (bible: she goes
## on chewing inside the ice); SAD has no cell of its own, dizzy is the closest.
const CELL := {
	ObjectFace.Mood.NEUTRAL: Vector3(0.0, 0.0, 0.0),
	ObjectFace.Mood.HAPPY: Vector3(1.0 / 3.0, 0.0, 0.0),
	ObjectFace.Mood.WIDE: Vector3(2.0 / 3.0, 0.0, 0.0),
	ObjectFace.Mood.DIZZY: Vector3(0.0, 0.5, 0.0),
	ObjectFace.Mood.SMUG: Vector3(1.0 / 3.0, 0.5, 0.0),
	ObjectFace.Mood.PANIC: Vector3(2.0 / 3.0, 0.5, 0.0),
	ObjectFace.Mood.SHUT: Vector3(0.0, 0.0, 0.0),
	ObjectFace.Mood.SAD: Vector3(0.0, 0.5, 0.0),
}

## Her own copy of the face material (the glb's is shared by every instance).
var face_mat: StandardMaterial3D
var _rig: ObjectFace
var _shown := -1


func setup(model: Node3D) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s) as StandardMaterial3D
			if mat and mat.resource_name.ends_with("_face"):
				face_mat = mat.duplicate()
				m.set_surface_override_material(s, face_mat)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("idle"):
		anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")


## The yard's face rig on this object (PhysicsObject adds it as a sibling of the art root).
func rig() -> ObjectFace:
	if _rig == null or not is_instance_valid(_rig):
		var visual := get_parent().get_parent() if get_parent() else null
		_rig = visual.get_node_or_null("Face") as ObjectFace if visual else null
		if _rig:
			_rig.visible = false
	return _rig


## The atlas cell she shows now.
func cell() -> Vector3:
	return face_mat.uv1_offset if face_mat else Vector3.ZERO


func _process(_delta: float) -> void:
	var r := rig()
	if r == null or face_mat == null or r.mood == _shown:
		return
	_shown = r.mood
	face_mat.uv1_offset = CELL.get(r.mood, Vector3.ZERO)
