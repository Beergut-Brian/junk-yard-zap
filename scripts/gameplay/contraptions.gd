## The yard's working contraptions (GAME.md "The yard"): the tower fan you zap on (Y-10), the scrap
## heap conveyor and its button (Y-05), the crane hook you can grab that carries what it catches
## (Y-04), and the barn trampoline that bounces (Y-08). Each one does something you can see.
## Built in code by YardLevel next to the dressing, so tests can drop a yard into any tree.
## Fan and button are zap targets: any gun switches them, with the gun's own zap sound (Zapper._press).
class_name Contraptions
extends Node3D

const METAL := Color("#9aa3a8")
const MUSTARD := Color("#e0a526")
const RUBBER := Color("#2c2a2e")
const TEAL := Color("#3e9c9a")
const LAMP_ON := Color("#ffd23a")
const LAMP_OFF := Color("#6b6152")

var fan: YardFan
var belt: Conveyor
var button: BeltButton
var hook: CraneHook
var trampoline: Trampoline


static func build(level: Node3D) -> Contraptions:
	var c := Contraptions.new()
	c.name = "Contraptions"
	level.add_child(c)
	c.fan = YardFan.new()
	c.fan.name = "Fan"
	c.fan.position = YardFan.AT
	c.add_child(c.fan)
	c.belt = Conveyor.new()
	c.belt.name = "Conveyor"
	c.belt.position = Conveyor.AT
	c.add_child(c.belt)
	c.button = BeltButton.new()
	c.button.name = "BeltButton"
	c.button.belt = c.belt
	c.button.position = BeltButton.AT
	c.add_child(c.button)
	c.hook = CraneHook.new()
	c.hook.name = "CraneHook"
	c.hook.position = CraneHook.ANCHOR + Vector3.DOWN * CraneHook.ROPE
	c.add_child(c.hook)
	c.trampoline = Trampoline.new()
	c.trampoline.name = "Trampoline"
	c.trampoline.position = Trampoline.AT
	c.add_child(c.trampoline)
	if level.has_signal(&"yard_reset"):
		level.connect(&"yard_reset", c.reset)
	return c


## Reset Yard: fan and belt off, the hook back on its rope with nothing on it.
func reset() -> void:
	fan.set_on(false, false)
	belt.set_on(false)
	button.sync()
	hook.reset()


static func mat(col: Color, emit := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.7
	if emit:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 0.6
	return m


static func mesh(parent: Node3D, m: Mesh, col: Color, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(col)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func cyl_mesh(r: float, h: float, segs := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = segs
	return c


static func torus_mesh(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 32
	t.ring_segments = 12
	return t


# ------------------------------------------------------------------------------------------- fan

## Y-10: the big fan on top of the tower. Zap it on and it blows light things off the tower to the
## left (a kite, a chicken, a bucket); zap it again and it winds down.
class YardFan extends Node3D:
	const AT := Vector3(42.4, 11.9, -1.0)
	const REACH := 15.0          # metres of wind to the left of the fan
	const HALF_HEIGHT := 3.4     # the wind is this tall above and below the fan
	const PUSH := 26.0           # m/s^2 on a light thing right in front of the fan
	const LIGHT := 4.0           # volume_mass under this gets blown
	var on := false
	var spin := 0.0
	var _blades: Node3D
	var _lamp: MeshInstance3D
	var _wind: CPUParticles3D

	func _ready() -> void:
		add_to_group(&"zap_targets")
		# A pole down to the top deck, the cage turned to face left (three-quarters to the sofa).
		Contraptions.mesh(self, Contraptions.cyl_mesh(0.12, 2.6), METAL.darkened(0.3), Vector3(0, -1.6, 0))
		var head := Node3D.new()
		head.rotation_degrees.y = -58.0   # local +z (the blow side) points left and a bit toward us
		add_child(head)
		Contraptions.mesh(head, Contraptions.torus_mesh(0.95, 1.12), METAL, Vector3.ZERO, Vector3(90, 0, 0))
		Contraptions.mesh(head, Contraptions.cyl_mesh(0.3, 0.5), METAL.darkened(0.25), Vector3(0, 0, -0.15), Vector3(90, 0, 0))
		for k in 3:   # the guard wires
			Contraptions.mesh(head, Contraptions.box_mesh(Vector3(2.0, 0.04, 0.04)), METAL, Vector3(0, 0, 0.28), Vector3(0, 0, k * 60.0))
		_blades = Node3D.new()
		_blades.position.z = 0.1
		head.add_child(_blades)
		for a in 4:
			Contraptions.mesh(_blades, Contraptions.box_mesh(Vector3(0.36, 0.95, 0.05)), TEAL,
					Vector3(0, 0.5, 0).rotated(Vector3.BACK, a * PI * 0.5), Vector3(8, 0, a * 90.0))
		_lamp = Contraptions.mesh(self, SphereMesh.new(), LAMP_OFF, Vector3(0, -0.75, 0.3))
		_lamp.scale = Vector3.ONE * 0.32
		_wind = CPUParticles3D.new()
		_wind.amount = 40
		_wind.lifetime = 1.3
		_wind.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_wind.emission_box_extents = Vector3(0.3, 1.3, 0.3)
		_wind.direction = Vector3(-1, 0.06, 0)
		_wind.spread = 6.0
		_wind.gravity = Vector3.ZERO
		_wind.initial_velocity_min = 9.0
		_wind.initial_velocity_max = 13.0
		var streak := BoxMesh.new()
		streak.size = Vector3(0.9, 0.05, 0.05)
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(1, 1, 1, 0.55)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		streak.material = sm
		_wind.mesh = streak
		_wind.position = Vector3(-0.8, 0, 1.0)
		_wind.emitting = false
		add_child(_wind)

	func radius() -> float:
		return 1.1

	func zapped_by(_z: Node, _gun: GunData) -> void:
		set_on(not on)

	func set_on(v: bool, loud := true) -> void:
		on = v
		_wind.emitting = on
		(_lamp.material_override as StandardMaterial3D).albedo_color = LAMP_ON if on else LAMP_OFF
		(_lamp.material_override as StandardMaterial3D).emission_enabled = on
		(_lamp.material_override as StandardMaterial3D).emission = LAMP_ON
		if loud and is_inside_tree():
			Audio.play("throw" if on else "drop", global_position)
			Fx.burst(get_tree(), global_position, Color(1, 1, 1, 0.8), 14, 0.9, 0.5)

	## 0..1: how hard the wind pushes at p (0 outside the wind).
	func wind_at(p: Vector3) -> float:
		var dx := global_position.x - p.x
		if not on or dx < -0.5 or dx > REACH or absf(p.y - global_position.y) > HALF_HEIGHT:
			return 0.0
		return clampf(1.0 - dx / REACH, 0.25, 1.0)

	func _physics_process(delta: float) -> void:
		spin = move_toward(spin, 14.0 if on else 0.0, delta * (10.0 if on else 4.0))
		_blades.rotate_z(-spin * delta)
		if not on:
			return
		for n in get_tree().get_nodes_in_group(PhysicsObject.GROUP):
			var o := n as PhysicsObject
			if o == null or o.freeze or o.stack.has(&"grab") or o.volume_mass() >= LIGHT:
				continue
			var w := wind_at(o.global_position)
			if w > 0.0:
				o.sleeping = false
				o.apply_central_force(Vector3(-1.0, 0.3, 0.0) * PUSH * w * o.mass)


# -------------------------------------------------------------------------------------- conveyor

## Y-05: a rubber belt let into the ground under the car. Zap its button and the belt runs left,
## carrying whatever sits on it toward the gate (the car shoves the oil drum); zap again to stop it.
class Conveyor extends StaticBody3D:
	const AT := Vector3(-26.6, 0.0, 0)
	const LENGTH := 4.4
	const SPEED := -2.2         # m/s along x: toward the gate (the heap's ramp blocks the other way)
	var on := false
	var _stripes: StandardMaterial3D
	var _rollers: Array[Node3D] = []

	func _ready() -> void:
		collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(LENGTH, 0.12, 1.8)
		cs.shape = sh
		add_child(cs)   # top at y 0.06: flush enough to walk on, high enough to carry
		var img := Image.create(8, 1, false, Image.FORMAT_RGB8)
		for x in 8:
			img.set_pixel(x, 0, MUSTARD if x < 2 else RUBBER)
		_stripes = StandardMaterial3D.new()
		_stripes.albedo_texture = ImageTexture.create_from_image(img)
		_stripes.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_stripes.uv1_scale = Vector3(LENGTH * 1.2, 1, 1)
		_stripes.roughness = 0.9
		var top := MeshInstance3D.new()
		top.mesh = Contraptions.box_mesh(Vector3(LENGTH, 0.13, 1.8))
		top.material_override = _stripes
		add_child(top)
		for x in [-LENGTH * 0.5, LENGTH * 0.5]:
			var r := Contraptions.mesh(self, Contraptions.cyl_mesh(0.16, 1.9, 12), METAL, Vector3(x, 0.0, 0), Vector3(90, 0, 0))
			_rollers.append(r)
			Contraptions.mesh(self, Contraptions.box_mesh(Vector3(0.12, 0.2, 0.12)), MUSTARD, Vector3(x, 0.02, 0.98))

	func set_on(v: bool) -> void:
		on = v
		if on:   # wake everything resting on it so it rides
			for n in get_tree().get_nodes_in_group(PhysicsObject.GROUP):
				var o := n as PhysicsObject
				if absf(o.global_position.x - global_position.x) < LENGTH * 0.5 + 1.0 and o.global_position.y < 3.0:
					o.sleeping = false

	## Riding the belt: something resting on it (its bottom near the belt's top, over the belt).
	func carries(p: Vector3, half_height: float) -> bool:
		var bottom := p.y - half_height
		return absf(p.x - global_position.x) < LENGTH * 0.5 and bottom < global_position.y + 0.45 and bottom > global_position.y - 0.4

	func _physics_process(delta: float) -> void:
		if not on:
			return
		# Jolt doesn't carry bodies on a static body's constant velocity, so the belt drags them itself.
		for n in get_tree().get_nodes_in_group(PhysicsObject.GROUP):
			var o := n as PhysicsObject
			if o.freeze or o.stack.has(&"grab") or not carries(o.global_position, o.half_extent_along(Vector3.UP)):
				continue
			o.sleeping = false
			o.linear_velocity.x = move_toward(o.linear_velocity.x, SPEED, 12.0 * delta)
		for n in get_tree().get_nodes_in_group(Zapper.GROUP):
			var z := n as Zapper
			if z.is_on_floor() and carries(z.global_position, 0.0):
				z.global_position.x += SPEED * delta
		_stripes.uv1_offset.x -= SPEED * delta / LENGTH   # the stripes march the way the belt runs
		for r in _rollers:
			r.rotate_object_local(Vector3.UP, -SPEED / 0.16 * delta)


## The big mushroom button on a post where the belt meets the heap. Any gun presses it.
class BeltButton extends Node3D:
	const AT := Vector3(-24.0, 1.7, -1.3)
	var belt: Conveyor
	var _cap: MeshInstance3D

	func _ready() -> void:
		add_to_group(&"zap_targets")
		Contraptions.mesh(self, Contraptions.cyl_mesh(0.09, 1.7), METAL.darkened(0.3), Vector3(0, -0.9, 0))
		Contraptions.mesh(self, Contraptions.box_mesh(Vector3(0.5, 0.22, 0.5)), MUSTARD, Vector3(0, -0.12, 0))
		_cap = Contraptions.mesh(self, Contraptions.cyl_mesh(0.3, 0.16, 20), LAMP_OFF, Vector3(0, 0.05, 0))
		sync()

	func radius() -> float:
		return 0.6

	func zapped_by(_z: Node, _gun: GunData) -> void:
		belt.set_on(not belt.on)
		sync()
		Audio.play("ui_confirm", global_position)
		Fx.ring(get_tree(), global_position, LAMP_ON, 0.6)
		var tw := _cap.create_tween()
		tw.tween_property(_cap, "position:y", -0.05, 0.08)
		tw.tween_property(_cap, "position:y", 0.05, 0.15)

	func sync() -> void:
		if _cap and belt:
			var m := _cap.material_override as StandardMaterial3D
			m.albedo_color = LAMP_ON if belt.on else LAMP_OFF
			m.emission_enabled = belt.on
			m.emission = LAMP_ON


# ------------------------------------------------------------------------------------------ hook

## Y-04: the crane's hook on its rope. Grab it with the gravity gun and swing it into something:
## the hook catches it (a glue joint, so the glue gun's blob lets it go) and, when you let go, the
## rope lifts it back up to dangle under the crane. Light enough to swing, strong enough for a cow.
class CraneHook extends PhysicsObject:
	const ANCHOR := Vector3(-17.8, 8.9, 0)
	const ROPE_TOP := Vector3(-17.8, 8.9, -2.6)   # where the rope leaves the crane's jib (dressing)
	const ROPE := 3.3
	const ROPE_SLACK := 9.0       # how far a player can pull it while holding it
	const REEL := 3.0             # m/s the winch pulls in
	const CARRY_MASS := 20.0      # the rope lifts up to this much physics mass
	const CATCH_GAP := 0.35
	var caught: PhysicsObject
	var _cooldown := 0.0
	var _rope: MeshInstance3D

	func _init() -> void:
		var d := ObjectData.make(&"crane_hook", ObjectData.Shape.BOX, Vector3(0.55, 0.7, 0.4), 3.0, METAL)
		d.has_face = false   # a machine part: no face
		d.voice = &"voice_anvil"
		d.max_step = 2
		super(d)

	func _ready() -> void:
		super()
		for mi in _visual.get_children():
			if mi is MeshInstance3D:
				mi.visible = false   # the greybox box: the hook draws itself
		Contraptions.mesh(_visual, Contraptions.box_mesh(Vector3(0.5, 0.36, 0.34)), MUSTARD, Vector3(0, 0.17, 0))
		Contraptions.mesh(_visual, Contraptions.torus_mesh(0.14, 0.27), METAL.darkened(0.15), Vector3(0, -0.2, 0), Vector3(90, 0, 0))
		_rope = MeshInstance3D.new()
		_rope.mesh = Contraptions.cyl_mesh(0.035, 1.0, 6)
		_rope.material_override = Contraptions.mat(Color("#24181a"))
		_rope.top_level = true
		add_child(_rope)

	func _physics_process(delta: float) -> void:
		super(delta)
		_cooldown -= delta
		var to := global_position - ANCHOR
		var dist := to.length()
		if dist > 14.0:   # recalled or flung far away: back on the rope
			reset()
			return
		var held := stack.has(&"grab")
		var rope := ROPE_SLACK if held else ROPE
		if dist > rope and not freeze:
			# A winch, not a spring: reel in at no more than REEL m/s, hold against gravity at the
			# rope's length, never fling (a spring this stiff threw the bathtub over the jib).
			var dir := to / dist
			var island := 0.0
			for o in stack.glued_group():
				island += o.mass
			var v_in := -linear_velocity.dot(dir)
			var want := minf((dist - rope) * 3.0, REEL)
			var hold := maxf(0.0, Yard.gravity_at(global_position).dot(dir))
			var acc := maxf(0.0, (want - v_in) * 8.0 + hold)
			apply_central_force(-dir * acc * minf(island, CARRY_MASS))
		_update_caught()
		_draw_rope()

	func _update_caught() -> void:
		var glue: Effects.Glue = stack.get_effect(&"glue")
		if caught and (glue == null or not is_instance_valid(caught)):
			caught = null
			_cooldown = 1.5   # just let go: don't snatch it straight back
		if caught or glue or _cooldown > 0.0 or freeze:
			return
		var tip := global_position + Vector3.DOWN * 0.3
		for n in get_tree().get_nodes_in_group(PhysicsObject.GROUP):
			var o := n as PhysicsObject
			if o == self or o.freeze or o.stack.has(&"grab"):
				continue
			if tip.distance_to(o.global_position) < o.radius() + CATCH_GAP:
				if Effects.glue(o, self):
					caught = o
					o.last_touch = &"gun"
					Audio.play("grab", global_position)
					o.speak("grabbed")
					Fx.ring(get_tree(), tip, MUSTARD, 0.6)
				return

	func _draw_rope() -> void:
		var top := ROPE_TOP
		var bottom := global_position + Vector3.UP * 0.35
		var d := bottom - top
		_rope.global_position = (top + bottom) * 0.5
		_rope.global_basis = Basis(Quaternion(Vector3.UP, d.normalized())).scaled(Vector3(1, d.length(), 1)) if d.length() > 0.01 else Basis()

	## Off whatever it holds, back under the crane, still.
	func reset() -> void:
		for e in stack.effects.duplicate():
			if e is Effects.Glue:
				e.undo(null)
		caught = null
		_cooldown = 1.0
		global_position = ANCHOR + Vector3.DOWN * ROPE
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		_last_v = Vector3.ZERO


# ------------------------------------------------------------------------------------ trampoline

## Y-08: the trampoline by the barn. Anything that lands on it hard springs back up (a little less
## each time, so it settles); a player bounces higher than a jump, high enough for the hayloft.
class Trampoline extends StaticBody3D:
	const AT := Vector3(10.4, 0.0, 0)
	const TOP := 0.32
	const RIM := 1.0
	const MIN_DROP := 3.0         # m/s down before it bounces back
	const KEEP := 0.86            # objects keep this much of their speed each bounce
	const PLAYER_POP := 8.6       # a player's bounce speed (hayloft height)
	var bounces := 0
	var _mat_mesh: MeshInstance3D

	func _ready() -> void:
		collision_layer = 1
		# A low trapezoid, so a player can walk up onto it and things roll off its edge.
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		for z in [-0.9, 0.9]:
			pts.append(Vector3(-RIM - 0.35, 0.0, z))
			pts.append(Vector3(RIM + 0.35, 0.0, z))
			pts.append(Vector3(RIM - 0.1, TOP, z))
			pts.append(Vector3(-RIM + 0.1, TOP, z))
		sh.points = pts
		cs.shape = sh
		add_child(cs)
		Contraptions.mesh(self, Contraptions.torus_mesh(RIM - 0.08, RIM + 0.08), TEAL, Vector3(0, TOP, 0))
		_mat_mesh = Contraptions.mesh(self, Contraptions.cyl_mesh(RIM - 0.05, 0.05, 28), RUBBER, Vector3(0, TOP - 0.02, 0))
		for k in 6:
			var a := TAU * (k + 0.5) / 6.0
			Contraptions.mesh(self, Contraptions.cyl_mesh(0.045, TOP), METAL, Vector3(cos(a) * RIM, TOP * 0.5, sin(a) * RIM))

	## Over the mat, falling, and about to touch it this step (checked before the physics step, so the
	## speed is the fall speed, not what's left after the contact).
	func _hits(x: float, bottom: float, vy: float, dt: float) -> bool:
		if absf(x - global_position.x) > RIM - 0.1 or vy > -MIN_DROP:
			return false
		var top := global_position.y + TOP
		return bottom > top - 0.25 and bottom + vy * dt * 2.0 < top + 0.05

	func _physics_process(delta: float) -> void:
		for n in get_tree().get_nodes_in_group(PhysicsObject.GROUP):
			var o := n as PhysicsObject
			if o.freeze or o.stack.has(&"grab"):
				continue
			var bottom := o.global_position.y - o.half_extent_along(Vector3.UP)
			if _hits(o.global_position.x, bottom, o.linear_velocity.y, delta):
				o.linear_velocity.y = -o.linear_velocity.y * KEEP
				o.sleeping = false
				_boing(o.global_position)
		for n in get_tree().get_nodes_in_group(Zapper.GROUP):
			var z := n as Zapper
			if not z.asleep and _hits(z.global_position.x, z.global_position.y, z.velocity.y, delta):
				z.velocity.y = PLAYER_POP
				_boing(z.global_position)

	func _boing(at: Vector3) -> void:
		bounces += 1
		Audio.play("boing", at)
		Fx.ring(get_tree(), Vector3(at.x, global_position.y + TOP + 0.05, 0.0), TEAL.lightened(0.3), RIM)
		var tw := _mat_mesh.create_tween()
		tw.tween_property(_mat_mesh, "position:y", TOP - 0.3, 0.06)
		tw.tween_property(_mat_mesh, "position:y", TOP - 0.02, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
