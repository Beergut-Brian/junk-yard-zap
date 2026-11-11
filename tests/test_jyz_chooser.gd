## Junk Yard Zap plays whoever you picked (Roster): each zapper's Jarling is the pick's .glb with
## the junk gun on hand_r and the belt on waist (tape in the player colour), partner zaps and aim
## rings work on any standard body, the lobby podiums and name plates follow the pick, barks are the
## character's own or a generic one (never another character's voice), and the test-only stand-in
## (tests/fixtures/standin/, "Sprocket", a generic seed Jarling) is never shipped.
class_name TestJyzChooser
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
var _clock := Clock.new()   # 60 Hz, time scale 1: frame counts below mean the same seconds everywhere

const P1 := Players.P1
const P2 := Players.P2
const GREEN := Color("3cc24a")
const RED := Color("e4393c")
const FIXTURE := "res://tests/fixtures/roster_standin.json"
const STANDIN_GLB := "res://tests/fixtures/standin/standin.glb"
const PICKS := "user://test_jyz_chooser_players.json"
const IDLE := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}

var world: Node3D
var _main: Node
var _real_settings := ""
var _real_data := ""
var _real_picks := ""


func before() -> void:
	_clock.pin()
	Save.profile = "gdunit"   # main.tscn saves the yard: never touch the family's profile
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_jyz_chooser.json"
	Save.wipe_settings()
	_real_data = Roster.data_path
	_real_picks = Roster.picks_path
	Roster.data_path = FIXTURE
	Roster.picks_path = PICKS


func after() -> void:
	_clock.restore()
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Roster.data_path = _real_data
	Roster.picks_path = _real_picks
	Roster.args_override = PackedStringArray()
	Roster.reload()
	if FileAccess.file_exists(PICKS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PICKS))


func before_test() -> void:
	if FileAccess.file_exists(PICKS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PICKS))
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	UiStyle.use_skin(load(UiStyle.SKIN_PATH))
	Audio.history.clear()


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()
	Game._set_state(Game.State.LOBBY)


## --p1-char= / --p2-char= the way the launcher passes them ("" = defaults).
func picks(p1: String, p2: String) -> void:
	var args := PackedStringArray(["--placeholder"])
	if p1 != "":
		args.append("--p1-char=" + p1)
	if p2 != "":
		args.append("--p2-char=" + p2)
	Roster.args_override = args
	Roster.reload()


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func yard() -> void:
	Game.start_round()
	world = Node3D.new()
	add_child(world)
	world.add_child(YardStrip.new())


func zapper(player: int, x: float) -> Zapper:
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	z.player = player
	z.position = Vector3(x, 0.05, 0)
	world.add_child(z)
	z.input_override = IDLE.duplicate()
	return z


func fire(z: Zapper) -> void:
	z.input_override = IDLE.merged({"action": true, "aim": Vector2.RIGHT}, true)
	await step(3)
	z.input_override = IDLE.duplicate()
	await step(3)


func gear_on(z: Zapper, slot: StringName) -> Array:
	var node := z.rig.equipment.slot_node(slot)
	assert_object(node).override_failure_message("no %s slot on %s" % [slot, z.character]).is_not_null()
	return node.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("gear_"))


func tape_color(z: Zapper) -> Color:
	var tape := z.rig.find_child("tape", true, false) as MeshInstance3D
	assert_object(tape).is_not_null()
	return (tape.material_override as StandardMaterial3D).albedo_color


# ------------------------------------------------------------------------------------- spawn

func test_defaults_are_jeff_p1_and_chuck_p2() -> void:
	picks("", "")
	yard()
	var a := zapper(P1, -2.0)
	var b := zapper(P2, 2.0)
	await step(2)
	assert_str(a.character).is_equal("jeff")
	assert_str(b.character).is_equal("chuck")
	assert_str(a.rig.model.scene_file_path).is_equal("res://assets/characters/jeff/jeff.glb")
	assert_str(b.rig.model.scene_file_path).is_equal("res://assets/characters/chuck/chuck.glb")


func test_spawn_follows_the_pick_with_the_stand_in() -> void:
	picks("sprocket", "")
	yard()
	var z := zapper(P1, 0.0)
	await step(2)
	assert_str(z.character).is_equal("sprocket")
	assert_str(String(z.rig.character)).is_equal("sprocket")
	assert_str(z.rig.model.scene_file_path).is_equal(STANDIN_GLB)
	assert_object(z.rig.anim).is_not_null()
	assert_bool(z.rig.anim.has_animation("idle") and z.rig.anim.has_animation("run")).is_true()


func test_swapped_picks_keep_the_slot_colours() -> void:
	picks("chuck", "jeff")
	yard()
	var a := zapper(P1, -2.0)
	var b := zapper(P2, 2.0)
	await step(2)
	assert_str(a.character).is_equal("chuck")
	assert_str(b.character).is_equal("jeff")
	assert_that(tape_color(a)).is_equal(GREEN)   # P1 is green whoever they are
	assert_that(tape_color(b)).is_equal(RED)
	assert_that((a._marker.material_override as StandardMaterial3D).albedo_color).is_equal(GREEN)
	assert_that((b._marker.material_override as StandardMaterial3D).albedo_color).is_equal(RED)


func test_gear_equips_on_the_picked_body() -> void:
	picks("sprocket", "")
	yard()
	var z := zapper(P1, 0.0)
	await step(2)
	assert_int(gear_on(z, &"waist").size()).is_equal(1)                 # the gun belt
	var held := gear_on(z, &"hand_r")
	assert_int(held.size()).is_equal(1)
	assert_str(held[0].name).starts_with("gear_gun_")
	assert_bool(z.rig.gun_tip_position().distance_to(z.global_position) > 0.3).is_true()
	assert_that(tape_color(z)).is_equal(GREEN)
	# Cycling the belt swaps the gun on the stand-in's hand too.
	z.set_gun(3)
	held = gear_on(z, &"hand_r")
	assert_int(held.size()).is_equal(1)
	assert_str(held[0].name).is_equal("gear_gun_%s" % z.gun().effect_id())


func test_stand_in_zaps_and_is_zapped_like_anyone() -> void:
	picks("sprocket", "jeff")
	yard()
	var z := zapper(P1, 0.0)
	var mate := zapper(P2, 2.5)
	await step(5)
	z.input_override = IDLE.merged({"aim": Vector2.RIGHT}, true)
	await step(3)
	assert_object(z.target).is_same(mate)          # aim ring on the partner's body
	assert_bool(z._marker.visible).is_true()
	await fire(z)
	assert_int(mate._partner_kind).is_equal(z.gun().kind)
	await step(int(Zapper.PARTNER_TIME * 60) + 25)
	assert_int(mate._partner_kind).is_equal(-1)
	# And the other way round: Jeff zaps the stand-in.
	mate.input_override = IDLE.merged({"aim": Vector2.LEFT}, true)
	await step(3)
	assert_object(mate.target).is_same(z)
	mate.input_override = IDLE.merged({"action": true, "aim": Vector2.LEFT}, true)
	await step(3)
	mate.input_override = IDLE.duplicate()
	await step(3)
	assert_int(z._partner_kind).is_equal(mate.gun().kind)


func test_main_spawns_the_picks_and_drop_in_sleeps_the_pick() -> void:
	picks("sprocket", "chuck")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await await_idle_frame()
	var a: Zapper = _main._spawn(P1, false)
	var b: Zapper = _main._spawn(P2, true)        # not readied: asleep in the tire pile
	await step(3)
	assert_str(a.character).is_equal("sprocket")
	assert_str(a.rig.model.scene_file_path).is_equal(STANDIN_GLB)
	assert_str(b.character).is_equal("chuck")
	assert_bool(b.asleep).is_true()
	b.wake()
	assert_bool(b.asleep).is_false()


# ------------------------------------------------------------------------------- lobby

func test_lobby_podiums_and_plates_follow_the_pick() -> void:
	picks("sprocket", "jeff")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await await_idle_frame()
	var lobby: Control = _main.get_node("UI/Lobby")
	var want := {P1: ["sprocket", "SPROCKET"], P2: ["jeff", "JEFF"]}
	for p in [P1, P2]:
		var slot: CharacterSlot = lobby.get_node("Spots/P%d/Character" % (p + 1))
		var rig: JarlingRig = slot.character.get("rig")
		assert_object(rig).is_not_null()
		assert_str(String(rig.character)).is_equal(want[p][0])
		assert_object(rig.gun_gear).is_not_null()   # still holding the taped gun
		assert_str(UiStyle.skin().player_name(p)).is_equal(want[p][1])


func test_lobby_swap_rebuilds_the_podium_rig_with_the_gun() -> void:
	picks("", "")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await await_idle_frame()
	var lobby: Control = _main.get_node("UI/Lobby")
	var slot: CharacterSlot = lobby.get_node("Spots/P1/Character")
	var rig: JarlingRig = slot.character.get("rig")
	var tape := (rig.find_child("tape", true, false) as MeshInstance3D)
	assert_that((tape.material_override as StandardMaterial3D).albedo_color).is_equal(GREEN)
	assert_bool(Roster.set_pick(P1, "sprocket")).is_true()
	slot._become("sprocket")
	assert_str(String(rig.character)).is_equal("sprocket")
	assert_str(rig.model.scene_file_path).is_equal(STANDIN_GLB)
	assert_object(rig.gun_gear).is_not_null()
	tape = rig.find_child("tape", true, false) as MeshInstance3D
	assert_that((tape.material_override as StandardMaterial3D).albedo_color).is_equal(GREEN)
	assert_str(UiStyle.skin().player_name(P1)).is_equal("SPROCKET")
	# The next spawn is the new pick.
	world = Node3D.new()
	add_child(world)
	var z := zapper(P1, 0.0)
	assert_str(z.character).is_equal("sprocket")


func test_skin_has_no_fixed_names() -> void:
	var sk := load("res://data/menu_skin.tres") as MenuSkin
	assert_str(sk.p1_name).is_empty()
	assert_str(sk.p2_name).is_empty()


# ------------------------------------------------------------------------------- voices

func test_barks_fall_back_to_generic_never_another_voice() -> void:
	picks("sprocket", "jeff")
	yard()
	var a := zapper(P1, -2.0)
	var b := zapper(P2, 2.0)
	await step(2)
	# Nobody has recorded barks yet: the stand-in and Jeff both use the generic cues.
	assert_str(a.bark()).is_equal("bark")
	assert_str(a.bark("cheer")).is_equal("bark_cheer")
	for cue in Audio.history:
		assert_bool(cue.contains("jeff") or cue.contains("chuck")).override_failure_message(cue).is_false()
	Audio.history.clear()
	var used := b.bark()
	assert_bool(used == "bark_jeff" or used == "bark").is_true()
	assert_bool(used.contains("chuck") or used.contains("sprocket")).is_false()


func test_a_character_with_own_cue_uses_it() -> void:
	# The cue lookup is by id: "bark_<id>" only when that file exists.
	assert_bool(Audio.has_cue("bark_sprocket")).is_false()
	assert_bool(Audio.has_cue("zz_no_such_cue")).is_false()
	picks("chuck", "jeff")
	yard()
	var a := zapper(P1, 0.0)
	await step(1)
	var used := a.bark("cheer")
	assert_bool(used == "bark_chuck_cheer" or used == "bark_cheer").is_true()
	assert_bool(used == "bark_chuck_cheer").is_equal(Audio.has_cue("bark_chuck_cheer"))


# ------------------------------------------------------------------------------- shipping

func test_the_stand_in_never_ships() -> void:
	var cfg := ConfigFile.new()
	assert_int(cfg.load("res://export_presets.cfg")).is_equal(OK)
	var excl := str(cfg.get_value("preset.0", "exclude_filter", ""))
	assert_bool(Array(excl.split(",")).has("tests/*")).is_true()
	var incl := str(cfg.get_value("preset.0", "include_filter", ""))
	assert_bool(incl.contains("tests")).is_false()
	# The shipped roster only names vendored characters.
	var shipped = JSON.parse_string(FileAccess.get_file_as_string("res://data/roster.json"))
	assert_bool(shipped is Dictionary).is_true()
	assert_bool(Array(shipped.roster).has("sprocket")).is_false()
	for id in shipped.characters:
		var c: Dictionary = shipped.characters[id]
		assert_str(str(c.glb)).starts_with("res://assets/characters/")
		assert_bool(ResourceLoader.exists(str(c.glb))).is_true()
	# Nothing outside tests/ loads the fixture.
	for path in ["res://scenes/main.gd", "res://scripts/players/zapper.gd", "res://scripts/players/jarling_rig.gd",
			"res://scenes/ui/lobby_jarling.gd", "res://scripts/autoload/Roster.gd"]:
		assert_bool(FileAccess.get_file_as_string(path).contains("tests/fixtures")).override_failure_message(path).is_false()


func test_long_names_fit_on_the_plate() -> void:
	const LobbySpot := preload("res://scenes/ui/lobby_spot.gd")
	assert_int(LobbySpot.name_size("JEFF", 300.0)).is_equal(62)
	var size := LobbySpot.name_size("SPROCKETEER", 300.0)
	assert_int(size).is_less(62)
	assert_float(UiStyle.show_width("SPROCKETEER", size)).is_less_equal(300.0)
	assert_int(LobbySpot.name_size("A VERY VERY LONG NAME INDEED", 300.0)).is_equal(34)   # floor: stays readable
