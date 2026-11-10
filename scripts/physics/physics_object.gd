## A yard object: RigidBody3D + EffectStack, configured by ObjectData.
## Jolt doesn't support scaling a RigidBody3D node, so the body itself is never scaled: grow/shrink
## re-creates the collision shape at the new size and scales only the Visual node.
## Gravity comes from Yard.gravity_at() (the engine's own gravity is off via gravity_scale = 0), and a
## soft spring holds the body on the Z = 0 play plane. Water (Yard.water_level_at) floats anything
## lighter than Yard.WATER_DENSITY. The face (ObjectFace) and effect attachments (EffectLook) are
## children of Visual, so they grow and shrink with it.
class_name PhysicsObject
extends RigidBody3D

const GROUP := &"yard_objects"
const SCALE_TIME := 0.25         # seconds per size step (the tween the sim follows)
const CLAMP_GRACE := 0.15        # keep the low speed cap a moment after a size change ends
const BLOCK_INSET := 0.06        # growth only counts as blocked past this much overlap
const BLOCKED_GIVE_UP := 0.4     # seconds a blocked grow waits before the step is refused

signal recalled(obj: PhysicsObject)
signal scale_refused(obj: PhysicsObject)
## GAME.md contract: an object hit something hard. impulse = logical mass x speed change (kg m/s).
signal object_landed(target: Node3D, impulse: float)
signal splashed(obj: PhysicsObject)

const LAND_DV := 3.5             # m/s of sudden velocity change that counts as a landing
const LAND_COOLDOWN := 0.25

@export var data: ObjectData
## Layout key ("cow", "chicken_2"): what saves and goal cards call this object. Defaults to data.id.
@export var key: StringName = &""

var stack: EffectStack
var props: BodyProps
var current_scale := 1.0
var target_scale := 1.0
var effective_gravity_scale := 1.0
var squash := Vector3.ONE
var nan_events := 0

var face: ObjectFace
var look: EffectLook
var in_water := false
## Last thing that moved it on purpose ("gun", "throw", ...) for cards and juice.
var last_touch: StringName = &""

var _shapes: Array[CollisionShape3D] = []
var _visual: Node3D
var _mats: Array[StandardMaterial3D] = []
var _last_v := Vector3.ZERO
var _land_cool := 0.0
var _pending_land := 0.0
var _pending_splash := false
var _clamp_left := 0.0
var _blocked_time := 0.0
var _squash_tween: Tween


func _init(p_data: ObjectData = null) -> void:
	if p_data:
		data = p_data


func _ready() -> void:
	if data == null:
		data = ObjectData.new()
	if key == &"":
		key = data.id
	add_to_group(GROUP)
	gravity_scale = 0.0
	can_sleep = true
	continuous_cd = true
	# No contact_monitor: turning on contact reporting changes how Godot-Jolt solves contacts (the
	# Phase 1 stress numbers drift). Landings are read from sudden velocity changes instead.
	collision_layer = 1
	collision_mask = 1
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	physics_material_override = PhysicsMaterial.new()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	if data.mesh:
		_visual.add_child(data.mesh.instantiate())
	else:
		_build_greybox()
	if data.has_face:
		face = ObjectFace.new()
		face.name = "Face"
		face.setup(data.face_size)
		var front := data.size.x * 0.5 if data.shape == ObjectData.Shape.SPHERE else data.size.z * 0.5
		face.position = Vector3(data.face_at.x * data.size.x, data.face_at.y * data.size.y, front + 0.01)
		if data.shape == ObjectData.Shape.SPHERE:
			face.position.z = sqrt(maxf(0.01, front * front - face.position.x * face.position.x - face.position.y * face.position.y)) + 0.01
		_visual.add_child(face)
	look = EffectLook.new()
	look.name = "Look"
	look.size = data.size if data.shape != ObjectData.Shape.SPHERE else Vector3.ONE * data.size.x
	_visual.add_child(look)
	stack = EffectStack.new()
	stack.name = "EffectStack"
	add_child(stack)
	stack.effect_changed.connect(_on_effect_changed)
	_rebuild_shape()
	stack.recompute()


func _build_greybox() -> void:
	var d := data
	match d.shape:
		ObjectData.Shape.SPHERE:
			var sm := SphereMesh.new()
			sm.radius = d.size.x * 0.5
			sm.height = d.size.x
			_add_mesh(sm, Transform3D.IDENTITY, d.color)
		ObjectData.Shape.CYLINDER:
			var cm := CylinderMesh.new()
			cm.top_radius = d.size.x * 0.5
			cm.bottom_radius = d.size.x * 0.5
			cm.height = d.size.z
			_add_mesh(cm, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), d.color)
		ObjectData.Shape.TUB:
			for part in _tub_parts(1.0, 0.0):
				var bm := BoxMesh.new()
				bm.size = (part[0] as BoxShape3D).size
				var xf: Transform3D = part[1]
				if xf.origin.z > 0.01:   # the front wall: low, so you can see what's in the tub
					bm.size.y *= 0.45
					xf.origin.y -= (part[0] as BoxShape3D).size.y * 0.275
				_add_mesh(bm, xf, d.color)
		_:
			var bm := BoxMesh.new()
			bm.size = d.size
			_add_mesh(bm, Transform3D.IDENTITY, d.color)
	for part in d.parts:
		var sz: Vector3 = part.get("size", Vector3.ONE * 0.3)
		var mesh: Mesh
		var xf := Transform3D(Basis.IDENTITY, part.get("at", Vector3.ZERO))
		match String(part.get("shape", "box")):
			"sphere":
				var sm := SphereMesh.new()
				sm.radius = sz.x * 0.5
				sm.height = sz.x
				mesh = sm
			"cylinder":
				var cm := CylinderMesh.new()
				cm.top_radius = sz.x * 0.5
				cm.bottom_radius = sz.x * 0.5
				cm.height = sz.z
				mesh = cm
				xf.basis = Basis(Vector3.RIGHT, PI * 0.5)
			_:
				var bm := BoxMesh.new()
				bm.size = sz
				mesh = bm
		_add_mesh(mesh, xf, part.get("color", d.color))


func _add_mesh(m: Mesh, xf: Transform3D, c: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.transform = xf
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.set_meta(&"base", c)
	mi.material_override = mat
	_mats.append(mat)
	_visual.add_child(mi)


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
			_last_v = Vector3.ZERO
	for o in stack.glued_group():
		o.refresh_mass()
	_update_look()
	wake_neighbours()


## Loading a save: jump straight to a size step with no tween and no room check.
func restore_size(steps: int) -> void:
	if steps == 0:
		return
	Effects.Size.new(steps).apply(self)
	current_scale = target_scale
	squash = Vector3.ONE
	_rebuild_shape()


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
	_land_cool -= delta
	if _pending_land > 0.0:
		var imp := _pending_land
		_pending_land = 0.0
		_on_landed(imp)
	if _pending_splash:
		_pending_splash = false
		Audio.play("splash", global_position)
		Fx.burst(get_tree(), global_position, Color(0.5, 0.75, 1.0, 0.8), 18, 1.2, 0.7)
		splashed.emit(self)
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
	for part in _shape_parts(s, BLOCK_INSET):
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = part[0]
		q.transform = Transform3D(global_basis, global_position + offset) * (part[1] as Transform3D)
		q.exclude = _island_rids()
		q.collision_mask = 1
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
	# A landing: the solver took a big bite out of the speed, or turned it round (bouncy), since the
	# velocity we handed it last step. Skipped while we steer the body ourselves (grab, size clamp).
	if _land_cool <= 0.0 and _clamp_left <= 0.0 and not stack.has(&"grab"):
		var dv := (v - _last_v).length()
		if dv > LAND_DV and (_last_v.length() - v.length() > LAND_DV * 0.5 or v.dot(_last_v) < 0.0):
			_pending_land = volume_mass() * dv
			_land_cool = LAND_COOLDOWN
	var up := Yard.up_at(pos)
	v += Yard.gravity_at(pos) * effective_gravity_scale * dt
	var surface := Yard.water_level_at(pos)
	var was_in := in_water
	in_water = false
	if surface > -INF:
		var h := _half_along(up, current_scale)
		var under := clampf((surface - (pos.dot(up) - h)) / maxf(2.0 * h, 0.01), 0.0, 1.0)
		if under > 0.0:
			in_water = true
			v += up * Yard.G * (Yard.WATER_DENSITY / maxf(data.density(), 0.01)) * under * dt
			v *= 1.0 - minf(1.0, Yard.WATER_DRAG * under * dt)
			if not was_in and v.length() > 1.5:
				_pending_splash = true
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
	_last_v = v


## Out of bounds: send the whole glued island back to the gate, keeping its shape.
func recall() -> void:
	var group := stack.glued_group()
	var offset := Yard.GATE - global_position
	for o in group:
		o.global_position += offset
		o.linear_velocity = Vector3.ZERO
		o.angular_velocity = Vector3.ZERO
		o._last_v = Vector3.ZERO
		o.recalled.emit(o)
	Yard.recalls += 1
	Audio.play("recall", Yard.GATE)
	Fx.sparkle(get_tree(), Yard.GATE)


func _rebuild_shape() -> void:
	var parts := _shape_parts(current_scale, 0.0)
	while _shapes.size() < parts.size():
		var cs := CollisionShape3D.new()
		cs.name = "Shape" if _shapes.is_empty() else "Shape%d" % _shapes.size()
		add_child(cs)
		_shapes.append(cs)
	for i in _shapes.size():
		# Only touch what changed: re-setting transform or disabled makes Jolt rebuild the body.
		var off := i >= parts.size()
		if _shapes[i].disabled != off:
			_shapes[i].disabled = off
		if not off:
			_shapes[i].shape = parts[i][0]
			if not _shapes[i].transform.is_equal_approx(parts[i][1]):
				_shapes[i].transform = parts[i][1]
	sleeping = false
	for o in stack.glued_group() if stack else [self]:
		o.refresh_mass()


## [Shape3D, local Transform3D] pairs for the body at scale s, shrunk by inset.
func _shape_parts(s: float, inset: float) -> Array:
	match data.shape:
		ObjectData.Shape.SPHERE:
			var sph := SphereShape3D.new()
			sph.radius = maxf(0.01, data.size.x * 0.5 * s - inset)
			return [[sph, Transform3D.IDENTITY]]
		ObjectData.Shape.CYLINDER:
			var cyl := CylinderShape3D.new()
			cyl.radius = maxf(0.01, data.size.x * 0.5 * s - inset)
			cyl.height = maxf(0.02, data.size.z * s - inset * 2.0)
			return [[cyl, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)]]
		ObjectData.Shape.TUB:
			return _tub_parts(s, inset)
	var box := BoxShape3D.new()
	box.size = (data.size * s - Vector3.ONE * inset * 2.0).max(Vector3.ONE * 0.02)
	return [[box, Transform3D.IDENTITY]]


## A box open on top: a floor and four walls, WALL thick at scale 1.
func _tub_parts(s: float, inset: float) -> Array:
	const WALL := 0.12
	var sz := data.size * s
	var t := WALL * s
	var out := []
	var specs := [
		[Vector3(sz.x, t, sz.z), Vector3(0, -sz.y * 0.5 + t * 0.5, 0)],
		[Vector3(t, sz.y, sz.z), Vector3(-sz.x * 0.5 + t * 0.5, 0, 0)],
		[Vector3(t, sz.y, sz.z), Vector3(sz.x * 0.5 - t * 0.5, 0, 0)],
		[Vector3(sz.x, sz.y, t), Vector3(0, 0, -sz.z * 0.5 + t * 0.5)],
		[Vector3(sz.x, sz.y, t), Vector3(0, 0, sz.z * 0.5 - t * 0.5)],
	]
	for sp in specs:
		var b := BoxShape3D.new()
		b.size = ((sp[0] as Vector3) - Vector3.ONE * inset * 2.0).max(Vector3.ONE * 0.02)
		out.append([b, Transform3D(Basis.IDENTITY, sp[1])])
	return out


## Inside a tub (or on top of anything else): the point is within the object's footprint, above its
## floor and below its rim plus a little. Goal cards use this for "duck in the bathtub".
func contains_point(p: Vector3) -> bool:
	var local := global_transform.affine_inverse() * p
	var h := size_now() * 0.5
	return absf(local.x) < h.x and local.y > -h.y and local.y < h.y + 0.3 and absf(local.z) < h.z + 0.5


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
	var tint := Color(0, 0, 0, 0)
	var glow := Color.BLACK
	for e in stack.effects:
		tint = tint.lerp(e.color, 0.5) if tint.a > 0.0 else Color(e.color, 1.0)
		glow += e.color * 0.25
	for m in _mats:
		var base: Color = m.get_meta(&"base")
		m.albedo_color = base.lerp(tint, 0.3) if tint.a > 0.0 else base
		m.emission_enabled = not stack.effects.is_empty()
		m.emission = glow
	look.sync(stack.effects)
	if face:
		face.set_base(_mood_for_stack())


func _mood_for_stack() -> ObjectFace.Mood:
	if stack.has(&"grab"):
		return ObjectFace.Mood.WIDE
	if stack.has(&"freeze"):
		return ObjectFace.Mood.SHUT
	if stack.has(&"balloon"):
		return ObjectFace.Mood.PANIC
	if stack.has(&"bouncy"):
		return ObjectFace.Mood.SMUG
	var sz: Effect = stack.get_effect(&"size")
	if sz and sz.steps > 0:
		return ObjectFace.Mood.HAPPY
	return ObjectFace.Mood.NEUTRAL


func _on_effect_changed(_t: Node3D, _effect: StringName, on: bool) -> void:
	if face:
		face.react(ObjectFace.Mood.WIDE if on else ObjectFace.Mood.HAPPY, 0.6)


## The object's voice, pitched by size: a giant cow moos low, a tiny car beeps high.
func speak() -> void:
	Audio.play(data.voice_cue(), global_position, 1.0 / sqrt(current_scale))


## Thrown or launched: dizzy for a moment.
func dizzy(seconds := 1.5) -> void:
	if face:
		face.react(ObjectFace.Mood.DIZZY, seconds)


func _on_landed(impulse: float) -> void:
	var m := volume_mass()
	var band := "light" if m < 1.0 else ("medium" if m < 8.0 else ("heavy" if m < 60.0 else "huge"))
	Audio.play("impact_%s" % band, global_position, 1.0 / sqrt(current_scale))
	Fx.impact(get_tree(), global_position - Yard.up_at(global_position) * _half_along(Yard.up_at(global_position), current_scale), m, impulse / maxf(m, 0.01))
	object_landed.emit(self, impulse)
