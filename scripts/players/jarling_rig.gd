## A Jarling from openjar-characters set up for Junk Yard Zap: whichever Roster character `character`
## names (its vendored .glb from data/roster.json), with looping idle/run/cheer, side-view facing,
## face expressions, and gear on the equipment system (the gun belt on `waist`, the held gun on
## `hand_r`). Works on any standard-body Jarling. Also used by the lobby podiums (set_character).
class_name JarlingRig
extends Node3D

const EXPR := {"neutral": Vector3(0, 0, 0), "happy": Vector3(0.5, 0, 0),
		"surprised": Vector3(0, 0.5, 0), "determined": Vector3(0.5, 0.5, 0)}
## Used when the id has no vendored .glb (an id from an older roster, an empty roster).
const FALLBACK_GLB := "res://assets/characters/jeff/jeff.glb"
const BELT_GLB := "res://assets/gear/belt.glb"
## The glbs are ~1.2 m tall; the yard's objects are sized for a ~1.55 m character.
const SCALE := 1.3

## A Roster id (data/roster.json). Change it after _ready with set_character().
@export var character: StringName = &"jeff"

var model: Node3D
var anim: AnimationPlayer
var equipment: JarlingEquipment
var gun_gear: JarlingGear
var _face_mats: Array[StandardMaterial3D] = []
var _gun_tip: Node3D
var _gun_tape: MeshInstance3D
var _tape := Color.WHITE
var _current := ""


func _ready() -> void:
	_build()


## The .glb for a Roster id; FALLBACK_GLB when the id is unknown or its file is missing.
static func glb_for(id: String) -> String:
	var who := Roster.info(id)
	if not who.is_empty() and str(who.glb) != "" and ResourceLoader.exists(str(who.glb)):
		return str(who.glb)
	return FALLBACK_GLB


## Become another Roster character in place: same gun (and tape), belt, facing and animation.
func set_character(id: String) -> void:
	if StringName(id) == character and model != null:
		return
	character = StringName(id)
	if model == null:
		return   # not in the tree yet: _ready builds it
	var turn := model.rotation.y
	var kind: StringName = gun_gear.id if gun_gear else &""
	var had_gun := gun_gear != null
	var was := _current
	model.free()
	equipment.free()
	model = null
	gun_gear = null
	_gun_tip = null
	_gun_tape = null
	_face_mats.clear()
	_current = ""
	_build()
	model.rotation.y = turn
	if had_gun:
		show_gun(StringName(str(kind).trim_prefix("gun_")), false)
	if was != "":
		play(was)


func _build() -> void:
	model = (load(glb_for(str(character))) as PackedScene).instantiate()
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


## The held gun: one of the seven junk-built guns (GunArt) worn on `hand_r` through the equipment
## system. tape is the player's colour (P1 green, P2 red, whoever they picked); show_gun() swaps to another gun.
func equip_gun(tape: Color, kind: StringName = &"size") -> void:
	_tape = tape
	show_gun(kind, false)


## Swap the gun in the hand for `kind` (GunArt.KINDS), with a little pop.
func show_gun(kind: StringName, pop := true) -> void:
	if not GunArt.KINDS.has(kind):
		kind = &"size"
	if gun_gear and gun_gear.id == StringName("gun_%s" % kind):
		return
	gun_gear = JarlingGear.new()
	gun_gear.id = StringName("gun_%s" % kind)
	gun_gear.slots = [&"hand_r"]
	gun_gear.scene = GunArt.packed(kind, _tape)
	equipment.equip(gun_gear)
	var holder := equipment.slot_node(&"hand_r").get_node_or_null("gear_%s" % gun_gear.id) as Node3D
	_gun_tip = holder.find_child("tip", true, false) if holder else null
	_gun_tape = holder.find_child("tape", true, false) if holder else null
	if holder and pop:
		var h := holder
		var rest := h.scale
		h.scale = rest * 1.5
		h.create_tween().tween_property(h, "scale", rest, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Older callers (the art-direction preview) pick a gun by its colour.
func recolor_gun(c: Color) -> void:
	var best: StringName = &"size"
	var dist := INF
	for k in GunArt.KINDS:
		var g := ArtKit.gun(k)
		var d := Vector3(g.r - c.r, g.g - c.g, g.b - c.b).length()
		if d < dist:
			dist = d
			best = k
	show_gun(best)


func gun_tip_position() -> Vector3:
	return _gun_tip.global_position if _gun_tip else global_position + Vector3(0, 0.8, 0)
