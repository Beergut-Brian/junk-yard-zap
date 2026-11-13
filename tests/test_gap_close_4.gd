## Gap-close lane 4 (jyz-gap-close-4). Standing rule: every curse or penalty shows its cause.
##   Y-20  a grow that a roof or a frozen thing stops: a bonk star where it hit, the blocker flashes,
##         a "nope" (it used to shrink back in silence).
##   Y-21  every size zap shows the size ladder; at a cap the end square blinks and a stop bar shows
##         (it used to be a bare "nope"). A grab on what the partner carries rings in their colour;
##         glue on a pair that is already stuck pulses their blob.
##   Y-22  glue that is still pulling shows a stretchy string; when the pair can't meet, the string
##         snaps with a sound (it used to let go in silence after 3 s).
## Every scene is staged on the flat strip: one object on the ground, nothing piled. Own save
## profile and settings file; fixture roster.
class_name TestGapClose4
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
var _clock := Clock.new()

const FIXTURE := "res://tests/fixtures/roster_two.json"
const OBJECTS := "res://data/objects/"
const P1 := Players.P1
const P2 := Players.P2
const IDLE := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}

var world: Node3D
var _real_settings := ""
var _real_profile := ""
var _real_roster := ""
var _real_picks := ""


func before() -> void:
	_clock.pin()
	_real_profile = Save.profile
	Save.profile = "gdunit_gap_close_4"
	Save.wipe()
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_gap_close_4.json"
	Save.wipe_settings()
	_real_roster = Roster.data_path
	Roster.data_path = FIXTURE
	_real_picks = Roster.picks_path
	Roster.picks_path = "user://test_gap_close_4_players.json"
	Roster.args_override = PackedStringArray(["--no-picks"])
	Roster.reload()


func after() -> void:
	_clock.restore()
	Save.wipe()
	Save.profile = _real_profile
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Roster.data_path = _real_roster
	Roster.picks_path = _real_picks
	Roster.args_override = PackedStringArray()
	Roster.reload()


func before_test() -> void:
	Players.reset()
	Game.demo = false
	Game.start_round()
	Audio.history.clear()
	Refusal.clear()
	world = Node3D.new()
	add_child(world)
	world.add_child(YardStrip.new())


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()
	get_tree().paused = false


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func spawn(id: String, at: Vector3) -> PhysicsObject:
	var o := PhysicsObject.new(load(OBJECTS + id + ".tres"))
	o.position = at
	world.add_child(o)
	return o


## A static slab: a low roof or a wall. Collision layer 1, like the yard's own geometry.
func slab(center: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	b.position = center
	world.add_child(b)
	return b


func zapper(player: int, x: float) -> Zapper:
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	z.player = player
	z.position = Vector3(x, 0.05, 0)
	world.add_child(z)
	z.input_override = IDLE.duplicate()
	return z


func gun_index(z: Zapper, id: StringName) -> int:
	for i in z.guns.size():
		if z.guns[i].id == id:
			return i
	return -1


func fire(z: Zapper, aim := Vector2.RIGHT, hold := 1, move := Vector2.ZERO) -> void:
	z.input_override = IDLE.merged({"action": true, "aim": aim, "move": move}, true)
	await step(hold)
	z.input_override = IDLE.merged({"aim": aim}, true)
	await step(2)


# ------------------------------------------------------------------------------------------ Y-20

func test_a_grow_under_a_roof_bonks_where_it_hit_and_says_nope() -> void:
	# A 1 m crate on the ground, a static roof 0.15 m over its top: one grow (x1.3) must hit it.
	var crate := spawn("crate", Vector3(0, 0.5, 0))
	var roof := slab(Vector3(0, 1.15 + 0.25, 0), Vector3(4, 0.5, 4))
	await step(10)
	assert_bool(Effects.zap(&"grow", crate)).is_true()
	await step(60)   # 0.4 s stalled, then refused
	var r := Refusal.last(&"blocked")
	assert_bool(r.is_empty()).override_failure_message("a blocked grow showed nothing").is_false()
	assert_object(r.cause).is_same(roof)
	assert_float((r.at as Vector3).y).is_between(1.0, 1.35)   # on the roof's underside, over the crate
	assert_float(absf((r.at as Vector3).x)).is_less(0.8)
	assert_bool(Audio.history.has("nope")).is_true()
	assert_object(crate.stack.get_effect(&"size")).is_null()   # it boinged back to normal size
	var ladder := crate.get_node_or_null("SizeLadder") as Refusal.SizeLadder
	assert_object(ladder).is_not_null()
	assert_bool(ladder.visible).is_true()
	assert_int(ladder.steps).is_equal(0)


func test_a_frozen_thing_that_stops_a_grow_is_named_as_the_cause() -> void:
	# A crate frozen in mid-air 0.15 m over a crate on the ground: growing up bumps into it.
	var crate := spawn("crate", Vector3(0, 0.5, 0))
	var ice := spawn("crate", Vector3(0, 1.65, 0))
	Effects.zap(&"freeze", ice)   # before any physics step: it never falls
	await step(10)
	assert_bool(ice.freeze).is_true()
	Effects.zap(&"grow", crate)
	await step(60)
	var r := Refusal.last(&"blocked")
	assert_bool(r.is_empty()).is_false()
	assert_object(r.cause).is_same(ice)
	assert_float((r.at as Vector3).y).is_between(1.0, 1.35)   # on the frozen crate's underside


func test_a_free_grow_shows_no_bonk() -> void:
	var crate := spawn("crate", Vector3(0, 0.5, 0))
	await step(10)
	Effects.zap(&"grow", crate)
	await step(60)
	assert_bool(Refusal.last(&"blocked").is_empty()).is_true()
	assert_int((crate.stack.get_effect(&"size") as Effects.Size).steps).is_equal(1)


# ------------------------------------------------------------------------------------------ Y-21

func test_size_zaps_light_the_ladder_and_the_cap_shows_a_stop() -> void:
	var z := zapper(P1, 0.0)
	var crate := spawn("crate", Vector3(3.0, 0.5, 0))
	await step(5)
	z._size_latched = crate
	assert_bool(z._size_step(1)).is_true()
	var ladder := crate.get_node_or_null("SizeLadder") as Refusal.SizeLadder
	assert_object(ladder).is_not_null()
	assert_array(ladder.lit_steps()).contains_exactly([0, 1])
	assert_int(ladder.cap).is_equal(0)
	for i in 3:
		z._size_step(1)
	assert_array(ladder.lit_steps()).contains_exactly([0, 1, 2, 3, 4])
	assert_bool(Refusal.last(&"size_cap").is_empty()).is_true()
	# One more: it's as big as it gets. The nope comes with the cause.
	assert_bool(z._size_step(1)).is_false()
	assert_bool(Audio.history.has("nope")).is_true()
	assert_int(ladder.cap).is_equal(1)
	assert_int(Refusal.last(&"size_cap").cause).is_equal(1)
	assert_bool(ladder._bar.visible).is_true()
	assert_float(ladder._bar.position.x).is_greater(ladder._cells[-1].position.x)   # past the biggest
	# All the way down, then one more.
	for i in 8:
		z._size_step(-1)
	assert_array(ladder.lit_steps()).contains_exactly([-4, -3, -2, -1, 0])
	assert_bool(z._size_step(-1)).is_false()
	assert_int(ladder.cap).is_equal(-1)
	assert_float(ladder._bar.position.x).is_less(ladder._cells[0].position.x)   # before the smallest


func test_the_ladder_fades_after_a_moment_and_rides_above_the_object() -> void:
	var crate := spawn("crate", Vector3(3.0, 0.5, 0))
	await step(5)
	Effects.zap(&"grow", crate)
	var ladder := Refusal.size_ladder(crate)
	await get_tree().process_frame
	assert_float(ladder.global_position.y).is_greater(crate.global_position.y + 0.5)
	assert_float(absf(ladder.global_position.x - crate.global_position.x)).is_less(0.2)
	await await_millis(int(Refusal.SizeLadder.LIFE * 1000.0) + 300)
	assert_bool(ladder.visible).is_false()


func test_grabbing_what_the_partner_carries_rings_in_their_colour() -> void:
	var z1 := zapper(P1, 0.0)
	var z2 := zapper(P2, 6.0)
	var crate := spawn("crate", Vector3(2.8, 0.5, 0))
	await step(5)
	assert_object(Effects.grab(crate, z2, Players.COLOR[P2])).is_not_null()
	z1.set_gun(gun_index(z1, &"grab"), false)
	await fire(z1)
	assert_object(z1.held).is_null()
	assert_bool(Audio.history.has("nope")).is_true()
	var r := Refusal.last(&"held")
	assert_bool(r.is_empty()).override_failure_message("a refused grab showed no cause").is_false()
	assert_object(r.obj).is_same(crate)
	assert_that(r.cause).is_equal(Players.COLOR[P2])


func test_glue_on_a_pair_already_stuck_pulses_their_blob() -> void:
	var z := zapper(P1, 0.0)
	var a := spawn("crate", Vector3(2.8, 0.5, 0))
	var b := spawn("crate", Vector3(3.8, 0.5, 0))
	await step(5)
	var g := Effects.glue(a, b)
	assert_object(g).is_not_null()
	await step(5)
	assert_bool(g.joined()).is_true()
	z.glue_first = a
	z.target = b
	assert_bool(z._fire_glue()).is_false()
	var r := Refusal.last(&"already_glued")
	assert_bool(r.is_empty()).is_false()
	assert_object(r.cause).is_same(g)


# ------------------------------------------------------------------------------------------ Y-22

func test_glue_that_cannot_meet_shows_a_string_then_snaps() -> void:
	# A static wall between the two crates, taller than both: the pull can't close the gap.
	var a := spawn("crate", Vector3(-1.6, 0.5, 0))
	var b := spawn("crate", Vector3(1.6, 0.5, 0))
	slab(Vector3(0, 1.5, 0), Vector3(0.4, 3.0, 4))
	await step(10)
	var g := Effects.glue(a, b)
	assert_object(g).is_not_null()
	assert_bool(g.joined()).is_false()
	await step(3)
	var string := g.string_mesh
	assert_object(string).is_not_null()
	assert_bool(string.is_inside_tree()).is_true()
	var ends := g.string_ends()
	assert_float(absf(string.global_position.x - (ends[0].x + ends[1].x) * 0.5)).is_less(0.15)
	await step(int(Effects.Glue.PULL_TIME * 60.0) + 10)
	assert_bool(a.stack.has(&"glue") or b.stack.has(&"glue")).is_false()
	assert_bool(is_instance_valid(string) and string.is_inside_tree() and not string.is_queued_for_deletion()).is_false()
	var r := Refusal.last(&"glue_snap")
	assert_bool(r.is_empty()).override_failure_message("the glue let go in silence").is_false()
	assert_bool(Audio.history.has("unglue")).is_true()
	# The snap is seen even with a wall in the way: both halves whip back (drawn over everything).
	assert_int(Refusal.recoils).is_equal(2)


func test_glue_that_meets_drops_the_string_for_the_blob() -> void:
	var a := spawn("crate", Vector3(-0.9, 0.5, 0))
	var b := spawn("crate", Vector3(0.9, 0.5, 0))
	await step(10)
	var g := Effects.glue(a, b)
	assert_object(g.string_mesh).is_not_null()
	for i in 120:
		await step(1)
		if g.joined():
			break
	assert_bool(g.joined()).is_true()
	assert_object(g.string_mesh).is_null()
	assert_object(g.blob).is_not_null()
	assert_bool(Refusal.last(&"glue_snap").is_empty()).is_true()
