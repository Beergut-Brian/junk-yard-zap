## What a yard object is, before any gun touches it. The Content lane makes these as .tres in
## data/objects/ (see data/objects/cow.tres); PhysicsObject builds the body, face and voice from it.
class_name ObjectData
extends Resource

## BOX, SPHERE; CYLINDER is a wheel facing the camera (axis along Z); TUB is a box open on top.
enum Shape { BOX, SPHERE, CYLINDER, TUB }

@export var id: StringName = &"box"
@export var shape: Shape = Shape.BOX
## Box/tub: full extents in metres. Sphere: x is the diameter. Cylinder: x diameter, z length.
@export var size := Vector3.ONE
@export var mass := 1.0
@export var color := Color(0.75, 0.55, 0.35)
@export var bounce := 0.1
@export var friction := 0.8
## Size steps: 4 down, 4 up. Each step multiplies the size by step_factor.
@export var min_step := -4
@export var max_step := 4
@export var step_factor := 1.3
## Voice cue played when a gun touches it (pitch follows size). Empty: "voice_<id>".
@export var voice: StringName = &""
## Two dots and a mouth on the front. face_at is the face centre relative to the object's centre,
## in units of size (0.5 on z is the front surface); face_size in metres at scale 1.
@export var has_face := true
@export var face_at := Vector3(0.25, 0.15, 0.5)
@export var face_size := 0.35
## Visual-only extra blocks (grey-box silhouettes until the Art lane ships meshes):
## {"shape": "box"|"sphere"|"cylinder", "size": Vector3, "at": Vector3, "color": Color}
@export var parts: Array[Dictionary] = []
## Art lane: a mesh scene that replaces the grey-box visual (same size at scale 1).
@export var mesh: PackedScene


func scale_for_step(step: int) -> float:
	return pow(step_factor, clampi(step, min_step, max_step))


## Volume at scale 1, so mass can follow volume.
func base_volume() -> float:
	if shape == Shape.SPHERE:
		var r := size.x * 0.5
		return 4.0 / 3.0 * PI * r * r * r
	if shape == Shape.CYLINDER:
		return PI * size.x * size.x * 0.25 * size.z
	return size.x * size.y * size.z


## Mass per cubic metre, unchanged by grow/shrink. Water floats anything under Yard.WATER_DENSITY.
func density() -> float:
	return mass / maxf(base_volume(), 0.001)


func voice_cue() -> String:
	return String(voice) if voice != &"" else "voice_%s" % id


static func make(p_id: StringName, p_shape: Shape, p_size: Vector3, p_mass: float, p_color: Color) -> ObjectData:
	var d := ObjectData.new()
	d.id = p_id
	d.shape = p_shape
	d.size = p_size
	d.mass = p_mass
	d.color = p_color
	return d
