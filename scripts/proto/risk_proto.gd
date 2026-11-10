## Phase 1 risk prototype: a yard strip, ten physics objects, a capsule player with the aim cone and
## the seven effects. Run: godot --path . res://scenes/proto/risk_proto.tscn
## User args (after --): --plain skips the showcase setup, --stress runs scripts/proto/stress.gd,
## --stress=40 also spawns copies up to 40 bodies.
extends Node3D

const ROSTER := [
	# id, shape, size, mass, colour, x, y
	[&"crate_a", ObjectData.Shape.BOX, Vector3(1, 1, 1), 1.0, Color(0.8, 0.55, 0.3), -9.0, 0.5],
	[&"crate_b", ObjectData.Shape.BOX, Vector3(1, 1, 1), 1.0, Color(0.7, 0.5, 0.35), -3.0, 0.5],
	[&"crate_c", ObjectData.Shape.BOX, Vector3(1.2, 1.2, 1.2), 1.5, Color(0.75, 0.6, 0.4), 6.0, 0.6],
	[&"small_box", ObjectData.Shape.BOX, Vector3(0.6, 0.6, 0.6), 0.4, Color(0.9, 0.7, 0.45), 3.0, 0.3],
	[&"tall_box", ObjectData.Shape.BOX, Vector3(0.8, 1.6, 0.8), 1.5, Color(0.6, 0.45, 0.35), -9.0, 1.8],
	[&"wide_box", ObjectData.Shape.BOX, Vector3(1.5, 0.7, 1.0), 1.5, Color(0.65, 0.55, 0.45), -9.0, 2.95],
	[&"ball", ObjectData.Shape.SPHERE, Vector3(0.9, 0.9, 0.9), 0.6, Color(0.95, 0.95, 0.9), 0.0, 0.45],
	[&"plank", ObjectData.Shape.BOX, Vector3(4.0, 0.25, 0.8), 2.0, Color(0.7, 0.6, 0.4), 10.0, 0.125],
	[&"car", ObjectData.Shape.BOX, Vector3(2.4, 1.1, 1.3), 12.0, Color(0.35, 0.45, 0.6), -5.5, 0.55],
	[&"chicken", ObjectData.Shape.BOX, Vector3(0.5, 0.6, 0.4), 0.3, Color(0.98, 0.98, 0.95), 13.0, 0.3],
]

var objects: Array[PhysicsObject] = []
var player: ProtoPlayer
var camera: Camera3D
var hud: Label
var stress: Node


func _ready() -> void:
	add_child(YardStrip.new())
	for r in ROSTER:
		spawn(ObjectData.make(r[0], r[1], r[2], r[3], r[4]), Vector3(r[5], r[6], 0))
	player = ProtoPlayer.new()
	player.name = "Player"
	player.position = Vector3(-14, 1.0, 0)
	add_child(player)
	camera = Camera3D.new()
	camera.fov = 32.0
	camera.position = Vector3(0, 5.5, 26)
	camera.rotation_degrees.x = -6.0
	add_child(camera)
	camera.make_current()
	hud = Label.new()
	hud.position = Vector2(24, 24)
	hud.add_theme_font_size_override("font_size", 28)
	var layer := CanvasLayer.new()
	layer.add_child(hud)
	add_child(layer)
	var args := OS.get_cmdline_user_args()
	var stress_arg := ""
	for a in args:
		if a == "--stress" or a.begins_with("--stress="):
			stress_arg = a
	if stress_arg != "":
		stress = load("res://scripts/proto/stress.gd").new()
		stress.count = int(stress_arg.trim_prefix("--stress=")) if "=" in stress_arg else 0
		add_child(stress)
	elif not args.has("--plain"):
		showcase.call_deferred()
	if Game.state != Game.State.PLAYING:
		Game.start_round()
	Game.round_started.connect(func(_i): get_tree().reload_current_scene.call_deferred())


func spawn(d: ObjectData, pos: Vector3) -> PhysicsObject:
	var o := PhysicsObject.new(d)
	o.name = String(d.id)
	o.position = pos
	add_child(o)
	objects.append(o)
	return o


func find(id: StringName) -> PhysicsObject:
	for o in objects:
		if o.data.id == id:
			return o
	return null


## What the screenshots show: different scales, a glued pair, a stack.
func showcase() -> void:
	for i in 3:
		Effects.zap(&"grow", find(&"crate_c"))
		Effects.zap(&"shrink", find(&"small_box"))
	for i in 4:
		Effects.zap(&"grow", find(&"chicken"))
	Effects.glue(find(&"car"), find(&"crate_b"))
	Effects.zap(&"grow", find(&"car"))
	Effects.zap(&"bouncy", find(&"ball"))
	Effects.zap(&"freeze", find(&"plank"))


func _process(_delta: float) -> void:
	camera.position.x = clampf(player.position.x * 0.6, -14.0, 14.0)
	var t := player.target
	hud.text = "gun: %s   (Q/E or LB/RB)\ntarget: %s%s\nfps %d" % [
		player.gun(), t.name if t else "-",
		("   glue A: %s" % player.glue_first.name) if is_instance_valid(player.glue_first) else "",
		Engine.get_frames_per_second()]
