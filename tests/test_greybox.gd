## Phase 2 grey-box: the gun belt, partner zaps, gravity grab and throw, Reset Yard, goal cards,
## the yard save round trip, drop-in from the tire pile, water, and the placeholder synth.
class_name TestGreybox
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const IDLE := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}

var world: Node3D
var _real_settings := ""


func before() -> void:
	Save.profile = "gdunit"   # never touch the family's yard
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings.json"
	Save.wipe_settings()


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()


func before_test() -> void:
	Players.reset()
	Game.demo = false
	Game.start_round()
	Audio.history.clear()
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()
	get_tree().paused = false


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func strip() -> void:
	world.add_child(YardStrip.new())


func box(pos: Vector3, size := Vector3.ONE, mass := 1.0) -> PhysicsObject:
	var o := PhysicsObject.new(ObjectData.make(&"box", ObjectData.Shape.BOX, size, mass, Color.TAN))
	o.position = pos
	world.add_child(o)
	return o


func zapper(player: int, x: float, parent: Node = null) -> Zapper:
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	z.player = player
	z.position = Vector3(x, 0.05, 0)
	(parent if parent else world).add_child(z)
	z.input_override = IDLE.duplicate()
	return z


func gun_index(z: Zapper, id: StringName) -> int:
	for i in z.guns.size():
		if z.guns[i].id == id:
			return i
	return -1


## Press A (with optional stick), hold it `hold` frames, let go.
func fire(z: Zapper, aim := Vector2.RIGHT, hold := 1, move := Vector2.ZERO) -> void:
	z.input_override = IDLE.merged({"action": true, "aim": aim, "move": move}, true)
	await step(hold)
	z.input_override = IDLE.merged({"aim": aim}, true)
	await step(2)


func level() -> YardLevel:
	var l := YardLevel.new()
	l.use_save = false
	l.layout = load(YardLevel.LAYOUT)
	world.add_child(l)
	var players := Node3D.new()
	players.name = "Players"
	l.add_child(players)
	return l


# ---------------------------------------------------------------------------------------- guns

func test_belt_has_seven_guns_in_belt_order() -> void:
	var guns := Zapper.load_guns()
	var ids := guns.map(func(g: GunData) -> StringName: return g.id)
	assert_array(ids).is_equal([&"size", &"grab", &"bouncy", &"balloon", &"freeze", &"glue", &"magnet"])
	for g in guns:   # never green or red: those belong to Jeff and Chuck
		for p in [P1, P2]:
			var c: Color = Players.COLOR[p]
			assert_bool(absf(g.beam_color.h - c.h) > 0.03 or absf(g.beam_color.s - c.s) > 0.3).is_true()


func test_belt_cycles_both_ways_with_a_click() -> void:
	strip()
	var z := zapper(P1, 0.0)
	await step(2)
	z.input_override = IDLE.merged({"next": true}, true)
	await step(2)
	z.input_override = IDLE.duplicate()
	await step(1)
	assert_int(z.gun_index).is_equal(1)
	z.input_override = IDLE.merged({"prev": true}, true)
	await step(2)
	z.input_override = IDLE.duplicate()
	await step(1)
	z.input_override = IDLE.merged({"prev": true}, true)
	await step(2)
	assert_int(z.gun_index).is_equal(6)
	assert_bool(Audio.played("wheel_move")).is_true()


func test_toggle_guns_zap_and_undo_with_a_sound() -> void:
	strip()
	var z := zapper(P1, 0.0)
	var o := box(Vector3(2.5, 0.5, 0))
	await step(3)
	for id in [&"bouncy", &"balloon", &"freeze", &"magnet"]:
		z.set_gun(gun_index(z, id))
		await fire(z)
		assert_bool(o.stack.has(id)).override_failure_message("%s on" % id).is_true()
		assert_bool(Audio.played("zap_%s" % id)).is_true()
		await fire(z)
		assert_bool(o.stack.has(id)).override_failure_message("%s off" % id).is_false()
		o.global_position = Vector3(2.5, 0.5, 0)
		await step(3)


func test_size_gun_tap_grows_stick_down_shrinks_hold_repeats() -> void:
	strip()
	var z := zapper(P1, 0.0)
	var o := box(Vector3(2.8, 0.5, 0))
	await step(3)
	z.set_gun(gun_index(z, &"size"))
	await fire(z)
	assert_int(o.stack.props.scale_step).is_equal(1)
	await fire(z, Vector2.RIGHT, 1, Vector2(0, 1))   # stick down: shrink
	assert_int(o.stack.props.scale_step).is_equal(0)
	await fire(z, Vector2.RIGHT, 70, Vector2(0, -1))   # hold up ~1.2 s: several steps
	assert_int(o.stack.props.scale_step).is_greater_equal(3)
	assert_bool(Audio.played("grow") and Audio.played("shrink")).is_true()


func test_glue_gun_sticks_two_things_and_the_blob_splits_them() -> void:
	strip()
	var z := zapper(P1, 0.0)
	var a := box(Vector3(2.0, 0.5, 0))
	var b := box(Vector3(-2.0, 0.5, 0))
	await step(3)
	z.set_gun(gun_index(z, &"glue"))
	await fire(z, Vector2.RIGHT)
	assert_object(z.glue_first).is_same(a)
	await fire(z, Vector2.LEFT)
	var g := Effects.Glue.between(a, b)
	assert_object(g).is_not_null()
	await step(90)
	assert_bool(g.joined()).is_true()


func test_zapping_nothing_sparkles() -> void:
	strip()
	var z := zapper(P1, 0.0)
	await step(2)
	await fire(z, Vector2.UP)
	assert_bool(Audio.played("sparkle")).is_true()


# --------------------------------------------------------------------------------- partner zaps

func test_partner_zaps_are_funny_and_last_at_most_a_second() -> void:
	strip()
	var z := zapper(P1, 0.0)
	var mate := zapper(P2, 2.5)
	await step(5)
	for i in z.guns.size():
		z.set_gun(i)
		var x0 := mate.global_position.x
		await fire(z)
		assert_int(mate._partner_kind).override_failure_message(String(z.guns[i].id)).is_equal(z.guns[i].kind)
		assert_float(mate.statue_left).is_less_equal(Zapper.PARTNER_TIME)
		assert_object(z.held).is_null()   # grab doesn't carry your partner off
		await step(int(Zapper.PARTNER_TIME * 60) + 25)
		assert_int(mate._partner_kind).is_equal(-1)
		assert_float(mate.statue_left).is_equal(0.0)
		assert_vector(mate.rig.scale).is_equal_approx(Vector3.ONE, Vector3.ONE * 0.05)
		assert_float(absf(mate.global_position.x - x0)).is_less(1.0)
		mate.global_position = Vector3(2.5, 0.05, 0)
		await step(30)


func test_frozen_partner_is_a_statue_then_moves_again() -> void:
	strip()
	var z := zapper(P1, 0.0)
	var mate := zapper(P2, 2.5)
	await step(5)
	z.set_gun(gun_index(z, &"freeze"))
	await fire(z)
	mate.input_override = IDLE.merged({"move": Vector2.RIGHT}, true)
	var x0 := mate.global_position.x
	await step(20)
	assert_float(mate.global_position.x - x0).is_less(0.05)
	await step(50)
	var x1 := mate.global_position.x
	await step(20)
	assert_float(mate.global_position.x - x1).is_greater(0.5)


# ------------------------------------------------------------------------------- grab and throw

func test_grab_carries_at_arms_length_and_drops_on_release() -> void:
	strip()
	var z := zapper(P1, 0.0)
	var o := box(Vector3(2.5, 0.5, 0), Vector3(0.8, 0.8, 0.8))
	await step(3)
	z.set_gun(gun_index(z, &"grab"))
	z.input_override = IDLE.merged({"action": true, "aim": Vector2.RIGHT}, true)
	await step(2)
	assert_object(z.held).is_same(o)
	assert_bool(o.stack.has(&"grab")).is_true()
	assert_bool(Audio.played("grab")).is_true()
	z.input_override = IDLE.merged({"action": true, "aim": Vector2.RIGHT, "move": Vector2.RIGHT}, true)
	await step(60)
	assert_float(o.global_position.distance_to(z.hold_point(o))).is_less(0.6)
	z.input_override = IDLE.duplicate()
	await step(2)
	assert_bool(o.stack.has(&"grab")).is_false()
	var y := o.global_position.y
	await step(20)
	assert_float(o.global_position.y).is_less(y - 0.2)


func test_flick_throws() -> void:
	strip()
	var z := zapper(P1, 0.0)
	var o := box(Vector3(2.5, 0.5, 0), Vector3(0.6, 0.6, 0.6))
	await step(3)
	z.set_gun(gun_index(z, &"grab"))
	z.input_override = IDLE.merged({"action": true, "aim": Vector2.RIGHT}, true)
	await step(30)
	z.input_override = IDLE.merged({"action": true, "aim": Vector2.RIGHT, "move": Vector2(1, -0.3)}, true)
	await step(2)
	z.input_override = IDLE.merged({"move": Vector2(1, -0.3)}, true)
	await step(2)
	assert_bool(o.stack.has(&"grab")).is_false()
	assert_float(o.linear_velocity.length()).is_greater(8.0)
	assert_bool(Audio.played("throw")).is_true()


# ------------------------------------------------------------------------------------- the yard

func test_yard_spawns_the_layout_with_faces() -> void:
	var l := level()
	await step(2)
	assert_int(l.objects.size()).is_greater_equal(15)
	for k in [&"cow", &"car", &"bathtub", &"ball", &"duck", &"plank", &"chicken"]:
		assert_object(l.object(k)).override_failure_message(String(k)).is_not_null()
		assert_object(l.object(k).face).is_not_null()
	assert_int(Yard.zones.size()).is_greater_equal(5)


func test_reset_yard_puts_everything_back() -> void:
	var l := level()
	await step(3)
	var cow := l.object(&"cow")
	var home := cow.global_position
	Effects.zap(&"grow", cow)
	Effects.zap(&"balloon", cow)
	Effects.glue(l.object(&"crate"), l.object(&"crate_2"))
	cow.global_position = Vector3(0, 8, 0)
	var resets := [0]
	l.yard_reset.connect(func() -> void: resets[0] += 1)
	l.reset_yard()
	await step(2)
	cow = l.object(&"cow")
	assert_float(cow.global_position.distance_to(home)).is_less(0.5)
	assert_bool(cow.stack.effects.is_empty()).is_true()
	assert_object(Effects.Glue.between(l.object(&"crate"), l.object(&"crate_2"))).is_null()
	assert_int(resets[0]).is_equal(1)
	assert_bool(Audio.played("reset_yard")).is_true()


func test_holding_a_on_the_sign_resets() -> void:
	var l := level()
	var z := zapper(P1, l.reset_sign.global_position.x, l.get_node("Players"))
	await step(5)
	z.input_override = IDLE.merged({"action": true}, true)
	await step(30)
	assert_float(l.reset_progress()).is_greater(0.2)
	assert_int(l.resets).is_equal(0)
	await step(50)
	assert_int(l.resets).is_equal(1)


func test_water_floats_light_things_and_sinks_heavy_ones() -> void:
	var l := level()
	await step(2)
	var duck := l.object(&"duck")
	var cannon := l.object(&"cannonball")
	duck.global_position = Vector3(-1, 1.5, 0)
	cannon.global_position = Vector3(3, 1.5, 0)
	await step(180)
	assert_float(duck.global_position.y).is_between(YardLevel.WATER_Y - 0.4, YardLevel.WATER_Y + 0.4)
	assert_float(cannon.global_position.y).is_less(YardLevel.POND_FLOOR + 0.6)
	assert_bool(Audio.played("splash")).is_true()


# ------------------------------------------------------------------------------------ goal cards

func test_goal_checker_knows_all_five_band_one_cards() -> void:
	var l := level()
	await step(5)
	var cards: Dictionary = l.deck.cards
	assert_int(cards.size()).is_equal(5)
	for id in cards:
		assert_bool(Goals.check(cards[id])).override_failure_message("%s before" % id).is_false()
	Effects.zap(&"grow", l.object(&"cow"))
	Effects.zap(&"grow", l.object(&"cow"))
	Effects.zap(&"balloon", l.object(&"chicken_2"))
	Effects.zap(&"bouncy", l.object(&"ball"))
	Effects.glue(l.object(&"crate"), l.object(&"crate_2"))
	var tub := l.object(&"bathtub")
	l.object(&"duck").global_position = tub.global_position + Vector3(0, 0.2, 0)
	await step(60)
	for id in cards:
		assert_bool(Goals.check(cards[id])).override_failure_message("%s after" % id).is_true()


func test_deck_completes_skips_and_cheers() -> void:
	var l := level()
	var z := zapper(P1, -40.0, l.get_node("Players"))
	await step(3)
	assert_str(String(l.deck.current().id)).is_equal("b1_big_cow")
	var done := []
	l.goal_completed.connect(func(id: StringName) -> void: done.append(id))
	Effects.zap(&"grow", l.object(&"cow"))
	Effects.zap(&"grow", l.object(&"cow"))
	await step(60)
	assert_array(done).is_equal([&"b1_big_cow"])
	assert_array(l.deck.done).contains([&"b1_big_cow"])
	assert_bool(Audio.played("card_done")).is_true()
	assert_bool(Fx.bursts > 0).is_true()
	# Zap the card on the fence: it goes to the back.
	var top := l.deck.current().id
	l.card.zapped_by(z, z.gun())
	assert_object(l.deck.current().id).is_not_equal(top)
	assert_object(l.deck.order.back()).is_equal(top)
	assert_bool(Audio.played("card_skip")).is_true()


# -------------------------------------------------------------------------------------- saving

func test_save_load_round_trip() -> void:
	var l := level()
	await step(3)
	var cow := l.object(&"cow")
	Effects.zap(&"grow", cow)
	Effects.zap(&"grow", cow)
	Effects.zap(&"bouncy", cow)
	Effects.zap(&"freeze", l.object(&"plank"))
	Effects.glue(l.object(&"crate"), l.object(&"crate_2"))
	l.object(&"ball").global_position = Vector3(-20, 3, 0)
	l.deck.skip()
	await step(40)
	var ball_at := l.object(&"ball").global_position
	var deck_order := l.deck.order.duplicate()
	Save.set_value(YardLevel.SAVE_KEY, l.to_save())
	Save.flush()
	Save._load()
	l.free()
	await step(2)
	var m := level()
	await step(1)
	assert_bool(m.load_yard()).is_true()
	await step(10)
	cow = m.object(&"cow")
	assert_int(cow.stack.props.scale_step).is_equal(2)
	assert_float(cow.current_scale).is_equal_approx(pow(1.3, 2), 0.001)
	assert_bool(cow.stack.has(&"bouncy")).is_true()
	assert_bool(m.object(&"plank").freeze).is_true()
	assert_object(Effects.Glue.between(m.object(&"crate"), m.object(&"crate_2"))).is_not_null()
	assert_float(m.object(&"ball").global_position.distance_to(ball_at)).is_less(0.6)
	assert_array(m.deck.order).is_equal(deck_order)
	Save.wipe()


# ---------------------------------------------------------------------------------------- drop-in

func test_chuck_sleeps_in_the_tire_pile_and_wakes_with_a_snort() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	world.add_child(main)
	await step(2)
	Game.to_lobby()
	Players.join_virtual(P1)
	Game.finish_lobby([P1])
	await step(2)
	var chuck: Zapper = main.zapper(P2)
	assert_bool(chuck.asleep).is_true()
	assert_float(absf(chuck.global_position.x - main.level.tire_pile.global_position.x)).is_less(2.0)
	chuck.input_override = IDLE.merged({"move": Vector2.RIGHT}, true)
	var x := chuck.global_position.x
	await step(20)
	assert_float(absf(chuck.global_position.x - x)).is_less(0.05)   # asleep: doesn't move
	Players.join_virtual(P2)
	assert_bool(chuck.asleep).is_false()
	assert_bool(Audio.played("snort")).is_true()
	await step(30)
	assert_float(chuck.global_position.x - x).is_greater(0.5)


func test_players_who_ready_in_the_lobby_start_awake() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	world.add_child(main)
	await step(2)
	Game.to_lobby()
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	Game.finish_lobby([P1, P2])
	await step(2)
	assert_bool(main.zapper(P1).asleep).is_false()
	assert_bool(main.zapper(P2).asleep).is_false()


func test_solo_swap_moves_the_pad_to_the_other_player() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	world.add_child(main)
	await step(2)
	Players.set_solo(true)
	Game.to_lobby()
	Game.finish_lobby([P1, P2])
	await step(2)
	assert_int(Players.solo_focus).is_equal(P1)
	main.swap_solo_focus()
	assert_int(Players.solo_focus).is_equal(P2)
	assert_bool(Audio.played("solo_swap")).is_true()


# ------------------------------------------------------------------------------------------ sound

func test_missing_cues_play_a_synth_beep() -> void:
	var w := Synth.beep("zap_definitely_not_a_file")
	assert_object(w).is_not_null()
	assert_int(w.data.size()).is_greater(1000)
	Audio.play("zap_definitely_not_a_file")
	assert_bool(Audio.played("zap_definitely_not_a_file")).is_true()
