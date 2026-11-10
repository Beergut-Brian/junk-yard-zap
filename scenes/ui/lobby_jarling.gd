## Jeff or Chuck on a Showtime lobby podium: the game's own Jarling rig holding a junk gun taped in
## the player's colour. data/menu_skin.tres hosts lobby_jeff.tscn / lobby_chuck.tscn as
## MenuSkin.p1_character / p2_character; CharacterSlot gives it its own lit SubViewport and calls
## set_joined(on), wave() and cheer().
extends Node3D

@export var player := Players.P1

## Three-quarter turn toward the menu on the right (on top of CharacterSlot's turntable), so the
## gun in the right hand points across the stage instead of straight at the camera, where its dish
## read as a frisbee covering the body.
const TURN := {Players.P1: 14.0, Players.P2: 50.0}

var rig: JarlingRig
var _joined := false


func _ready() -> void:
	rig = JarlingRig.new()
	rig.character = Zapper.CHARACTER[player]
	rig.rotation_degrees.y = TURN[player]
	add_child(rig)
	rig.equip_gun(Players.COLOR[player])
	set_joined(_joined)


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
