## R-07 (jyz-hint-panel-1): the in-play hint panel. One test per context of the pure rules
## (HintPanel.hint_for_state), one that a frozen or refused press is the nope state (the same glyphs,
## never a new hint), and live checks on a real Zapper. Own settings and picks files, fixture roster.
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
var _clock := Clock.new()

const P1 := Players.P1
const P2 := Players.P2
const C := HintPanel.Context
const IDLE := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false,
		"prev": false, "reset": false, "start": false}
const FIXTURE := "res://tests/fixtures/roster_two.json"

var world: Node3D
var _real_profile := ""
var _real_settings := ""
var _real_picks := ""
var _real_data := ""


func before() -> void:
	_clock.pin()
	_real_profile = Save.profile
	Save.profile = "gdunit_hint"
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_hint.json"
	Save.wipe_settings()
	_real_data = Roster.data_path
	_real_picks = Roster.picks_path
	Roster.data_path = FIXTURE
	Roster.picks_path = "user://test_hint_players.json"
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
	get_tree().paused = false
	if is_instance_valid(world):
		world.free()
	Game._set_state(Game.State.PLAYING)
	Yard.reset_world()
	Players.reset()


# ------------------------------------------------------------------------------- the pure rules

func h(s: Dictionary) -> Dictionary:
	return HintPanel.hint_for_state(s)


func toks(hint: Dictionary) -> Array:
	return (hint["glyphs"] as Array).map(func(e: Dictionary) -> String: return e["tok"])


func pics(hint: Dictionary) -> Array:
	return (hint["glyphs"] as Array).map(func(e: Dictionary) -> int: return e["pic"])


func test_hidden_when_not_playing() -> void:
	var r := h({"live": false, "target": "object"})
	assert_int(r["context"]).is_equal(C.HIDDEN)
	assert_array(r["glyphs"]).is_empty()
	assert_str(r["blink"]).is_empty()


func test_asleep_shows_only_the_wake_glyph() -> void:
	var r := h({"asleep": true})
	assert_int(r["context"]).is_equal(C.ASLEEP)
	assert_array(toks(r)).is_equal(["a"])
	assert_array(pics(r)).is_equal([HintPanel.Pic.WAKE])


func test_on_foot_shows_jump_and_belt() -> void:
	var r := h({})
	assert_int(r["context"]).is_equal(C.ON_FOOT)
	assert_array(toks(r)).is_equal(["b", "rb"])
	assert_array(pics(r)).is_equal([HintPanel.Pic.JUMP, HintPanel.Pic.BELT])
	assert_str(r["blink"]).is_empty()
	assert_bool(r["nope"]).is_false()


func test_holding_a_gun_on_a_target_shows_fire() -> void:
	var r := h({"target": "object", "gun_kind": GunData.Kind.BOUNCY})
	assert_int(r["context"]).is_equal(C.AIMING)
	assert_array(toks(r)).is_equal(["a", "b", "rb"])
	assert_int(pics(r)[0]).is_equal(HintPanel.Pic.FIRE)
	assert_str(r["blink"]).is_empty()   # zapping an object is play, not an "interaction ready"
	assert_int(h({"target": "partner", "gun_kind": GunData.Kind.SIZE})["context"]).is_equal(C.AIMING)


func test_a_contraption_in_the_beam_blinks_a() -> void:
	var r := h({"target": "contraption", "gun_kind": GunData.Kind.FREEZE})
	assert_int(r["context"]).is_equal(C.AIMING)
	assert_str(r["blink"]).is_equal("a")


func test_grab_gun_next_to_a_grabbable_object_is_ready() -> void:
	var r := h({"target": "object", "grabbable": true, "gun_kind": GunData.Kind.GRAB})
	assert_int(r["context"]).is_equal(C.GRAB_READY)
	assert_array(toks(r)).is_equal(["a", "b", "rb"])
	assert_int(pics(r)[0]).is_equal(HintPanel.Pic.HAND)
	assert_str(r["blink"]).is_equal("a")
	# Someone else is carrying it: not grab-able, so no invitation (a press is the refusal).
	var busy := h({"target": "object", "grabbable": false, "gun_kind": GunData.Kind.GRAB})
	assert_int(busy["context"]).is_equal(C.AIMING)
	assert_str(busy["blink"]).is_empty()


func test_carrying_shows_drop_throw_and_jump() -> void:
	var r := h({"held": true, "target": "object", "gun_kind": GunData.Kind.GRAB})
	assert_int(r["context"]).is_equal(C.CARRYING)
	assert_array(toks(r)).is_equal(["a", "lr", "b"])
	assert_array(pics(r)).is_equal([HintPanel.Pic.DROP, HintPanel.Pic.THROW, HintPanel.Pic.JUMP])
	assert_bool(r["glyphs"][0]["lit"]).is_true()   # A is held down


func test_sizing_shows_the_up_down_glyph() -> void:
	var r := h({"sizing": true, "target": "object", "gun_kind": GunData.Kind.SIZE})
	assert_int(r["context"]).is_equal(C.SIZING)
	assert_array(toks(r)).is_equal(["ud", "a"])
	assert_int(pics(r)[0]).is_equal(HintPanel.Pic.SIZE)


func test_after_a_zap_the_a_glyph_is_sunk_then_back() -> void:
	var r := h({"since_zap": 0.1, "target": "object", "gun_kind": GunData.Kind.BOUNCY})
	assert_int(r["context"]).is_equal(C.COOLDOWN)
	assert_array(toks(r)).is_equal(["a", "b", "rb"])
	assert_bool(r["glyphs"][0]["lit"]).is_true()
	var later := h({"since_zap": HintPanel.ZAP_BEAT + 0.01, "target": "object", "gun_kind": GunData.Kind.BOUNCY})
	assert_int(later["context"]).is_equal(C.AIMING)
	assert_bool(later["glyphs"][0]["lit"]).is_false()


func test_by_the_reset_sign_shows_the_swirl_without_blinking() -> void:
	var r := h({"near_sign": true, "target": "object", "grabbable": true, "gun_kind": GunData.Kind.GRAB})
	assert_int(r["context"]).is_equal(C.SIGN)
	assert_int(pics(r)[0]).is_equal(HintPanel.Pic.SWIRL)
	assert_str(r["blink"]).is_empty()   # the sign wipes the yard: shown, never invited


func test_frozen_ices_the_row() -> void:
	var r := h({"statue": true, "held": true, "target": "object", "grabbable": true, "gun_kind": GunData.Kind.GRAB})
	assert_int(r["context"]).is_equal(C.FROZEN)
	assert_bool(r["iced"]).is_true()
	assert_array(toks(r)).is_equal(["a", "b", "rb"])
	assert_str(r["blink"]).is_empty()


func test_a_frozen_or_refused_press_is_the_nope_state_not_a_new_hint() -> void:
	for s in [{"statue": true}, {"target": "object", "gun_kind": GunData.Kind.SIZE},
			{"target": "object", "grabbable": true, "gun_kind": GunData.Kind.GRAB}, {}]:
		var before := h(s as Dictionary)
		var pressed: Dictionary = (s as Dictionary).duplicate()
		pressed["since_nope"] = 0.05
		var after := h(pressed)
		assert_bool(before["nope"]).is_false()
		assert_bool(after["nope"]).is_true()
		assert_int(after["context"]).is_equal(before["context"])
		assert_array(after["glyphs"]).is_equal(before["glyphs"])
		pressed["since_nope"] = HintPanel.NOPE_TIME + 0.01
		assert_bool(h(pressed)["nope"]).is_false()


# --------------------------------------------------------------------------- on a real Zapper

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


func gun(kind: GunData.Kind) -> GunData:
	for g in Zapper.load_guns():
		if g.kind == kind:
			return g
	return null


func live_hint(z: Zapper, panel: HintPanel = null) -> Dictionary:
	if panel:
		return HintPanel.hint_for_state(HintPanel.state_of(z, panel.since_zap, panel.since_nope))
	return HintPanel.hint_for_state(HintPanel.state_of(z))


func test_a_real_zapper_on_foot_then_frozen_then_nope() -> void:
	var a := zapper(P1, -2.0)
	var b := zapper(P2, 2.0)
	var hud := Hud.new()
	world.add_child(hud)
	var panel := HintPanel.make(b, null, hud)
	b.input_override["aim"] = Vector2.DOWN   # aim at the ground: nothing in the beam
	await step(5)
	assert_int(live_hint(b, panel)["context"]).is_equal(C.ON_FOOT)
	b.partner_zap(gun(GunData.Kind.FREEZE), a)
	assert_int(live_hint(b, panel)["context"]).is_equal(C.FROZEN)
	var glyphs: Array = live_hint(b, panel)["glyphs"]
	b.input_override["action"] = true
	await step(2)
	var r := live_hint(b, panel)
	assert_bool(r["nope"]).is_true()          # the statue's nope reached the panel
	assert_int(r["context"]).is_equal(C.FROZEN)
	assert_array(r["glyphs"]).is_equal(glyphs)
	assert_int(Array(Audio.history).count("nope")).is_greater_equal(1)


func test_a_real_zapper_grab_ready_then_carrying() -> void:
	var z := zapper(P1, 0.0)
	var crate := PhysicsObject.new(ObjectData.make(&"crate", ObjectData.Shape.BOX, Vector3.ONE * 0.8, 1.0, Color.WHITE))
	crate.position = Vector3(1.6, 0.5, 0)
	world.add_child(crate)
	for i in z.guns.size():
		if z.guns[i].kind == GunData.Kind.GRAB:
			z.set_gun(i, false)
	z.input_override["aim"] = Vector2.RIGHT
	await step(8)
	assert_object(z.target).is_same(crate)
	var r := live_hint(z)
	assert_int(r["context"]).is_equal(C.GRAB_READY)
	assert_str(r["blink"]).is_equal("a")
	z.input_override["action"] = true
	await step(3)
	assert_object(z.held).is_same(crate)
	assert_int(live_hint(z)["context"]).is_equal(C.CARRYING)


func test_the_game_gives_each_player_a_panel_in_their_colour() -> void:
	world.free()
	Game._set_state(Game.State.LOBBY)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	Game.start_round()
	await step(3)
	var hud: Hud = main.get_node("UI/Hud")
	var p1: HintPanel = hud.get_node_or_null("HintP1")
	var p2: HintPanel = hud.get_node_or_null("HintP2")
	assert_object(p1).is_not_null()
	assert_object(p2).is_not_null()
	assert_int(p1.zapper.player).is_equal(P1)
	assert_int(p2.zapper.player).is_equal(P2)
	var before: Vector3 = p1.zapper.global_position
	await step(2)
	assert_float(p1.zapper.global_position.x).is_equal_approx(before.x, 0.001)   # the hint never moves anyone
	main.free()
