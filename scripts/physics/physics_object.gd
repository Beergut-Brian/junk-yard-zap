## A yard object: RigidBody3D + EffectStack, configured by ObjectData.
## Jolt doesn't support scaling a RigidBody3D node, so the body itself is never scaled: grow/shrink
## re-creates the collision shape at the new size and scales only the Visual node.
## Gravity comes from Yard.gravity_at() (the engine's own gravity is off via gravity_scale = 0), and a
## soft spring holds the body on the Z = 0 play plane.
class_name PhysicsObject
extends RigidBody3D

const GROUP := &"yard_objects"
const SCALE_TIME := 0.25         # seconds per size step (the tween the sim follows)
const CLAMP_GRACE := 0.15        # keep the low speed cap a moment after a size change ends
const BLOCK_INSET := 0.06        # growth only counts as blocked past this much overlap
const BLOCKED_GIVE_UP := 0.4     # seconds a blocked grow waits before the step is refused

signal recalled(obj: PhysicsObject)
signal scale_refused(obj: PhysicsObject)

@export var data: ObjectData

var stack: EffectStack
var props: BodyProps
var current_scale := 1.0
var target_scale := 1.0
var effective_gravity_scale := 1.0
var squash := Vector3.ONE
var nan_events := 0

var _shape_node: CollisionShape3D
var _visual: Node3D
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _label: Label3D
var _clamp_left := 0.0
var _blocked_time := 0.0
var _squash_tween: Tween


func _init(p_data: ObjectData = null) -> void:
	if p_data:
		data = p_data


func _ready() -> void:
	if data == null:
		data = ObjectData.new()
	add_to_group(GROUP)
	gravity_scale = 0.0
	can_sleep = true
	continuous_cd = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	physics_material_override = PhysicsMaterial.new()
	_shape_node = CollisionShape3D.new()
	_shape_node.name = "Shape"
	add_child(_shape_node)
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_mesh = MeshInstance3D.new()
	_mat = StandardMaterial3D.new()
	if data.shape == ObjectData.Shape.SPHERE:
		var sm := SphereMesh.new()
		sm.radius = data.size.x * 0.5
		sm.height = data.size.x
		_mesh.mesh = sm
	else:
		var bm := BoxMesh.new()
		bm.size = data.size
		_mesh.mesh = bm
	_mesh.material_override = _mat
	_visual.add_child(_mesh)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 48
	_label.outline_size = 12
	_label.no_depth_test = true
	add_child(_label)
	stack = EffectStack.new()
	stack.name = "EffectStack"
	add_child(stack)
	_rebuild_shape()
	stack.recompute()


## Called by EffectStack.recompute() with the folded result of every effect.
func apply_props(p: BodyProps) -> void:
	props = p
	var new_target := data.scale_for_step(p.scale_step)
	if not is_equal_approx(new_target, target_scale):
		_start_squash(new_target > target_scale)
		target_scale = new_target
	effective_gravity_scale = p.gravity_scale
	physics_material_override.bounce = p.bounce
	physics_material_override.friction = p.friction
	linear_damp = p.linear_damp
	angular_damp = p.angular_damp
	if freeze != p.freeze:
		freeze = p.freeze
		if not freeze:
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
	for o in stack.glued_group():
		o.refresh_mass()
	_update_look()
	wake_neighbours()


func is_scaling() -> bool:
	return not is_equal_approx(current_scale, target_scale)


func size_now() -> Vector3:
	return data.size * current_scale


## Half the object's thickness along a world direction (for glue anchors and spacing).
func half_extent_along(dir: Vector3) -> float:
	var h := size_now() * 0.5
	if data.shape == ObjectData.Shape.SPHERE:
		return h.x
	var b := global_basis.orthonormalized()
	return absf(dir.dot(b.x)) * h.x + absf(dir.dot(b.y)) * h.y + absf(dir.dot(b.z)) * h.z


func radius() -> float:
	return size_now().length() * 0.5


func wake_neighbours() -> void:
	if not is_inside_tree():
		return
	sleeping = false
	for o in get_tree().get_nodes_in_group(GROUP):
		var other := o as PhysicsObject
		if other != self and other.global_position.distance_to(global_position) < radius() + other.radius() + 0.5:
			other.sleeping = false


func _physics_process(delta: float) -> void:
	if is_scaling():
		_scale_step(delta)
	elif _clamp_left > 0.0:
		_clamp_left -= delta
	_visual.scale = squash * current_scale
	if sleeping and absf(global_position.z) > 0.02:
		sleeping = false   # don't let a body fall asleep off the plane
	stack.tick(delta)
	if not Yard.in_bounds(global_position):
		recall()


## One frame of a size change. Growth is anchored at the bottom when something supports the object
## (so it grows up off the floor instead of into it), and stalls when the bigger shape would overlap
## static geometry or a frozen object; stalled too long, the step is refused and it boings back.
func _scale_step(delta: float) -> void:
	# Move in log space so every step takes SCALE_TIME whatever the size.
	var rate := log(data.step_factor) / SCALE_TIME * delta
	var l := log(current_scale)
	var goal := log(target_scale)
	var next := exp(minf(l + rate, goal) if goal > l else maxf(l - rate, goal))
	if absf(log(next) - goal) < 0.0001:
		next = target_scale
	if next > current_scale:
		var up := Yard.up_at(global_position)
		var lift := up * (_half_along(up, next) - _half_along(up, current_scale))
		if not _supported(up):
			lift = Vector3.ZERO
		if _blocked(next, lift):
			_blocked_time += delta
			if _blocked_time > BLOCKED_GIVE_UP:
				_blocked_time = 0.0
				scale_refused.emit(self)
				Effects.Size.new(-1).apply(self)
			return
		global_position += lift
	_blocked_time = 0.0
	current_scale = next
	_rebuild_shape()
	_clamp_left = CLAMP_GRACE
	_label.position.y = size_now().y * 0.5 + 0.5
	if not is_scaling():
		wake_neighbours()


func _half_along(dir: Vector3, s: float) -> float:
	return half_extent_along(dir) * s / current_scale


## Something (anything but our own glued island) right under us.
func _supported(up: Vector3) -> bool:
	var from := global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - up * (_half_along(up, current_scale) + 0.1))
	q.exclude = _island_rids()
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Would the shape at scale s (moved by offset) overlap something that can't get out of the way?
func _blocked(s: float, offset: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _make_shape(s, BLOCK_INSET)
	q.transform = Transform3D(global_basis, global_position + offset)
	q.exclude = _island_rids()
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var c: Object = hit.collider
		if c is StaticBody3D or (c is RigidBody3D and c.freeze):
			return true
	return false


func _island_rids() -> Array[RID]:
	var out: Array[RID] = []
	for o in stack.glued_group():
		out.append(o.get_rid())
	return out


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dt := state.step
	var pos := state.transform.origin
	var v := state.linear_velocity
	var w := state.angular_velocity
	if not (v.is_finite() and w.is_finite() and pos.is_finite()):
		nan_events += 1
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		return
	v += Yard.gravity_at(pos) * effective_gravity_scale * dt
	v.z += Yard.plane_accel(pos.z, v.z) * dt
	# Friction can hold a resting body off the plane against the spring; creep it back directly.
	if absf(pos.z) > 0.001:
		var xf := state.transform
		xf.origin.z -= pos.z * minf(1.0, Yard.PLANE_CREEP * dt)
		state.transform = xf
	var cap := Yard.SCALE_CHANGE_MAX_SPEED if _clamp_left > 0.0 else Yard.MAX_SPEED
	if v.length() > cap:
		v = v.normalized() * cap
	if w.length() > Yard.MAX_SPIN:
		w = w.normalized() * Yard.MAX_SPIN
	state.linear_velocity = v
	state.angular_velocity = w


## Out of bounds: send the whole glued island back to the gate, keeping its shape.
func recall() -> void:
	var group := stack.glued_group()
	var offset := Yard.GATE - global_position
	for o in group:
		o.global_position += offset
		o.linear_velocity = Vector3.ZERO
		o.angular_velocity = Vector3.ZERO
		o.recalled.emit(o)
	Yard.recalls += 1


func _rebuild_shape() -> void:
	_shape_node.shape = _make_shape(current_scale, 0.0)
	sleeping = false
	for o in stack.glued_group() if stack else [self]:
		o.refresh_mass()


func _make_shape(s: float, inset: float) -> Shape3D:
	if data.shape == ObjectData.Shape.SPHERE:
		var sph := SphereShape3D.new()
		sph.radius = maxf(0.01, data.size.x * 0.5 * s - inset)
		return sph
	var box := BoxShape3D.new()
	box.size = (data.size * s - Vector3.ONE * inset * 2.0).max(Vector3.ONE * 0.02)
	return box


## Mass follows volume: volume_mass() is the object's logical mass (goal cards, impact sounds, Fx).
## Jolt gets a compressed body mass (Yard.body_mass) because it sinks light bodies under heavy ones
## past ~25:1, and grow/shrink alone spans 500:1. Glued islands also keep every member within
## GLUE_MASS_RATIO of the heaviest: joints go soft when a heavy half hangs off a light one.
func volume_mass() -> float:
	return clampf(data.mass * pow(current_scale, 3), Yard.MASS_MIN, Yard.MASS_MAX)


func refresh_mass() -> void:
	var m := Yard.body_mass(volume_mass())
	if stack:
		for o in stack.glued_group():
			m = maxf(m, Yard.body_mass(o.volume_mass()) / Yard.GLUE_MASS_RATIO)
	mass = m


func _start_squash(growing: bool) -> void:
	if _squash_tween:
		_squash_tween.kill()
	squash = Vector3(1.25, 0.75, 1.25) if growing else Vector3(0.8, 1.25, 0.8)
	_squash_tween = create_tween()
	_squash_tween.tween_property(self, "squash", Vector3.ONE, 0.45) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _update_look() -> void:
	var c := data.color
	var glow := Color.BLACK
	var words := PackedStringArray()
	for e in stack.effects:
		c = c.lerp(e.color, 0.45)
		glow += e.color * 0.35
		words.append(e.label())
	_mat.albedo_color = c
	_mat.emission_enabled = not stack.effects.is_empty()
	_mat.emission = glow
	_label.text = " ".join(words)
	_label.position = Vector3(0, size_now().y * 0.5 + 0.5, 0)
	_label.modulate = Color.WHITE
