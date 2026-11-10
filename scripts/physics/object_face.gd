## Two dots and a mouth on the front of a yard object, and the moods they make (GAME.md Art
## direction: wide-eyed when grabbed, dizzy when thrown, smug when bouncy, panicked when ballooning).
## Built from spheres so it reads at any size; the Art lane can replace it with a face rig.
class_name ObjectFace
extends Node3D

enum Mood { NEUTRAL, HAPPY, WIDE, DIZZY, SMUG, PANIC, SHUT, SAD }

const MOUTH_DOTS := 5
const INK := Color(0.08, 0.06, 0.06)

var mood := Mood.NEUTRAL
## The mood the effects on the object ask for; flashes (react) fall back to it.
var base_mood := Mood.NEUTRAL
var _flash_left := 0.0
var _blink := 2.0
var _t := 0.0
var _eyes: Array[MeshInstance3D] = []
var _mouth: Array[MeshInstance3D] = []
var _size := 0.35


func setup(face_size: float) -> void:
	_size = face_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = INK
	mat.roughness = 0.4
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(1, 1, 1)
	for i in 2:
		var white_eye := _dot(_size * 0.2, white)
		white_eye.position = Vector3((i * 2 - 1) * _size * 0.3, _size * 0.15, -0.005)
		white_eye.scale.z = 0.3
		var pupil := _dot(_size * 0.11, mat, white_eye)
		pupil.position = Vector3(0, 0, _size * 0.2)
		_eyes.append(white_eye)
	for i in MOUTH_DOTS:
		_mouth.append(_dot(_size * 0.055, mat))
	_pose(0.0)


func _dot(r: float, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 5
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


## A quick reaction for `seconds`, then back to base_mood.
func react(m: Mood, seconds := 0.8) -> void:
	mood = m
	_flash_left = seconds


func set_base(m: Mood) -> void:
	base_mood = m
	if _flash_left <= 0.0:
		mood = m


func _process(delta: float) -> void:
	_t += delta
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			mood = base_mood
	_blink -= delta
	if _blink < -0.12:
		_blink = randf_range(2.0, 4.5)
	_pose(delta)


func _pose(_delta: float) -> void:
	if _eyes.is_empty():
		return
	var eye := 1.0
	var lid := 1.0
	var curve := 0.0      # + smile, - frown
	var open := 0.0       # 0 a line, 1 a round O
	var width := 1.0
	var wobble := Vector3.ZERO
	match mood:
		Mood.HAPPY: curve = 1.0
		Mood.WIDE: eye = 1.45; open = 0.7
		Mood.DIZZY: curve = -0.3; wobble = Vector3(cos(_t * 14.0), sin(_t * 14.0), 0) * _size * 0.06
		Mood.SMUG: lid = 0.45; curve = 0.8; width = 1.3
		Mood.PANIC: eye = 1.35; open = 1.0; width = 0.6; wobble = Vector3(sin(_t * 50.0), 0, 0) * _size * 0.03
		Mood.SHUT: lid = 0.12; curve = 0.2
		Mood.SAD: curve = -0.8
	if _blink < 0.0 and mood != Mood.SHUT:
		lid = 0.1
	for i in 2:
		var e := _eyes[i]
		e.scale = Vector3(eye, eye * lid, 0.3)
		var pupil := e.get_child(0) as Node3D
		pupil.position = Vector3(0, 0, _size * 0.2) + (wobble * (1 if i == 0 else -1)) / maxf(eye, 0.01)
	for i in MOUTH_DOTS:
		var u := float(i) / (MOUTH_DOTS - 1) * 2.0 - 1.0   # -1..1 across the mouth
		var line := Vector3(u * _size * 0.28 * width, -_size * 0.22 + curve * (1.0 - u * u) * -_size * 0.12, 0.0)
		var ang := (u * 0.5 + 0.5) * TAU
		var ring := Vector3(cos(ang) * _size * 0.09, -_size * 0.25 + sin(ang) * _size * 0.1, 0.0)
		_mouth[i].position = line.lerp(ring, open)
