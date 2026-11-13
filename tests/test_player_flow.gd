## Player-flow lane (jyz-player-flow-1, handoff/PLAYER-FLOW.md): the fails found by playing the export
## as a new and a returning player. PF-1 a second pad joins out of solo; PF-2 a zap saves the yard
## within seconds. Own save profile, settings and picks files: never the family's.
class_name TestPlayerFlow
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const PAD_A := 30   # synthetic device ids, never a real pad's
const PAD_B := 31

var world: Node3D
var _real_settings := ""
var _real_profile := ""
var _real_picks := ""


func before() -> void:
	_real_profile = Save.profile
	Save.profile = "gdunit_player_flow"
	Save.wipe()
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_player_flow.json"
	Save.wipe_settings()
	_real_picks = Roster.picks_path
	Roster.picks_path = "user://test_player_flow_players.json"


func after() -> void:
	Save.wipe()
	Save.profile = _real_profile
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Roster.picks_path))
	Roster.picks_path = _real_picks


func before_test() -> void:
	Players.reset()
	Game.demo = false
	Audio.history.clear()
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()
	Game.to_lobby()
	get_tree().paused = false


func _press(device: int, button: JoyButton) -> void:
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = button
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await get_tree().process_frame


# PF-1: one pad playing solo (Select + Start), a second pad presses A: it gets P2, solo ends.
func test_a_second_pad_takes_p2_out_of_solo() -> void:
	Players._assign(P1, PAD_A)
	Players.set_solo(true, PAD_A)
	assert_bool(Players.solo).is_true()
	Audio.history.clear()
	await _press(PAD_B, JOY_BUTTON_A)
	assert_bool(Players.solo).is_false()
	assert_int(Players.device_of(P1)).is_equal(PAD_A)
	assert_int(Players.device_of(P2)).is_equal(PAD_B)
	assert_bool(Audio.played("player_join")).is_true()
	assert_bool(Audio.played("solo_off")).is_true()


# PF-1, --solo (no pad held the buttons): the new pad still gets P2 and solo ends.
func test_a_second_pad_takes_p2_after_cli_solo() -> void:
	Players.set_solo(true)
	await _press(PAD_B, JOY_BUTTON_A)
	assert_bool(Players.solo).is_false()
	assert_int(Players.device_of(P2)).is_equal(PAD_B)
	assert_int(Players.device_of(P1)).is_not_equal(PAD_B)


# PF-1: the solo pad itself pressing A is still solo play, not a join.
func test_the_solo_pad_pressing_a_stays_solo() -> void:
	Players._assign(P1, PAD_A)
	Players.set_solo(true, PAD_A)
	await _press(PAD_A, JOY_BUTTON_A)
	assert_bool(Players.solo).is_true()


# PF-1 in the main scene: solo play, a second pad presses A, P2 is theirs and awake.
func test_a_second_pad_wakes_p2_during_solo_play() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Arena").use_save = false
	world.add_child(main)
	Players._assign(P1, PAD_A)
	Players.set_solo(true, PAD_A)
	Game.finish_lobby([P1])
	await get_tree().process_frame
	assert_object(main.zapper(P2)).is_not_null()   # solo: the one pad drives both, both awake
	await _press(PAD_B, JOY_BUTTON_A)
	await get_tree().process_frame
	assert_bool(Players.solo).is_false()
	assert_int(Players.device_of(P2)).is_equal(PAD_B)
	assert_bool(main.zapper(P2).asleep).is_false()   # handed over: a snort in the tire pile, awake


# PF-2: a zap saves the yard a few seconds later, not up to 30 s later, so a hard stop loses little.
func test_a_zap_saves_the_yard_within_seconds() -> void:
	Game.start_round()
	var l := YardLevel.new()
	l.use_save = false   # no load at _ready; the save path is turned on below
	l.layout = load(YardLevel.LAYOUT)
	world.add_child(l)
	var players := Node3D.new()
	players.name = "Players"
	l.add_child(players)
	l.use_save = true
	Save.wipe()
	var cow := l.object(&"cow")
	Effects.zap(&"grow", cow)
	l._on_zapped(P1, &"grow", cow)
	l._process(1.0)
	assert_object(Save.get_value(YardLevel.SAVE_KEY)).is_null()
	l._process(YardLevel.SAVE_SOON)
	var saved = Save.get_value(YardLevel.SAVE_KEY)
	assert_object(saved).is_not_null()
	assert_int(int(saved.objects.cow.size)).is_equal(1)
	Save._load()   # it reached the file
	assert_int(int(Save.get_value(YardLevel.SAVE_KEY).objects.cow.size)).is_equal(1)
	assert_float(YardLevel.SAVE_SOON).is_less_equal(5.0)


func test_player_flow_phase_from_args() -> void:
	assert_str(PlayerFlowRun.phase_from_args(PackedStringArray(["--solo", "--player-flow=return"]))).is_equal("return")
	assert_str(PlayerFlowRun.phase_from_args(PackedStringArray(["--demo"]))).is_equal("")


# PF-3: the pause bar that goes back to the lobby says so ("Restart" under "Reset Yard" read as a
# fresh yard), and still goes to the lobby in one press.
func test_pause_main_menu_bar_says_main_menu_and_goes_to_the_lobby() -> void:
	var pm: Control = load("res://scenes/ui/pause_menu.tscn").instantiate()
	world.add_child(pm)
	var bars := []
	for b in pm.get_node("Card/Buttons").get_children():
		bars.append(str(b.text))
	assert_array(bars).contains(["Main Menu"]).not_contains(["Restart"])
	assert_str(str(pm.get_node("Card/Buttons/Restart").text)).is_equal("Main Menu")
	Game.start_round()
	Game.pause()
	pm.press(pm.Choice.RESTART)
	assert_int(Game.state).is_equal(Game.State.LOBBY)
