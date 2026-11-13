## Feel rule "Start fresh" (Kaden, standing; audited 2026-11-13). Boots main.tscn with a yard saved:
## the start menu shows Continue and New yard; New asks first (A held, FreshCard), keeps the old save
## as a backup (never deletes it) and opens the layout's yard with a new deck; B or a tap keeps the
## yard; Settings offers Restore old yard, which brings the backup back and keeps the yard it
## replaces too; the pause menu's Main Menu bar reaches that menu. Own profile, settings and picks.
extends GdUnitTestSuite

const P1 := Players.P1
const Lobby := preload("res://scenes/ui/lobby.gd")
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")
const PROFILE := "gdunit_fresh"
const DT := 1.0 / 60.0
const NO_INPUT := { "move": Vector2i.ZERO, "a": -1, "b": -1 }

var _main: Node
var _real_profile := ""
var _real_settings := ""
var _real_picks := ""
var _moved_key := ""
var _moved_to := Vector3.ZERO
var _done_id := StringName()


func before() -> void:
	_real_profile = Save.profile
	Save.profile = PROFILE
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_fresh.json"
	Save.wipe_settings()
	_real_picks = Roster.picks_path
	Roster.picks_path = "user://test_fresh_players.json"
	Game.quit_exits = false


func after() -> void:
	_clean_files()
	Save.replace({})
	Game.quit_exits = true
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Save.profile = _real_profile
	DirAccess.remove_absolute(Roster.picks_path)
	Roster.picks_path = _real_picks
	Roster.reload()


func before_test() -> void:
	_clean_files()
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


func _clean_files() -> void:
	for f in FreshStart.backups():
		DirAccess.remove_absolute(FreshStart.DIR.path_join(f))


func _boot() -> Node:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	return _main


func _lobby() -> Lobby:
	return _main.get_node("UI/Lobby")


func _level() -> YardLevel:
	return _main.get_node("Arena")


func _card() -> FreshCard:
	return _lobby().get_node("FreshCard")


## A played yard on disk: one object moved well away from its layout spot, one goal card done.
func _played_save() -> void:
	_boot()
	var l := _level()
	_moved_key = String(l.objects.keys()[0])
	var o: PhysicsObject = l.objects[StringName(_moved_key)]
	_moved_to = o.global_position + Vector3(6.0, 3.0, 0.0)
	o.global_position = _moved_to
	_done_id = l.deck.order[0]
	l.deck.complete()
	l.save_yard()
	_main.free()
	Yard.reset_world()
	_boot()


## The card's hold, frame by frame: the opening press still down, then up (arms), then held.
func _hold_a(seconds: float) -> void:
	var c := _card()
	c.step(DT, NO_INPUT, true)
	c.step(DT, NO_INPUT, false)
	for i in int(seconds / DT) + 1:
		c.step(DT, NO_INPUT, true)
	c.step(DT, NO_INPUT, false)


func _saved_pos(d: Dictionary) -> Vector3:
	var p: Array = d["yard"]["objects"][_moved_key]["p"]
	return Vector3(p[0], p[1], p[2])


func test_no_save_shows_play_and_no_new_yard() -> void:
	_boot()
	var lobby := _lobby()
	assert_str(lobby.get_node("Buttons/Play").text).is_equal("Play")
	assert_bool(lobby.get_node("Buttons/NewYard").visible).is_false()
	lobby.move_focus(1)
	assert_int(lobby.focus).is_equal(Lobby.Choice.SETTINGS)   # New yard is skipped


func test_a_saved_yard_shows_continue_and_new_yard_and_loads_as_left() -> void:
	_played_save()
	var lobby := _lobby()
	assert_str(lobby.get_node("Buttons/Play").text).is_equal("Continue")
	assert_bool(lobby.get_node("Buttons/NewYard").visible).is_true()
	lobby.move_focus(1)
	assert_int(lobby.focus).is_equal(Lobby.Choice.NEW)
	var o: PhysicsObject = _level().objects[StringName(_moved_key)]
	assert_float(o.global_position.distance_to(_moved_to)).is_less(0.05)
	assert_bool(_level().deck.done.has(_done_id)).is_true()


func test_new_yard_asks_with_a_hold_then_keeps_the_old_save_as_a_backup() -> void:
	_played_save()
	var lobby := _lobby()
	var before := Save.data()
	lobby.focus_item(Lobby.Choice.NEW)
	lobby.press_a(P1)
	assert_bool(_card().active).is_true()
	assert_int(_card().ask).is_equal(FreshCard.Ask.NEW)
	assert_bool(lobby.in_submenu()).is_true()
	_hold_a(FreshCard.HOLD)
	assert_bool(_card().active).is_false()
	# The backup is the whole save as it was, on disk; the save itself starts empty.
	var list := FreshStart.backups()
	assert_int(list.size()).is_equal(1)
	var kept = JSON.parse_string(FileAccess.get_file_as_string(FreshStart.DIR.path_join(list[0])))
	assert_float(_saved_pos(kept).distance_to(_saved_pos(before))).is_less(0.01)
	assert_bool((kept["yard"]["deck"]["done"] as Array).has(String(_done_id))).is_true()
	assert_bool(FreshStart.has_save()).is_false()
	# The yard is the layout's again, with the deck from its first card and no trophies.
	var l := _level()
	var o: PhysicsObject = l.objects[StringName(_moved_key)]
	assert_float(o.global_position.distance_to(_moved_to)).is_greater(1.0)
	assert_array(l.deck.done).is_empty()
	assert_str(String(l.deck.order[0])).is_equal(String(_done_id))
	# The menu: Play again, no New yard.
	assert_str(lobby.get_node("Buttons/Play").text).is_equal("Play")
	assert_bool(lobby.get_node("Buttons/NewYard").visible).is_false()


func test_b_or_a_tap_on_the_question_keeps_the_yard() -> void:
	_played_save()
	var lobby := _lobby()
	var before := Save.data()
	lobby.focus_item(Lobby.Choice.NEW)
	lobby.press_a(P1)
	var c := _card()
	c.step(DT, NO_INPUT, true)
	c.step(DT, NO_INPUT, false)
	for i in 20:   # a third of a second: a tap
		c.step(DT, NO_INPUT, true)
	c.step(DT, NO_INPUT, false)
	assert_bool(c.active).is_true()
	assert_float(c.progress()).is_equal(0.0)   # let go: the ring empties
	c.step(DT, { "move": Vector2i.ZERO, "a": -1, "b": P1 }, false)
	assert_bool(c.active).is_false()
	assert_int(FreshStart.backups().size()).is_equal(0)
	assert_bool(Save.data() == before).is_true()
	assert_str(lobby.get_node("Buttons/Play").text).is_equal("Continue")


func test_settings_restore_brings_the_old_yard_back_and_deletes_nothing() -> void:
	_played_save()
	var lobby := _lobby()
	var settings: SettingsPanel = lobby.get_node("Settings")
	var restore: MenuItem = settings.get_node("Card/Rows/Restore")
	lobby.focus_item(Lobby.Choice.SETTINGS)
	lobby.press_a(P1)
	assert_bool(restore.visible).is_false()   # no backup yet: no Restore
	settings.close()
	lobby.focus_item(Lobby.Choice.NEW)
	lobby.press_a(P1)
	_hold_a(FreshCard.HOLD)
	assert_bool(FreshStart.has_save()).is_false()
	lobby.focus_item(Lobby.Choice.SETTINGS)
	lobby.press_a(P1)
	assert_bool(restore.visible).is_true()
	for i in 6:
		settings.move_focus(1)
	assert_int(settings.focus).is_equal(SettingsPanel.Row.RESTORE)
	settings.handle({ "move": Vector2i.ZERO, "a": P1, "b": -1 })
	assert_bool(_card().active).is_true()
	assert_int(_card().ask).is_equal(FreshCard.Ask.RESTORE)
	_hold_a(FreshCard.HOLD)
	# The old yard is back, in the save and in the yard.
	assert_bool(FreshStart.has_save()).is_true()
	assert_float(_saved_pos(Save.data()).distance_to(_moved_to)).is_less(0.05)
	var o: PhysicsObject = _level().objects[StringName(_moved_key)]
	assert_float(o.global_position.distance_to(_moved_to)).is_less(0.05)
	assert_bool(_level().deck.done.has(_done_id)).is_true()
	# Nothing deleted: the first backup is still there, and the fresh yard was kept too.
	assert_int(FreshStart.backups().size()).is_equal(2)
	assert_str(lobby.get_node("Buttons/Play").text).is_equal("Continue")
	assert_bool(settings.active).is_true()   # back in Settings where Restore was pressed


func test_pause_main_menu_reaches_continue_and_new_yard() -> void:
	_boot()
	Players.join_virtual(P1)
	await get_tree().process_frame
	Game.start_round()
	await get_tree().process_frame
	Game.pause()
	var pm: PauseMenu = _main.get_node("UI/PauseMenu")
	pm.press(PauseMenu.Choice.RESTART)
	await get_tree().process_frame
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	var lobby := _lobby()
	assert_bool(lobby.visible).is_true()
	assert_bool(FreshStart.has_save()).is_true()   # leaving play saved the yard
	assert_str(lobby.get_node("Buttons/Play").text).is_equal("Continue")
	assert_bool(lobby.get_node("Buttons/NewYard").visible).is_true()


## Leaving play saves the yard after the lobby has opened (first time on a profile): Continue and
## New yard still appear, from the save itself, not from the next open.
func test_a_save_made_while_the_lobby_is_open_shows_continue() -> void:
	_boot()
	var lobby := _lobby()
	assert_str(lobby.get_node("Buttons/Play").text).is_equal("Play")
	_level().save_yard()
	assert_str(lobby.get_node("Buttons/Play").text).is_equal("Continue")
	assert_bool(lobby.get_node("Buttons/NewYard").visible).is_true()
