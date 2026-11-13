## Feel rule (Kaden, standing; audited 2026-11-13): "No stick-only requirement: buttons are fine
## anywhere, menus included." The D-pad moves the character in play, one test per pad slot, each
## pad only its own player; solo's pad moves the focused player with it; the pause menu's cursor
## takes it (MenuInput). Real pad events through Input (no input_override), so the InputMap is what
## is under test: project.godot binds the move actions to the stick and keys, Players.add_dpad()
## adds the D-pad at boot. Own settings and picks files, fixture roster.
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
var _clock := Clock.new()

const P1 := Players.P1
const P2 := Players.P2
const PAD_A := 0
const PAD_B := 1
const FIXTURE := "res://tests/fixtures/roster_two.json"

var world: Node3D
var _real_settings := ""
var _real_picks := ""
var _real_data := ""


func before() -> void:
	_clock.pin()
	Save.profile = "gdunit_dpad"
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_dpad.json"
	Save.wipe_settings()
	_real_data = Roster.data_path
	_real_picks = Roster.picks_path
	Roster.data_path = FIXTURE
	Roster.picks_path = "user://test_dpad_players.json"
	Roster.args_override = PackedStringArray(["--no-picks"])
	Roster.reload()


func after() -> void:
	_clock.restore()
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Roster.data_path = _real_data
	Roster.picks_path = _real_picks
	Roster.args_override = PackedStringArray()
	Roster.reload()


func before_test() -> void:
	Players.reset()
	Game.demo = false
	Game.start_round()
	world = Node3D.new()
	add_child(world)
	world.add_child(YardStrip.new())


func after_test() -> void:
	for d in [PAD_A, PAD_B]:
		for b in Players.DPAD.values():
			pad(d, b, false)
	get_tree().paused = false
	if Game.state != Game.State.PLAYING:
		Game.start_round()
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func pad(device: int, button: JoyButton, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


## A zapper reading the real input (no override), standing on the strip.
func zapper(player: int, x: float) -> Zapper:
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	z.player = player
	z.position = Vector3(x, 0.05, 0)
	world.add_child(z)
	return z


## Holds the button for frames, returns how far the zapper went in x.
func hold(z: Zapper, device: int, button: JoyButton, frames := 40) -> float:
	var x0 := z.global_position.x
	pad(device, button, true)
	await step(frames)
	pad(device, button, false)
	return z.global_position.x - x0


func test_every_move_action_has_its_dpad_button() -> void:
	for p in [P1, P2]:
		for a: String in Players.DPAD:
			var found := 0
			for ev in InputMap.action_get_events(Players.action(p, a)):
				if ev is InputEventJoypadButton and ev.button_index == Players.DPAD[a]:
					found += 1
			assert_int(found).override_failure_message("%s has no D-pad" % Players.action(p, a)).is_equal(1)
	Players.add_dpad()   # once only, however often it is called
	for ev_count in [InputMap.action_get_events("p1_move_left").filter(
			func(e: InputEvent) -> bool: return e is InputEventJoypadButton).size()]:
		assert_int(ev_count).is_equal(1)


## Pad slot 1: P1's pad. D-pad right walks P1 right, left walks back; P2 (on the other pad) stays.
func test_dpad_moves_p1_on_pad_slot_1() -> void:
	var a := zapper(P1, -6.0)
	var b := zapper(P2, 6.0)
	Players._assign(P1, PAD_A)
	Players._assign(P2, PAD_B)
	await step(10)
	var bx := b.global_position.x
	assert_float(await hold(a, PAD_A, JOY_BUTTON_DPAD_RIGHT)).is_greater(1.0)
	assert_float(await hold(a, PAD_A, JOY_BUTTON_DPAD_LEFT)).is_less(-1.0)
	assert_float(absf(b.global_position.x - bx)).is_less(0.05)


## Pad slot 2: P2's pad moves P2, and never P1.
func test_dpad_moves_p2_on_pad_slot_2() -> void:
	var a := zapper(P1, -6.0)
	var b := zapper(P2, 6.0)
	Players._assign(P1, PAD_A)
	Players._assign(P2, PAD_B)
	await step(10)
	var ax := a.global_position.x
	assert_float(await hold(b, PAD_B, JOY_BUTTON_DPAD_LEFT)).is_less(-1.0)
	assert_float(await hold(b, PAD_B, JOY_BUTTON_DPAD_RIGHT)).is_greater(1.0)
	assert_float(absf(a.global_position.x - ax)).is_less(0.05)


## D-pad up / down are the stick's up / down too (grow vs shrink, aim): the move vector reads them.
func test_dpad_up_and_down_read_as_the_stick() -> void:
	Players._assign(P1, PAD_A)
	pad(PAD_A, JOY_BUTTON_DPAD_DOWN, true)
	assert_float(Players.move_vector(P1).y).is_greater(0.5)
	pad(PAD_A, JOY_BUTTON_DPAD_DOWN, false)
	pad(PAD_A, JOY_BUTTON_DPAD_UP, true)
	assert_float(Players.move_vector(P1).y).is_less(-0.5)
	pad(PAD_A, JOY_BUTTON_DPAD_UP, false)


## Solo: the one pad's D-pad moves the focused player, then the other after the swap.
func test_solo_pad_dpad_moves_the_focused_player() -> void:
	var a := zapper(P1, -6.0)
	var b := zapper(P2, 6.0)
	Players._assign(P1, PAD_A)
	Players.set_solo(true, PAD_A)
	await step(10)
	var bx := b.global_position.x
	assert_float(await hold(a, PAD_A, JOY_BUTTON_DPAD_RIGHT)).is_greater(1.0)
	assert_float(absf(b.global_position.x - bx)).is_less(0.05)
	Players.set_solo_focus(P2)
	await step(40)   # P1 coasts to a stop from its own walk first
	var ax := a.global_position.x
	assert_float(await hold(b, PAD_A, JOY_BUTTON_DPAD_LEFT)).is_less(-1.0)
	assert_float(absf(a.global_position.x - ax)).is_less(0.05)


## The pause menu's cursor (MenuInput) moves on the D-pad, once per press (never twice in a frame).
func test_pause_menu_cursor_takes_the_dpad_once_per_press() -> void:
	Players._assign(P1, PAD_A)
	await get_tree().process_frame
	pad(PAD_A, JOY_BUTTON_DPAD_DOWN, true)
	var r: Dictionary = MenuInput.read()
	assert_int(r.move.y).is_equal(1)
	await get_tree().process_frame
	assert_int(MenuInput.read().move.y).is_equal(0)   # held, not a new press
	pad(PAD_A, JOY_BUTTON_DPAD_DOWN, false)
