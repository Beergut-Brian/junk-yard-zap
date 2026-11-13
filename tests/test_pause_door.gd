## The pause menu's big door icon back to Open Jar (adopted from the template's pause door): it is
## in the scene (IconButton, 128 px, 140 px focused, the words beneath), it takes the focus, A asks
## first (then Game.quit, saved first), B resumes, and the d-pad (read through MenuInput) reaches it.
## Boots main.tscn with real pad events. Own profile, settings and picks files, never the real ones.
class_name TestPauseDoor
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")

var _main: Node
var _quits := 0
var _real_settings := ""
var _real_picks := ""
var _real_profile := ""


func before() -> void:
	_real_profile = Save.profile
	Save.profile = "gdunit_pause_door"   # main.tscn saves the yard: never the family's profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_pause_door.json"
	_real_picks = Roster.picks_path
	Roster.picks_path = "user://test_pause_door_players.json"
	Roster.reload()
	Game.quit_exits = false
	Game.quit_requested.connect(_on_quit)


func after() -> void:
	Game.quit_requested.disconnect(_on_quit)
	Game.quit_exits = true
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	DirAccess.remove_absolute(Roster.picks_path)
	Roster.picks_path = _real_picks
	Roster.reload()
	Save.profile = _real_profile


func before_test() -> void:
	Save.wipe_settings()
	Save.replace({})
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	_quits = 0


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Players.reset()
	Game.demo = false
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	Yard.reset_world()


func _on_quit() -> void:
	_quits += 1


func _pad(device: int, button: JoyButton) -> void:
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = button
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await await_idle_frame()


## Two real pads (5 and 6) join, the round starts, P1 pauses.
func _playing_with_pads() -> PauseMenu:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _pad(5, JOY_BUTTON_A)
	await _pad(6, JOY_BUTTON_A)
	var lobby: Lobby = _main.get_node("UI/Lobby")
	assert_int(Players.device_of(P1)).is_equal(5)
	assert_int(Players.device_of(P2)).is_equal(6)
	lobby.count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	Game.pause()
	await await_idle_frame()
	return _main.get_node("UI/PauseMenu")


func _door(pm: Node) -> IconButton:
	return pm.get_node("Card/Door/Icon")


func _to_door(pm: PauseMenu) -> void:
	for i in 4:   # Resume, Reset Yard, Main Menu, Settings, door
		pm.move_focus(1)


func test_door_icon_is_in_the_pause_scene() -> void:
	var pm: Node = auto_free(load("res://scenes/ui/pause_menu.tscn").instantiate())
	var door: Node = pm.get_node_or_null("Card/Door/Icon")
	assert_object(door).is_instanceof(IconButton)
	var icon := door as IconButton
	assert_int(icon.icon).is_equal(IconButton.Icon.DOOR)
	assert_vector(icon.size).is_equal(Vector2(128, 128))
	assert_float(icon.size.x * icon.focus_scale).is_equal_approx(140.0, 0.01)
	var label: Label = pm.get_node("Card/Door/Label")
	assert_str(label.text).is_equal("Back to Open Jar")
	# Beneath the icon, centred under it, and still on screen.
	assert_float(label.position.y).is_greater(icon.position.y + 128.0)
	assert_float(label.position.x + label.size.x * 0.5).is_equal_approx(icon.position.x + 64.0, 1.0)
	var door_box: Control = pm.get_node("Card/Door")
	assert_float(door_box.position.y + label.position.y + label.size.y).is_less_equal(1080.0)
	# The old text bar is gone: the door is the only way back to Open Jar.
	assert_object(pm.get_node_or_null("Card/Buttons/Door")).is_null()


func test_door_wears_this_games_accent() -> void:
	var pm := await _playing_with_pads()
	assert_object(_door(pm).tint).is_equal(UiStyle.accent)


func test_door_icon_takes_the_focus() -> void:
	var pm := await _playing_with_pads()
	var door := _door(pm)
	assert_bool(door.focused).is_false()
	_to_door(pm)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.DOOR)
	assert_bool(door.focused).is_true()
	pm.move_focus(1)   # bumps the end: stays on the door
	assert_int(pm.focus).is_equal(PauseMenu.Choice.DOOR)
	pm.move_focus(-1)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.SETTINGS)
	assert_bool(door.focused).is_false()


func test_dpad_reaches_the_door() -> void:
	var pm := await _playing_with_pads()
	assert_int(pm.focus).is_equal(PauseMenu.Choice.RESUME)
	await _pad(5, JOY_BUTTON_DPAD_DOWN)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.RESET)
	await _pad(6, JOY_BUTTON_DPAD_DOWN)   # either pad
	assert_int(pm.focus).is_equal(PauseMenu.Choice.RESTART)
	await _pad(5, JOY_BUTTON_DPAD_DOWN)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.SETTINGS)
	await _pad(5, JOY_BUTTON_DPAD_DOWN)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.DOOR)
	assert_bool(_door(pm).focused).is_true()
	await _pad(6, JOY_BUTTON_DPAD_UP)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.SETTINGS)


func test_a_on_the_door_asks_first_then_quits_saved() -> void:
	var pm := await _playing_with_pads()
	Save.set_value("pause_door_quit", 1)
	_to_door(pm)
	await _pad(5, JOY_BUTTON_A)
	var confirm: ConfirmDialog = pm.get_node("Confirm")
	assert_bool(confirm.active).is_true()
	assert_int(_quits).is_equal(0)
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	await _pad(5, JOY_BUTTON_B)   # B in the question: stay
	assert_bool(confirm.active).is_false()
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	assert_int(_quits).is_equal(0)
	await _pad(5, JOY_BUTTON_A)   # ask again, then leave
	assert_bool(confirm.active).is_true()
	confirm.choose(true)
	assert_int(_quits).is_equal(1)
	assert_bool(Save._dirty).is_false()   # Game.quit saved first


func test_b_on_the_door_resumes() -> void:
	var pm := await _playing_with_pads()
	_to_door(pm)
	await _pad(6, JOY_BUTTON_B)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_bool(get_tree().paused).is_false()
	assert_bool(pm.visible).is_false()
	assert_int(_quits).is_equal(0)
