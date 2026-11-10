## Junk Yard Zap on the Showtime kit: data/menu_skin.tres loads with the game's colours, the lobby
## podiums show Jeff and Chuck (the game's own Jarling rigs, guns taped green / red), and the
## backdrop blurs the yard the game already draws instead of loading a second one.
class_name TestJyzMenus
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2

var _main: Node
var _real_settings := ""
var _real_picks := ""


func before() -> void:
	Save.profile = "gdunit"   # main.tscn saves the yard: never touch the family's profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_jyz_menus.json"
	Save.wipe_settings()
	_real_picks = Roster.picks_path   # the defaults (Jeff P1, Chuck P2), never the family's picks
	Roster.picks_path = "user://test_jyz_menus_players.json"
	Roster.args_override = PackedStringArray(["--no-picks"])
	Roster.reload()


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Roster.picks_path = _real_picks
	Roster.args_override = PackedStringArray()
	Roster.reload()


func before_test() -> void:
	Save.wipe_settings()
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	UiStyle.use_skin(load(UiStyle.SKIN_PATH))   # another suite may have left the template default


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Players.reset()
	Game._set_state(Game.State.LOBBY)


func test_skin_loads_with_the_game_look() -> void:
	var sk := load("res://data/menu_skin.tres") as MenuSkin
	assert_object(sk).is_not_null()
	assert_str(sk.title()).is_equal("Junk Yard Zap")
	assert_str(sk.accent.to_html(false)).is_equal("ffb21f")
	assert_str(sk.accent2.to_html(false)).is_equal("ff6a2b")
	assert_str(sk.deep.to_html(false)).is_equal("33201a")
	assert_int(sk.backdrop).is_equal(MenuSkin.Backdrop.SCREEN)
	assert_object(sk.backdrop_scene).is_null()   # never a second yard (physics would run twice)
	assert_bool(sk.round_card).is_true()
	assert_str(sk.round_card_title).is_equal("ZAP TIME!")


func test_lobby_shows_jeff_and_chuck() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await await_idle_frame()
	var lobby: Control = _main.get_node("UI/Lobby")
	assert_str(lobby.get_node("TitleArt/TitleLabel").text).is_equal("JUNK YARD ZAP")
	var want := {P1: [&"jeff", "JEFF"], P2: [&"chuck", "CHUCK"]}
	for p in [P1, P2]:
		var slot: CharacterSlot = lobby.get_node("Spots/P%d/Character" % (p + 1))
		assert_bool(slot.character is Node3D).override_failure_message("P%d not the Jarling" % (p + 1)).is_true()
		var rig: JarlingRig = slot.character.get("rig")
		assert_object(rig).is_not_null()
		assert_str(String(rig.character)).is_equal(String(want[p][0]))
		assert_object(rig.model).is_not_null()
		assert_object(rig.gun_gear).is_not_null()   # holding a junk gun
		assert_str(UiStyle.skin().player_name(p)).is_equal(want[p][1])
	# The blurred backdrop is the live yard behind the menu, not a second copy.
	assert_int(_main.find_children("*", "YardLevel", true, false).size()).is_equal(1)
	assert_int(lobby.find_children("*", "SubViewport", true, false).size()).is_equal(2)   # just the podiums
	# Joining lights a podium and plays the join cue.
	Players.join_virtual(P1)
	await await_idle_frame()
	assert_bool(lobby.readied[P1]).is_true()
	assert_that((lobby.get_node("Spots/P1/Character") as Control).modulate).is_equal(Color.WHITE)


func test_round_card_says_the_yard_is_open() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	assert_str(_main.get_node("UI/Lobby").round_card_subtitle).is_equal("THE YARD IS OPEN")
