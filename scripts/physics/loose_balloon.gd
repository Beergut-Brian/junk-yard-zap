## A loose balloon (Y-11): floats at its hover height, drifts back inside its zone, pops into a small
## smiling puff on a hard hit or a sharp poke, and pops back in at its layout spot after respawn_time.
## While popped it is out of the yard_objects group (no gun, magnet or goal card sees it) and has no
## collision; it waits, still and in bounds, at its home spot.
class_name LooseBalloon
extends PhysicsObject

## Ids that count as sharp: touching one fast enough pops a balloon.
const SHARP: Array[StringName] = [&"traffic_cone", &"garden_gnome", &"lawn_flamingo", &"bowling_pin",
		&"pipe", &"toolbox", &"anvil", &"cannonball", &"kite"]
const ZONE_INSET := 1.2       # metres kept inside the zone's edges
const ZONE_K := 4.0           # 1/s^2 back into the zone when it drifts out
const PUFF_TIME := 0.9

signal popped(obj: LooseBalloon)
signal respawned(obj: LooseBalloon)

var home := Vector3.ZERO
var zone_x := Vector2(-INF, INF)
var is_popped := false
var pops := 0
var _respawn_left := 0.0
var _pop_queued := false
var _t := 0.0
var _grace := 0.0   # seconds after a grab ends when a speed change is a throw, not a hit


func _ready() -> void:
	super._ready()
	home = position
	for z in YardLevel.ZONES:
		if home.x >= z[1] and home.x < z[2]:
			zone_x = Vector2(z[1] + ZONE_INSET, z[2] - ZONE_INSET)
	_t = float(get_instance_id() % 97) * 0.13


func bd() -> BalloonData:
	return data as BalloonData


func hover_y() -> float:
	return home.y + bd().hover


func _physics_process(delta: float) -> void:
	_t += delta
	if is_popped:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			respawn()
		return
	super._physics_process(delta)
	if _pop_queued:
		pop()
		return
	_check_pokes()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_popped:
		var xf := state.transform
		xf.origin = home
		state.transform = xf
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		return
	var before := _last_v
	var v_in := state.linear_velocity
	super._integrate_forces(state)
	var held := stack.has(&"grab")
	_grace = 0.2 if held else maxf(0.0, _grace - state.step)
	if _grace <= 0.0 and not freeze and (v_in - before).length() > bd().pop_dv:
		_pop_queued = true
	if held or freeze:
		return
	var dt := state.step
	var pos := state.transform.origin
	var v := state.linear_velocity
	# Cancel the gravity the body just took (gun lift included) and float on a soft spring instead.
	v -= Yard.gravity_at(pos) * effective_gravity_scale * dt
	var goal := hover_y() + sin(_t * 1.6) * 0.12
	if stack.has(&"balloon"):
		goal += 2.5   # the balloon gun lifts it a bit higher, still in the yard
	v.y += (bd().hover_k * (goal - pos.y) - bd().hover_damp * v.y) * dt
	if pos.x < zone_x.x:
		v.x += ZONE_K * (zone_x.x - pos.x) * dt
	elif pos.x > zone_x.y:
		v.x += ZONE_K * (zone_x.y - pos.x) * dt
	v.x *= 1.0 - minf(1.0, bd().air_drag * dt)
	_keep_upright(state, dt)
	state.linear_velocity = v
	_last_v = v


func _keep_upright(state: PhysicsDirectBodyState3D, dt: float) -> void:
	# Keep it upright: a balloon on a string swings back, it doesn't tumble.
	var w := state.angular_velocity * (1.0 - minf(1.0, 3.0 * dt))
	var tilt := state.transform.basis.get_euler().z
	w.z -= tilt * 6.0 * dt
	state.angular_velocity = w


## A sharp thing moving into it pops it (cheap: only the few SHARP bodies close by are checked).
func _check_pokes() -> void:
	if stack.has(&"grab"):
		return
	var r := radius()
	for n in get_tree().get_nodes_in_group(GROUP):
		var o := n as PhysicsObject
		if o == self or not SHARP.has(o.data.id):
			continue
		var gap := o.global_position.distance_to(global_position) - r - o.radius() * 0.7
		if gap < 0.05 and (o.linear_velocity - linear_velocity).length() > bd().poke_speed:
			pop()
			return


## Pop: a happy puff with a little face and confetti, then gone for respawn_time.
func pop() -> void:
	_pop_queued = false
	if is_popped:
		return
	var at := global_position
	is_popped = true
	pops += 1
	_respawn_left = bd().respawn_time
	stack.clear()
	chute_left = 0.0
	remove_from_group(GROUP)
	_visual.visible = false
	for cs in find_children("*", "CollisionShape3D", false, false):
		(cs as CollisionShape3D).set_deferred(&"disabled", true)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_last_v = Vector3.ZERO
	Audio.play(String(bd().pop_cue), at)
	Fx.burst(get_tree(), at, Color(data.color, 0.95), 14, 0.9, 0.6)
	Fx.burst(get_tree(), at, Color(1, 0.95, 0.6, 0.9), 8, 0.7, 0.5)
	var puff := make_puff(data.size.x * current_scale)
	get_parent().add_child(puff)
	puff.global_position = at
	popped.emit(self)


## Back in: grows from nothing at its layout spot with a sparkle and a squeak.
func respawn() -> void:
	is_popped = false
	current_scale = 1.0
	target_scale = 1.0
	global_position = home
	rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	_last_v = Vector3.ZERO
	for cs in find_children("*", "CollisionShape3D", false, false):
		(cs as CollisionShape3D).set_deferred(&"disabled", false)
	_rebuild_shape()
	add_to_group(GROUP)
	_visual.visible = true
	squash = Vector3.ONE * 0.05
	var tw := create_tween()
	tw.tween_property(self, "squash", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Fx.sparkle(get_tree(), home)
	speak("grabbed")
	if face:
		face.react(ObjectFace.Mood.HAPPY, 1.2)
	respawned.emit(self)


## A tiny cloud puff with a smile: swells, drifts up and fades out.
static func make_puff(d: float) -> Node3D:
	var root := Node3D.new()
	root.name = "BalloonPuff"
	var r := maxf(0.18, d * 0.32)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.97, 0.9, 0.95)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	for off in [Vector3(-0.8, 0, 0), Vector3(0.8, 0, 0), Vector3(0, 0.55, 0), Vector3(0, -0.2, 0.2), Vector3(-0.35, 0.4, 0), Vector3(0.4, 0.35, 0)]:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = 12
		s.rings = 6
		mi.mesh = s
		mi.material_override = m
		mi.position = off * r
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var f := ObjectFace.new()
	f.setup(r * 0.9)
	f.position = Vector3(0, 0.15 * r, r + 0.3 * r)
	root.add_child(f)
	f.set_base(ObjectFace.Mood.HAPPY)
	root.scale = Vector3.ONE * 0.3
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "position:y", 0.8, PUFF_TIME).as_relative()
	tw.tween_property(m, "albedo_color:a", 0.0, PUFF_TIME * 0.6).set_delay(PUFF_TIME * 0.4)
	tw.chain().tween_callback(root.queue_free)
	return root
