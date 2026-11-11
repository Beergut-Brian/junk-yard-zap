## Comedy lane (jyz-comedy-1): Jeff delights at big impacts, Chuck narrates his zaps and blames the
## partner (P-05, P-06, A-12), at most one bark per zap and rate-capped; the idle bits (P-07) on
## any picked Jarling, falling back to idle when the rig hasn't got the action; the wobble.
class_name TestComedy
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
var _clock := Clock.new()   # 60 Hz, time scale 1: frame counts below mean the same seconds everywhere

const P1 := Players.P1
const P2 := Players.P2
const IDLE := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}

var world: Node3D
var _real_settings := ""
var _real_profile := ""
var _t0 := 100000.0


func before() -> void:
	_clock.pin()
	_real_profile = Save.profile
	Save.profile = "gdunit_comedy"   # never touch the family's yard
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_comedy.json"   # never the real settings file
	Save.wipe_settings()


func after() -> void:
	_clock.restore()
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Save.profile = _real_profile
	Audio.clock = -1.0
	# The fake clock ran far ahead: leave the bark gates as a fresh boot has them.
	Audio._last_bark.clear()
	Audio._last_any_bark = -100.0


func before_test() -> void:
	Players.reset()
	Game.demo = false
	Game.start_round()
	Audio.history.clear()
	_t0 += 1000.0
	Audio.clock = _t0   # always well after every earlier bark (tests push the clock on)
	world = Node3D.new()
	add_child(world)
	world.add_child(YardStrip.new())


func after_test() -> void:
	Audio.clock = -1.0
	Audio.stop_all()
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()
	get_tree().paused = false


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func box(pos: Vector3, size := Vector3.ONE, mass := 1.0) -> PhysicsObject:
	var o := PhysicsObject.new(ObjectData.make(&"box", ObjectData.Shape.BOX, size, mass, Color.TAN))
	o.position = pos
	world.add_child(o)
	return o


func zapper(player: int, x: float, who := "") -> Zapper:
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	z.player = player
	z.character = who
	z.position = Vector3(x, 0.05, 0)
	world.add_child(z)
	z.input_override = IDLE.duplicate()
	return z


func use_gun(z: Zapper, id: StringName) -> void:
	for i in z.guns.size():
		if z.guns[i].id == id:
			z.set_gun(i, false)


func fire(z: Zapper, aim := Vector2.RIGHT) -> void:
	z.input_override = IDLE.merged({"action": true, "aim": aim}, true)
	await step(2)
	z.input_override = IDLE.duplicate()
	await step(2)


## Every bark in the history (game cues bark*, voice packs roster:<id>).
func barks() -> PackedStringArray:
	var out: PackedStringArray = []
	for c in Audio.history:
		if c.begins_with("bark") or c.begins_with("roster:"):
			out.append(c)
	return out


func quiet() -> void:
	Audio.clock += Audio.BARK_GAP + 0.1   # past every bark gap
	Audio.history.clear()


# ------------------------------------------------------------------------------------ barks

func test_bark_rate_cap_holds_back_a_burst_of_impacts() -> void:
	var jeff := zapper(P1, 0.0, "jeff")
	await step(3)
	for i in 10:   # a Reset lands everything at once: ten big impacts in half a second
		Audio.big_impact.emit(Vector3(2, 0, 0), "impact_huge")
		Audio.clock += 0.05
	assert_array(Array(barks())).is_equal(["bark_delight"])
	assert_str(jeff.reactions.last_reaction).is_equal("delight")   # one clap for the lot
	Audio.clock += Audio.BARK_GAP
	Audio.big_impact.emit(Vector3(2, 0, 0), "impact_heavy")
	assert_int(barks().size()).is_equal(2)
	# Too far away: no bark, no wobble.
	quiet()
	jeff.reactions.last_reaction = ""
	Audio.big_impact.emit(Vector3(80, 0, 0), "impact_huge")
	assert_int(barks().size()).is_equal(0)
	assert_str(jeff.reactions.last_reaction).is_equal("")


func test_one_bark_per_zap() -> void:
	var jeff := zapper(P1, -3.0, "jeff")
	var chuck := zapper(P2, 0.0, "chuck")
	var b := box(Vector3(1.6, 0.5, 0))
	await step(20)
	# Chuck zaps the box: he narrates (one bark), Jeff says nothing.
	use_gun(chuck, &"bouncy")
	await fire(chuck)
	assert_array(Array(barks())).is_equal(["bark_zap"])
	assert_str(chuck.reactions.last_reaction).is_equal("narrate")
	# Again at once: the gate holds it back, still one bark for two zaps.
	await fire(chuck)
	assert_int(barks().size()).is_equal(1)
	# Jeff zaps the box: Jeff doesn't narrate.
	quiet()
	use_gun(jeff, &"bouncy")
	jeff.input_override = IDLE.merged({"aim": Vector2.RIGHT}, true)
	await step(2)
	if jeff.target == b:
		await fire(jeff)
		assert_int(barks().size()).is_equal(0)
	# Chuck zaps Jeff: only the zapped partner barks.
	quiet()
	chuck.input_override = IDLE.merged({"aim": Vector2.LEFT}, true)
	await step(3)
	assert_object(chuck.target).is_same(jeff)
	await fire(chuck, Vector2.LEFT)
	assert_int(barks().size()).is_equal(1)
	await step(int(Zapper.PARTNER_TIME * 60) + 20)


func test_chuck_blames_the_partner_when_a_zap_is_refused() -> void:
	var jeff := zapper(P1, -3.0, "jeff")
	var chuck := zapper(P2, 0.0, "chuck")
	var b := box(Vector3(1.6, 0.5, 0))
	await step(20)
	use_gun(chuck, &"size")
	var refused := false
	for i in 8:   # grow until the cap or the room says no
		quiet()
		await fire(chuck)
		if Audio.played("nope"):
			refused = true
			break
		await step(30)
	assert_bool(refused).override_failure_message("the size gun never said nope").is_true()
	assert_str(chuck.reactions.last_reaction).is_equal("blame")
	assert_array(Array(barks())).is_equal(["roster:chuck"])  # his own plain "hey!" from his voice pack (no blame cue; voiced since characters v0.5.3)
	assert_float(chuck.reactions.facing(chuck.facing)).is_equal(-1.0)   # turned round on Jeff
	assert_float(chuck.facing).is_equal(1.0)                 # but his aim is still his own
	assert_object(b).is_not_null()
	# Jeff never blames.
	assert_bool(jeff.reactions.blames()).is_false()
	quiet()
	assert_str(jeff.reactions.own_zap(false, true)).is_equal("")
	assert_int(barks().size()).is_equal(0)


func test_jeff_claps_at_a_big_impact_and_everyone_wobbles() -> void:
	var jeff := zapper(P1, -2.0, "jeff")
	var chuck := zapper(P2, 2.0, "chuck")
	await step(5)
	Audio.big_impact.emit(Vector3(0, 0, 0.01), "impact_huge")
	assert_str(jeff.reactions.last_reaction).is_equal("delight")
	assert_str(chuck.reactions.last_reaction).is_equal("wobble")
	await step(4)
	assert_str(jeff.rig.current()).is_equal("cheer")              # the clap, not idle
	var rest := Vector3.ONE * JarlingRig.SCALE
	assert_bool(chuck.rig.model.scale.is_equal_approx(rest)).is_false()   # mid-wobble
	await step(70)
	assert_bool(chuck.rig.model.scale.is_equal_approx(rest)).is_true()    # and back
	assert_str(jeff.rig.current()).is_equal("idle")


func test_a_sleeping_partner_does_not_react() -> void:
	var chuck := zapper(P2, 0.0, "chuck")
	chuck.set_asleep(true)
	await step(3)
	Audio.big_impact.emit(Vector3(1, 0, 0), "impact_huge")
	assert_str(chuck.reactions.last_reaction).is_equal("")


# ------------------------------------------------------------------------------------ idles

func test_idle_bits_follow_the_character() -> void:
	var jeff := zapper(P1, -4.0, "jeff")
	var chuck := zapper(P2, 4.0, "chuck")
	var other := zapper(P1, 0.0, "astro_ana")
	await step(3)
	assert_array(jeff.reactions.bits()).is_equal(["poke", "hum"])
	assert_array(chuck.reactions.bits()).is_equal(["kick_tire", "check_hat"])
	assert_array(other.reactions.bits()).is_equal(Reactions.ALL_BITS)


func test_jeff_pokes_the_junk_and_it_answers() -> void:
	var jeff := zapper(P1, 0.0, "jeff")
	var b := box(Vector3(1.3, 0.5, 0))
	await step(40)
	Audio.history.clear()
	assert_str(jeff.reactions.do_bit("poke")).is_equal("poke")
	assert_str(jeff.reactions.last_action).is_equal("idle")   # no poke clip on a Jarling: idle + lean
	await step(30)
	assert_float(b.linear_velocity.length() + absf(b.global_position.x - 1.3)).is_greater(0.02)
	assert_bool(Audio.history.size() > 0).is_true()          # the box says something


func test_chuck_kicks_a_tire_with_his_own_kick() -> void:
	var chuck := zapper(P2, 0.0, "chuck")
	var b := box(Vector3(1.3, 0.5, 0))
	await step(40)
	Audio.history.clear()
	assert_str(chuck.reactions.do_bit("kick_tire")).is_equal("kick_tire")
	assert_str(chuck.reactions.last_action).is_equal("kick")
	await step(2)
	assert_str(chuck.rig.current()).is_equal("kick")         # the zapper doesn't force idle over it
	await step(30)
	assert_bool(Audio.played(Reactions.KICK_CUE)).is_true()
	assert_float(b.linear_velocity.length() + absf(b.global_position.x - 1.3)).is_greater(0.05)


func test_a_missing_action_falls_back_to_idle() -> void:
	var chuck := zapper(P2, 0.0, "chuck")
	var b := box(Vector3(1.3, 0.5, 0))
	await step(40)
	chuck.rig.actions = PackedStringArray(["idle", "run"])   # a rig without kick
	assert_str(chuck.rig.play_action("dance")).is_equal("idle")
	Audio.history.clear()
	assert_str(chuck.reactions.do_bit("kick_tire")).is_equal("kick_tire")
	assert_str(chuck.reactions.last_action).is_equal("idle")
	await step(30)
	assert_bool(Audio.played(Reactions.KICK_CUE)).is_true()  # the kick still lands and is heard
	assert_object(b).is_not_null()
	# A rig with no clips at all: nothing plays, nothing breaks.
	chuck.rig.actions = PackedStringArray()
	assert_str(chuck.rig.play_action("kick")).is_equal("")
	assert_str(chuck.reactions.do_bit("check_hat")).is_equal("check_hat")


func test_nothing_in_reach_turns_into_the_other_bit() -> void:
	var jeff := zapper(P1, 0.0, "jeff")
	var chuck := zapper(P2, 8.0, "chuck")
	await step(10)
	Audio.history.clear()
	assert_str(jeff.reactions.do_bit("poke")).is_equal("hum")
	assert_bool(Audio.played(Reactions.HUM_CUE)).is_true()
	assert_str(chuck.reactions.do_bit("kick_tire")).is_equal("check_hat")
	assert_bool(Audio.played(Reactions.HAT_CUE)).is_true()


func test_a_still_player_idles_on_his_own_and_moving_stops_it() -> void:
	var jeff := zapper(P1, 0.0, "jeff")
	await step(int((Reactions.IDLE_AFTER + 0.3) * 60))
	assert_int(jeff.reactions.bits_done).is_equal(1)
	assert_bool(jeff.reactions.busy()).is_true()
	jeff.input_override = IDLE.merged({"move": Vector2.RIGHT}, true)
	await step(3)
	assert_bool(jeff.reactions.busy()).is_false()
	assert_float(jeff.reactions.still_time).is_equal(0.0)
	assert_str(jeff.rig.current()).is_equal("run")
