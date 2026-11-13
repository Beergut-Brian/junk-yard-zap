## Kaden's standing feel rules, audited 2026-11-13 (REPORT.md of fix/jyz-rules-audit-1).
## Rule 5, every action beeps: a statue (partner freeze) ignores its buttons, but a fresh press
## says so (the refusal "nope" plus ice chips; the ice look is the cause), never a button that was
## already down. Rule 7, show the buttons that matter: the lobby footer and Settings hint follow
## the focus and who is joined / ready. Rule 4: solo is off at boot even when settings remember it
## on. Own settings and picks files, fixture roster.
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
var _clock := Clock.new()

const P1 := Players.P1
const P2 := Players.P2
const IDLE := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false,
		"prev": false, "reset": false, "start": false}
const FIXTURE := "res://tests/fixtures/roster_two.json"
const Lobby := preload("res://scenes/ui/lobby.gd")

var world: Node3D
var _main: Node
var _real_profile := ""
var _real_settings := ""
var _real_picks := ""
var _real_data := ""


func before() -> void:
	_clock.pin()
	_real_profile = Save.profile
	Save.profile = "gdunit_feel"
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_feel.json"
	Save.wipe_settings()
	_real_data = Roster.data_path
	_real_picks = Roster.picks_path
	Roster.data_path = FIXTURE
	Roster.picks_path = "user://test_feel_players.json"
	Roster.args_override = PackedStringArray(["--no-picks"])
	Roster.reload()


func after() -> void:
	_clock.restore()
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Save.profile = _real_profile
	Roster.data_path = _real_data
	Roster.picks_path = _real_picks
	Roster.args_override = PackedStringArray()
	Roster.reload()


func before_test() -> void:
	Players.reset()
	Save.replace({})
	Game.demo = false
	Game.start_round()
	Audio.history.clear()
	world = Node3D.new()
	add_child(world)
	world.add_child(YardStrip.new())


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	get_tree().paused = false
	if is_instance_valid(world):
		world.free()
	Game._set_state(Game.State.PLAYING)
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


func freeze_gun() -> GunData:
	for g in Zapper.load_guns():
		if g.kind == GunData.Kind.FREEZE:
			return g
	return null


func nopes() -> int:
	return Array(Audio.history).count("nope")


func test_a_press_on_a_statue_is_refused_out_loud() -> void:
	var a := zapper(P1, -2.0)
	var b := zapper(P2, 2.0)
	await step(5)
	b.partner_zap(freeze_gun(), a)
	assert_float(b.statue_left).is_greater(0.0)
	Audio.history.clear()
	for k in ["action", "jump", "next"]:
		b.input_override[k] = true
		await step(2)
		b.input_override[k] = false
		await step(14)   # 16 frames a press: past the 0.25 s gap between refusals
	assert_int(nopes()).is_equal(3)
	assert_float(b.statue_left).is_greater(0.0)   # still a statue: nothing else happened
	assert_int(b.gun_index).is_equal(0)


func test_a_button_held_into_the_freeze_is_not_a_new_press() -> void:
	var a := zapper(P1, -2.0)
	var b := zapper(P2, 2.0)
	b.input_override["action"] = true
	await step(5)
	b.partner_zap(freeze_gun(), a)
	Audio.history.clear()
	await step(20)
	assert_int(nopes()).is_equal(0)


func test_lobby_hint_follows_focus_and_readiness() -> void:
	world.free()
	Game._set_state(Game.State.LOBBY)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	var lobby: Lobby = _main.get_node("UI/Lobby")
	assert_str(lobby.hint_text()).contains("Join")
	Players.join_virtual(P1)
	await get_tree().process_frame
	lobby.set_ready(P1, false)
	assert_str(lobby.hint_text()).contains("[lr]")
	assert_str(lobby.hint_text()).contains("Ready")
	lobby.set_ready(P1, true)
	assert_str(lobby.hint_text()).contains("Hold [a] Start")
	lobby.focus_item(Lobby.Choice.SETTINGS)
	assert_str(lobby.hint_text()).contains("[a] Select")
	lobby.update_hint()
	assert_str(lobby.get_node("Footer/Hints").text).is_equal(lobby.hint_text())


func test_solo_remembered_in_settings_is_off_at_boot() -> void:
	Save.set_setting(SettingsPanel.SOLO, true)
	world.free()
	Game._set_state(Game.State.LOBBY)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(Players.solo).is_false()
	assert_bool(Players.solo_from_args(PackedStringArray([]))).is_false()
	assert_bool(Players.solo_from_args(PackedStringArray(["--solo"]))).is_true()
