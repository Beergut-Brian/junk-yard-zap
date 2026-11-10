## What a yard object is, before any gun touches it. The Content lane makes these as .tres later.
class_name ObjectData
extends Resource

enum Shape { BOX, SPHERE }

@export var id: StringName = &"box"
@export var shape: Shape = Shape.BOX
## Box: full extents in metres. Sphere: x is the diameter.
@export var size := Vector3.ONE
@export var mass := 1.0
@export var color := Color(0.75, 0.55, 0.35)
@export var bounce := 0.1
@export var friction := 0.8
## Size steps: 4 down, 4 up. Each step multiplies the size by step_factor.
@export var min_step := -4
@export var max_step := 4
@export var step_factor := 1.3


func scale_for_step(step: int) -> float:
	return pow(step_factor, clampi(step, min_step, max_step))


## Volume at scale 1, so mass can follow volume.
func base_volume() -> float:
	if shape == Shape.SPHERE:
		var r := size.x * 0.5
		return 4.0 / 3.0 * PI * r * r * r
	return size.x * size.y * size.z


static func make(p_id: StringName, p_shape: Shape, p_size: Vector3, p_mass: float, p_color: Color) -> ObjectData:
	var d := ObjectData.new()
	d.id = p_id
	d.shape = p_shape
	d.size = p_size
	d.mass = p_mass
	d.color = p_color
	return d
