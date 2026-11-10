## Polish lane (jyz-polish-1): last gun per player (S-16), piano chord on landing (A-13), parachute
## recall (K-08), the working contraptions (Y-10 fan, Y-05 conveyor, Y-04 hook), the podium gun
## (M-03) and the barn trampoline, balloons and pipe pile (Y-08, Y-11).
class_name TestPolish
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")

var _main: Node
var _real_settings := ""
var _real_picks := ""
var _real_profile := ""


func before() -> void:
	_real_profile = Save.profile
	Save.profile = "gdunit_polish"   # main.tscn saves the yard: never touch the family's profile
	Save.wipe()
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_polish.json"
	Save.wipe_settings()
	_real_picks = Roster.picks_path
	Roster.picks_path = "user://test_polish_players.json"
	Roster.args_override = PackedStringArray(["--no-picks"])
	Roster.reload()
	Game.quit_exits = false


func after() -> void:
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
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Yard.reset_world()
	Players.reset()
	Game.demo = false
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func _boot() -> Node:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	return _main


func _lobby() -> Lobby:
	return _main.get_node("UI/Lobby")


func _start_two() -> void:
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	_lobby().count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


# --- S-16: last gun per player --------------------------------------------------

func test_each_player_keeps_their_last_gun_after_the_lobby_and_a_reload() -> void:
	_boot()
	_start_two()
	await step(2)
	_main.zapper(P1).set_gun(3)
	_main.zapper(P2).set_gun(5)
	# Back to the lobby and into the yard again: the same guns, not the size gun.
	Game.to_lobby()
	await await_idle_frame()
	_lobby().press_a(P1)
	_lobby().press_a(P2)
	_lobby().count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	await step(2)
	assert_int(_main.zapper(P1).gun_index).is_equal(3)
	assert_int(_main.zapper(P2).gun_index).is_equal(5)
	# A whole reload (quit and boot again) keeps them too, including a change made just before.
	_main.zapper(P1).set_gun(6)
	Game.quit()
	_main.free()
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	Save._load()
	_boot()
	_start_two()
	await step(2)
	assert_int(_main.zapper(P1).gun_index).is_equal(6)
	assert_int(_main.zapper(P2).gun_index).is_equal(5)


# --- yard-strip helpers -----------------------------------------------------------

var _world: Node3D


func _strip() -> Node3D:
	_world = Node3D.new()
	add_child(_world)
	_world.add_child(YardStrip.new())
	return _world


func _drop(id: StringName, pos: Vector3) -> PhysicsObject:
	var o := PhysicsObject.new(load("res://data/objects/%s.tres" % id))
	o.position = pos
	_world.add_child(o)
	return o


func _free_world() -> void:
	if is_instance_valid(_world):
		_world.free()


# --- A-13: piano chord on landing ------------------------------------------------

func test_the_piano_plays_its_chord_when_it_lands_even_tiny() -> void:
	_strip()
	Audio.history.clear()
	var piano := _drop(&"piano", Vector3(0, 4.0, 0))
	var lands := []
	piano.object_landed.connect(func(_t: Node3D, imp: float) -> void: lands.append(imp))
	await step(80)
	assert_int(lands.size()).is_greater_equal(1)
	assert_bool(Audio.played("voice_piano_landed")).is_true()
	# Shrunk twice it lands in the light band (no landed voice for anything else), but still chords.
	Audio.history.clear()
	piano.restore_size(-2)
	piano.global_position = Vector3(0, 4.0, 0)
	piano.linear_velocity = Vector3.ZERO
	await step(80)
	assert_bool(Audio.played("voice_piano_landed")).is_true()
	# A crate of the same drop never plays the piano's chord.
	Audio.history.clear()
	_drop(&"crate", Vector3(3, 4.0, 0))
	await step(80)
	assert_bool(Audio.played("voice_piano_landed")).is_false()
	_free_world()


# --- K-08: parachute on recall ----------------------------------------------------

func test_a_recalled_object_floats_down_at_the_gate_under_a_parachute() -> void:
	_strip()
	Yard.GATE = Vector3(0, 4.0, 0)
	var crate := _drop(&"crate", Vector3(0, 0.6, 0))
	await step(10)
	crate.global_position = Vector3(0, -30, 0)   # off the map
	await step(2)
	assert_int(Yard.recalls).is_greater_equal(1)
	assert_float(crate.chute_left).is_greater(0.0)
	var canopy := crate.get_node_or_null("Parachute")
	assert_object(canopy).is_not_null()
	# Slow: still in the air half a second later, falling at no more than the chute speed.
	await step(30)
	assert_float(crate.global_position.y).is_greater(1.5)
	assert_float(-crate.linear_velocity.y).is_less_equal(PhysicsObject.CHUTE_SPEED + 0.5)
	# Down and folded away within 2 s.
	await step(90)
	assert_float(crate.chute_left).is_equal(0.0)
	assert_bool(is_instance_valid(canopy) and canopy.is_inside_tree() and not canopy.is_queued_for_deletion()).is_false()
	assert_float(crate.global_position.y).is_less(1.2)
	_free_world()


# --- Y-10, Y-05, Y-04, Y-08: the contraptions in a real yard --------------------------

var _level: YardLevel


func _yard() -> YardLevel:
	_world = Node3D.new()
	add_child(_world)
	_level = YardLevel.new()
	_level.use_save = false
	_level.layout = load(YardLevel.LAYOUT)
	_world.add_child(_level)
	return _level


func _zapper(player: int, at: Vector3) -> Zapper:
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	z.player = player
	z.position = at
	_world.add_child(z)
	z.input_override = {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}
	return z


func _zap_with(z: Zapper, target: Node3D, gun := 0) -> void:
	z.set_gun(gun, false)
	var to := target.global_position - z.aim_origin()
	z.input_override["aim"] = Vector2(to.x, -to.y).normalized()
	z.input_override["action"] = true
	await step(2)
	z.input_override["action"] = false
	await step(2)


func test_zapping_the_fan_blows_the_kite_off_the_tower() -> void:
	var l := _yard()
	Game.start_round()
	await step(10)
	var fan := l.contraptions.fan
	var kite := l.object(&"kite")
	var x0 := kite.global_position.x
	var anvil := l.object(&"anvil")
	anvil.global_position = Vector3(41.8, 9.9, 0)   # heavy: the wind can't move it
	await step(20)
	var ax := anvil.global_position.x
	var z := _zapper(P1, Vector3(42.8, 9.25, 0))   # on the top deck, under the fan
	Audio.history.clear()
	await _zap_with(z, fan, 2)
	assert_bool(fan.on).is_true()
	assert_bool(Audio.played(z.gun().zap_cue())).is_true()
	await step(60)
	assert_float(kite.global_position.x).is_less(x0 - 2.0)   # blown left
	assert_float(absf(anvil.global_position.x - ax)).is_less(0.3)
	# Zap it again: it winds down.
	await _zap_with(z, fan, 2)
	assert_bool(fan.on).is_false()
	_free_world()


func test_the_belt_button_runs_the_conveyor_and_carries_the_car() -> void:
	var l := _yard()
	Game.start_round()
	await step(30)
	var car := l.object(&"car")
	var x0 := car.global_position.x
	var z := _zapper(P1, Vector3(-24.6, 0.1, 0))
	await _zap_with(z, l.contraptions.button, 4)
	assert_bool(l.contraptions.belt.on).is_true()
	await step(60)
	assert_float(car.global_position.x).is_less(x0 - 0.8)   # toward the gate
	await _zap_with(z, l.contraptions.button, 4)
	assert_bool(l.contraptions.belt.on).is_false()
	var x1 := car.global_position.x
	await step(40)
	assert_float(absf(car.global_position.x - x1)).is_less(0.3)
	_free_world()


func test_the_crane_hook_can_be_grabbed_and_carries_what_it_catches() -> void:
	var l := _yard()
	Game.start_round()
	await step(10)
	var hook := l.contraptions.hook
	assert_object(hook.face).is_null()   # a machine part: no face
	var chicken := l.object(&"chicken")
	for o in l.objects.values():   # just the chicken under the crane
		if o != chicken and absf(o.global_position.x + 17.8) < 4.5:
			o.global_position.x -= 14.0
	chicken.global_position = Vector3(-17.8, 0.3, 0)
	var z := _zapper(P1, Vector3(-15.5, 0.1, 0))
	# The gravity gun takes the hook.
	await _zap_with(z, hook, 1)
	z.input_override["action"] = true
	await step(4)
	assert_bool(hook.stack.has(&"grab")).is_true()
	assert_object(z.held).is_same(hook)
	# Swing it down onto the chicken: it catches.
	z.input_override["aim"] = Vector2(-0.5, -1.0).normalized()
	await step(60)
	z.input_override["action"] = false
	await step(2)
	if hook.caught == null:   # not quite over it: drop it right on
		hook.global_position = chicken.global_position + Vector3(0, 0.5, 0)
		await step(10)
	assert_object(hook.caught).is_same(chicken)
	# Let go: the rope lifts the hook and the chicken off the ground.
	await step(150)
	assert_float(chicken.global_position.y).is_greater(2.0)
	assert_float(hook.global_position.y).is_less(Contraptions.CraneHook.ANCHOR.y)   # dangles under the jib, never flung over it
	# Reset Yard: the hook hangs empty again.
	l.reset_yard()
	await step(5)
	assert_object(hook.caught).is_null()
	assert_bool(hook.stack.has(&"glue")).is_false()
	_free_world()


func test_the_trampoline_bounces_a_launched_object_and_a_player() -> void:
	var l := _yard()
	Game.start_round()
	await step(10)
	var t := l.contraptions.trampoline
	for o in l.objects.values():   # a clear mat (the cow likes to stand next to it)
		if absf(o.global_position.x - t.global_position.x) < 2.5:
			o.global_position.x += 6.0
	await step(5)
	var ball := l.object(&"ball")
	ball.global_position = t.global_position + Vector3(0, 4.0, 0)
	ball.linear_velocity = Vector3(0, -6, 0)
	var peak := -INF
	var hit := false
	for i in 90:
		await step(1)
		if t.bounces > 0:
			hit = true
			peak = maxf(peak, ball.global_position.y)
	assert_bool(hit).is_true()
	assert_float(peak).is_greater(2.0)   # it went back up, not just stopped
	var z := _zapper(P2, t.global_position + Vector3(0, 3.0, 0))
	z.velocity.y = -6.0
	var top := 0.0
	for i in 70:
		await step(1)
		top = maxf(top, z.global_position.y)
	assert_int(t.bounces).is_greater_equal(2)
	assert_float(top).is_greater(4.0)   # higher than a jump: hayloft height
	_free_world()


# --- M-03: podium gun held up, legs showing ----------------------------------------

func test_the_podium_gun_points_up_not_over_the_legs() -> void:
	for scene in ["res://scenes/ui/lobby_p1.tscn", "res://scenes/ui/lobby_p2.tscn"]:
		var podium: Node3D = load(scene).instantiate()
		add_child(podium)
		await await_idle_frame()
		await await_idle_frame()
		var holder: Node3D = podium.raise_gun()
		assert_object(holder).is_not_null()
		var barrel := holder.global_basis.z.normalized()
		assert_float(barrel.y).override_failure_message(scene).is_greater(0.6)   # up, by the shoulder
		podium.set_character("chuck" if scene.ends_with("p1.tscn") else "jeff")   # a swap keeps it up
		await await_idle_frame()
		await await_idle_frame()
		holder = podium.raise_gun()
		assert_float(holder.global_basis.z.normalized().y).is_greater(0.6)
		podium.free()
