## Every press answers (docs/press-answers.md, template feature/template-press-answers-1, adopted
## here): on each menu screen a press that does nothing plays the soft refusal (honk) and wobbles the
## focused item, and nothing else changes. Presses that already do something keep doing it (Start in
## pause resumes, Start in the lobby readies (PF-5), a join press joins, Select in solo switches).
## This game's own screen, the New yard / Restore question (FreshCard), shakes the card.
## Boots main.tscn with real pad events (devices 5 and 6), with its own profile, settings file and
## picks file (never the real ones).
class_name TestPressAnswers
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")

const PROFILE := "gdunit_press_answers"
const SETTINGS := "user://test_settings_press_answers.json"

var _main: Node
var _real_profile := ""
var _real_settings := ""
var _real_picks := ""


func before() -> void:
	_real_profile = Save.profile
	Save.profile = PROFILE
	_real_settings = Save.settings_path
	Save.settings_path = SETTINGS
	Save.wipe_settings()
	_real_picks = Roster.picks_path
	Roster.picks_path = "user://test_press_answers_players.json"
	Game.quit_exits = false


func after() -> void:
	_clean_backups()
	Save.replace({})
	Game.quit_exits = true
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Save.profile = _real_profile
	DirAccess.remove_absolute(Roster.picks_path)
	Roster.picks_path = _real_picks
	Roster.reload()


func _clean_backups() -> void:
	for f in FreshStart.backups():
		DirAccess.remove_absolute(FreshStart.DIR.path_join(f))


func before_test() -> void:
	Save.wipe_settings()
	_clean_backups()
	Save.replace({})
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	Yard.reset_world()


func _pad(device: int, button: JoyButton) -> void:
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = button
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await await_idle_frame()


func _trigger(device: int, axis: JoyAxis) -> void:
	for v in [1.0, 0.0]:
		var ev := InputEventJoypadMotion.new()
		ev.device = device
		ev.axis = axis
		ev.axis_value = v
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await await_idle_frame()


func _honks() -> int:
	return UiSound.plays.get(MenuInput.REFUSE_CUE, 0)


## Two real pads join (B: joined, not ready) on the lobby.
func _lobby_with_pads() -> Lobby:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _pad(5, JOY_BUTTON_B)
	await _pad(6, JOY_BUTTON_B)
	await await_idle_frame()
	return _main.get_node("UI/Lobby")


func _paused() -> PauseMenu:
	var lobby := await _lobby_with_pads()
	lobby.press_a(P1)
	lobby.press_a(P2)
	lobby.count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	Game.pause()
	await await_idle_frame()
	await await_idle_frame()
	return _main.get_node("UI/PauseMenu")


# ---- lobby -------------------------------------------------------------------------------------

func test_lobby_unused_buttons_refuse_and_change_nothing() -> void:
	var lobby := await _lobby_with_pads()
	var play: MenuItem = lobby.get_node("Buttons/Play")
	var r0 := MenuInput.refusals
	var h0 := _honks()
	var picks := [Roster.pick(P1), Roster.pick(P2)]
	await _pad(5, JOY_BUTTON_X)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_str(MenuInput.last_refused).is_equal("x")
	assert_int(_honks()).is_equal(h0 + 1)
	assert_bool(play.is_wobbling()).is_true()
	for b in [JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
			JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_BACK]:
		await _pad(6, b)
	await _trigger(5, JOY_AXIS_TRIGGER_RIGHT)
	await _trigger(6, JOY_AXIS_TRIGGER_LEFT)
	assert_int(MenuInput.refusals).is_equal(r0 + 9)
	assert_str(MenuInput.last_refused).is_equal("lt")
	# Nothing else changed.
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_int(lobby.focus).is_equal(Lobby.Choice.PLAY)
	assert_bool(lobby.readied[P1] or lobby.readied[P2]).is_false()
	assert_bool(lobby.in_submenu()).is_false()
	assert_array([Roster.pick(P1), Roster.pick(P2)]).is_equal(picks)


## PF-5: Start readies (not a refusal); Start again while the other player is not ready has
## nothing to do, so it refuses; once both are ready and counting, Start refuses too.
func test_lobby_start_readies_then_refuses_when_it_has_nothing_to_do() -> void:
	var lobby := await _lobby_with_pads()
	var r0 := MenuInput.refusals
	await _pad(5, JOY_BUTTON_START)
	assert_bool(lobby.readied[P1]).is_true()
	assert_int(MenuInput.refusals).is_equal(r0)
	await _pad(5, JOY_BUTTON_START)   # P2 not ready yet: nothing to start
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_str(MenuInput.last_refused).is_equal("start")
	assert_bool(lobby.counting).is_false()
	assert_bool(lobby.get_node("Buttons/Play").is_wobbling()).is_true()
	await _pad(6, JOY_BUTTON_START)   # P2 readies: the countdown starts
	assert_bool(lobby.readied[P2]).is_true()
	assert_bool(lobby.counting).is_true()
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	await _pad(6, JOY_BUTTON_START)   # already counting
	assert_int(MenuInput.refusals).is_equal(r0 + 2)
	assert_bool(lobby.counting).is_true()
	assert_int(Game.state).is_equal(Game.State.LOBBY)


func test_lobby_b_with_nothing_to_back_out_of_refuses() -> void:
	var lobby := await _lobby_with_pads()
	var r0 := MenuInput.refusals   # the two B joins were joins, not refusals
	await _pad(5, JOY_BUTTON_B)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_bool(lobby.readied[P1]).is_false()
	assert_int(lobby.focus).is_equal(Lobby.Choice.PLAY)


func test_lobby_join_press_is_not_a_refusal() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await await_idle_frame()
	var r0 := MenuInput.refusals
	await _pad(5, JOY_BUTTON_B)
	await _pad(6, JOY_BUTTON_X)   # X joins P2 too
	assert_bool(Players.is_active(P1) and Players.is_active(P2)).is_true()
	assert_int(MenuInput.refusals).is_equal(r0)


func test_lobby_left_right_on_a_locked_podium_refuses() -> void:
	var lobby := await _lobby_with_pads()
	lobby.set_ready(P1, true)
	var pick := Roster.pick(P1)
	var r0 := MenuInput.refusals
	await _pad(5, JOY_BUTTON_DPAD_RIGHT)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_str(MenuInput.last_refused).is_equal("right")
	assert_str(Roster.pick(P1)).is_equal(pick)
	assert_bool(lobby.readied[P1]).is_true()


func test_lobby_select_in_solo_still_switches() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await await_idle_frame()
	Players.set_solo(true, 5)
	await await_idle_frame()
	await await_idle_frame()
	var r0 := MenuInput.refusals
	assert_int(Players.solo_focus).is_equal(P1)
	await _pad(5, JOY_BUTTON_BACK)
	assert_int(Players.solo_focus).is_equal(P2)
	assert_int(MenuInput.refusals).is_equal(r0)


# ---- pause -------------------------------------------------------------------------------------

func test_pause_unused_buttons_refuse_and_change_nothing() -> void:
	var pm := await _paused()
	var resume: MenuItem = pm.get_node("Card/Buttons/Resume")
	var r0 := MenuInput.refusals
	var h0 := _honks()
	await _pad(5, JOY_BUTTON_Y)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_int(_honks()).is_equal(h0 + 1)
	assert_bool(resume.is_wobbling()).is_true()
	await _pad(6, JOY_BUTTON_LEFT_SHOULDER)
	await _pad(6, JOY_BUTTON_BACK)   # Select: restart is PLAYING only
	await _trigger(5, JOY_AXIS_TRIGGER_LEFT)
	assert_int(MenuInput.refusals).is_equal(r0 + 4)
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.RESUME)
	assert_bool(pm.in_submenu()).is_false()


func test_pause_left_right_cycle_then_refuse_at_the_end() -> void:
	var pm := await _paused()
	var r0 := MenuInput.refusals
	await _pad(5, JOY_BUTTON_DPAD_LEFT)   # nothing above Resume
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.RESUME)
	assert_bool(pm.get_node("Card/Buttons/Resume").is_wobbling()).is_true()
	for want in [PauseMenu.Choice.RESET, PauseMenu.Choice.RESTART, PauseMenu.Choice.SETTINGS,
			PauseMenu.Choice.DOOR]:
		await _pad(5, JOY_BUTTON_DPAD_RIGHT)
		assert_int(pm.focus).is_equal(want)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	await _pad(6, JOY_BUTTON_DPAD_RIGHT)   # past the door: refuse, the door wobbles
	assert_int(pm.focus).is_equal(PauseMenu.Choice.DOOR)
	assert_int(MenuInput.refusals).is_equal(r0 + 2)
	var door: MenuItem = pm.get_node("Card/Buttons/Door")
	assert_bool(door.is_wobbling()).is_true()
	assert_int(door.wobbles).is_equal(1)
	await _pad(5, JOY_BUTTON_DPAD_LEFT)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.SETTINGS)
	assert_int(Game.state).is_equal(Game.State.PAUSED)


func test_pause_start_still_resumes() -> void:
	var pm := await _paused()
	var r0 := MenuInput.refusals
	await _pad(5, JOY_BUTTON_START)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_int(MenuInput.refusals).is_equal(r0)
	assert_bool(pm.visible).is_false()


# ---- settings ----------------------------------------------------------------------------------

func test_settings_unused_button_refuses_and_changes_nothing() -> void:
	var pm := await _paused()
	pm.press(PauseMenu.Choice.SETTINGS)
	var settings: SettingsPanel = pm.get_node("Settings")
	assert_bool(settings.active).is_true()
	await await_idle_frame()
	var before := [SettingsPanel.value_of(SettingsPanel.MUSIC), SettingsPanel.value_of(SettingsPanel.SOUND),
			SettingsPanel.value_of(SettingsPanel.SHAKE), Players.solo]
	var r0 := MenuInput.refusals
	await _pad(5, JOY_BUTTON_X)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_bool(pm.get_node("Settings/Card/Rows/Music").is_wobbling()).is_true()
	assert_bool(settings.active).is_true()
	assert_int(settings.focus).is_equal(SettingsPanel.Row.MUSIC)
	assert_array([SettingsPanel.value_of(SettingsPanel.MUSIC), SettingsPanel.value_of(SettingsPanel.SOUND),
			SettingsPanel.value_of(SettingsPanel.SHAKE), Players.solo]).is_equal(before)
	assert_str(Save.settings_path).is_equal(SETTINGS)   # never the real file


# ---- leave the game? ---------------------------------------------------------------------------

func test_confirm_unused_button_refuses_and_stays_open() -> void:
	var lobby := await _lobby_with_pads()
	lobby.focus_item(Lobby.Choice.DOOR)
	lobby.press_a(P1)
	var confirm: ConfirmDialog = lobby.get_node("Confirm")
	assert_bool(confirm.active).is_true()
	await await_idle_frame()
	var r0 := MenuInput.refusals
	await _pad(6, JOY_BUTTON_RIGHT_SHOULDER)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_bool(confirm.get_node("Card/Buttons/Cancel").is_wobbling()).is_true()
	assert_bool(confirm.active).is_true()
	assert_int(confirm.focus).is_equal(ConfirmDialog.Choice.CANCEL)
	await _pad(6, JOY_BUTTON_START)   # Start in the lobby's question: nothing, so refuse
	assert_int(MenuInput.refusals).is_equal(r0 + 2)
	assert_bool(confirm.active).is_true()
	assert_int(Game.state).is_equal(Game.State.LOBBY)


# ---- start a new yard? (this game's own screen) -----------------------------------------------

func test_fresh_card_unused_presses_refuse_and_keep_the_question() -> void:
	var lobby := await _lobby_with_pads()
	var card: FreshCard = lobby.get_node("FreshCard")
	card.open(FreshCard.Ask.NEW)
	await await_idle_frame()
	var r0 := MenuInput.refusals
	var h0 := _honks()
	await _pad(5, JOY_BUTTON_X)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_int(_honks()).is_equal(h0 + 1)
	assert_bool(card.is_wobbling()).is_true()
	await _pad(6, JOY_BUTTON_DPAD_DOWN)   # nothing to move between on the card
	assert_str(MenuInput.last_refused).is_equal("down")
	await _pad(6, JOY_BUTTON_START)
	await _trigger(5, JOY_AXIS_TRIGGER_RIGHT)
	assert_int(MenuInput.refusals).is_equal(r0 + 4)
	assert_int(card.wobbles).is_equal(4)
	# Nothing else changed: the question is still up, no yard was replaced, nobody readied.
	assert_bool(card.active).is_true()
	assert_int(card.ask).is_equal(FreshCard.Ask.NEW)
	assert_float(card.hold).is_equal(0.0)
	assert_array(FreshStart.backups()).is_empty()
	assert_bool(lobby.readied[P1] or lobby.readied[P2]).is_false()
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	await _pad(5, JOY_BUTTON_B)   # B still keeps the yard
	assert_bool(card.active).is_false()


## This game's own Settings row, Restore old yard (lobby, with a backup): A asks; left / right and the
## unused buttons used to return silently, now they refuse. Nothing else changes.
func test_settings_restore_row_refuses_left_right_and_unused_buttons() -> void:
	Save.replace({ "press_answers": true })
	assert_str(FreshStart.back_up()).is_not_empty()   # a backup, on this suite's own profile
	var lobby := await _lobby_with_pads()
	lobby.focus_item(Lobby.Choice.SETTINGS)
	lobby.press_a(P1)
	var settings: SettingsPanel = lobby.get_node("Settings")
	var restore: MenuItem = settings.get_node("Card/Rows/Restore")
	assert_bool(restore.visible).is_true()
	for i in 6:
		settings.move_focus(1)
	assert_int(settings.focus).is_equal(SettingsPanel.Row.RESTORE)
	await await_idle_frame()
	var before := [SettingsPanel.value_of(SettingsPanel.MUSIC), SettingsPanel.value_of(SettingsPanel.SOUND),
			SettingsPanel.value_of(SettingsPanel.SHAKE), Players.solo, FreshStart.backups().size()]
	var r0 := MenuInput.refusals
	await _pad(5, JOY_BUTTON_DPAD_RIGHT)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_str(MenuInput.last_refused).is_equal("right")
	assert_bool(restore.is_wobbling()).is_true()
	await _pad(6, JOY_BUTTON_Y)
	await _pad(6, JOY_BUTTON_START)   # Start in the lobby's Settings: nothing to do
	assert_int(MenuInput.refusals).is_equal(r0 + 3)
	assert_str(MenuInput.last_refused).is_equal("start")
	assert_bool(settings.active).is_true()
	assert_int(settings.focus).is_equal(SettingsPanel.Row.RESTORE)
	assert_bool(lobby.get_node("FreshCard").active).is_false()   # no question asked
	assert_array([SettingsPanel.value_of(SettingsPanel.MUSIC), SettingsPanel.value_of(SettingsPanel.SOUND),
			SettingsPanel.value_of(SettingsPanel.SHAKE), Players.solo, FreshStart.backups().size()]) \
			.is_equal(before)
	assert_str(Save.settings_path).is_equal(SETTINGS)
