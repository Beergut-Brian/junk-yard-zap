## The shared camera (GAME.md "Camera and controls"): frames every awake player, zooms out as they
## separate, soft-locked to the yard. Never splits. If a player still ends up off-screen (more than
## MAX_Z apart), the HUD points an arrow in their colour. Registers itself as Fx.camera for shake.
class_name CameraRig
extends Camera3D

const MIN_Z := 19.0
const MAX_Z := 46.0
const MARGIN := 5.0          # metres of room around the players
const LOOK_DOWN := 5.0       # degrees
const FOLLOW := 3.5          # 1/s

var left := YardLevel.LEFT
var right := YardLevel.RIGHT
## Frame the whole yard (the "yard wide" shot, and the lobby backdrop).
var overview := false
## Extra things to keep in frame (the demo's staged shots).
var focus: Array[Node3D] = []
var _trauma := 0.0


func _ready() -> void:
	fov = 34.0
	near = 0.5
	far = 300.0
	rotation_degrees.x = -LOOK_DOWN
	Fx.camera = self
	position = Vector3(-36, 6, 22)


func shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func targets() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for z in get_tree().get_nodes_in_group(Zapper.GROUP):
		if not (z as Zapper).asleep:
			out.append(z)
	for f in focus:
		if is_instance_valid(f):
			out.append(f)
	return out


func _process(delta: float) -> void:
	var want := goal_position()
	var k := 1.0 - exp(-FOLLOW * delta)
	position = position.lerp(want, k)
	_trauma = maxf(0.0, _trauma - delta * 1.8)
	var s := _trauma * _trauma
	h_offset = randf_range(-1, 1) * s * 0.6
	v_offset = randf_range(-1, 1) * s * 0.4


func half_width(z: float) -> float:
	return z * tan(deg_to_rad(fov * 0.5)) * _aspect()


func half_height(z: float) -> float:
	return z * tan(deg_to_rad(fov * 0.5))


func _aspect() -> float:
	var vp := get_viewport()
	if vp == null:
		return 16.0 / 9.0
	var r := vp.get_visible_rect().size
	return r.x / maxf(r.y, 1.0)


func goal_position() -> Vector3:
	if overview:
		var oz := ((right - left) * 0.5 + 1.0) / (tan(deg_to_rad(fov * 0.5)) * _aspect())
		return Vector3((left + right) * 0.5, 6.0 + oz * tan(deg_to_rad(LOOK_DOWN)), oz)
	var ts := targets()
	if ts.is_empty():
		return position
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for t in ts:
		var p := t.global_position
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y + (t.radius() * 1.8 if t is PhysicsObject else 1.6)))
	var c := (lo + hi) * 0.5
	var t_h := tan(deg_to_rad(fov * 0.5))
	var z := maxf((hi.x - lo.x) * 0.5 + MARGIN, 0.0) / (t_h * _aspect())
	z = maxf(z, ((hi.y - lo.y) * 0.5 + MARGIN * 0.6) / t_h)
	z = clampf(z, MIN_Z, MAX_Z)
	var hw := half_width(z)
	var x := clampf(c.x, left + hw - 2.0, right - hw + 2.0) if right - left > hw * 2.0 else (left + right) * 0.5
	# Keep the ground near the bottom of the frame; look a little above the players.
	var y := maxf(c.y + 1.5, half_height(z) * 0.7 - 2.5)
	return Vector3(x, y + z * tan(deg_to_rad(LOOK_DOWN)), z)


## A world point is on screen (with a small margin).
func sees(p: Vector3, margin := 40.0) -> bool:
	if is_position_behind(p):
		return false
	var s := unproject_position(p)
	var r := get_viewport().get_visible_rect().size
	return s.x > margin and s.y > margin and s.x < r.x - margin and s.y < r.y - margin
