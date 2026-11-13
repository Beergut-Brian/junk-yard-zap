## Every effect a gun can put on an object, plus zap(): the one entry point guns use.
## Rule from GAME.md: every effect composes with every other without special cases. Nothing in this
## file checks which other effects are on the stack.
class_name Effects
extends RefCounted

const GUNS: Array[StringName] = [&"grow", &"shrink", &"bouncy", &"balloon", &"freeze", &"glue", &"magnet"]
## The fixed gun hues (D44 palette; never P1 green or P2 red). Mirrors ArtKit.GUN.
const COLORS := {
	&"size": Color("#ff9a14"), &"bouncy": Color("#ffd21a"), &"balloon": Color("#ec3cf0"),
	&"freeze": Color("#4fd8ff"), &"glue": Color("#ff9fdf"), &"magnet": Color("#2f68ff"),
}


## Fire a single-target gun at target. Toggles undo; grow and shrink undo each other.
## Returns true if something changed (false: at a size limit, or glue, which needs two targets).
static func zap(gun: StringName, target: PhysicsObject) -> bool:
	match gun:
		&"grow":
			return Size.new(1).apply(target)
		&"shrink":
			return Size.new(-1).apply(target)
		&"glue":
			return false
	var on := target.stack.get_effect(gun)
	if on:
		on.undo(target)
		return true
	return make(gun).apply(target)


static func make(kind: StringName) -> Effect:
	match kind:
		&"bouncy": return Bouncy.new()
		&"balloon": return Balloon.new()
		&"freeze": return Freeze.new()
		&"magnet": return Magnet.new()
	push_error("Effects.make: unknown effect %s" % kind)
	return null


static func glue(a: PhysicsObject, b: PhysicsObject) -> Glue:
	if a == b or a == null or b == null or Glue.between(a, b):
		return null
	var g := Glue.new(a, b)
	return g if g.apply(a) else null


## Gravity grab: holder is any Node3D with hold_point() -> Vector3 (a player's hand at arm's length).
## Returns null if the object is already held by someone else.
static func grab(target: PhysicsObject, holder: Node3D, color: Color) -> Grab:
	var on: Grab = target.stack.get_effect(&"grab")
	if on:
		return on if on.holder == holder else null
	var g := Grab.new(holder, color)
	return g if g.apply(target) else null


## Let go. throw_velocity adds a flick (kept under the speed cap by the body).
static func release(target: PhysicsObject, throw_velocity := Vector3.ZERO) -> void:
	var on: Grab = target.stack.get_effect(&"grab")
	if on == null:
		return
	on.undo(target)
	if throw_velocity != Vector3.ZERO and not target.freeze:
		target.linear_velocity += throw_velocity
		target.angular_velocity += Vector3(0, 0, -signf(throw_velocity.x) * 6.0)
		target.last_touch = &"throw"
		target.dizzy()


## Grow/shrink. A stack holds at most one Size; new steps merge into it and it leaves at step 0.
class Size extends Effect:
	var steps := 0

	func _init(p_steps: int = 1) -> void:
		id = &"size"
		steps = p_steps
		color = COLORS[&"size"]

	func apply(target: PhysicsObject) -> bool:
		var cur: Size = target.stack.get_effect(&"size")
		var now := cur.steps if cur else 0
		var want := clampi(now + steps, target.data.min_step, target.data.max_step)
		if want == now:
			return false
		if cur == null:
			var s := Size.new(want)
			return target.stack.push(s)
		cur.steps = want
		if want == 0:
			target.stack.remove(cur)
		else:
			target.stack.recompute()
		return true

	func undo(target: PhysicsObject) -> void:
		Size.new(-steps).apply(target)

	func modify(p: BodyProps) -> void:
		p.scale_step += steps

	func label() -> String:
		return "%+d" % steps


class Bouncy extends Effect:
	func _init() -> void:
		id = &"bouncy"
		color = COLORS[id]

	func modify(p: BodyProps) -> void:
		p.bounce = maxf(p.bounce, 0.95)
		p.friction *= 0.5


## Gravity flips (gently) until the object stops rising, then it parks where it is.
class Balloon extends Effect:
	const LIFT := -0.5
	const PARK_AFTER := 0.3   # metres risen before a stall counts as hitting something
	const MAX_RISE := 6.0     # metres: parks here if nothing stops it first
	var start_h := 0.0
	var stall := 0.0
	var parked := false

	func _init() -> void:
		id = &"balloon"
		color = COLORS[id]

	func added(t: PhysicsObject) -> void:
		start_h = t.global_position.dot(Yard.up_at(t.global_position))

	func modify(p: BodyProps) -> void:
		if parked:
			p.gravity_scale *= 0.0
			p.linear_damp += 4.0
			p.angular_damp += 2.0
		else:
			p.gravity_scale *= LIFT
			p.linear_damp += 0.6

	func tick(t: PhysicsObject, delta: float) -> void:
		if parked:
			return
		var up := Yard.up_at(t.global_position)
		var risen := t.global_position.dot(up) - start_h
		stall = stall + delta if risen > PARK_AFTER and t.linear_velocity.dot(up) < 0.05 else 0.0
		# Open sky: park MAX_RISE up, so a ballooned cow stays in view and in reach of a zap instead
		# of floating off to the lid (playtest #1).
		if stall > 0.25 or risen > MAX_RISE:
			parked = true
			t.stack.recompute()


class Freeze extends Effect:
	func _init() -> void:
		id = &"freeze"
		color = COLORS[id]

	func modify(p: BodyProps) -> void:
		p.freeze = true


## Pulls every other dynamic object in range for DURATION seconds, then switches itself off.
## The pull on an object is capped at MASS_LEVERAGE times the magnet's own mass, so a tiny magnet
## can't slam a giant car onto itself and crush itself through the floor.
class Magnet extends Effect:
	const DURATION := 5.0
	const RADIUS := 7.0
	const ACCEL := 25.0        # m/s^2 at the centre, falling off to 0 at RADIUS
	const MASS_LEVERAGE := 3.0
	var time_left := DURATION

	func _init() -> void:
		id = &"magnet"
		color = COLORS[id]

	func tick(t: PhysicsObject, delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			undo(t)
			return
		var c := t.global_position
		var reach := RADIUS * maxf(1.0, t.current_scale)
		for o in t.get_tree().get_nodes_in_group(PhysicsObject.GROUP):
			var other := o as PhysicsObject
			if other == t:
				continue
			var d := c - other.global_position
			var dist := d.length()
			if dist < 0.05 or dist > reach:
				continue
			var acc := ACCEL * (1.0 - dist / reach)
			other.apply_central_force(d / dist * acc * minf(other.mass, t.mass * MASS_LEVERAGE))

	func label() -> String:
		return "MG%d" % ceili(time_left)


## A locked Generic6DOFJoint3D between two objects. The same Glue sits on both stacks; undoing it from
## either side frees the joint and leaves both. Objects that aren't touching are pulled together first
## (a glue string) and lock on contact; if they can't meet within PULL_TIME the glue lets go.
class Glue extends Effect:
	const JOIN_GAP := 0.25         # metres between surfaces that counts as touching
	const PULL_ACCEL := 20.0       # m/s^2 on each half while pulling together
	const PULL_TIME := 3.0
	var a: PhysicsObject
	var b: PhysicsObject
	var joint: Generic6DOFJoint3D
	var blob: MeshInstance3D
	## Y-22: while the pair pulls together, a stretchy pink string between them shows the glue is
	## working; it thins as it stretches, shivers near the end, and snaps when they never meet.
	var string_mesh: MeshInstance3D
	var pull_left := PULL_TIME
	const STRING_R := 0.09
	const SHIVER := 0.8   # s before the snap the string starts to shiver

	func _init(p_a: PhysicsObject = null, p_b: PhysicsObject = null) -> void:
		id = &"glue"
		color = COLORS[id]
		a = p_a
		b = p_b

	static func between(p: PhysicsObject, q: PhysicsObject) -> Glue:
		for e in p.stack.effects:
			if e is Glue and (e.a == q or e.b == q):
				return e
		return null

	func other(t: PhysicsObject) -> PhysicsObject:
		return b if t == a else a

	func joined() -> bool:
		return is_instance_valid(joint)

	func apply(_target: PhysicsObject) -> bool:
		if not a.stack.push(self):
			return false
		b.stack.push(self)
		if gap() <= JOIN_GAP:
			_make_joint()
		else:
			_make_string()
		return true

	func undo(_target: PhysicsObject) -> void:
		_drop_string()
		if is_instance_valid(joint):
			joint.queue_free()
		joint = null
		if is_instance_valid(a):
			a.stack.remove(self)
		if is_instance_valid(b):
			b.stack.remove(self)

	func _dir() -> Vector3:
		var d := b.global_position - a.global_position
		return d.normalized() if d.length_squared() > 0.0001 else Vector3.UP

	## Distance between the two surfaces along the line between centres (0 when overlapping).
	func gap() -> float:
		var dir := _dir()
		return maxf(0.0, a.global_position.distance_to(b.global_position) - a.half_extent_along(dir) - b.half_extent_along(-dir))

	## Where the blob sits: between the surfaces, on the line between centres.
	func anchor() -> Vector3:
		var dir := _dir()
		return a.global_position + dir * (a.half_extent_along(dir) + gap() * 0.5)

	func _make_string() -> void:
		if not a.is_inside_tree():
			return
		string_mesh = MeshInstance3D.new()
		string_mesh.name = "GlueString"
		var m := CylinderMesh.new()
		m.top_radius = STRING_R
		m.bottom_radius = STRING_R
		m.height = 1.0
		m.radial_segments = 8
		m.rings = 1
		string_mesh.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color * 0.6
		mat.no_depth_test = true   # visible even where it runs behind a thing
		string_mesh.material_override = mat
		string_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		string_mesh.top_level = true
		a.add_child(string_mesh)
		_pose_string()

	func _drop_string() -> void:
		if is_instance_valid(string_mesh):
			string_mesh.queue_free()
		string_mesh = null

	## End points on the two surfaces, along the line between centres.
	func string_ends() -> Array[Vector3]:
		var dir := _dir()
		return [a.global_position + dir * a.half_extent_along(dir), b.global_position - dir * b.half_extent_along(-dir)]

	func _pose_string() -> void:
		if not is_instance_valid(string_mesh):
			return
		var ends := string_ends()
		var d: Vector3 = ends[1] - ends[0]
		var length := maxf(d.length(), 0.05)
		var y := d / length if d.length() > 0.001 else Vector3.UP
		var x := y.cross(Vector3.BACK)
		if x.length() < 0.01:
			x = Vector3.RIGHT
		x = x.normalized()
		var z := x.cross(y)
		var thin := clampf(1.4 / sqrt(length + 1.0), 0.45, 1.2)   # stretched glue gets thinner
		var shiver := Vector3.ZERO
		if pull_left < SHIVER:
			shiver = x * sin(pull_left * 70.0) * 0.06 * (1.0 - pull_left / SHIVER)
		string_mesh.global_transform = Transform3D(Basis(x * thin, y * length, z * thin), (ends[0] + ends[1]) * 0.5 + shiver + Vector3(0, 0, 0.3))

	func _make_joint() -> void:
		_drop_string()
		joint = Generic6DOFJoint3D.new()
		joint.name = "Glue_%s_%s" % [a.name, b.name]
		# All six axes default to locked limits of 0, which is exactly "glued".
		a.get_parent().add_child(joint)
		joint.global_position = anchor()
		joint.node_a = joint.get_path_to(a)
		joint.node_b = joint.get_path_to(b)
		joint.set_meta(&"glue", self)
		joint.add_to_group(&"glue_joints")
		blob = MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = 0.3
		m.height = 0.6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color * 0.8
		mat.no_depth_test = true   # always visible, even inside the pair
		m.material = mat
		blob.mesh = m
		joint.add_child(blob)
		a.stack.recompute()   # label, look and the island's mass floor
		b.stack.recompute()

	## Pull together until touching, then lock. The blob follows A (the joint node doesn't move).
	func tick(t: PhysicsObject, delta: float) -> void:
		if t != a:
			return
		if joined():
			if is_instance_valid(blob):
				blob.global_position = anchor()
			return
		var g := gap()
		if g <= JOIN_GAP:
			_make_joint()
			return
		pull_left -= delta
		if pull_left <= 0.0:
			var ends := string_ends()
			undo(a)
			Refusal.snapped(self, (ends[0] + ends[1]) * 0.5, ends)   # every curse shows its cause (Y-22)
			return
		if string_mesh == null:
			_make_string()
		_pose_string()
		var acc := _dir() * PULL_ACCEL * clampf(g, 0.3, 1.0)
		a.apply_central_force(acc * a.mass)
		b.apply_central_force(-acc * b.mass)

	func label() -> String:
		return "GL" if joined() else "gl~"


## Carried at arm's length: no gravity, heavy damping, steered toward the holder's hand every frame.
## A frozen object stays put (freeze wins by being static, not by a special case).
class Grab extends Effect:
	const FOLLOW := 12.0        # 1/s: how hard it chases the hand
	const MAX_CHASE := 18.0     # m/s
	var holder: Node3D

	func _init(p_holder: Node3D = null, p_color := Color.WHITE) -> void:
		id = &"grab"
		color = p_color
		holder = p_holder

	func modify(p: BodyProps) -> void:
		p.gravity_scale *= 0.0
		p.angular_damp += 4.0

	func tick(t: PhysicsObject, _delta: float) -> void:
		if not is_instance_valid(holder):
			undo(t)
			return
		var to: Vector3 = holder.hold_point(t) - t.global_position
		var want := to * FOLLOW
		if want.length() > MAX_CHASE:
			want = want.normalized() * MAX_CHASE
		t.apply_central_force((want - t.linear_velocity) * t.mass * 10.0)
