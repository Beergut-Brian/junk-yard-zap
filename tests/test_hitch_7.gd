## S-18 steady frames (jyz-hitch-7). The 2026-11-18 GTX 1060 bench of v0.1.7-dev.8 (high, 60 cap,
## --bench-trace) said cause=process: the frames over 25 ms spent ~16 ms in process against ~8 ms on a
## normal frame. --bench-scripts (scripts/tools/script_trace.gd) split that per script, and on a renderer
## (lavapipe) it was three things, each done every frame whether or not anything changed:
##   the HUD redrew every frame, the whole goal card in vector art included (~2.9 ms, p99 11.7 ms),
##   the two hint panels redrew every frame (~2.4 ms),
##   48 object faces recomputed their whole pose every frame (~0.9 ms).
## Now each redraws or poses only when something it shows changes. These pin it: the work is gone when
## nothing changes (per-call counters), and every change still shows in the frame it happens.
class_name TestHitch7
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
var _clock := Clock.new()
const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")

var world: Node3D
var _main: Node
var _real_profile := ""
var _real_settings := ""
var _real_picks := ""


func before() -> void:
	_clock.pin()
	_real_profile = Save.profile
	Save.profile = "gdunit_hitch_7"   # main.tscn saves the yard: never the family's profile
	Save.wipe()
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_hitch_7.json"
	Save.wipe_settings()
	_real_picks = Roster.picks_path   # the defaults, never the family's picks
	Roster.picks_path = "user://test_hitch_7_players.json"
	Roster.args_override = PackedStringArray(["--no-picks"])
	Roster.reload()
	Game.quit_exits = false


func after() -> void:
	_clock.restore()
	Game.quit_exits = true
	Save.wipe()
	Save.profile = _real_profile
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Roster.picks_path = _real_picks
	Roster.args_override = PackedStringArray()
	Roster.reload()


func before_test() -> void:
	Save.wipe()
	Players.reset()
	Game.demo = false
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()
	Game.demo = false
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# --- object faces ---------------------------------------------------------------------------------

func _face(at: Vector3, yaw := 0.0) -> ObjectFace:
	var f := ObjectFace.new()
	world.add_child(f)
	f.set_process(false)   # the test steps it
	f.position = at
	f.rotation.y = yaw
	f.setup(0.35)
	return f


## Every part's pose, to compare two faces exactly.
static func _parts(f: ObjectFace) -> Array:
	var out := []
	for n: Node3D in f._eyes + f._pupils + f._brows + f._mouth + [f._sweat]:
		out.append([n.position, n.scale, n.rotation, n.visible])
	return out


func test_a_still_face_skips_its_pose_and_writes_nothing() -> void:
	var f := _face(Vector3.ZERO)
	f._blink = 100.0   # no blink in this window
	f._process(1.0 / 60.0)
	var poses := ObjectFace.poses
	var writes := ObjectFace.part_writes
	for i in 60:
		f._process(1.0 / 60.0)
	# The look glides back to ahead and settles; from then on a still face does nothing at all.
	var settle := ObjectFace.poses - poses
	poses = ObjectFace.poses
	writes = ObjectFace.part_writes
	for i in 120:
		f._process(1.0 / 60.0)
	assert_int(ObjectFace.poses - poses).override_failure_message("a still face posed (settled after %d)" % settle).is_equal(0)
	assert_int(ObjectFace.part_writes - writes).is_equal(0)
	# A change poses in the same call: a flash, then the blink.
	f.react(ObjectFace.Mood.WIDE, 0.5)
	f._process(1.0 / 60.0)
	assert_int(ObjectFace.poses - poses).is_equal(1)
	assert_float(f._eyes[0].scale.x).is_equal_approx(1.4, 0.0001)
	f._blink = 0.001
	f.react(ObjectFace.Mood.NEUTRAL, 0.0)
	f.set_base(ObjectFace.Mood.NEUTRAL)
	f._process(1.0 / 60.0)
	assert_float(f._eyes[0].scale.y).is_less(0.2)   # shut for the blink


func test_a_dizzy_or_panicked_face_still_moves_every_frame() -> void:
	var f := _face(Vector3.ZERO)
	for m in [ObjectFace.Mood.DIZZY, ObjectFace.Mood.PANIC]:
		f.set_base(m)
		f._process(1.0 / 60.0)
		var poses := ObjectFace.poses
		var before := _parts(f)
		for i in 10:
			f._process(1.0 / 60.0)
		assert_int(ObjectFace.poses - poses).is_equal(10)
		assert_bool(_parts(f) == before).is_false()


## The face posed only on a change against the same face posed every frame (the old code), through every
## mood, a blink, and a player walking up to it and away, on a face turned to one side: the same pose on
## every frame. The two faces draw blinks from the same RNG state, so they blink together.
func test_a_face_looks_the_same_as_posing_every_frame() -> void:
	var a := _face(Vector3(0, 1, 0), 0.7)
	var b := _face(Vector3(0, 1, 0), 0.7)
	var kid := Node3D.new()
	world.add_child(kid)
	kid.add_to_group(Zapper.GROUP)
	kid.position = Vector3(20, 0, 0)
	var moods := [ObjectFace.Mood.NEUTRAL, ObjectFace.Mood.HAPPY, ObjectFace.Mood.WIDE, ObjectFace.Mood.DIZZY,
			ObjectFace.Mood.SMUG, ObjectFace.Mood.PANIC, ObjectFace.Mood.SHUT, ObjectFace.Mood.SAD, ObjectFace.Mood.NEUTRAL]
	var dt := 1.0 / 60.0
	var frame := 0
	for m in moods:
		a.set_base(m)
		b.set_base(m)
		for i in 50:
			frame += 1
			# the kid walks in for a while and out again, sometimes standing still
			if frame % 90 < 40:
				kid.position = kid.position.move_toward(Vector3(1.5, 0, 2.0), 0.3)
			elif frame % 90 > 60:
				kid.position = kid.position.move_toward(Vector3(20, 0, 0), 0.4)
			if frame % 77 == 0:
				a.react(ObjectFace.Mood.WIDE, 0.3)
				b.react(ObjectFace.Mood.WIDE, 0.3)
			var rng := ObjectFace._rng.state
			a._process(dt)
			ObjectFace._rng.state = rng
			b._process(dt)
			b._pose(dt)   # the old code: a full pose every frame
			assert_bool(_parts(a) == _parts(b)).override_failure_message(
					"frame %d mood %d: %s vs %s" % [frame, m, _parts(a), _parts(b)]).is_true()
			assert_bool(a.watching()).is_equal(b.watching())


# --- HUD and hint panels --------------------------------------------------------------------------

func _boot_two() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	(_main.get_node("UI/Lobby") as Lobby).count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	await frames(3)


func _hud() -> Hud:
	return _main.get_node("UI/Hud")


func _hint(p: int) -> HintPanel:
	return _hud().get_node("HintP%d" % (p + 1))


## Redraws of the HUD, its card layer and both hint panels over n frames, counted through their draw
## signals.
class Draws:
	var hud := 0
	var card := 0
	var hint := [0, 0]


func _count(n: int) -> Draws:
	var d := Draws.new()
	var on_hud := func() -> void: d.hud += 1
	var on_card := func() -> void: d.card += 1
	var on_h1 := func() -> void: d.hint[0] += 1
	var on_h2 := func() -> void: d.hint[1] += 1
	_hud().draw.connect(on_hud)
	_hud()._card_layer.draw.connect(on_card)
	_hint(P1).draw.connect(on_h1)
	_hint(P2).draw.connect(on_h2)
	await frames(n)
	_hud().draw.disconnect(on_hud)
	_hud()._card_layer.draw.disconnect(on_card)
	_hint(P1).draw.disconnect(on_h1)
	_hint(P2).draw.disconnect(on_h2)
	return d


func test_the_goal_card_draws_on_a_layer_behind_the_hud() -> void:
	await _boot_two()
	var layer := _hud()._card_layer
	assert_bool(layer.show_behind_parent).is_true()   # under the HUD's own drawing, as when it opened _draw
	assert_object(layer.get_parent()).is_same(_hud())
	assert_int(layer.get_index()).is_less(_hint(P1).get_index())   # hint rows stay on top
	assert_int(layer.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_a_still_hud_and_hint_rows_do_not_redraw() -> void:
	await _boot_two()
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	await frames(30)   # the spawn settles
	var d: Draws = await _count(30)
	assert_int(d.card).override_failure_message("the card redrew %d times" % d.card).is_equal(0)
	assert_int(d.hud).override_failure_message("the hud redrew %d times" % d.hud).is_less_equal(1)
	assert_int(d.hint[0] + d.hint[1]).override_failure_message("hint rows redrew %s" % [d.hint]).is_less_equal(2)


func test_a_card_event_redraws_the_card_every_frame_until_it_ends() -> void:
	await _boot_two()
	await frames(30)
	var hud := _hud()
	var id: StringName = hud.level.deck.current().id
	hud._card_event("done", id)
	var during: Draws = await _count(10)
	assert_int(during.card).is_greater_equal(9)   # the slam, the glow, the confetti: every frame
	hud._process(Hud.CARD_DONE)   # the event's time is up (headless frames are not 1/60 s)
	await frames(2)
	var after: Draws = await _count(20)
	assert_int(after.card).is_equal(0)
	assert_str(hud.card_mode).is_equal("")


func test_every_hud_change_redraws_in_its_frame() -> void:
	await _boot_two()
	await frames(30)
	var hud := _hud()
	# the gun wheel over a player, and the corner badge's punch
	hud.show_wheel(P1)
	var d: Draws = await _count(5)
	assert_int(d.hud).is_equal(5)
	hud._process(Hud.WHEEL_TIME + 5.0)   # the wheel and the badge's punch are over
	await frames(2)
	d = await _count(10)
	assert_int(d.hud).is_less_equal(1)
	# a first-fire beat
	var z: Zapper = hud._zapper(P1)
	hud._beats.append({"player": P1, "gun": z.gun(), "age": 0.0})
	d = await _count(5)
	assert_int(d.hud).is_equal(5)
	hud._process(Hud.BEAT_TIME + 0.1)
	await frames(2)
	# a card done: the done pile's star is on the card layer, the HUD itself doesn't redraw for it
	hud.level.deck.done.append(hud.level.deck.current().id)
	d = await _count(2)
	assert_int(d.card).is_equal(1)
	assert_int(d.hud).is_less_equal(1)
	# solo: the pad's player gets a marker
	Players.solo = true
	Players.solo_focus = P2
	d = await _count(2)
	assert_int(d.hud).is_greater_equal(1)
	assert_int(d.hint[0]).is_greater_equal(1)   # P1's row goes quiet (half alpha)
	Players.solo = false


func test_a_refused_press_shakes_the_hint_row_every_frame() -> void:
	await _boot_two()
	await frames(30)
	var z: Zapper = _hud()._zapper(P2)
	z.noped.emit(P2)
	var d: Draws = await _count(10)   # headless frames are short: all 10 are inside the shake
	assert_float(_hint(P2).since_nope).is_less(HintPanel.NOPE_TIME)
	assert_int(d.hint[1]).is_equal(10)
	_hint(P2).since_nope = HintPanel.NOPE_TIME   # the shake is over
	await frames(2)
	d = await _count(10)
	assert_int(d.hint[1]).is_less_equal(1)


func test_a_hint_row_redraws_when_its_context_changes() -> void:
	await _boot_two()
	await frames(30)
	var hp := _hint(P1)
	var before: int = hp.hint["context"]
	hp.since_zap = 0.0   # a zap: the cooldown beat
	hp.zapper._refused = false
	var d: Draws = await _count(1)
	assert_int(hp.hint["context"]).is_not_equal(before)
	assert_int(d.hint[0]).is_equal(1)


# --- the bench's per-script split ------------------------------------------------------------------

func test_script_trace_flag() -> void:
	assert_bool(ScriptTrace.wanted(PackedStringArray(["--bench", "--bench-trace", "--bench-scripts"]))).is_true()
	assert_bool(ScriptTrace.wanted(PackedStringArray(["--bench", "--bench-trace"]))).is_false()


## Two groups with known costs: the split names them, their own time and the redraw they queue.
class _Busy extends Node:
	var usec := 0
	func _process(_d: float) -> void:
		var t := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t < usec:
			pass


func test_script_trace_splits_process_by_script() -> void:
	var slow := _Busy.new()
	slow.usec = 1500
	world.add_child(slow)
	var st := ScriptTrace.new()
	world.add_child(st)
	await frames(12)
	var t := st.table()
	assert_int(st.frames.size()).is_greater(5)
	# the busy node's group comes first, with its 1.5 ms a frame
	assert_int(t[0].nodes).is_equal(1)
	assert_float(t[0].own).is_greater(1.3)
	assert_str("\n".join(st.lines())).contains("BENCH-SCRIPTS counters").contains("BENCH-SCRIPTS " + t[0].key)
	var prio := slow.process_priority
	st.free()
	assert_int(slow.process_priority).is_equal(0)   # every node gets its own priority back
	assert_int(prio).is_not_equal(0)


func test_script_trace_flag_runs_with_the_bench_and_prints_its_lines() -> void:
	var scratch := ProjectSettings.globalize_path("user://script_trace_child")
	DirAccess.make_dir_recursive_absolute(scratch)
	var out := []
	var cmd := "XDG_DATA_HOME='%s' timeout 150 '%s' --headless --path '%s' -- --bench --bench-seconds=2 --bench-trace='%s' --bench-scripts 2>&1" % [
			scratch, OS.get_executable_path(), ProjectSettings.globalize_path("res://"), scratch.path_join("t.csv")]
	var code := OS.execute("bash", ["-c", cmd], out)
	var text: String = "\n".join(out)
	OS.execute("rm", ["-rf", "--", scratch])
	assert_int(code).override_failure_message("exit %d\n%s" % [code, text.right(2000)]).is_equal(0)
	assert_str(text).contains("BENCH-TRACE slow=").contains("BENCH-SCRIPTS counters per_frame:") \
			.contains("BENCH-SCRIPTS object_face.gd").contains("BENCH-SCRIPTS hud.gd")
	assert_str(text).not_contains("SCRIPT ERROR")
