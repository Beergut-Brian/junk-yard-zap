## Screenshots of Start fresh (feel-rules audit, 2026-11-13): `-- --fresh-ui=<state>` stages the
## lobby with a yard saved. States: menu (Continue + New yard, New focused), card-new (the hold-A
## question, ring 60 %), settings-restore (Settings with Restore old yard focused), card-restore.
## Run it with --profile=<a throwaway id> (scripts/tools/shots.sh ... --profile=shots_fresh): it
## saves that profile's yard and makes a backup there, and uses its own settings file.
class_name FreshPreview
extends Node

var state := ""


static func state_from_args(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with("--fresh-ui="):
			return a.trim_prefix("--fresh-ui=")
	return ""


func _ready() -> void:
	state = state_from_args(OS.get_cmdline_user_args())
	if Save.profile == "p1":
		push_warning("FreshPreview: pass --profile=<throwaway>; not staging on the family profile")
		return
	Save.settings_path = "user://%s_settings.json" % Save.profile
	_stage.call_deferred()


func _stage() -> void:
	await get_tree().create_timer(0.3).timeout
	var lobby: Node = get_tree().get_first_node_in_group("openjar_lobby")
	var level := YardLevel.find(lobby)
	if not FreshStart.has_save():
		level.save_yard()
	if state.contains("restore") and not FreshStart.has_backup():
		FreshStart.back_up()
	lobby.update_fresh_items()
	Players.join_virtual(Players.P1)
	await get_tree().process_frame
	var card: FreshCard = lobby.get_node("FreshCard")
	match state:
		"menu":
			lobby.focus_item(lobby.Choice.NEW)
		"card-new":
			lobby.focus_item(lobby.Choice.NEW)
			lobby.press_a(Players.P1)
		"settings-restore", "card-restore":
			lobby.focus_item(lobby.Choice.SETTINGS)
			lobby.press_a(Players.P1)
			var settings: SettingsPanel = lobby.get_node("Settings")
			settings.refresh()
			for i in 6:
				settings.move_focus(1)
			if state == "card-restore":
				settings.handle({ "move": Vector2i.ZERO, "a": Players.P1, "b": -1 })
	lobby.update_hint()
	await get_tree().create_timer(0.6).timeout
	if card.active:
		card.hold = FreshCard.HOLD * 0.6
		card.queue_redraw()
	lobby.process_mode = Node.PROCESS_MODE_DISABLED
