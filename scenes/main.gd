## Boot scene: the lobby (start screen and main menu) over the yard (its look, Jeff and Chuck on the
## podiums and the blurred yard behind, is data/menu_skin.tres), Jeff and Chuck in play, the shared
## camera, the HUD, the pause menu. There are no rounds: a session is however long you want, and
## the yard saves as you leave it (scripts/levels/yard_level.gd).
## Drop-in: whoever didn't ready in the lobby sleeps in the tire pile; any press of their pad (or a
## key from their keys) wakes them with a snort. Players who readied start awake.
## Solo (playtest): one pad drives the active player; LB + RB + Select (or Tab) swaps who that is.
## CLI (after --): --demo (bots play), --demo-beat=combo|goal|wide|rings|apart|zone-<name> (staged
## shots), --soak (with --demo: stress + a log line every 30 s), --proto.
extends Node3D

const ZAPPER := preload("res://scenes/players/zapper.tscn")
const SWAP_BUTTONS := [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_BACK]

@onready var level: YardLevel = $Arena
@onready var players_root: Node3D = $Arena/Players
@onready var camera: CameraRig = $Camera
@onready var hud: Hud = $UI/Hud
@onready var lobby: Control = $UI/Lobby

var _players := {}
var _bots := {}


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--proto"):   # Phase 1 risk prototype, reachable from an export
		get_tree().change_scene_to_file.call_deferred("res://scenes/proto/risk_proto.tscn")
		return
	var cursor := Cursor.new()
	cursor.name = "Cursor"
	add_child(cursor)
	hud.attach(level, camera)
	camera.make_current()
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	Game.lobby_ready.connect(_on_lobby_ready)
	Game.back_to_lobby.connect(_clear_players)
	Game.round_started.connect(_on_round_started)
	Game.state_changed.connect(func(_f: int, to: int) -> void: camera.overview = to == Game.State.LOBBY)
	camera.overview = Game.state == Game.State.LOBBY
	if Game.demo:
		(func() -> void:
			Players.join_virtual(Players.P1)
			Players.join_virtual(Players.P2)
			Game.start_round()
			_start_demo()).call_deferred()
	elif Game.state != Game.State.LOBBY:
		Game.to_lobby()


func _on_lobby_ready(players: Array) -> void:
	_spawn_all(players)


func _on_round_started(_round: int) -> void:
	_spawn_all(Players.active_players())


func _spawn_all(awake: Array) -> void:
	for p in [Players.P1, Players.P2]:
		_spawn(p, not awake.has(p))
		if awake.has(p):
			_players[p].wake()


## A pad joined while playing: if it's Chuck's, he wakes up.
func _on_player_joined(player: int, _device: int) -> void:
	if Game.state == Game.State.LOBBY:
		return
	if _players.has(player):
		_players[player].wake()
	else:
		_spawn(player, false)


## Drop-out: back to sleep in the tire pile.
func _on_player_left(player: int) -> void:
	if not _players.has(player):
		return
	var z: Zapper = _players[player]
	z._let_go(false)
	z.global_position = level.spawns[Players.P2].global_position
	z.velocity = Vector3.ZERO
	z.set_asleep(true)


func _clear_players() -> void:
	if level.use_save:
		level.save_yard()
	for p in _players.values():
		p.queue_free()
	_players.clear()
	for b in _bots.values():
		b.queue_free()
	_bots.clear()


func _spawn(player: int, asleep := false) -> Zapper:
	if _players.has(player):
		return _players[player]
	var z: Zapper = ZAPPER.instantiate()
	z.player = player
	z.asleep = asleep
	var guns: Dictionary = Save.get_value("guns", {})
	z.gun_index = int(guns.get(str(player), 0))
	z.position = level.spawns[Players.P2 if asleep else player].global_position
	players_root.add_child(z)
	_players[player] = z
	level.register_zapper(z)
	z.gun_changed.connect(_on_gun_changed)
	return z


func zapper(player: int) -> Zapper:
	return _players.get(player)


func _on_gun_changed(player: int, _gun: GunData) -> void:
	hud.show_wheel(player)
	var guns: Dictionary = Save.get_value("guns", {})
	guns[str(player)] = _players[player].gun_index if _players.has(player) else 0
	Save.set_value("guns", guns)


func _input(event: InputEvent) -> void:
	if not Players.solo or Game.state != Game.State.PLAYING:
		return
	var swap := false
	if event is InputEventJoypadButton and event.pressed and event.button_index in SWAP_BUTTONS:
		swap = SWAP_BUTTONS.all(func(b: int) -> bool: return Input.is_joy_button_pressed(event.device, b))
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		swap = true
	if swap:
		swap_solo_focus()


func swap_solo_focus() -> void:
	var to := Players.P2 if Players.solo_focus == Players.P1 else Players.P1
	Players.set_solo_focus(to)
	Audio.play("solo_swap")
	if _players.has(to):
		var z: Zapper = _players[to]
		z.wake()
		Fx.ring(get_tree(), z.global_position + Vector3(0, 1, 0), Players.COLOR[to], 1.2)


# ---------------------------------------------------------------------------------------- demo

func _start_demo() -> void:
	var beat := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo-beat="):
			beat = a.trim_prefix("--demo-beat=")
	if beat.begins_with("zone-"):
		_beat_zone(StringName(beat.trim_prefix("zone-")))
		return
	match beat:
		"combo": _beat_combo()
		"goal": _beat_goal()
		"rings": _beat_rings()
		"apart": _beat_apart()
		_:
			camera.overview = beat == "wide"
			for p in _players:
				var b := DemoBot.new(_players[p], 20261109 + p)
				_bots[p] = b
				add_child(b)
			if OS.get_cmdline_user_args().has("--soak"):   # scripts/tools/soak.gd
				var probe := SoakProbe.new()
				probe.level = level
				add_child(probe)


func _place(p: int, x: float, face: float) -> void:
	var z: Zapper = _players[p]
	z.global_position = Vector3(x, 0.1, 0)
	z.facing = face
	z.aim_dir = Vector2(face, 0.15).normalized()


## A giant bouncy balloon cow: Jeff grows it, Chuck makes it bouncy, Jeff balloons it.
func _beat_combo() -> void:
	var cow := level.object(&"cow")
	camera.focus = [cow]
	_place(Players.P1, 8.2, 1.0)
	_place(Players.P2, 17.5, -1.0)
	var steps := [
		[0.4, Players.P1, &"grow"], [0.8, Players.P1, &"grow"], [1.2, Players.P1, &"grow"],
		[1.7, Players.P2, &"bouncy"], [2.2, Players.P1, &"balloon"],
	]
	for s in steps:
		get_tree().create_timer(s[0]).timeout.connect(func() -> void:
			var z: Zapper = _players[s[1]]
			z.aim_dir = Vector2(cow.global_position.x - z.global_position.x, cow.global_position.y - z.global_position.y - 1.0).normalized()
			Effects.zap(s[2], cow)
			Audio.play("zap_%s" % s[2], cow.global_position)
			cow.speak()
			Fx.ring(get_tree(), cow.global_position, level.guns_by_effect.get(&"size" if s[2] == &"grow" else s[2], level.guns_by_effect[&"size"]).beam_color, cow.radius())
			z._flash())


## Art check: Jeff and Chuck standing in one zone (front_gate, scrap_heap, pond, barn, tower), guns up.
func _beat_zone(zone: StringName) -> void:
	var at := {&"front_gate": [-41.0, -36.5], &"scrap_heap": [-24.5, -15.0], &"pond": [-7.0, 10.6],
			&"barn": [14.0, 22.4], &"tower": [36.0, 45.0]}
	var xs: Array = at.get(zone, at[&"front_gate"])
	_place(Players.P1, xs[0], 1.0)
	_place(Players.P2, xs[1], -1.0)
	if zone == &"pond":
		(_players[Players.P1] as Zapper).global_position.y = 0.45   # on the dock


## A goal card completing: the cow is by the fence; Jeff makes it big; fireworks.
func _beat_goal() -> void:
	var cow := level.object(&"cow")
	cow.global_position = Vector3(-40.5, 1.0, 0)
	_place(Players.P1, -43.5, 1.0)
	_place(Players.P2, -36.0, -1.0)
	for t in [0.6, 1.0]:
		get_tree().create_timer(t).timeout.connect(func() -> void:
			Effects.zap(&"grow", cow)
			Audio.play("grow", cow.global_position)
			_players[Players.P1]._flash())


## Colour check: Jeff aims at a crate (green ring), Chuck aims at Jeff (a red ring round Jeff's body).
func _beat_rings() -> void:
	_place(Players.P1, -38.0, 1.0)
	_place(Players.P2, -35.0, -1.0)
	for o in level.objects.values():   # clear the ground between them so Chuck's beam finds Jeff
		var po := o as PhysicsObject
		if po and po.global_position.x > -39.5 and po.global_position.x < -33.0:
			po.global_position.x += 8.0
	var crate := level.object(&"crate")
	crate.global_position = Vector3(-41.0, 0.6, 0)
	(func() -> void:
		(_players[Players.P1] as Zapper).input_override = {"aim": Vector2.LEFT}
		(_players[Players.P2] as Zapper).input_override = {"aim": Vector2.LEFT}).call_deferred()


## The widest play zoom: Jeff at the gate, Chuck at the tower; the camera must not show under the table.
func _beat_apart() -> void:
	_place(Players.P1, YardLevel.LEFT + 3.0, 1.0)
	_place(Players.P2, YardLevel.RIGHT - 3.0, -1.0)
	for p in _players:
		(_players[p] as Zapper).input_override = {"aim": Vector2.UP}

