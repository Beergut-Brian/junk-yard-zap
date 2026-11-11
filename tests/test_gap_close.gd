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
