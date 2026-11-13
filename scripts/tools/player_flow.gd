## The player-flow QA runs (handoff/PLAYER-FLOW.md): one phase per process, so a save, a setting or a
## pick has to survive a real quit and relaunch of the exported game. main.gd adds this node for
##   game.x86_64 -- --player-flow=<phase> --flow-out=<dir>
## and every run sets XDG_DATA_HOME to a scratch folder (user://, the save, settings.json and the
## shared players.json all live under it), so the family's save is never touched.
## Phases, in order on one XDG_DATA_HOME:
##   first   : a new player. Lobby, join with B, pick the next Jarling, hold A to start alone, grow
##             the cow, pause, Settings: music down to 0.3, back, Back to Open Jar, Leave (exit 0).
##   return  : the cow is still big, music 0.3, the pick kept. Pause, Reset Yard (a fresh yard),
##             grow the tire, then the window is closed mid-play (exit 0).
##   return2 : the tire is still big and the cow normal. Grow the cow, then wait for SIGTERM
##             (the caller kills the process) to see what a hard stop loses.
##   killed  : after the SIGTERM: is the cow big?
##   close_early: a returning player closes the window on the title screen seconds after launch.
##   lobby_quit: boot, join, Back to Open Jar, Leave, straight from the title screen (exit 0 expected).
##   hang_exit: PF-6 proof. Like close_early, but a node left in the tree blocks the main thread forever
##             while the tree is freed, so the engine's shutdown never ends: Game.quit()'s exit
##             watchdog must end the process about Game.EXIT_GRACE_MS later (killed, not exit 0).
##   solo    : with --solo. Both podiums ready, play, then a second pad presses A: P2 is theirs.
## Each check appends "PASS|FAIL <step> <note>" to <dir>/<phase>.txt and saves <dir>/<phase>_NN_<step>.png.
class_name PlayerFlowRun
extends Node

const COW := &"cow"
const TIRE := &"tire"

var phase := ""
var out := ""
var main: Node
var flow: SessionFlow


static func phase_from_args(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with("--player-flow="):
			return a.trim_prefix("--player-flow=")
	return ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--flow-out="):
			out = a.trim_prefix("--flow-out=")
	phase = phase_from_args(OS.get_cmdline_user_args())
	main = get_parent()
	flow = SessionFlow.new()
	flow.main = main
	flow.shot_dir = out
	add_child(flow)
	_run.call_deferred()


func _level() -> YardLevel:
	return main.get_node("Arena") as YardLevel


func _size(key: StringName) -> int:
	var o := _level().object(key)
	if o == null:
		return -99
	var sz = o.stack.get_effect(&"size")
	return sz.steps if sz else 0


func _grow(key: StringName) -> void:
	var o := _level().object(key)
	if o and _size(key) == 0:
		Effects.Size.new(2).apply(o)
		_level()._on_zapped(Players.P1, &"grow", o)   # what a real zap tells the yard


func check(step: String, ok: bool, note := "") -> void:
	var n := flow.steps.size() + 1
	await flow.check(phase + "_" + step, ok, note)
	var line := "%s %02d_%s %s\n" % ["PASS" if ok else "FAIL", n, step, note]
	var path := out.path_join(phase + ".txt")
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	f.seek_end()
	f.store_string(line)
	f.close()


func _menu_down(times: int) -> void:
	for i in times:
		await flow.pad(SessionFlow.PAD1, JOY_BUTTON_DPAD_DOWN)


func _start_alone() -> void:
	# Joined and ready: hold A on Play for 1.5 s (the lobby's own hold rule reads the held button).
	flow._button(SessionFlow.PAD1, JOY_BUTTON_A, true)
	await flow.until(func() -> bool: return Game.state == Game.State.PLAYING, 30.0)
	flow._button(SessionFlow.PAD1, JOY_BUTTON_A, false)
	await flow.until(func() -> bool: return main.zapper(Players.P1) != null, 30.0)
	await flow._wait(1.0)


func _pause_open() -> void:
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_START)
	await flow._wait(0.4)


func _run() -> void:
	await flow._frames(10)
	match phase:
		"first":
			await _first()
		"return":
			await _return()
		"return2":
			await _return2()
		"killed":
			await check("cow_kept_after_sigterm", _size(COW) > 0, "cow size %d" % _size(COW))
			get_tree().quit(0)
		"solo":
			await _solo()
		"lobby_quit":
			await _lobby_quit()
		"close_early":   # a returning player closes the window on the title screen right after launch
			await check("title_then_close", Game.state == Game.State.LOBBY, "window closes now")
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		"hang_exit":   # PF-6: a shutdown that never ends, to prove the exit watchdog
			get_tree().root.add_child(StuckShutdown.new())
			await check("title_then_close_stuck", Game.state == Game.State.LOBBY, "shutdown will block")
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)


## Blocks the main thread for 10 minutes when it is freed (the tree is freed after quit()), standing in
## for an engine shutdown that never ends.
class StuckShutdown extends Node:
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			printerr("player_flow: shutdown blocked on purpose (hang_exit)")
			OS.delay_msec(600000)


func _first() -> void:
	await check("fresh_boot_lobby", Save.get_value("yard") == null and Game.state == Game.State.LOBBY,
			"no save yet")
	var first := Roster.pick(Players.P1)
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_B)   # join without readying
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_DPAD_RIGHT)
	await flow._wait(0.5)
	await check("pick_next", Roster.pick(Players.P1) != first, "%s -> %s" % [first, Roster.pick(Players.P1)])
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_A)   # ready
	await check("ready_alone_hint", Game.state == Game.State.LOBBY, "status: hold A to start solo")
	await _start_alone()
	await check("playing_alone", Game.state == Game.State.PLAYING and main.zapper(Players.P2) != null
			and main.zapper(Players.P2).asleep, "P2 asleep in the tire pile")
	_grow(COW)
	await flow._wait(1.0)
	await check("cow_grown", _size(COW) > 0, "cow size %d" % _size(COW))
	await _pause_open()
	await check("pause", Game.state == Game.State.PAUSED)
	await _menu_down(3)   # Resume -> Reset Yard -> Restart -> Settings
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_A)
	await flow._wait(0.4)
	for i in 5:   # Music 0.8 -> 0.3
		await flow.pad(SessionFlow.PAD1, JOY_BUTTON_DPAD_LEFT)
	await check("music_down", is_equal_approx(float(Save.get_setting("music_volume", 0.8)), 0.3),
			"music %s" % Save.get_setting("music_volume", 0.8))
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_B)
	await flow._wait(0.3)
	await _menu_down(1)   # Settings -> Back to Open Jar
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_A)
	await flow._wait(0.4)
	await check("door_asks", Game.state == Game.State.PAUSED, "Leave the game?")
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_DPAD_RIGHT)   # Stay -> Leave
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_A)
	await flow._wait(5.0)
	await check("door_leave_never_quit", false, "still running 5 s after Leave")
	get_tree().quit(3)


func _return() -> void:
	var music := float(Save.get_setting("music_volume", 0.8))
	var bus := db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))
	await check("settings_stuck", is_equal_approx(music, 0.3) and absf(bus - 0.3) < 0.02,
			"music setting %.2f, bus %.2f" % [music, bus])
	await check("pick_kept", Roster.pick(Players.P1) != Roster.default_for(Players.P1),
			"P1 is %s" % Roster.pick(Players.P1))
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_A)   # join and ready
	await _start_alone()
	await check("yard_as_left", _size(COW) > 0, "cow size %d" % _size(COW))
	await _pause_open()
	await _menu_down(1)   # Reset Yard
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_A)
	await flow.until(func() -> bool: return _size(COW) == 0, 10.0)
	await flow._wait(1.0)
	await check("fresh_yard_from_pause", _size(COW) == 0 and Game.state == Game.State.PLAYING,
			"cow size %d" % _size(COW))
	_grow(TIRE)
	await flow._wait(0.5)
	await check("tire_grown_then_close", _size(TIRE) > 0, "tire size %d, window closes now" % _size(TIRE))
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	await flow._wait(5.0)
	await check("close_never_quit", false, "still running 5 s after the window close")
	get_tree().quit(3)


func _return2() -> void:
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_A)
	await _start_alone()
	await check("close_kept_the_yard", _size(TIRE) > 0 and _size(COW) == 0,
			"tire %d, cow %d" % [_size(TIRE), _size(COW)])
	_grow(COW)
	await flow._wait(0.5)
	await check("cow_grown_waiting_for_kill", _size(COW) > 0)
	var f := FileAccess.open(out.path_join("return2.ready"), FileAccess.WRITE)
	f.store_string("kill me\n")
	f.close()


func _solo() -> void:
	await flow.until(func() -> bool: return Players.solo and Game.state == Game.State.PLAYING, 60.0)
	await flow._wait(1.0)
	await check("solo_flag_plays", Players.solo and Game.state == Game.State.PLAYING,
			"--solo readies both and starts")
	await flow.pad(SessionFlow.PAD2, JOY_BUTTON_A)
	await flow._wait(1.0)
	await check("second_pad_joins_solo", Players.device_of(Players.P2) == SessionFlow.PAD2
			and not Players.solo, "P2 device %d, solo %s" % [Players.device_of(Players.P2), Players.solo])
	get_tree().quit(0)


func _lobby_quit() -> void:
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_B)   # join, not ready
	# Play (Continue) -> [New yard, with a yard saved] -> Settings -> Back to Open Jar
	await _menu_down(3 if FreshStart.has_save() else 2)
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_A)
	await flow._wait(0.4)
	await check("lobby_door_asks", Game.state == Game.State.LOBBY, "Leave the game?")
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_DPAD_RIGHT)   # Stay -> Leave
	await flow.pad(SessionFlow.PAD1, JOY_BUTTON_A)
	await flow._wait(5.0)
	await check("lobby_leave_never_quit", false, "still running 5 s after Leave")
	get_tree().quit(3)
