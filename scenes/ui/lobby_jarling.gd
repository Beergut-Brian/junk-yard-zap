## The player's pick on a Showtime lobby podium: the game's own Jarling rig (whoever Roster says,
## Jeff and Chuck by default) holding a junk gun taped in the player's colour. data/menu_skin.tres
## hosts lobby_p1.tscn / lobby_p2.tscn as MenuSkin.p1_character / p2_character; CharacterSlot gives
## it its own lit SubViewport and calls set_character(id) (at host time and on every chooser swap),
## set_joined(on), wave() and cheer().
extends Node3D

@export var player := Players.P1

## Three-quarter turn toward the menu on the right (on top of CharacterSlot's turntable), so the
## gun in the right hand points across the stage instead of straight at the camera, where its dish
## read as a frisbee covering the body.
const TURN := {Players.P1: 14.0, Players.P2: 50.0}
## M-03: the gun held up and out to the side ("guns up!"), in the rig's own space (+z is the way
## the character faces, -x their right), so the dish sits by the shoulder instead of over the legs.
const GUN_UP := Vector3(-0.55, 0.75, 0.38)

var rig: JarlingRig
## The Roster id shown; "" until the slot says (then Roster.pick(player)).
var id := ""
var _joined := false


func _ready() -> void:
	if id == "":
		id = Roster.pick(player)
	rig = JarlingRig.new()
	rig.character = StringName(id)
	rig.rotation_degrees.y = TURN[player]
	add_child(rig)
	rig.equip_gun(Players.COLOR[player])
	set_joined(_joined)
	raise_gun.call_deferred()


## The chooser swapped (or the slot is telling us the pick before _ready): same rig, gun and tape,
## new body.
func set_character(to: String) -> void:
	if not Roster.has(to):
		return
	id = to
	if rig:
		rig.set_character(to)
		set_joined(_joined)
		raise_gun.call_deferred()


func set_joined(on: bool) -> void:
	_joined = on
	if rig == null:
		return
	rig.play("idle", 1.0 if on else 0.4)
	rig.set_expression("happy" if on else "neutral")


func wave() -> void:
	_cheer_for(1.4)


## The round is starting: both jump (the slot hops them too).
func cheer() -> void:
	_cheer_for(2.0)


func _cheer_for(secs: float) -> void:
	if rig == null:
		return
	rig.play("cheer")
	rig.set_expression("happy")
	get_tree().create_timer(secs).timeout.connect(func() -> void:
		if is_instance_valid(rig):
			set_joined(_joined))


## Points the held gun's barrel (+z in GunArt) along GUN_UP. Returns the holder it turned.
func raise_gun() -> Node3D:
	if rig == null or rig.gun_gear == null or not rig.is_inside_tree():
		return null
	var slot := rig.equipment.slot_node(&"hand_r")
	var holder := slot.get_node_or_null("gear_%s" % rig.gun_gear.id) as Node3D if slot else null
	if holder == null:
		return null
	var dir := (rig.global_basis * GUN_UP).normalized()
	var s := holder.global_basis.get_scale()
	holder.global_basis = Basis.looking_at(-dir, rig.global_basis.y).scaled(s)
	return holder
