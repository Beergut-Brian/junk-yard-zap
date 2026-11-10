## Risk-prototype player stand-in: a capsule on the locked plane that walks, jumps and zaps.
## Stick (or WASD) moves and aims; A/Space fires; B/Enter jumps; LB/RB or Q/E cycle the gun.
class_name ProtoPlayer
extends CharacterBody3D

const SPEED := 6.0
const JUMP := 7.0
const RISE_GRAVITY := 0.7     # floaty on the way up, forgiving

signal fired(gun: StringName, target: Node3D, changed: bool)

var player := Players.P1
var gun_index := 0
var aim_dir := Vector2.RIGHT
var target: Node3D
var glue_first: PhysicsObject

var _beam: MeshInstance3D
var _marker: MeshInstance3D


func _ready() -> void:
	axis_lock_linear_z = true
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	cs.shape = cap
	add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.6
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Players.COLOR[player]
	mi.material_override = m
	add_child(mi)
	_beam = MeshInstance3D.new()
	_beam.mesh = _cone_mesh()
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.albedo_color = Color(1, 1, 1, 0.12)
	_beam.material_override = bmat
	add_child(_beam)
	_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.7
	_marker.mesh = tm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color.WHITE
	mm.no_depth_test = true
	_marker.material_override = mm
	_marker.rotation_degrees.x = 90
	_marker.top_level = true
	add_child(_marker)


func gun() -> StringName:
	return Effects.GUNS[gun_index]


func _physics_process(delta: float) -> void:
	up_direction = Yard.up_at(global_position)
	var g := Yard.gravity_at(global_position)
	if not is_on_floor():
		velocity += g * (RISE_GRAVITY if velocity.dot(up_direction) > 0.0 else 1.0) * delta
	var mv := Players.move_vector(player)
	velocity.x = mv.x * SPEED
	if Input.is_action_just_pressed(Players.action(player, "jump")) and is_on_floor():
		velocity += up_direction * JUMP
		Audio.play("jump")
	move_and_slide()
	if mv.length() > 0.2:
		aim_dir = Vector2(mv.x, -mv.y).normalized()
	_beam.rotation.z = aim_dir.angle()
	target = Aim.pick(global_position, aim_dir, candidates())
	_marker.visible = target != null
	if target:
		var r := (target as PhysicsObject).radius() if target is PhysicsObject else 0.3
		_marker.global_position = target.global_position + Vector3(0, 0, 1.0)
		_marker.scale = Vector3.ONE * maxf(0.5, r)
	if Input.is_action_just_pressed(Players.action(player, "action")):
		fire()


func candidates() -> Array:
	var out: Array = get_tree().get_nodes_in_group(PhysicsObject.GROUP)
	if gun() == &"glue":
		for j in get_tree().get_nodes_in_group(&"glue_joints"):
			var glue: Effects.Glue = j.get_meta(&"glue")
			if is_instance_valid(glue.blob):
				out.append(glue.blob)
	return out


func fire() -> void:
	var changed := false
	if target == null:
		Audio.play("sparkle")
	elif gun() == &"glue":
		changed = _fire_glue()
	else:
		changed = Effects.zap(gun(), target as PhysicsObject)
		Audio.play("zap_%s" % gun() if changed else "nope")
	var flash := create_tween()
	flash.tween_property(_beam.material_override, "albedo_color:a", 0.12, 0.25).from(0.6)
	fired.emit(gun(), target, changed)


func _fire_glue() -> bool:
	if target is MeshInstance3D:   # a glue blob: split
		(target.get_parent().get_meta(&"glue") as Effects.Glue).undo(null)
		glue_first = null
		Audio.play("unglue")
		return true
	var obj := target as PhysicsObject
	if glue_first == null or not is_instance_valid(glue_first) or glue_first == obj:
		glue_first = obj
		Audio.play("glue_pick")
		return false
	var ok := Effects.glue(glue_first, obj) != null
	glue_first = null
	Audio.play("glue" if ok else "nope")
	return ok


func _unhandled_input(event: InputEvent) -> void:
	var step := 0
	if event is InputEventJoypadButton and event.pressed:
		step = -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else (1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else 0)
	elif event is InputEventKey and event.pressed and not event.echo:
		step = -1 if event.physical_keycode == KEY_Q else (1 if event.physical_keycode == KEY_E else 0)
	if step != 0:
		gun_index = posmod(gun_index + step, Effects.GUNS.size())
		glue_first = null
		Audio.play("gun_cycle")


## A flat wedge on the play plane showing the aim cone.
func _cone_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	for i in n:
		var a0 := -Aim.HALF_ANGLE + 2.0 * Aim.HALF_ANGLE * i / n
		var a1 := -Aim.HALF_ANGLE + 2.0 * Aim.HALF_ANGLE * (i + 1) / n
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a0), sin(a0), 0) * Aim.RANGE)
		st.add_vertex(Vector3(cos(a1), sin(a1), 0) * Aim.RANGE)
	return st.commit()
