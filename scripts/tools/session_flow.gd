## Scripted full session, driven by synthetic pad events (the same path a real pad takes):
## boot -> lobby -> chooser (catchphrase, a full lap of the roster) -> lobby settings -> lobby door (stay) -> ready -> play
## (zap, gun wheel, jump, Select tap / hold reset) -> drop-out / drop-in -> pause -> settings -> back -> Reset Yard ->
## Restart -> solo (Select+Start 2 s, swap, play, off) -> pause door (leave) and a window close
## at every screen. Each step records ok / note and, with a renderer, a real frame.
##   scripts/tools/session_flow.sh <out_dir>        (real frames + flow.txt)
## tests/test_session_flow.gd runs the same steps headless (no frames).
## Never touches the family's save, settings or shared picks: the caller points those elsewhere.
class_name SessionFlow
extends Node

const PAD1 := 20   # synthetic device ids, never a real pad's
const PAD2 := 21

var main: Node
var shot_dir := ""
var steps: Array[Dictionary] = []
var quits := 0
var _n := 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _lobby() -> Node:
	return main.get_node("UI/Lobby")


func _pause() -> Node:
	return main.get_node("UI/PauseMenu")


func _on_quit() -> void:
	quits += 1


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


## Note for readers: a press is held across two physics ticks, because gameplay (gun wheel, jump)
## reads "just pressed" in _physics_process and an uncapped headless run can draw frames without one.
func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


## A press and release. Injected at the top of a frame: after a timer resumes us, that frame's
## _process has already run and a "just pressed" would be missed.
## Waits until cond() is true or timeout real seconds pass (the software renderer draws a frame
## every few hundred ms, so fixed waits are not enough there). Returns cond().
func until(cond: Callable, timeout := 20.0) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not cond.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	return cond.call()


func pad(device: int, button: JoyButton, hold := 0.0) -> void:
	await get_tree().process_frame
	_button(device, button, true)
	await _frames(2)
	await get_tree().physics_frame   # gameplay reads the pad in physics time
	await get_tree().physics_frame
	if hold > 0.0:
		await _wait(hold)
	_button(device, button, false)
	await _frames(2)


## Select + Start held for SOLO_HOLD. Players polls Input.get_connected_joypads(), which a synthetic
## pad is not in, so feed its hold rule for this pad the way that poll does, once a frame.
func hold_select_start(device: int) -> void:
	await get_tree().process_frame
	_button(device, JOY_BUTTON_BACK, true)
	_button(device, JOY_BUTTON_START, true)
	var t := 0.0
	var last := Time.get_ticks_usec()
	while t < Players.SOLO_HOLD + 0.3:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000000.0
		last = now
		t += dt
		Players.hold_step(device, true, dt, true)
	_button(device, JOY_BUTTON_START, false)
	_button(device, JOY_BUTTON_BACK, false)
	Players.hold_step(device, false, 0.0, false)
	await _frames(4)


func _button(device: int, button: JoyButton, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func check(step: String, ok: bool, note := "") -> bool:
	_n += 1
	if not ok:
		note += " [state=%s paused=%s solo=%s]" % [Game.State.keys()[Game.state], get_tree().paused, Players.solo]
	var name := "%02d_%s" % [_n, step]
	if shot_dir != "" and DisplayServer.get_name() != "headless":
		await _wait(0.6)   # let slides and pops settle before the frame
		await _frames(2)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	steps.append({ "step": name, "ok": ok, "note": note })
	print("flow: %s %s %s" % ["PASS" if ok else "FAIL", name, note])
	return ok


## A window close (the launcher's or Alt+F4) on this screen: Game asks for a clean quit.
func close_window(screen: String) -> void:
	var before := quits
	Game.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	await _frames(1)
	steps.append({ "step": "close@" + screen, "ok": quits == before + 1, "note": "WM close -> Game.quit" })
	print("flow: %s close@%s" % ["PASS" if quits == before + 1 else "FAIL", screen])


func _stop(why: String) -> void:
	steps.append({ "step": "stopped", "ok": false, "note": why })
	print("flow: FAIL stopped: " + why)
	Game.quit_requested.disconnect(_on_quit)


func failures() -> Array[Dictionary]:
	return steps.filter(func(s: Dictionary) -> bool: return not s.ok)


func run(main_scene: Node) -> void:
	main = main_scene
	Game.quit_requested.connect(_on_quit)
	var lobby := _lobby()
	await _frames(10)
	await check("boot_lobby", Game.state == Game.State.LOBBY and lobby.visible, "state LOBBY, lobby shown")
	await close_window("lobby")

	# Chooser: join with B (in, not ready), D-pad right picks the next free Jarling, then its catchphrase.
	var first := Roster.pick(Players.P1)
	await pad(PAD1, JOY_BUTTON_B)
	await pad(PAD1, JOY_BUTTON_DPAD_RIGHT)
	await until(func() -> bool: return str(Roster.last_said.get(Players.P1, "")) != "", 5.0)
	var said: Variant = Roster.last_said.get(Players.P1, "")
	await check("chooser_pick_and_catchphrase", Players.device_of(Players.P1) == PAD1
			and Roster.pick(Players.P1) != first and str(said) != "",
			"P1 %s -> %s, said %s" % [first, Roster.pick(Players.P1), str(said).get_file()])
	await close_window("chooser")

	# The whole roster, one D-pad step at a time: every playable Jarling comes up once and says its
	# own catchphrase; the lap comes back round to where it started (roster v0.5.3: 22 Jarlings).
	var start := Roster.pick(Players.P1)
	var seen := {}
	var spoke := 0
	var has_none := 0   # fixture Jarlings with no catchphrase file (the real roster has none of these)
	var wrong := PackedStringArray()
	var free := Roster.roster().filter(func(r: String) -> bool: return not Roster.taken(r, Players.P1))
	for i in Roster.roster().size() + 1:
		Roster.last_said.erase(Players.P1)
		await pad(PAD1, JOY_BUTTON_DPAD_RIGHT)
		await until(func() -> bool: return str(Roster.last_said.get(Players.P1, "")) != "", 3.0)
		var id := Roster.pick(Players.P1)
		var line := str(Roster.last_said.get(Players.P1, ""))
		var phrase := str(Roster.info(id).get("catchphrase", ""))
		if phrase != "" and ResourceLoader.exists(phrase):
			# Has a catchphrase file: it must be the line (else the chooser falls back to a bark).
			if line == phrase:
				spoke += 1
			else:
				wrong.append(id)
		else:
			has_none += 1
		seen[id] = true
		if id == start:
			break
	await check("chooser_full_lap", seen.size() == free.size() and spoke + has_none == seen.size()
			and wrong.is_empty() and Roster.pick(Players.P1) == start,
			"%d / %d Jarlings, %d catchphrases, %d without one, wrong voice %s"
			% [seen.size(), free.size(), spoke, has_none, wrong])

	# Lobby settings and back.
	await pad(PAD1, JOY_BUTTON_DPAD_DOWN)
	await pad(PAD1, JOY_BUTTON_A)
	var settings: Node = lobby.get_node("Settings")
	await _wait(0.4)
	await check("lobby_settings_open", settings.active)
	await close_window("lobby_settings")
	await pad(PAD1, JOY_BUTTON_B)
	await _wait(0.3)
	await check("lobby_settings_back", not settings.active and lobby.visible)

	# Lobby door: asks first, B stays.
	await pad(PAD1, JOY_BUTTON_DPAD_DOWN)
	await pad(PAD1, JOY_BUTTON_A)
	var confirm: Node = lobby.get_node("Confirm")
	await _wait(0.3)
	var q := quits
	await check("lobby_door_asks", confirm.active and quits == q)
	await close_window("lobby_door")
	q = quits
	await pad(PAD1, JOY_BUTTON_B)
	await pad(PAD1, JOY_BUTTON_B)   # focus back to Play
	await check("lobby_door_stay", not confirm.active and quits == q and Game.state == Game.State.LOBBY)

	# Two players ready, countdown, play.
	await pad(PAD1, JOY_BUTTON_A)
	await pad(PAD2, JOY_BUTTON_A)
	await check("two_ready_countdown", lobby.counting, "P2 joined on A and readied")
	await until(func() -> bool: return Game.state == Game.State.PLAYING and main.zapper(Players.P2) != null)
	await _wait(0.5)
	if not await check("playing_two", Game.state == Game.State.PLAYING and main.zapper(Players.P1) != null
			and main.zapper(Players.P2) != null and not main.zapper(Players.P2).asleep):
		return _stop("never reached play")
	await close_window("play")

	# Play: gun wheel, zap, jump.
	var z1: Zapper = main.zapper(Players.P1)
	var gun := z1.gun_index
	await pad(PAD1, JOY_BUTTON_RIGHT_SHOULDER)
	await _wait(0.3)
	await check("gun_wheel", z1.gun_index != gun, "gun %d -> %d" % [gun, z1.gun_index])
	await pad(PAD1, JOY_BUTTON_A, 0.2)
	await pad(PAD1, JOY_BUTTON_B, 0.3)
	await _wait(0.4)
	await check("zap_and_jump", Game.state == Game.State.PLAYING)

	# Select: a tap does nothing; held 1.5 s the ring fills and the yard resets (whoosh and bell).
	Audio.history.clear()
	await pad(PAD1, JOY_BUTTON_BACK)
	await _wait(0.3)
	await check("select_tap_no_reset", not Audio.played("reset_yard"))
	_button(PAD1, JOY_BUTTON_BACK, true)
	await until(func() -> bool: return z1.reset_held >= Zapper.RESET_HOLD * 0.5, 5.0)
	await check("select_hold_ring", z1.reset_held > 0.0 and not Audio.played("reset_yard"),
			"held %.2f s" % z1.reset_held)
	await until(func() -> bool: return Audio.played("reset_yard"), 5.0)
	_button(PAD1, JOY_BUTTON_BACK, false)
	# Players polls Input.get_connected_joypads() for the Select release, which a synthetic pad is
	# not in: feed it the way that poll does, or the spent Select would block the solo hold below.
	Players.hold_step(PAD1, false, 0.0, false)
	await _frames(2)
	await check("select_hold_resets", Audio.played("reset_yard") and Game.state == Game.State.PLAYING)

	# Drop-out (pad unplugged) and drop-in (press on it again).
	Players._on_joy_connection_changed(PAD2, false)
	await until(func() -> bool: return main.zapper(Players.P2) != null and main.zapper(Players.P2).asleep, 5.0)
	var z2: Zapper = main.zapper(Players.P2)
	await check("p2_drops_out_to_tire_pile", z2 != null and z2.asleep)
	await pad(PAD2, JOY_BUTTON_A)
	await until(func() -> bool: return main.zapper(Players.P2) != null and not main.zapper(Players.P2).asleep, 5.0)
	await check("p2_drops_back_in", main.zapper(Players.P2) != null and not main.zapper(Players.P2).asleep)

	# Pause -> settings -> back -> resume.
	var pm := _pause()
	await pad(PAD1, JOY_BUTTON_START)
	await _wait(0.5)
	await check("pause", Game.state == Game.State.PAUSED and pm.visible)
	await close_window("pause")
	pm._set_focus(pm.Choice.SETTINGS, false)
	await pad(PAD1, JOY_BUTTON_A)
	await _wait(0.4)
	var psettings: Node = pm.get_node("Settings")
	await check("pause_settings", psettings.active)
	await close_window("pause_settings")
	await pad(PAD1, JOY_BUTTON_B)
	await _wait(0.2)
	await check("pause_settings_back", not psettings.active and Game.state == Game.State.PAUSED)
	await pad(PAD1, JOY_BUTTON_B)
	await _wait(0.3)
	await check("resume_with_b", Game.state == Game.State.PLAYING and not get_tree().paused)

	# Pause -> Reset Yard: back in the yard, reset.
	await pad(PAD1, JOY_BUTTON_START)
	await _wait(0.3)
	pm._set_focus(pm.Choice.RESET, false)
	await pad(PAD1, JOY_BUTTON_A)
	await until(func() -> bool: return Audio.played("reset_yard"), 5.0)
	await check("pause_reset_yard", Game.state == Game.State.PLAYING and Audio.played("reset_yard"))

	# Pause -> Restart: back to the lobby, pads still joined.
	await pad(PAD1, JOY_BUTTON_START)
	await _wait(0.3)
	pm._set_focus(pm.Choice.RESTART, false)
	await pad(PAD1, JOY_BUTTON_A)
	await until(func() -> bool: return Game.state == Game.State.LOBBY, 5.0)
	await _wait(0.4)
	await check("restart_to_lobby", Game.state == Game.State.LOBBY and lobby.visible
			and Players.is_active(Players.P1) and Players.is_active(Players.P2))

	# Solo: P2 unplugs, P1 holds Select+Start 2 s, then readies both and plays.
	Players._on_joy_connection_changed(PAD2, false)
	await _frames(4)
	await hold_select_start(PAD1)
	await check("solo_on", Players.solo)
	await until(func() -> bool: return Game.state == Game.State.PLAYING and main.zapper(Players.P1) != null)
	await _wait(0.5)
	await check("solo_playing", Game.state == Game.State.PLAYING, "solo readies both")
	var focus := Players.solo_focus
	await get_tree().process_frame
	_button(PAD1, JOY_BUTTON_LEFT_SHOULDER, true)
	_button(PAD1, JOY_BUTTON_RIGHT_SHOULDER, true)
	await _frames(2)
	await pad(PAD1, JOY_BUTTON_BACK)
	_button(PAD1, JOY_BUTTON_RIGHT_SHOULDER, false)
	_button(PAD1, JOY_BUTTON_LEFT_SHOULDER, false)
	await _wait(0.4)
	await check("solo_swap", Players.solo_focus != focus)
	await close_window("solo_play")
	await hold_select_start(PAD1)
	if Game.state == Game.State.PAUSED:   # Start went down with Select: the pause is expected
		Game.resume()
	await check("solo_off", not Players.solo)

	# Pause door: asks, Leave quits cleanly (Game.quit -> exit code 0 for the launcher).
	await pad(PAD1, JOY_BUTTON_START)
	await _wait(0.3)
	pm._set_focus(pm.Choice.DOOR, false)
	await pad(PAD1, JOY_BUTTON_A)
	await _wait(0.3)
	var pconfirm: Node = pm.get_node("Confirm")
	q = quits
	await check("pause_door_asks", pconfirm.active and quits == q)
	pconfirm.move_focus(1)   # Stay is first; one step to Leave
	await pad(PAD1, JOY_BUTTON_A)
	await check("pause_door_leave_quits", quits == q + 1)
	Game.quit_requested.disconnect(_on_quit)
