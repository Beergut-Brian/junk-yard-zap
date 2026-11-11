## Gap-close lane (jyz-gap-close-1): every gun sounds like itself (U-15), vehicles and machines
## react without a face (Y-12, K-10), loose balloons (Y-11), the trophy shelf (G-13).
## Own settings file, own save profile and the fixture roster: never the family's or the real roster.
class_name TestGapClose
extends GdUnitTestSuite

const P1 := Players.P1
const IDLE := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}
const FIXTURE := "res://tests/fixtures/roster_two.json"
const SFX := "res://assets/audio/sfx/"

var world: Node3D
var _real_settings := ""
var _real_profile := ""
var _real_roster := ""
var _real_picks := ""


func before() -> void:
	_real_profile = Save.profile
	Save.profile = "gdunit_gap_close"
	Save.wipe()
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_gap_close.json"
	Save.wipe_settings()
	_real_roster = Roster.data_path
	Roster.data_path = FIXTURE
	_real_picks = Roster.picks_path
	Roster.picks_path = "user://test_gap_close_players.json"
	Roster.args_override = PackedStringArray(["--no-picks"])
	Roster.reload()


func after() -> void:
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
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


## The cue a gun plays on a successful zap (zapper.gd): Size steps grow, Grab hums, the rest zap_<id>.
static func fire_cue(g: GunData) -> String:
	match g.kind:
		GunData.Kind.SIZE: return "grow"
		GunData.Kind.GRAB: return "grab"
	return g.zap_cue()


static func _md5(cue: String) -> String:
	var path := SFX + cue + ".ogg"
	if not FileAccess.file_exists(path):
		path = SFX + cue + "_1.ogg"
	return FileAccess.get_md5(path)


# ------------------------------------------------------------------------------------------ U-15

func test_every_gun_fires_its_own_sound() -> void:
	var seen := {}
	var guns := Zapper.load_guns()
	assert_int(guns.size()).is_equal(7)
	for g in guns:
		var cue := fire_cue(g)
		assert_bool(Audio.has_cue(cue)).override_failure_message("%s has no file for %s" % [g.id, cue]).is_true()
		assert_int(Audio.variants(cue)).override_failure_message("%s is a synth beep" % cue).is_greater_equal(1)
		var sum := _md5(cue)
		assert_bool(seen.has(sum)).override_failure_message("%s sounds the same as %s" % [g.id, seen.get(sum)]).is_false()
		seen[sum] = g.id


# ---------------------------------------------------------------------------- Y-12, K-10 faces

const FACELESS := [&"car", &"tractor", &"boat", &"wheelbarrow", &"washing_machine", &"tv", &"toaster",
		&"fridge", &"cannon"]


static func _all_objects() -> Array[ObjectData]:
	var out: Array[ObjectData] = []
	for f in DirAccess.get_files_at("res://data/objects/"):
		if f.ends_with(".tres"):
			out.append(load("res://data/objects/" + f) as ObjectData)
	return out


func test_vehicles_and_machines_have_no_face_everything_else_does() -> void:
	var datas := _all_objects()
	assert_int(datas.size()).is_greater_equal(48)
	for d in datas:
		assert_bool(d.has_face).override_failure_message("%s: face rule" % d.id).is_equal(not FACELESS.has(d.id))
		# Nothing is mute: every type, faceless or not, has its own voice file set.
		assert_bool(Audio.has_cue(d.voice_cue() + "_react")).override_failure_message("%s is mute" % d.id).is_true()


func test_a_faceless_machine_rattles_and_speaks_when_zapped() -> void:
	world.add_child(YardStrip.new())
	var car := PhysicsObject.new(load("res://data/objects/car.tres"))
	car.position = Vector3(0, 1.0, 0)
	world.add_child(car)
	await step(40)
	assert_object(car.face).is_null()
	var vis := car.get_node("Visual") as Node3D
	assert_float(vis.rotation.z).is_equal(0.0)
	Audio.history.clear()
	Audio.stop_all()
	Audio.clock = 5000.0   # clear of the landing's voice rate cap
	assert_bool(Effects.zap(&"bouncy", car)).is_true()
	car.speak()
	Audio.clock = -1.0
	assert_bool(car.rattling()).is_true()
	assert_bool(Audio.played("voice_car_react")).is_true()
	var moved := false
	for i in 20:
		await step(1)
		moved = moved or absf(vis.rotation.z) > 0.02 or vis.position.y > 0.01
	assert_bool(moved).override_failure_message("the car did not rattle").is_true()
	await step(60)
	assert_bool(car.rattling()).is_false()
	assert_float(vis.rotation.z).is_equal(0.0)
	assert_float(vis.position.y).is_equal(0.0)


func test_a_cow_still_pulls_a_face_and_does_not_rattle() -> void:
	world.add_child(YardStrip.new())
	var cow := PhysicsObject.new(load("res://data/objects/cow.tres"))
	cow.position = Vector3(0, 1.0, 0)
	world.add_child(cow)
	await step(20)
	assert_object(cow.face).is_not_null()
	Effects.zap(&"bouncy", cow)
	assert_bool(cow.rattling()).is_false()


# ------------------------------------------------------------------------------------- Y-11 balloons

func test_the_loose_balloons_hover_bob_and_come_back_up() -> void:
	world.add_child(YardStrip.new())
	var d: ObjectData = load("res://data/objects/balloons.tres")
	assert_float(d.hover_height).is_greater(0.0)
	assert_bool(ObjectArt.has_art(&"balloons")).is_true()
	assert_bool(Audio.has_cue(d.voice_cue() + "_react")).is_true()
	var b := PhysicsObject.new(d)
	b.position = Vector3(0, d.size.y * 0.5 + 0.05, 0)
	world.add_child(b)
	assert_object(b.face).is_not_null()
	await step(180)
	var bottom := b.global_position.y - d.size.y * 0.5
	assert_float(bottom).override_failure_message("bottom %.2f" % bottom).is_between(d.hover_height - 0.35, d.hover_height + 0.35)
	assert_bool(b.hovering()).is_true()
	# Pushed down hard, it floats back up; it never sleeps mid-air.
	b.linear_velocity = Vector3(3, -8, 0)
	await step(150)
	bottom = b.global_position.y - d.size.y * 0.5
	assert_float(bottom).is_between(d.hover_height - 0.35, d.hover_height + 0.35)
	assert_bool(b.sleeping).is_false()
	assert_float(absf(b.linear_velocity.x)).is_less(0.6)   # air drag: it drifts to a stop


func test_balloon_gun_freeze_and_undo_take_over_then_hand_back() -> void:
	world.add_child(YardStrip.new())
	var d: ObjectData = load("res://data/objects/balloons.tres")
	var b := PhysicsObject.new(d)
	b.position = Vector3(0, 2.5, 0)
	world.add_child(b)
	await step(120)
	var rest := b.global_position.y
	assert_bool(Effects.zap(&"freeze", b)).is_true()
	assert_bool(b.hovering()).is_false()
	assert_bool(Effects.zap(&"freeze", b)).is_true()   # unfreeze
	assert_bool(Effects.zap(&"balloon", b)).is_true()
	await step(120)
	assert_float(b.global_position.y).is_greater(rest + 1.0)   # the balloon gun lifts it higher
	assert_bool(Effects.zap(&"balloon", b)).is_true()           # undo: back down to its own hover
	await step(240)
	assert_float(b.global_position.y).is_between(rest - 0.4, rest + 0.4)


func test_the_balloons_are_placed_at_the_front_gate() -> void:
	var layout: YardLayout = load(YardLevel.LAYOUT)
	var found := false
	for e in layout.entries:
		if e.key == &"balloons":
			found = true
			assert_float(e.position.x).is_between(-48.0, -29.0)
	assert_bool(found).is_true()


# --------------------------------------------------------------------------------- G-13 trophy shelf

func _deck_with_done(n: int) -> GoalDeck:
	var deck := GoalDeck.new()
	deck.load_dir(GoalDeck.DIR)
	world.add_child(deck)
	deck.checking = false
	for i in n:
		deck.complete()
	return deck


func test_the_trophy_shelf_flips_through_done_cards_and_wraps() -> void:
	var deck := _deck_with_done(3)
	var card := FenceCard.new()
	card.deck = deck
	world.add_child(card)
	await step(2)
	var shelf := card.shelf
	assert_object(shelf).is_not_null()
	assert_bool(shelf.is_in_group(&"zap_targets")).is_true()
	assert_int(shelf.count()).is_equal(3)
	assert_str(String(shelf.showing())).is_equal("")
	Audio.history.clear()
	shelf.zapped_by(null, null)   # newest first
	assert_str(String(shelf.showing())).is_equal(String(deck.done[2]))
	assert_bool(Audio.played("card_view")).is_true()
	shelf.zapped_by(null, null)
	assert_str(String(shelf.showing())).is_equal(String(deck.done[1]))
	shelf.zapped_by(null, null)
	shelf.zapped_by(null, null)   # wraps back round to the newest
	assert_str(String(shelf.showing())).is_equal(String(deck.done[2]))
	await step(20)
	var sprite := shelf.get_child(shelf.get_child_count() - 1) as Sprite3D
	assert_bool(sprite.visible).is_true()
	assert_float(sprite.scale.x).is_greater(0.5)
	# Left alone, it folds itself away; the pile and the deck are untouched.
	shelf.fold()
	await step(30)
	assert_str(String(shelf.showing())).is_equal("")
	assert_bool(sprite.visible).is_false()
	assert_int(deck.done.size()).is_equal(3)


func test_an_empty_shelf_still_answers_a_zap() -> void:
	var deck := _deck_with_done(0)
	var card := FenceCard.new()
	card.deck = deck
	world.add_child(card)
	await step(2)
	Audio.history.clear()
	card.shelf.zapped_by(null, null)
	assert_bool(Audio.played("sparkle")).is_true()
	assert_str(String(card.shelf.showing())).is_equal("")


func test_a_zapper_aimed_at_the_shelf_flips_it_not_the_card() -> void:
	world.add_child(YardStrip.new())
	var deck := _deck_with_done(2)
	var card := FenceCard.new()
	card.deck = deck
	card.position = Vector3(0, 2.6, -0.9)
	world.add_child(card)
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	z.player = P1
	z.position = Vector3(-1.5, 0.05, 0)
	world.add_child(z)
	z.input_override = IDLE.duplicate()
	await step(5)
	var top := deck.current().id
	var aim := Vector2(card.shelf.global_position.x - z.aim_origin().x, card.shelf.global_position.y - z.aim_origin().y).normalized()
	z.input_override = IDLE.merged({"action": true, "aim": aim}, true)
	await step(1)
	z.input_override = IDLE.merged({"aim": aim}, true)
	await step(3)
	assert_str(String(card.shelf.showing())).is_equal(String(deck.done[1]))
	assert_str(String(deck.current().id)).is_equal(String(top))   # the card was not skipped


func test_the_first_glue_pick_gets_a_voice_and_a_face() -> void:
	world.add_child(YardStrip.new())
	var cow := PhysicsObject.new(load("res://data/objects/cow.tres"))
	cow.position = Vector3(2.5, 1.0, 0)
	world.add_child(cow)
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	z.player = P1
	z.position = Vector3(0, 0.05, 0)
	world.add_child(z)
	z.input_override = IDLE.duplicate()
	await step(40)
	for i in z.guns.size():
		if z.guns[i].id == &"glue":
			z.set_gun(i)
	Audio.history.clear()
	Audio.stop_all()
	Audio.clock = 6000.0
	z.input_override = IDLE.merged({"action": true, "aim": Vector2.RIGHT}, true)
	await step(1)
	Audio.clock = -1.0
	z.input_override = IDLE.merged({"aim": Vector2.RIGHT}, true)
	await step(2)
	assert_object(z.glue_first).is_same(cow)
	assert_bool(Audio.played("glue_pick")).is_true()
	assert_bool(Audio.played("voice_cow_react")).is_true()


# ------------------------------------------------------------------------------------------ A-14

## No scary sounds: nothing long enough to be a rumble or a drone, and every file mastered under
## full scale (the Master limiter catches stacks). The cartoon recipes are in make_cues.py.
func test_no_sound_effect_is_a_long_rumble() -> void:
	var n := 0
	for f in DirAccess.get_files_at(SFX):
		if not f.ends_with(".ogg"):
			continue
		var s: AudioStream = load(SFX + f)
		n += 1
		assert_float(s.get_length()).override_failure_message("%s is %.1f s" % [f, s.get_length()]).is_less_equal(4.0)
	assert_int(n).is_greater(250)
	assert_bool(AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Master")) > 0).is_true()
