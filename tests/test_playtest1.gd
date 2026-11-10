## Playtest #1 readiness: P1 = Jeff = green and P2 = Chuck = red everywhere, the partner aim ring
## sits on the partner's body (not at his feet, where it read as a ring in the wrong colour), the
## mouse pointer stays hidden in play, and the camera never looks under the table.
class_name TestPlaytest1
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const GREEN := Color("3cc24a")
const RED := Color("e4393c")
const IDLE := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}

var world: Node3D
var _real_settings := ""


func before() -> void:
	Save.profile = "gdunit"
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_playtest1.json"
	Save.wipe_settings()


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()


func before_test() -> void:
	Players.reset()
	Game.demo = false
	Game.start_round()
	world = Node3D.new()
	add_child(world)
	world.add_child(YardStrip.new())


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func zapper(player: int, x: float) -> Zapper:
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	z.player = player
	z.position = Vector3(x, 0.05, 0)
	world.add_child(z)
	z.input_override = IDLE.duplicate()
	return z


func _tape_color(z: Zapper) -> Color:
	var tape := z.rig.find_child("tape", true, false) as MeshInstance3D
	assert_object(tape).is_not_null()
	return (tape.material_override as StandardMaterial3D).albedo_color


func test_p1_is_jeff_and_green_p2_is_chuck_and_red() -> void:
	assert_that(Players.COLOR[P1]).is_equal(GREEN)
	assert_that(Players.COLOR[P2]).is_equal(RED)
	var jeff := zapper(P1, -3.0)
	var chuck := zapper(P2, 3.0)
	await step(3)
	assert_str(String(jeff.rig.character)).is_equal("jeff")
	assert_str(String(chuck.rig.character)).is_equal("chuck")
	# Gun tape, aim ring.
	assert_that(_tape_color(jeff)).is_equal(GREEN)
	assert_that(_tape_color(chuck)).is_equal(RED)
	assert_that((jeff._marker.material_override as StandardMaterial3D).albedo_color).is_equal(GREEN)
	assert_that((chuck._marker.material_override as StandardMaterial3D).albedo_color).is_equal(RED)
	# The gun survives a belt cycle with the right tape.
	chuck.set_gun(3)
	await step(2)
	assert_that(_tape_color(chuck)).is_equal(RED)
	# Grab glow in the grabber's colour.
	var o := PhysicsObject.new(ObjectData.make(&"box", ObjectData.Shape.BOX, Vector3.ONE * 0.6, 1.0, Color.TAN))
	o.position = Vector3(4.5, 0.5, 0)
	world.add_child(o)
	await step(2)
	var g := Effects.grab(o, chuck, Players.COLOR[chuck.player])
	assert_that(g.color).is_equal(RED)


## The cause of "a red ring under Jeff": Chuck's aim ring snapped to Jeff and was drawn at his
## feet (a Zapper's origin), where it looked like Jeff's own player ring. It now circles his body.
func test_partner_aim_ring_circles_the_partner_not_his_feet() -> void:
	var jeff := zapper(P1, -1.5)
	var chuck := zapper(P2, 1.5)
	await step(10)
	chuck.input_override = IDLE.merged({"aim": Vector2.LEFT}, true)
	await step(3)
	assert_object(chuck.target).is_same(jeff)
	assert_bool(chuck._marker.visible).is_true()
	var feet := jeff.global_position
	assert_float(chuck._marker.global_position.y - feet.y).is_greater(Zapper.HEIGHT * 0.35)
	assert_float(chuck._marker.global_position.x).is_equal_approx(feet.x, 0.01)
	# Big enough to go round him: reads as "aimed at", never as a ring on the floor.
	assert_float(chuck._marker.scale.x).is_greater_equal(Zapper.HEIGHT * 0.5)


func test_a_sleeping_partner_is_not_a_target() -> void:
	var jeff := zapper(P1, -1.5)
	var chuck := zapper(P2, 1.5)
	chuck.set_asleep(true)
	await step(5)
	assert_bool(jeff.candidates().has(chuck)).is_false()
	chuck.wake()
	assert_bool(jeff.candidates().has(chuck)).is_true()


func test_mouse_pointer_hidden_in_play_shown_only_after_mouse_use_in_menus() -> void:
	assert_bool(Cursor.should_show(Game.State.PLAYING, true)).is_false()
	assert_bool(Cursor.should_show(Game.State.PLAYING, false)).is_false()
	assert_bool(Cursor.should_show(Game.State.LOBBY, false)).is_false()
	assert_bool(Cursor.should_show(Game.State.PAUSED, true)).is_true()
	assert_bool(Cursor.should_show(Game.State.LOBBY, true)).is_true()
	var c := Cursor.new()
	world.add_child(c)
	var mm := InputEventMouseMotion.new()
	c._input(mm)
	assert_bool(c.mouse_recent).is_true()
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	c._input(pad)
	assert_bool(c.mouse_recent).is_false()


## The wide shots and the widest play zoom: the bottom of the frame lands on the table apron.
func test_camera_never_looks_under_the_table() -> void:
	var cam := CameraRig.new()
	world.add_child(cam)
	await step(1)
	var tilt := deg_to_rad(CameraRig.LOOK_DOWN + cam.fov * 0.5)
	for ov in [true, false]:
		cam.overview = ov
		var jeff := zapper(P1, YardLevel.LEFT + 2.0)
		var chuck := zapper(P2, YardLevel.RIGHT - 2.0)   # as far apart as they can be
		await step(2)
		var p := cam.goal_position()
		var bottom := p.y - (p.z - YardDressing.TABLE_FRONT_Z) * tan(tilt)
		assert_float(bottom).override_failure_message("overview=%s bottom %.2f" % [ov, bottom]) \
				.is_greater_equal(YardDressing.APRON_BOTTOM)
		jeff.free()
		chuck.free()


# ------------------------------------------------------------------------- first-playable audit

func level() -> YardLevel:
	world.get_child(0).free()   # the strip: the level has its own ground
	var l := YardLevel.new()
	l.use_save = false
	l.layout = load(YardLevel.LAYOUT)
	world.add_child(l)
	var players := Node3D.new()
	players.name = "Players"
	l.add_child(players)
	return l


func _props(o: PhysicsObject) -> Array:
	return [snappedf(o.mass, 0.001), o.effective_gravity_scale, o.physics_material_override.bounce,
			o.physics_material_override.friction, o.freeze, o.target_scale, o.linear_damp, o.angular_damp]


## GAME.md first playable: ten objects, every effect stacking and undoing cleanly.
func test_ten_objects_stack_every_effect_and_undo_cleanly() -> void:
	var l := level()
	var hand := zapper(P1, -30.0)
	await step(30)
	var keys := [&"cow", &"car", &"bathtub", &"ball", &"duck", &"piano", &"fridge", &"crate", &"tire", &"chicken"]
	var before := {}
	for k in keys:
		var o := l.object(k)
		assert_object(o).override_failure_message("%s missing" % k).is_not_null()
		before[k] = _props(o)
	for k in keys:
		var o := l.object(k)
		var mate := l.object(&"crate_2") if k != &"crate_2" else l.object(&"crate")
		Effects.zap(&"grow", o)
		await step(30)
		for e in [&"bouncy", &"balloon", &"magnet", &"freeze"]:
			assert_bool(Effects.zap(e, o)).override_failure_message("%s %s on" % [k, e]).is_true()
		var g := Effects.glue(o, mate)
		var grab := Effects.grab(o, hand, Players.COLOR[P1])
		await step(5)
		for e in [&"bouncy", &"balloon", &"magnet", &"freeze"]:
			assert_bool(o.stack.has(e)).override_failure_message("%s %s stacked" % [k, e]).is_true()
		# Undo in a different order than applied.
		if grab:
			Effects.release(o)
		if g:
			g.undo(null)
		for e in [&"freeze", &"magnet", &"bouncy", &"balloon"]:
			if o.stack.has(e):
				Effects.zap(e, o)
		var sz: Effects.Size = o.stack.get_effect(&"size")
		if sz:
			for i in absi(sz.steps):
				Effects.zap(&"shrink" if sz.steps > 0 else &"grow", o)
		await step(40)
		assert_int(o.stack.effects.size()).override_failure_message("%s left %s" % [k, o.stack.effects]).is_equal(0)
		assert_array(_props(o)).override_failure_message("%s props" % k).is_equal(before[k])


func test_balloon_parks_in_reach_and_a_reload_keeps_it_there() -> void:
	var l := level()
	var duck := l.object(&"duck")
	duck.global_position = Vector3(30.0, 1.0, 0)
	await step(30)
	var y0 := duck.global_position.y
	Effects.zap(&"balloon", duck)
	await step(60 * 8)
	var b: Effects.Balloon = duck.stack.get_effect(&"balloon")
	assert_bool(b.parked).is_true()
	var y1 := duck.global_position.y
	assert_float(y1 - y0).is_between(Effects.Balloon.MAX_RISE - 0.5, Effects.Balloon.MAX_RISE + 1.5)
	var saved := l.to_save()
	l.free()
	var l2 := YardLevel.new()
	l2.use_save = false
	l2.layout = load(YardLevel.LAYOUT)
	world.add_child(l2)
	await step(5)
	l2.from_save(saved)
	await step(60 * 4)
	var d2 := l2.object(&"duck")
	assert_bool(d2.stack.has(&"balloon")).is_true()
	assert_float(d2.global_position.y).is_between(y1 - 0.5, y1 + 0.5)


func test_objects_leaving_the_yard_come_back_at_the_gate() -> void:
	var l := level()
	await step(5)
	var ball := l.object(&"ball")
	ball.global_position = Vector3(YardLevel.RIGHT + 30.0, 5.0, 0)
	await step(3)
	assert_float(ball.global_position.distance_to(Yard.GATE)).is_less(1.5)
	assert_bool(Yard.in_bounds(ball.global_position)).is_true()


func test_giant_and_tiny_caps_hold() -> void:
	var l := level()
	var cow := l.object(&"cow")
	cow.global_position = Vector3(30.0, 2.0, 0)
	await step(10)
	for i in 10:
		Effects.zap(&"grow", cow)
		await step(45)
	var s: Effects.Size = cow.stack.get_effect(&"size")
	assert_int(s.steps).is_less_equal(4)
	assert_int(s.steps).is_less_equal(cow.data.max_step)
	for i in 20:
		Effects.zap(&"shrink", cow)
		await step(20)
	s = cow.stack.get_effect(&"size")
	assert_int(s.steps).is_greater_equal(-4)
	assert_int(s.steps).is_equal(cow.data.min_step)
	assert_float(cow.radius()).is_greater(0.1)   # tiny, never vanished


func test_both_players_walk_and_jump() -> void:
	for p in [P1, P2]:
		var z := zapper(p, 0.0 if p == P1 else 4.0)
		await step(15)
		var x0 := z.global_position.x
		z.input_override = IDLE.merged({"move": Vector2.RIGHT}, true)
		await step(30)
		assert_float(z.global_position.x - x0).is_greater(1.0)
		z.input_override = IDLE.merged({"jump": true}, true)
		var top := z.global_position.y
		for i in 30:
			await step(1)
			top = maxf(top, z.global_position.y)
		assert_float(top - 0.05).is_greater(1.0)
		assert_bool(Audio.played("jump")).is_true()
		z.free()


## A whole evening in the real main scene: hold A to start alone, Chuck drops in, pause, resume,
## restart to the lobby, both ready, a pad drops out and back in, solo on with the keyboard and a
## Tab swap, quit. Never two Jeffs, never a stuck pause, the pointer hidden whenever we play.
func test_a_whole_session_loops_cleanly_in_the_main_scene() -> void:
	const Lobby := preload("res://scenes/ui/lobby.gd")
	const PauseMenu := preload("res://scenes/ui/pause_menu.gd")
	Game.quit_exits = false
	Game._set_state(Game.State.LOBBY)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await step(2)
	var lobby: Lobby = main.get_node("UI/Lobby")
	var finish := func() -> void: lobby.count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	var players_root: Node = main.get_node("Arena/Players")
	Players.join_virtual(P1)
	assert_bool(lobby.hold_step(P1, true, Lobby.HOLD_TO_START)).is_true()
	finish.call()
	await step(2)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	var cursor: Cursor = main.get_node("Cursor")
	assert_bool(Cursor.should_show(Game.state, cursor.mouse_recent)).is_false()
	if DisplayServer.get_name() != "headless":   # headless always reports VISIBLE
		assert_int(Input.mouse_mode).is_equal(Input.MOUSE_MODE_HIDDEN)
	Players.join_virtual(P2)   # drop-in
	assert_bool(main.zapper(P2).asleep).is_false()
	for i in 3:
		Game.pause()
		assert_bool(get_tree().paused).is_true()
		Game.resume()
		assert_bool(get_tree().paused).is_false()
		await step(2)
	Game.pause()
	(main.get_node("UI/PauseMenu") as PauseMenu).press(PauseMenu.Choice.RESTART)
	await step(2)
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_int(players_root.get_child_count()).is_equal(0)
	lobby.press_a(P1)
	lobby.press_a(P2)
	finish.call()
	await step(2)
	assert_int(players_root.get_child_count()).is_equal(2)
	var seen := {}
	for z in players_root.get_children():
		seen[(z as Zapper).player] = true
	assert_int(seen.size()).is_equal(2)
	# A pad drops out: Chuck back to sleep; it comes back: awake.
	Players.player_left.emit(P2)
	assert_bool(main.zapper(P2).asleep).is_true()
	Players.player_joined.emit(P2, Players.VIRTUAL)
	assert_bool(main.zapper(P2).asleep).is_false()
	# Keyboard solo: both players' keys drive the active one; Tab swaps.
	Players.reset()
	Players.set_solo(true)
	var keys_on := func(p: int) -> int:
		return InputMap.action_get_events(Players.action(p, "move_right")).filter(
				func(e: InputEvent) -> bool: return e is InputEventKey).size()
	assert_int(keys_on.call(P1)).is_greater_equal(2)
	assert_int(keys_on.call(P2)).is_equal(0)
	var tab := InputEventKey.new()
	tab.pressed = true
	tab.physical_keycode = KEY_TAB
	main._input(tab)
	assert_int(Players.solo_focus).is_equal(P2)
	assert_int(keys_on.call(P2)).is_greater_equal(2)
	assert_int(keys_on.call(P1)).is_equal(0)
	Players.set_solo(false)
	Game.quit()
	assert_int(Players.active_players().size()).is_greater_equal(1)
	main.free()
	Game.quit_exits = true
	Game._set_state(Game.State.LOBBY)


## Holding A for a long grab next to the sign doesn't wipe the yard; letting go clears the ring.
func test_a_long_grab_hold_by_the_sign_does_not_reset() -> void:
	var l := level()
	var z := zapper(P1, l.reset_sign.global_position.x + 1.0)
	l.register_zapper(z)
	await step(5)
	z.input_override = IDLE.merged({"action": true}, true)
	await step(90)   # 1.5 s
	assert_int(l.resets).is_equal(0)
	z.input_override = IDLE.duplicate()
	await step(3)
	assert_float(l.reset_progress()).is_equal(0.0)
	assert_int(l.resets).is_equal(0)
