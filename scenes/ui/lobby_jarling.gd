## Jeff or Chuck standing in a lobby join panel: the real Jarling rendered in its own little world.
## Swapped in for the template's placeholder Spots/P*/Character by main.gd, in code (exported builds
## drop overrides on instanced children). The lobby calls set_joined(on) and wave().
extends SubViewportContainer

var player := Players.P1
var rig: JarlingRig
var _joined := false
var _vp: SubViewport


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var stage := Node3D.new()
	_vp.add_child(stage)
	rig = JarlingRig.new()
	rig.character = Zapper.CHARACTER[player]
	stage.add_child(rig)
	rig.equip_gun(Players.COLOR[player])
	rig.model.rotation.y = deg_to_rad(20.0 if player == Players.P1 else -20.0)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 0.95, 3.4)
	cam.rotation_degrees.x = -6.0
	stage.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.2
	stage.add_child(key)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.85, 0.8)
	env.environment.ambient_light_energy = 0.6
	stage.add_child(env)
	set_joined(_joined)


func set_joined(on: bool) -> void:
	_joined = on
	if not is_node_ready():
		return
	modulate = Color(1, 1, 1, 1) if on else Color(0.35, 0.35, 0.4, 0.55)
	rig.play("idle", 1.0 if on else 0.4)
	rig.set_expression("happy" if on else "neutral")


func wave() -> void:
	rig.play("cheer")
	rig.set_expression("happy")
	get_tree().create_timer(1.4).timeout.connect(func() -> void:
		if is_instance_valid(rig):
			rig.play("idle"))
