## Controls lane (jyz-controls-1), playtest 2026-11-10 items 4 and 5 (GAME.md "Playtest 2026-11-10
## changes"): reset the yard by holding Select (ring by the player, a tap does nothing), from the
## pause menu, and on the big lit sign; Select + Start for solo never triggers a reset and a reset
## never triggers solo, in either order; variable jump (tap = short hop, hold = higher, capped).
## Own settings file and picks file, fixture roster (Jeff and Chuck only).
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
var _clock := Clock.new()   # 60 Hz, time scale 1: frame counts below mean the same seconds everywhere

const P1 := Players.P1
const P2 := Players.P2
const IDLE := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false,
		"prev": false, "reset": false, "start": false}
const FIXTURE := "res://tests/fixtures/roster_two.json"
const PAD := 0
const DT := 1.0 / 60.0
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")

var world: Node3D
var _real_settings := ""
var _real_picks := ""
var _real_data := ""


func before() -> void:
	_clock.pin()
	Save.profile = "gdunit"
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_controls.json"
	Save.wipe_settings()
	_real_data = Roster.data_path
	_real_picks = Roster.picks_path
	Roster.data_path = FIXTURE
	Roster.picks_path = "user://test_controls_players.json"
	Roster.args_override = PackedStringArray(["--no-picks"])
	Roster.reload()


func after() -> void:
	_clock.restore()
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Roster.data_path = _real_data
	Roster.picks_path = _real_picks
	Roster.args_override = PackedStringArray()
	Roster.reload()


func before_test() -> void:
	Players.reset()
	Game.demo = false
	Game.start_round()
	Audio.history.clear()
	world = Node3D.new()
	add_child(world)
	world.add_child(YardStrip.new())


func after_test() -> void:
	get_tree().paused = false
	if Game.state != Game.State.PLAYING:
		Game.start_round()
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func zapper(player: int, x: float, y := 0.05) -> Zapper:
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	z.player = player
	z.position = Vector3(x, y, 0)
	world.add_child(z)
	z.input_override = IDLE.duplicate()
	return z


func level() -> YardLevel:
	world.get_child(0).free()   # the strip: the level has its own ground
	var l := YardLevel.new()
	l.use_save = false
	l.layout = load(YardLevel.LAYOUT)
	world.add_child(l)
	var players := Node3D.new()
	players.name = "Players"
	l.add_child(players)
	return l


## Jumps each zapper at once with B held for its hold_frames; returns each apex height above
## where it started.
func jump_peaks(zs: Array, holds: Array, frames := 150) -> Array:
	await step(20)   # settle on the floor
	var y0: Array = zs.map(func(z: Zapper) -> float: return z.global_position.y)
	var peak: Array = y0.duplicate()
	for i in frames:
		for k in zs.size():
			zs[k].input_override["jump"] = i < holds[k]
		await get_tree().physics_frame
		for k in zs.size():
			peak[k] = maxf(peak[k], zs[k].global_position.y)
	for z in zs:
		z.input_override["jump"] = false
	var out := []
	for k in zs.size():
		out.append(peak[k] - y0[k])
	return out


# --------------------------------------------------------------------------------- variable jump

func test_jump_numbers_live_in_data() -> void:
	var jt := load(Zapper.JUMP_DATA) as JumpTuning
	assert_object(jt).is_not_null()
	var z := zapper(P1, -3.0)
	await step(2)
	assert_str(z.jump_tuning.resource_path).is_equal(Zapper.JUMP_DATA)
	# A tap is a real hop (onto a crate) but well under a third of the full jump.
	assert_float(jt.hop_height()).is_between(0.7, 1.4)
	assert_float(jt.cap_height()).is_greater(jt.hop_height() * 3.0)


func test_tap_is_a_short_hop_and_hold_goes_higher() -> void:
	var tapper := zapper(P1, -4.0)
	var holder := zapper(P2, 4.0)
	var pk: Array = await jump_peaks([tapper, holder], [2, 90])
	var t: float = pk[0]
	var h: float = pk[1]
	assert_float(t).is_between(0.6, 1.6)
	assert_float(h).is_greater(3.0)
	assert_float(h).is_greater(t * 3.0)
	assert_bool(Audio.played("jump")).is_true()   # every jump still has its sound


func test_letting_go_halfway_is_in_between() -> void:
	var z := zapper(P1, 0.0)
	var mid: float = (await jump_peaks([z], [15]))[0]   # 0.25 s
	var jt := z.jump_tuning
	assert_float(mid).is_greater(jt.hop_height() + 0.4)
	assert_float(mid).is_less(jt.cap_height() - 0.4)


## Holding past the top doesn't go higher: the cap. Jeff and Chuck jump the same.
func test_hold_is_capped_and_both_characters_match() -> void:
	var jeff := zapper(P1, -4.0)
	var chuck := zapper(P2, 4.0)
	await step(2)
	assert_str(String(jeff.rig.character)).is_equal("jeff")
	assert_str(String(chuck.rig.character)).is_equal("chuck")
	var pk: Array = await jump_peaks([jeff, chuck], [90, 200], 220)
	var ha: float = pk[0]
	var hb: float = pk[1]
	assert_float(absf(ha - hb)).is_less(0.08)
	assert_float(ha).is_less(jeff.jump_tuning.cap_height() + 0.15)


## Still forgiving: B pressed just before landing still jumps (buffered), as a hop if it's let go.
func test_buffered_tap_before_landing_still_hops() -> void:
	var z := zapper(P1, 0.0, 2.0)
	for i in 120:
		await get_tree().physics_frame
		if not z.is_on_floor() and z.velocity.y < 0.0 and z.global_position.y < 0.35:
			break
	z.input_override["jump"] = true
	await step(2)
	z.input_override["jump"] = false
	var peak := z.global_position.y
	for i in 60:
		await get_tree().physics_frame
		peak = maxf(peak, z.global_position.y)
	assert_float(peak).is_between(0.6, 1.8)


## Works standing on objects: the same tap/hold difference off the top of a crate.
func test_variable_jump_works_on_objects() -> void:
	var crate := PhysicsObject.new(ObjectData.make(&"box", ObjectData.Shape.BOX, Vector3(1.4, 1.0, 1.4), 1.0, Color.TAN))
	crate.position = Vector3(-4.0, 0.5, 0)
	world.add_child(crate)
	var crate2 := PhysicsObject.new(ObjectData.make(&"box", ObjectData.Shape.BOX, Vector3(1.4, 1.0, 1.4), 1.0, Color.TAN))
	crate2.position = Vector3(4.0, 0.5, 0)
	world.add_child(crate2)
	await step(30)
	var tapper := zapper(P1, -4.0, 1.2)
	var holder := zapper(P2, 4.0, 1.2)
	await step(20)
	assert_float(tapper.global_position.y).is_greater(0.8)   # standing on the crate
	var pk: Array = await jump_peaks([tapper, holder], [2, 90])
	var t: float = pk[0]
	var h: float = pk[1]
	assert_float(t).is_between(0.5, 1.6)
	assert_float(h).is_greater(t * 2.5)


# ------------------------------------------------------------------------------ reset: Select hold

func test_select_is_a_player_action_on_the_back_button() -> void:
	assert_bool(Players.ACTIONS.has("reset")).is_true()
	for p in [P1, P2]:
		var pad := false
		for ev in InputMap.action_get_events(Players.action(p, "reset")):
			if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_BACK:
				pad = true
		assert_bool(pad).is_true()


func test_a_select_tap_does_nothing() -> void:
	var l := level()
	var z := zapper(P1, -20.0)
	l.register_zapper(z)
	await step(5)
	z.input_override["reset"] = true
	await step(30)   # 0.5 s
	assert_float(z.reset_progress()).is_between(0.25, 0.4)
	assert_bool(Audio.played("reset_hold")).is_true()   # the tap still answers: ratchet and ring
	z.input_override["reset"] = false
	await step(3)
	assert_float(z.reset_progress()).is_equal(0.0)
	assert_int(l.resets).is_equal(0)


func test_holding_select_resets_once_with_whoosh_and_bell() -> void:
	var l := level()
	var z := zapper(P1, -20.0)
	l.register_zapper(z)
	await step(5)
	var crate := l.object(&"crate")
	crate.global_position += Vector3(3, 2, 0)
	z.input_override["reset"] = true
	await step(int(Zapper.RESET_HOLD * 60) - 10)
	assert_int(l.resets).is_equal(0)
	await step(15)
	assert_int(l.resets).is_equal(1)
	assert_bool(Audio.played("reset_yard")).is_true()   # whoosh and two bells (assets/audio/CUES.md)
	assert_bool(l.object(&"crate") != crate).is_true()
	await step(150)   # still holding: once per press
	assert_int(l.resets).is_equal(1)
	z.input_override["reset"] = false
	await step(2)
	z.input_override["reset"] = true
	await step(int(Zapper.RESET_HOLD * 60) + 5)
	assert_int(l.resets).is_equal(2)


## Solo's swap is LB + RB + Select: never a reset.
func test_solo_swap_combo_never_resets() -> void:
	var l := level()
	var z := zapper(P1, -20.0)
	l.register_zapper(z)
	await step(5)
	z.input_override.merge({"reset": true, "next": true, "prev": true}, true)
	await step(150)
	assert_int(l.resets).is_equal(0)


## Feeds Players' solo hold the way its _process does, one frame of the real pad.
func pad_frames(frames: int, select: bool, start: bool, z: Zapper) -> void:
	for i in frames:
		z.input_override["reset"] = select
		z.input_override["start"] = start
		if Players.hold_step(PAD, select and start, DT, select):
			if Game.state == Game.State.PAUSED:
				Game.resume()   # Players._undo_hold_pause: the Start of the hold doesn't leave it paused
		await get_tree().physics_frame


## Select first, then Start (which pauses): solo toggles at 2 s, and the yard never resets, even
## with Select kept down after Start comes up.
func test_select_then_start_toggles_solo_and_never_resets() -> void:
	var l := level()
	var z := zapper(P1, -20.0)
	l.register_zapper(z)
	Players._assign(P1, PAD)
	await step(5)
	await pad_frames(60, true, false, z)   # 1.0 s of Select: ring two thirds full
	assert_float(z.reset_progress()).is_greater(0.5)
	Game.pause()   # Start's press
	await pad_frames(int(Players.SOLO_HOLD * 60) + 5, true, true, z)
	assert_bool(Players.solo).is_true()
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	await pad_frames(20, true, true, z)
	await pad_frames(150, true, false, z)   # Start up, Select still down for 2.5 s
	assert_int(l.resets).is_equal(0)
	assert_float(z.reset_progress()).is_equal(0.0)


## Start first (pauses), then Select: solo toggles, the yard never resets.
func test_start_then_select_toggles_solo_and_never_resets() -> void:
	var l := level()
	var z := zapper(P1, -20.0)
	l.register_zapper(z)
	Players._assign(P1, PAD)
	await step(5)
	Game.pause()
	await pad_frames(15, false, true, z)
	await pad_frames(int(Players.SOLO_HOLD * 60) + 5, true, true, z)
	assert_bool(Players.solo).is_true()
	await pad_frames(10, true, true, z)
	await pad_frames(150, true, false, z)
	assert_int(l.resets).is_equal(0)


## A Select hold that already reset the yard can't turn into a solo toggle when Start joins it.
## Select up and a fresh Select + Start still toggles solo.
func test_a_reset_never_turns_into_solo() -> void:
	var l := level()
	var z := zapper(P1, -20.0)
	l.register_zapper(z)
	Players._assign(P1, PAD)
	await step(5)
	await pad_frames(int(Zapper.RESET_HOLD * 60) + 5, true, false, z)
	assert_int(l.resets).is_equal(1)
	await pad_frames(180, true, true, z)   # Start joins for 3 s
	assert_bool(Players.solo).is_false()
	assert_int(l.resets).is_equal(1)
	await pad_frames(3, false, false, z)
	await pad_frames(int(Players.SOLO_HOLD * 60) + 5, true, true, z)
	assert_bool(Players.solo).is_true()
	assert_int(l.resets).is_equal(1)


# ------------------------------------------------------------------------------ reset: pause menu

func test_pause_menu_has_a_reset_yard_entry_that_resets_at_once() -> void:
	var l := level()
	var pm: Control = load("res://scenes/ui/pause_menu.tscn").instantiate()
	world.add_child(pm)
	await step(2)
	Game.pause()
	await step(2)
	assert_bool(pm.visible).is_true()
	var item: MenuItem = pm._buttons[PauseMenu.Choice.RESET]
	assert_str(item.text).is_equal("Reset Yard")
	assert_bool(item.glyph.is_valid()).is_true()   # the swirl picture
	for b in pm._buttons:
		assert_bool((b as MenuItem).glyph.is_valid()).is_true()
	pm.move_focus(1)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.RESET)
	pm.press()
	assert_int(Game.state).is_equal(Game.State.PLAYING)   # no question, straight back in
	assert_int(l.resets).is_equal(1)
	assert_bool(Audio.played("reset_yard")).is_true()


# ------------------------------------------------------------------------------ reset: the sign

func test_the_sign_is_big_lit_and_by_the_start() -> void:
	var l := level()
	await step(2)
	var s := l.reset_sign
	var fx := s.get_node("SignFx") as ResetSignFx
	assert_object(fx).is_not_null()
	assert_int(fx.bulbs.size()).is_greater_equal(20)
	assert_object(fx.lamp).is_not_null()
	assert_float(fx.lamp.light_energy).is_greater(1.0)
	# Big: the board spans about 2.5 m (it was 1.35), its middle above a player's head.
	var box := AABB()
	var first := true
	for mi in s.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).get_aabb()
		bb = (mi as MeshInstance3D).global_transform * bb
		box = bb if first else box.merge(bb)
		first = false
	assert_float(box.size.x).is_greater(2.4)
	assert_float(box.end.y).is_greater(3.8)
	assert_float(absf(s.global_position.x - l.spawns[P1].global_position.x)).is_less(4.0)
	# Holding A on it races the bulbs: still 2.0 s, so a grab nearby never wipes the yard.
	var z := zapper(P1, s.global_position.x)
	l.register_zapper(z)
	await step(5)
	z.input_override["action"] = true
	await step(int(YardLevel.RESET_HOLD * 60) + 10)
	assert_int(l.resets).is_equal(1)
