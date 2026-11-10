## -- --ui=<state>: boots straight into a menu state, frozen, for screenshots (scripts/tools/shots.sh).
## lobby, lobby-joined, lobby-ready, lobby-hold, lobby-settings, lobby-confirm,
## pause, pause-settings, pause-confirm. The lobby calls run() once from _ready().
class_name UiPreview
extends RefCounted

const P1 := Players.P1
const P2 := Players.P2


static func state_from_args(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with("--ui="):
			return a.trim_prefix("--ui=")
	return ""


static func run(lobby: Control) -> void:
	var s := state_from_args(OS.get_cmdline_user_args())
	if s == "" or Game.demo:
		return
	lobby.freeze = true
	if s.begins_with("pause"):
		Players.join_virtual(P1)
		Players.join_virtual(P2)
		lobby.freeze = false
		Game.finish_lobby([P1, P2])
		Game.pause()
		var pm: Node = lobby.get_tree().get_first_node_in_group("openjar_pause_menu")
		pm.paused_by = P2
		if s == "pause-settings":
			pm.press(pm.Choice.SETTINGS)
			pm.get_node("Settings").move_focus(1)
		elif s == "pause-confirm":
			pm.press(pm.Choice.DOOR)
		return
	if s != "lobby":
		Players.join_virtual(P1)
	match s:
		"lobby-joined", "lobby-settings", "lobby-confirm":
			Players.join_virtual(P2)
			lobby.set_ready(P2, false)
			if s == "lobby-settings":
				lobby.focus_item(lobby.Choice.SETTINGS)
				lobby.press_a(P1)
			elif s == "lobby-confirm":
				lobby.focus_item(lobby.Choice.DOOR)
				lobby.press_a(P1)
		"lobby-ready":
			Players.join_virtual(P2)
			lobby.count_step(lobby.COUNT_STEP + 0.05)
		"lobby-hold":
			lobby.hold_step(P1, true, lobby.HOLD_TO_START * 0.6)
