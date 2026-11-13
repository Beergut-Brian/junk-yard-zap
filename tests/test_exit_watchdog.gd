## PF-6 (gap-close-5): closing the game seconds after launch, a save present, hung the exported build at
## exit (the engine's own shutdown waited forever in WorkerThreadPool::exit_languages_threads()). Game.quit()
## now writes the save, arms an exit watchdog, then quits. These tests prove: the save is on disk before
## the tree quits; the watchdog fires after its grace and not before; and, in real child processes with a
## save present, the quit path ends the process: exit 0 when the engine shuts down cleanly, and ended by
## the watchdog within its grace when the shutdown is made to block forever.
class_name TestExitWatchdog
extends GdUnitTestSuite

const PROFILE := "gdunit_pf6"
const CHILD_PROFILE := "pf6child"

var _real_profile := ""
var _fired := 0


func before() -> void:
	_real_profile = Save.profile
	Save.profile = PROFILE
	Save.wipe()


func after() -> void:
	Save.wipe()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % PROFILE))
	Save.profile = _real_profile
	Game.quit_exits = true


func test_quit_writes_the_save_before_the_tree_quits() -> void:
	Game.quit_exits = false
	Save.set_value("pf6", 7)
	var heard := [false]
	var on_quit := func() -> void: heard[0] = true
	Game.quit_requested.connect(on_quit)
	Game.quit()
	Game.quit_requested.disconnect(on_quit)
	Game.quit_exits = true
	assert_bool(heard[0]).is_true()
	var text := FileAccess.get_file_as_string("user://saves/%s.json" % PROFILE)
	var data = JSON.parse_string(text)
	assert_bool(data is Dictionary).is_true()
	assert_int(int(data.get("pf6", 0))).is_equal(7)


func test_exit_watchdog_fires_after_its_grace_and_not_before() -> void:
	_fired = 0
	var t := Game.arm_exit_watchdog(300, func() -> void: _fired += 1)
	await get_tree().create_timer(0.1).timeout
	assert_int(_fired).override_failure_message("fired before its grace").is_equal(0)
	t.wait_to_finish()   # returns once the 300 ms sleep is over and on_overdue ran
	assert_int(_fired).is_equal(1)


func test_exit_grace_covers_a_clean_shutdown() -> void:
	# A clean shutdown took 1.5-3.5 s from quit() to exit on the software renderer (handoff/REPORT.md);
	# the grace must leave room for that, and still let the launcher resume within seconds.
	assert_int(Game.EXIT_GRACE_MS).is_between(5000, 10000)


## Runs the project in a child process (headless) on a scratch XDG_DATA_HOME with a save present,
## through the player-flow phase `phase`. Returns [ended, exit_code, seconds, save_text].
func _run_child(phase: String, limit_s: float) -> Array:
	var root := ProjectSettings.globalize_path("user://pf6_child_%s" % phase)
	var out := root.path_join("out")
	var saves := root.path_join("godot/app_userdata/%s/saves" % ProjectSettings.get_setting("application/config/name"))
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.make_dir_recursive_absolute(saves)
	var save_path := saves.path_join(CHILD_PROFILE + ".json")
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"pf6_marker": 1}))   # a returning player: a save is present
	f.close()
	var real_xdg := OS.get_environment("XDG_DATA_HOME")
	OS.set_environment("XDG_DATA_HOME", root)
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"), "--profile=" + CHILD_PROFILE,
			"--", "--player-flow=" + phase, "--flow-out=" + out]))
	if real_xdg.is_empty():
		OS.unset_environment("XDG_DATA_HOME")
	else:
		OS.set_environment("XDG_DATA_HOME", real_xdg)
	assert_int(pid).is_greater(0)
	var start := Time.get_ticks_msec()
	while OS.is_process_running(pid) and Time.get_ticks_msec() - start < limit_s * 1000.0:
		await get_tree().create_timer(0.25).timeout
	var ended := not OS.is_process_running(pid)
	var secs := (Time.get_ticks_msec() - start) / 1000.0
	if not ended:
		OS.kill(pid)
	var code := OS.get_process_exit_code(pid) if ended else -999
	var text := FileAccess.get_file_as_string(save_path)
	var flow := FileAccess.get_file_as_string(out.path_join(phase + ".txt"))
	OS.execute("rm", ["-rf", "--", root])
	return [ended, code, secs, text, flow]


func test_closing_on_the_title_screen_with_a_save_ends_the_process_with_code_0() -> void:
	var r: Array = await _run_child("close_early", 90.0)
	assert_bool(r[0]).override_failure_message("still running after 90 s (PF-6)").is_true()
	assert_int(r[1]).override_failure_message("exit code %d" % r[1]).is_equal(0)
	assert_str(r[4]).contains("PASS")   # it really reached the title screen and closed from there
	var data = JSON.parse_string(r[3])
	assert_bool(data is Dictionary and data.has("pf6_marker")).override_failure_message(r[3]).is_true()


func test_a_shutdown_that_never_ends_is_ended_by_the_watchdog() -> void:
	var r: Array = await _run_child("hang_exit", 90.0)
	assert_bool(r[0]).override_failure_message("still running after 90 s: the watchdog never fired").is_true()
	assert_int(r[1]).override_failure_message("exit code %d: a clean exit means the hang never happened" % r[1]) \
			.is_not_equal(0)
	assert_str(r[4]).contains("PASS")   # it reached the title screen and closed from there
	var data = JSON.parse_string(r[3])
	assert_bool(data is Dictionary and data.has("pf6_marker")).override_failure_message(r[3]).is_true()
