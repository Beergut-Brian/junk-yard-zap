## Boot scene: the lobby (start screen and main menu) over the yard (its look, each player's pick on
## the podiums and the blurred yard behind, is data/menu_skin.tres), the picks in play (Roster; Jeff
## and Chuck by default, Zapper reads the pick at spawn), the shared
## camera, the HUD, the pause menu. There are no rounds: a session is however long you want, and
## the yard saves as you leave it (scripts/levels/yard_level.gd).
## Drop-in: whoever didn't ready in the lobby sleeps in the tire pile; any press of their pad (or a
## key from their keys) wakes them with a snort. Players who readied start awake.
## Solo (playtest): one pad drives the active player; LB + RB + Select (or Tab) swaps who that is.
## CLI (after --): --demo (bots play), --demo-beat=combo|goal|wide|rings|apart|chute|piano|fan|belt|hook|trampoline|delight|blame|idles|rattle|trophy|jump|jump-crate|reset-hold|sign-hold|bonk|cap|glue-snap|gags-<zone>|zone-<name> (staged
## shots), --soak (with --demo: stress + a log line every 30 s), --proto, --session-flow --flow-out=<dir>
## (scripts/tools/session_flow.gd on an export), --player-flow=<phase> (scripts/tools/player_flow.gd).
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
	# The scripted session (scripts/tools/session_flow.gd) on a release export, which takes no scene path.
	if OS.get_cmdline_user_args().has("--session-flow") and get_parent() == get_tree().root:
		get_tree().change_scene_to_file.call_deferred("res://scripts/tools/session_flow.tscn")
		return
	# The round card after the wipe (its title, "ZAP TIME!", is in data/menu_skin.tres).
	lobby.round_card_subtitle = "THE YARD IS OPEN"
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
	if FreshPreview.state_from_args(OS.get_cmdline_user_args()) != "":   # Start fresh screenshots
		add_child(FreshPreview.new())
	if PlayerFlowRun.phase_from_args(OS.get_cmdline_user_args()) != "":   # handoff/PLAYER-FLOW.md runs
		add_child(PlayerFlowRun.new())


func _on_lobby_ready(players: Array) -> void:
	_spawn_all(players)


func _on_round_started(_round: int) -> void:
	_spawn_all(Players.active_players())


func _spawn_all(awake: Array) -> void:
	for p in [Players.P1, Players.P2]:
		_spawn(p, not awake.has(p))
		if awake.has(p):
			_players[p].wake()


## A pad joined while playing: if that player is asleep in the tire pile, they wake up.
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
	z.zapped.connect(hud.on_zapped)   # PT10-2: the first-fire beat
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
		z.say("swap_in")   # "I'm in!" in the character's own voice (the gate keeps it to one line)


# ---------------------------------------------------------------------------------------- demo

func _start_demo() -> void:
	var beat := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--demo-beat="):
			beat = a.trim_prefix("--demo-beat=")
	if beat.begins_with("gags-"):
		_beat_gags(StringName(beat.trim_prefix("gags-")))
		return
	if beat.begins_with("zone-"):
		_beat_zone(StringName(beat.trim_prefix("zone-")))
		return
	match beat:
		"combo": _beat_combo()
		"goal": _beat_goal()
		"rings": _beat_rings()
		"apart": _beat_apart()
		"chute": _beat_chute()
		"piano": _beat_piano()
		"fan": _beat_fan()
		"belt": _beat_belt()
		"hook": _beat_hook()
		"trampoline": _beat_trampoline()
		"delight": _beat_delight()
		"blame": _beat_blame()
		"idles": _beat_idles()
		"rattle": _beat_rattle()
		"trophy": _beat_trophy()
		"jump": _beat_jump(false)
		"jump-crate": _beat_jump(true)
		"reset-hold": _beat_reset_hold()
		"sign-hold": _beat_sign_hold()
		"wheel": _beat_wheel()
		"beams": _beat_beams()
		"bonk": _beat_bonk()
		"cap": _beat_cap()
		"glue-snap": _beat_glue_snap()
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


## Vehicles and machines rattle instead of pulling a face: the scrap heap's car, TV, fridge and
## toaster get zapped in turn every 0.4 s, so any frame catches one mid-rattle.
func _beat_rattle() -> void:
	_beat_zone(&"scrap_heap")
	var ids := [&"car", &"tv", &"fridge", &"toaster"]
	for i in 12:
		get_tree().create_timer(1.0 + i * 0.4).timeout.connect(func() -> void:
			var o := level.object(ids[i % ids.size()])
			if o:
				o.react_look(ObjectFace.Mood.WIDE, 0.9)
				o.speak())


## Y-19: every faceless machine in the yard reacts at 1.0 s, 2.5 s and 4.0 s, so a frame ~0.35 s
## later catches the fridge door open, the toast up, the antennae mid-wobble (--demo-beat=gags-<zone>).
func _beat_gags(zone: StringName) -> void:
	_beat_zone(zone)
	for i in 3:
		get_tree().create_timer(1.0 + i * 1.5).timeout.connect(func() -> void:
			for o in get_tree().get_nodes_in_group(PhysicsObject.GROUP):
				var po := o as PhysicsObject
				if po and not po.data.has_face:
					po.react_look(ObjectFace.Mood.WIDE, 0.9))


## G-13: three cards done, then Jeff zaps the trophy shelf and the newest one flips up.
func _beat_trophy() -> void:
	_place(Players.P1, -42.5, -1.0)
	_place(Players.P2, -38.0, -1.0)
	camera.focus = [level.card.shelf]
	for i in 3:
		level.deck.complete()
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		level.card.shelf.zapped_by(_players[Players.P1], null)
		_players[Players.P1]._flash())


## PT10-1/2 (jyz-ui-1): both players flick the belt (wheel + switch preview), then Jeff fires his new
## gun at the cow for the first time (the first-fire beat). Shots at ~1.7 s (wheel), ~2.8 s (preview) and ~3.7 s (beat).
func _beat_wheel() -> void:
	var cow := level.object(&"cow")
	cow.global_position = Vector3(-34.0, 1.0, 0)
	_place(Players.P1, -37.5, 1.0)   # clear of the Reset Yard sign (A there holds the reset)
	_place(Players.P2, -29.5, -1.0)
	camera.focus = [cow]
	for t in [1.2, 1.45]:
		get_tree().create_timer(t).timeout.connect(func() -> void:
			var z: Zapper = _players[Players.P1]
			z.set_gun(z.gun_index + 1))
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		var z: Zapper = _players[Players.P2]
		z.set_gun(z.gun_index + 4))
	get_tree().create_timer(3.4).timeout.connect(func() -> void:
		var z: Zapper = _players[Players.P1]
		z.aim_dir = Vector2(1, 0.05).normalized()
		z._update_target()
		z._press())


## PT10-2: every gun's beam and hit, one after another. Jeff fires each of the seven guns at the
## crate, 0.7 s apart from 1.0 s (size, grab, bouncy, balloon, freeze, glue, magnet); Chuck aims his
## freeze beam at the tire so two patterns show at once.
func _beat_beams() -> void:
	var crate := level.object(&"crate")
	crate.global_position = Vector3(-33.5, 0.6, 0)
	var tire := level.object(&"tire")
	tire.global_position = Vector3(-30.0, 0.6, 0)
	_place(Players.P1, -37.0, 1.0)
	_place(Players.P2, -26.5, -1.0)
	camera.focus = [crate, tire]
	(_players[Players.P2] as Zapper).set_gun(4, false)
	for i in 7:
		get_tree().create_timer(1.0 + i * 0.7).timeout.connect(func() -> void:
			var z: Zapper = _players[Players.P1]
			z.set_gun(i)
			z.aim_dir = Vector2(1, 0.05).normalized()
			z._update_target()
			if i == 5 and z.target:   # glue needs a first pick: stick the crate to the tire
				z._press()
				z.target = tire
			if z.target:
				z._press())


## Y-20: a grow that something stops shows what stopped it. A plank frozen just over the crate;
## Jeff grows the crate at 1.2 s; it bumps the plank and a bonk star pops there at ~1.9 s.
func _beat_bonk() -> void:
	var crate := level.object(&"crate")
	crate.global_position = Vector3(-33.5, 0.5, 0)
	var plank := level.object(&"plank")
	plank.global_position = Vector3(-33.5, 1.3, 0)
	plank.rotation = Vector3.ZERO
	Effects.zap(&"freeze", plank)
	_place(Players.P1, -37.0, 1.0)
	_place(Players.P2, -29.0, -1.0)
	camera.focus = [crate]
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		var z: Zapper = _players[Players.P1]
		z.set_gun(0, false)
		z.target = crate
		z._press())


## Y-21: the size ladder and its cap. The cow starts at +3; Jeff grows it to +4 at 2.0 s (ladder
## full) and tries once more at 2.8 s: the end square blinks and a stop bar shows.
func _beat_cap() -> void:
	var cow := level.object(&"cow")
	cow.global_position = Vector3(-33.0, 1.0, 0)
	for i in 3:
		Effects.zap(&"grow", cow)
	_place(Players.P1, -39.0, 1.0)
	_place(Players.P2, -26.0, -1.0)
	camera.focus = [cow]
	for t in [2.0, 2.8]:
		get_tree().create_timer(t).timeout.connect(func() -> void:
			var z: Zapper = _players[Players.P1]
			z.set_gun(0, false)
			z.target = cow
			z._press())


## Y-22: glue that can't meet. A fridge frozen between two crates; Jeff glues them at 1.0 s; the
## pink string stretches round it, shivers, and snaps at ~4.0 s.
func _beat_glue_snap() -> void:
	var a := level.object(&"crate")
	var b := level.object(&"crate_2")
	var wall := level.object(&"fridge")
	a.global_position = Vector3(-35.6, 0.5, 0)
	b.global_position = Vector3(-31.4, 0.5, 0)
	wall.global_position = Vector3(-33.5, 0.9, 0)
	wall.rotation = Vector3.ZERO
	Effects.zap(&"freeze", wall)
	_place(Players.P1, -39.0, 1.0)
	_place(Players.P2, -28.0, -1.0)
	camera.focus = [a, b]
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		var z: Zapper = _players[Players.P1]
		z.set_gun(5, false)
		z.target = a
		z._press()
		z.target = b
		z._press())


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


## K-08: the bathtub flies off the map and floats back down at the gate under a parachute.
func _beat_chute() -> void:
	_place(Players.P1, -41.5, 1.0)
	_place(Players.P2, -32.5, -1.0)
	var tub := level.object(&"bathtub")
	camera.focus = [tub]
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		tub.global_position = Vector3(YardLevel.LEFT - 20.0, 5.0, 0))


## A-13: the piano drops from the loft height and lands with its chord.
func _beat_piano() -> void:
	var piano := level.object(&"piano")
	_place(Players.P1, 10.0, 1.0)
	_place(Players.P2, 15.0, -1.0)
	piano.global_position = Vector3(12.5, 6.0, 0)
	piano.linear_velocity = Vector3.ZERO
	camera.focus = [piano]


## Y-10: Jeff on the top deck zaps the fan on; the kite blows off the tower.
func _beat_fan() -> void:
	var c := level.contraptions
	_place(Players.P1, 42.8, -1.0)
	(_players[Players.P1] as Zapper).global_position.y = 9.3
	_place(Players.P2, 36.0, 1.0)
	camera.focus = [c.fan, level.object(&"kite")]
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		Audio.play("zap_bouncy", c.fan.global_position)
		Fx.ring(get_tree(), c.fan.global_position, Color(1, 0.85, 0.3), 1.1)
		c.fan.zapped_by(_players[Players.P1], null))


## Y-05: Chuck zaps the belt button; the belt carries the car toward the gate.
func _beat_belt() -> void:
	var c := level.contraptions
	_place(Players.P1, -31.5, 1.0)
	_place(Players.P2, -23.2, -1.0)
	camera.focus = [level.object(&"car"), c.button]
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		Audio.play("zap_glue", c.button.global_position)
		c.button.zapped_by(_players[Players.P2], null))


## Y-04: Jeff grabs the crane hook and swings it onto the chicken; the rope lifts the chicken.
func _beat_hook() -> void:
	var c := level.contraptions
	var chicken := level.object(&"chicken")
	for o in level.objects.values():   # just the chicken under the crane
		if o != chicken and absf(o.global_position.x + 17.8) < 3.0:
			o.global_position.x -= 9.0
	chicken.global_position = Vector3(-17.8, 0.3, 0)
	_place(Players.P1, -15.6, -1.0)
	_place(Players.P2, -21.0, 1.0)
	camera.focus = [c.hook, chicken]
	var z: Zapper = _players[Players.P1]
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		z.set_gun(1, false)
		z.aim_dir = Vector2(-0.6, 0.8).normalized()
		if Effects.grab(c.hook, z, Players.COLOR[Players.P1]):
			z.held = c.hook
			Audio.play("grab", c.hook.global_position))
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		z._let_go(false)
		c.hook.global_position = chicken.global_position + Vector3(0, 0.55, 0))


## Y-08: the ball drops onto the barn trampoline and Chuck bounces beside it.
func _beat_trampoline() -> void:
	var t := level.contraptions.trampoline
	for o in level.objects.values():
		if absf(o.global_position.x - t.global_position.x) < 2.0:
			o.global_position.x -= 3.0
	_place(Players.P1, 9.6, 1.0)
	_place(Players.P2, t.global_position.x + 0.3, -1.0)
	(_players[Players.P2] as Zapper).global_position.y = 3.0
	var ball := level.object(&"ball")
	ball.global_position = t.global_position + Vector3(-0.5, 5.0, 0)
	camera.focus = [t, ball]


## Space between the two players by the gate: everything else in x0..x1 moves off a little.
func _clear(x0: float, x1: float) -> void:
	for o in level.objects.values():
		var po := o as PhysicsObject
		if po and po.global_position.x > x0 and po.global_position.x < x1:
			po.global_position.x = x1 + 2.0 + randf() * 3.0


## P-05 / A-12: a big anvil lands between them. Jeff claps and hops (delight); Chuck wobbles.
func _beat_delight() -> void:
	_clear(-39.0, -31.0)
	_place(Players.P1, -37.2, 1.0)
	_place(Players.P2, -32.8, -1.0)
	var anvil := level.object(&"anvil")
	Effects.zap(&"grow", anvil)
	anvil.global_position = Vector3(-35.0, 11.0, 0)
	anvil.linear_velocity = Vector3.ZERO
	camera.focus = [anvil]
	(func() -> void:   # aim up, so no aim ring sits over the landing
		for p in _players:
			(_players[p] as Zapper).input_override = {"aim": Vector2.UP}).call_deferred()


## P-06: Chuck zaps the crate bouncy and takes the credit (puffs up); then his size zap on a giant
## crate is refused and he turns on Jeff (a ring in Jeff's green round him).
func _beat_blame() -> void:
	_clear(-41.0, -29.0)
	_place(Players.P1, -41.0, 1.0)
	_place(Players.P2, -30.2, -1.0)
	var crate := level.object(&"crate")
	crate.global_position = Vector3(-35.6, 0.6, 0)
	var chuck: Zapper = _players[Players.P2]
	var press := func(gun: StringName) -> void:
		for i in chuck.guns.size():
			if chuck.guns[i].id == gun:
				chuck.set_gun(i, false)
		chuck.input_override = {"action": true, "aim": Vector2.LEFT}
		get_tree().create_timer(0.1).timeout.connect(func() -> void: chuck.input_override = {"aim": Vector2.LEFT})
	(func() -> void: chuck.input_override = {"aim": Vector2.LEFT}).call_deferred()
	get_tree().create_timer(0.5).timeout.connect(press.bind(&"bouncy"))
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		for i in 4:
			Effects.zap(&"grow", crate))   # as big as it goes: the next grow is a "nope"
	get_tree().create_timer(3.4).timeout.connect(press.bind(&"size"))


## P-07: Jeff pokes the crate and hums; Chuck kicks the tire and checks his hat.
func _beat_idles() -> void:
	_clear(-40.0, -30.0)
	_place(Players.P1, -38.0, 1.0)
	_place(Players.P2, -32.0, -1.0)
	level.object(&"crate").global_position = Vector3(-36.7, 0.6, 0)
	level.object(&"tire").global_position = Vector3(-30.8, 0.5, 0)
	var jeff: Zapper = _players[Players.P1]
	var chuck: Zapper = _players[Players.P2]
	get_tree().create_timer(0.6).timeout.connect(func() -> void:
		jeff.reactions.do_bit("poke")
		chuck.reactions.do_bit("kick_tire"))
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		jeff.reactions.do_bit("hum")
		chuck.reactions.do_bit("check_hat"))


## PT10-5: side by side, at 1.0 s Jeff taps B (a short hop) and Chuck holds it (the full, capped
## jump). jump-crate: the same off two crates, so it works on objects.
func _beat_jump(on_crates: bool) -> void:
	_clear(-36.0, -24.0)
	var xs := [-31.5, -28.5]
	camera.focus = []
	for i in 2:
		var p: int = [Players.P1, Players.P2][i]
		var z: Zapper = _players[p]
		_place(p, xs[i], 1.0 if i == 0 else -1.0)
		z.input_override = {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}
		camera.focus.append(z)
	if on_crates:
		for i in 2:
			var c := level.object([&"crate", &"crate_2"][i])
			if c:
				c.global_position = Vector3(xs[i], 0.6, 0)
				(_players[[Players.P1, Players.P2][i]] as Zapper).global_position.y = 1.4
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		for p in [Players.P1, Players.P2]:
			(_players[p] as Zapper).input_override["jump"] = true)
	get_tree().create_timer(1.04).timeout.connect(func() -> void:
		(_players[Players.P1] as Zapper).input_override["jump"] = false)
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		(_players[Players.P2] as Zapper).input_override["jump"] = false)


## PT10-4: Jeff holds Select by the tire pile; the ring by him fills for 1.5 s, then the yard resets.
func _beat_reset_hold() -> void:
	_place(Players.P1, -37.0, 1.0)
	_place(Players.P2, -33.0, -1.0)
	var jeff: Zapper = _players[Players.P1]
	jeff.input_override = {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false, "reset": false}
	get_tree().create_timer(0.5).timeout.connect(func() -> void: jeff.input_override["reset"] = true)
	get_tree().create_timer(3.0).timeout.connect(func() -> void: jeff.input_override["reset"] = false)


## PT10-4: the big lit sign with Jeff holding A on it (its own ring and racing bulbs).
func _beat_sign_hold() -> void:
	_place(Players.P1, -42.0, 1.0)
	_place(Players.P2, -36.0, -1.0)
	var jeff: Zapper = _players[Players.P1]
	jeff.input_override = {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}
	get_tree().create_timer(0.6).timeout.connect(func() -> void: jeff.input_override["action"] = true)
