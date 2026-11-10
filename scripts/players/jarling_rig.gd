## A Jarling from openjar-characters (assets/characters/<id>/<id>.glb) set up for Junk Yard Zap:
## looping idle/run/cheer, side-view facing, face expressions, and gear on the equipment system
## (the gun belt on `waist`, the held gun on `hand_r`). Also used by the lobby panels.
class_name JarlingRig
extends Node3D

const EXPR := {"neutral": Vector3(0, 0, 0), "happy": Vector3(0.5, 0, 0),
		"surprised": Vector3(0, 0.5, 0), "determined": Vector3(0.5, 0.5, 0)}
const SCENES := {&"jeff": "res://assets/characters/jeff/jeff.glb", &"chuck": "res://assets/characters/chuck/chuck.glb"}
const BELT_GLB := "res://assets/characters/gear/belt.glb"
## The glbs are ~1.2 m tall; the yard's objects are sized for a ~1.55 m character.
const SCALE := 1.3

@export var character: StringName = &"jeff"

var model: Node3D
var anim: AnimationPlayer
var equipment: JarlingEquipment
var gun_gear: JarlingGear
var _face_mats: Array[StandardMaterial3D] = []
var _gun_tip: MeshInstance3D
var _gun_tape: MeshInstance3D
var _current := ""


func _ready() -> void:
	model = (load(SCENES.get(character, SCENES[&"jeff"])) as PackedScene).instantiate()
	model.scale = Vector3.ONE * SCALE
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		for a in ["idle", "run", "cheer"]:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s) as StandardMaterial3D
			if mat == null:
				continue
			mat = mat.duplicate()
			mat.rim_enabled = true
			mat.rim = 0.4
			mat.rim_tint = 0.3
			m.set_surface_override_material(s, mat)
			if mat.resource_name.ends_with("_face"):
				_face_mats.append(mat)
	equipment = JarlingEquipment.new()
	equipment.jarling = model
	equipment.pop_in = false
	add_child(equipment)
	equipment.equip(belt_gear())
	play("idle")


func play(a: String, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(a):
		return
	anim.speed_scale = speed
	if _current != a:
		_current = a
		anim.play(a, 0.15)


func set_expression(e: String) -> void:
	for m in _face_mats:
		m.uv1_offset = EXPR.get(e, Vector3.ZERO)


## Side view: +1 faces right, -1 left; turned toward the camera a little so the face reads.
func face_dir(dir: float, delta := 1.0) -> void:
	var want := deg_to_rad(65.0) * signf(dir) if dir != 0.0 else 0.0
	model.rotation.y = lerp_angle(model.rotation.y, want, minf(1.0, delta * 12.0))


static func belt_gear() -> JarlingGear:
	var g := JarlingGear.new()
	g.id = &"belt"
	g.slots = [&"waist"]
	g.scene = load(BELT_GLB) as PackedScene
	g.fit = {"boxy": {"scale": [1.03, 1.0, 1.05]}}
	return g


## The held gun: a placeholder junk blaster packed into a scene so it goes on like any gear.
## tape is the player's colour (Jeff green, Chuck red); recolour() sets the nozzle per gun.
func equip_gun(tape: Color) -> void:
	var root := Node3D.new()
	root.name = "blaster"
	var body := _part(root, BoxMesh.new(), Vector3(0.07, 0.08, 0.22), Vector3(0, 0, 0.06), Color(0.55, 0.55, 0.58))
	body.name = "body"
	var tape_node := _part(root, BoxMesh.new(), Vector3(0.075, 0.085, 0.04), Vector3(0, 0, 0.02), tape)
	tape_node.name = "tape"
	var tip := _part(root, CylinderMesh.new(), Vector3(0.1, 0.1, 0.08), Vector3(0, 0, 0.2), Color.WHITE)
	tip.rotation_degrees.x = 90
	tip.name = "tip"
	var pack := PackedScene.new()
	pack.pack(root)
	root.free()
	gun_gear = JarlingGear.new()
	gun_gear.id = &"blaster"
	gun_gear.slots = [&"hand_r"]
	gun_gear.scene = pack
	equipment.equip(gun_gear)
	var holder := equipment.slot_node(&"hand_r").get_node("gear_blaster")
	_gun_tip = holder.find_child("tip", true, false)
	_gun_tape = holder.find_child("tape", true, false)


func recolor_gun(c: Color) -> void:
	if _gun_tip:
		(_gun_tip.material_override as StandardMaterial3D).albedo_color = c
		(_gun_tip.material_override as StandardMaterial3D).emission_enabled = true
		(_gun_tip.material_override as StandardMaterial3D).emission = c * 0.6
		var h := _gun_tip.get_parent() as Node3D
		h.scale = Vector3.ONE * 1.6
		h.create_tween().tween_property(h, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func gun_tip_position() -> Vector3:
	return _gun_tip.global_position if _gun_tip else global_position + Vector3(0, 0.8, 0)


func _part(root: Node3D, m: Mesh, size: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	if m is BoxMesh:
		m.size = size
	elif m is CylinderMesh:
		m.top_radius = size.x * 0.5
		m.bottom_radius = size.x * 0.5
		m.height = size.z
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mi.material_override = mat
	root.add_child(mi)
	mi.owner = root
	return mi
