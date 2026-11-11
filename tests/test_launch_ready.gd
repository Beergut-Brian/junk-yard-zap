## Launch-readiness (feature/launch-ready-1): the whole session scripted end to end with synthetic
## pad events (SessionFlow: lobby, chooser + catchphrase, settings, doors, two players, drop-out /
## in, pause, Reset Yard, Restart, solo, quit at every screen), the D-pad driving every menu, and
## every menu cue a designed file instead of the code synth.
## Own save profile, own settings file, own picks file, the voice fixture roster.
class_name TestLaunchReady
extends GdUnitTestSuite

const VOICE := "res://tests/fixtures/roster_voice.json"
const PICKS := "user://test_launch_ready_picks.json"
const Lobby := preload("res://scenes/ui/lobby.gd")

var _main: Node
var _real := {}


func before() -> void:
	_real = { "profile": Save.profile, "settings": Save.settings_path, "data": Roster.data_path,
			"picks": Roster.picks_path, "args": Roster.args_override }
	Save.profile = "gdunit_launch_ready"
	Save.wipe()
	Save.settings_path = "user://test_settings_launch_ready.json"
	Save.wipe_settings()
	Roster.data_path = VOICE
	Roster.picks_path = PICKS
	Roster.args_override = PackedStringArray(["--gdunit-launch-ready"])
	Roster.reload()
	Game.quit_exits = false


func after() -> void:
	Game.quit_exits = true
	Save.wipe()
	Save.profile = _real.profile
	Save.wipe_settings()
	Save.settings_path = _real.settings
	Save.reload_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PICKS))
	Roster.data_path = _real.data
	Roster.picks_path = _real.picks
	Roster.args_override = _real.args
	Roster.reload()


func before_test() -> void:
	Save.wipe_settings()
	Players.reset()
	Players.set_solo(false)
	Game.demo = false
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Players.set_solo(false)
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func _boot() -> Node:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	return _main


func _press(device: int, button: JoyButton) -> void:
	await get_tree().process_frame
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = button
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await get_tree().process_frame
		await get_tree().process_frame


func test_the_whole_session_flows_with_a_way_back_from_every_screen() -> void:
	_boot()
	var flow := SessionFlow.new()
	add_child(flow)
	await flow.run(_main)
	var bad := flow.failures()
	assert_array(bad).is_empty()
	assert_int(flow.steps.size()).is_greater_equal(30)
	# A window close was tried on every screen and each asked for exactly one clean quit.
	var closes := flow.steps.filter(func(s: Dictionary) -> bool: return str(s.step).begins_with("close@"))
	assert_int(closes.size()).is_greater_equal(7)
	flow.free()


func test_the_d_pad_moves_the_lobby_cursor_and_the_pause_menu() -> void:
	_boot()
	var lobby: Lobby = _main.get_node("UI/Lobby")
	await _press(30, JOY_BUTTON_B)   # joins, not ready
	assert_int(Players.device_of(Players.P1)).is_equal(30)
	assert_int(lobby.focus).is_equal(Lobby.Choice.PLAY)
	await _press(30, JOY_BUTTON_DPAD_DOWN)
	assert_int(lobby.focus).is_equal(Lobby.Choice.SETTINGS)
	await _press(30, JOY_BUTTON_DPAD_DOWN)
	assert_int(lobby.focus).is_equal(Lobby.Choice.DOOR)
	await _press(30, JOY_BUTTON_DPAD_UP)
	assert_int(lobby.focus).is_equal(Lobby.Choice.SETTINGS)
	await _press(30, JOY_BUTTON_DPAD_UP)
	lobby.press_a(Players.P1)
	Game.start_round()
	Game.pause()
	await get_tree().process_frame
	var pm: Node = _main.get_node("UI/PauseMenu")
	assert_int(pm.focus).is_equal(0)
	await _press(30, JOY_BUTTON_DPAD_DOWN)
	assert_int(pm.focus).is_equal(1)   # Reset Yard


func test_a_held_d_pad_moves_once_not_every_frame() -> void:
	_boot()
	var lobby: Lobby = _main.get_node("UI/Lobby")
	await _press(31, JOY_BUTTON_B)
	await get_tree().process_frame
	var ev := InputEventJoypadButton.new()
	ev.device = 31
	ev.button_index = JOY_BUTTON_DPAD_DOWN
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 20:
		await get_tree().process_frame
	assert_int(lobby.focus).is_equal(Lobby.Choice.SETTINGS)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await get_tree().process_frame


func test_every_menu_cue_is_a_designed_file_not_the_synth() -> void:
	for cue in UiSound.CUES:
		var found := ResourceLoader.exists("res://assets/audio/sfx/%s.ogg" % cue) \
				or ResourceLoader.exists("res://assets/audio/sfx/%s_1.ogg" % cue)
		assert_bool(found).override_failure_message("menu cue '%s' has no file" % cue).is_true()
		var s: AudioStream = load("res://assets/audio/sfx/%s.ogg" % cue) if ResourceLoader.exists(
				"res://assets/audio/sfx/%s.ogg" % cue) else load("res://assets/audio/sfx/%s_1.ogg" % cue)
		assert_float(s.get_length()).is_between(0.05, 1.0)   # menu cues stay short


func test_the_release_stamps_the_tag_into_the_version_before_export() -> void:
	var yml := FileAccess.get_file_as_string("res://.github/workflows/release.yml")
	var stamp := yml.find("Stamp the version from the tag")
	assert_int(stamp).is_greater(0)
	assert_int(stamp).is_less(yml.find("--export-release"))
	assert_str(yml).contains('V="${GITHUB_REF_NAME#v}"')
	# The same substitution the workflow's sed makes, on the real project.godot: exactly one line.
	var cfg := FileAccess.get_file_as_string("res://project.godot")
	var re := RegEx.create_from_string('(?m)^config/version=.*$')
	assert_int(re.search_all(cfg).size()).is_equal(1)
	var out := re.sub(cfg, 'config/version="1.0.0-dev.3"')
	assert_str(out).contains('config/version="1.0.0-dev.3"')


func test_the_lobby_footer_shows_the_project_version() -> void:
	_boot()
	await get_tree().process_frame
	var label: Label = _main.get_node("UI/Lobby/Footer/Version")
	assert_str(label.text).is_equal("v%s" % ProjectSettings.get_setting("application/config/version"))
	assert_str(label.text).is_not_equal("v0.0.1")


func test_a_full_cue_rebuild_never_writes_over_the_elevenlabs_music() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/audio/make_cues.py")
	assert_str(src).contains('stems = args.only or [s for s in FILES if FILES[s][1] != "music"]')
	assert_bool(FileAccess.file_exists("res://assets/audio/music/music_yard.ogg")).is_true()


## The gun wheel pops its tokens in from size 0: those frames used to log "Invalid polygon data,
## triangulation failed" (seen in the soak and the session flow).
func test_gun_icons_skip_shapes_squashed_to_nothing() -> void:
	assert_bool(GunIcons.has_area(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))).is_false()
	assert_bool(GunIcons.has_area(PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2(2, 0)]))).is_false()
	assert_bool(GunIcons.has_area(PackedVector2Array([Vector2.ZERO, Vector2(10, 0), Vector2(0, 10)]))).is_true()
	var canvas := Control.new()
	canvas.size = Vector2(400, 400)
	add_child(canvas)
	var tiny := [0]
	var big := [0]
	canvas.draw.connect(func() -> void:
		for kind in GunData.Kind.values():
			for t in [0.0, 0.1, 0.5, 1.0]:
				var before := GunIcons.skipped
				GunIcons.token(canvas, kind, Color.ORANGE, Vector2(50, 50), 0.02, t)
				tiny[0] += GunIcons.skipped - before
				before = GunIcons.skipped
				GunIcons.token(canvas, kind, Color.ORANGE, Vector2(200, 200), 60.0, t)
				big[0] += GunIcons.skipped - before)
	canvas.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(tiny[0]).is_greater(0)    # the squashed shapes were caught, not sent to the engine
	assert_int(big[0]).is_equal(0)       # a full-size icon draws every shape
	canvas.free()
