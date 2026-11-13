## Gap-close lane 2 (jyz-gap-close-2). A-12 / P-05 / P-06: a character's delight and zap barks
## speak in their own voice pack (cheer / win), not the generic synth, and nobody talks over a
## spoken line. Fixture roster and settings only, never the real roster's contents.
class_name TestGapClose2
extends GdUnitTestSuite

const ROSTER := "res://tests/fixtures/roster_comedy.json"
const CHEER := "res://tests/fixtures/voice/cheer.ogg"

var _real_roster := ""
var _real_settings := ""
var world: Node


func before() -> void:
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_gap_close_2.json"   # never the real settings file
	Save.wipe_settings()
	_real_roster = Roster.data_path
	Roster.data_path = ROSTER
	Roster.reload()


func after() -> void:
	Roster.data_path = _real_roster
	Roster.reload()
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	_fresh_gates()


func before_test() -> void:
	world = Node.new()
	add_child(world)
	Audio.history.clear()
	_fresh_gates()


func after_test() -> void:
	Audio.stop_all()
	Audio.clock = -1.0
	if is_instance_valid(world):
		world.free()


func _fresh_gates() -> void:
	Audio.clock = -1.0
	Audio._last_bark.clear()
	Audio._last_any_bark = -100.0
	Audio._voice_until = -100.0


func test_delight_and_zap_use_the_characters_own_voice_pack() -> void:
	# The packs have cheer/win, never delight.ogg or zap.ogg: both kinds still find a line.
	assert_str(Audio._pack_file("jeff", "delight")).is_equal(CHEER)
	assert_str(Audio._pack_file("chuck", "zap")).is_equal(CHEER)
	assert_str(Audio._pack_file("jeff", "cheer")).is_equal(CHEER)
	# A kind with no line in the pack (and no alias) still says nothing from the pack.
	assert_str(Audio._pack_file("jeff", "lose")).is_equal("")
	# No voice at all: the generic cue, never another character's voice.
	Audio.clock = 7000.0
	assert_str(Audio.bark("dee", "delight", world)).is_equal("bark_delight")
	Audio.clock = 7100.0
	assert_str(Audio.bark("jeff", "delight", world)).is_equal("roster:jeff")
	Audio.clock = 7200.0
	assert_str(Audio.bark("chuck", "zap", world)).is_equal("roster:chuck")


func test_aliases_only_name_lines_the_library_packs_ship() -> void:
	# The aliases only name kinds the library packs ship (openjar-characters voice/ file stems).
	var shipped := ["catchphrase", "cheer", "join", "lose", "oops", "ready", "swap_in", "wait", "win"]
	for kind in Audio.PACK_KINDS:
		for k in Audio.PACK_KINDS[kind]:
			assert_bool(k in shipped).override_failure_message("%s -> %s is not a pack line" % [kind, k]).is_true()


func test_nobody_talks_over_a_spoken_line() -> void:
	var secs := (load(CHEER) as AudioStream).get_length()
	assert_float(secs).is_greater(Audio.BARK_ANY_GAP)   # a real line outlasts the old gap
	var jeff := Node.new()
	var chuck := Node.new()
	world.add_child(jeff)
	world.add_child(chuck)
	Audio.clock = 9000.0
	assert_bool(Audio.can_bark(jeff)).is_true()
	assert_str(Audio.bark("jeff", "delight", jeff)).is_equal("roster:jeff")
	# Past the old 0.7 s gap but Jeff is still talking: Chuck waits.
	Audio.clock = 9000.0 + Audio.BARK_ANY_GAP + 0.1
	assert_bool(Audio.can_bark(chuck)).is_false()
	# The line is over: Chuck may speak; Jeff gets a breath first.
	Audio.clock = 9000.0 + secs + 0.05
	assert_bool(Audio.can_bark(chuck)).is_true()
	assert_bool(Audio.can_bark(jeff)).is_false()
	Audio.clock = 9000.0 + secs + Audio.BARK_GAP + 0.05
	assert_bool(Audio.can_bark(jeff)).is_true()

