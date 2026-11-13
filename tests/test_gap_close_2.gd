## Gap-close lane 2 (jyz-gap-close-2). A-12 / P-05 / P-06: a character's delight and zap barks
## speak in their own voice pack (cheer / win), not the generic synth, and nobody talks over a
## spoken line; a player who drops in (wakes in the tire pile) says hello, and the solo swap says
## "I'm in", and a refused zap gets a gentle "oops", each in their own voice. Fixture roster and settings only, never the real roster's contents.
class_name TestGapClose2
extends GdUnitTestSuite

const ROSTER := "res://tests/fixtures/roster_comedy.json"
const CHEER := "res://tests/fixtures/voice/cheer.ogg"

var _real_roster := ""
var _real_picks := ""
var _real_args: Variant = null
var _real_profile := ""
const PICKS := "user://test_gap_close_2_players.json"
var _real_settings := ""
var world: Node3D
const IDLE := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}


func before() -> void:
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_gap_close_2.json"   # never the real settings file
	Save.wipe_settings()
	_real_profile = Save.profile
	Save.profile = "gdunit_gap_close_2"   # main.tscn saves the yard: never the family's profile
	_real_roster = Roster.data_path
	_real_picks = Roster.picks_path
	_real_args = Roster.args_override
	Roster.data_path = ROSTER
	Roster.picks_path = PICKS
	Roster.args_override = PackedStringArray(["--gdunit-gap-close-2"])   # not this run's real args
	Roster.reload()


func after() -> void:
	Roster.data_path = _real_roster
	Roster.picks_path = _real_picks
	Roster.args_override = _real_args
	if FileAccess.file_exists(PICKS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PICKS))
	Roster.reload()
	Save.profile = _real_profile
	Players.set_solo(false)
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	_fresh_gates()


func before_test() -> void:
	Players.reset()
	Game.demo = false
	world = Node3D.new()
	add_child(world)
	world.add_child(YardStrip.new())
	Audio.history.clear()
	_fresh_gates()


func after_test() -> void:
	Audio.stop_all()
	Audio.clock = -1.0
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()


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



func zapper(player: int, who: String) -> Zapper:
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	z.player = player
	z.character = who
	z.position = Vector3(2.0 * player, 0.05, 0)
	world.add_child(z)
	z.input_override = IDLE.duplicate()
	return z


func test_a_drop_in_snorts_then_says_hello_in_their_own_voice() -> void:
	assert_str(Audio._pack_file("chuck", "join")).is_equal("res://tests/fixtures/voice/join.ogg")
	var chuck := zapper(Players.P2, "chuck")
	await get_tree().physics_frame
	chuck.set_asleep(true)
	Audio.clock = 12000.0
	Audio.history.clear()
	chuck.wake()
	assert_bool(Audio.played("snort")).is_true()     # the snort comes first, at once
	assert_bool(Audio.played("roster:chuck")).is_false()
	await get_tree().create_timer(Zapper.JOIN_LINE_DELAY + 0.25).timeout
	assert_bool(Audio.played("roster:chuck")).is_true()   # then his own "join" line
	assert_bool(Audio.can_bark("anyone")).is_false()      # and nobody talks over it


func test_a_drop_in_with_no_voice_pack_still_says_something() -> void:
	var dee := zapper(Players.P2, "dee")
	await get_tree().physics_frame
	dee.set_asleep(true)
	Audio.clock = 13000.0
	Audio.history.clear()
	dee.wake()
	await get_tree().create_timer(Zapper.JOIN_LINE_DELAY + 0.25).timeout
	assert_bool(Audio.played("bark")).is_true()   # no bark_join cue: the plain generic bark


func test_the_solo_swap_says_im_in() -> void:
	assert_str(Audio._pack_file("jeff", "swap_in")).is_equal("res://tests/fixtures/voice/swap_in.ogg")
	var jeff := zapper(Players.P1, "jeff")
	await get_tree().physics_frame
	Audio.clock = 14000.0
	Audio.history.clear()
	assert_str(jeff.say("swap_in")).is_equal("roster:jeff")
	assert_str(jeff.say("swap_in")).is_equal("")   # the gate: never twice over itself


func test_the_solo_swap_in_the_yard_speaks_the_new_players_line() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	world.add_child(main)
	for i in 2:
		await get_tree().physics_frame
	Players.set_solo(true)
	Game.to_lobby()
	Game.finish_lobby([Players.P1, Players.P2])
	for i in 2:
		await get_tree().physics_frame
	Audio.clock = 15000.0
	Audio.history.clear()
	main.swap_solo_focus()
	assert_int(Players.solo_focus).is_equal(Players.P2)
	assert_bool(Audio.played("solo_swap")).is_true()
	assert_bool(Audio.played("roster:chuck")).is_true()   # the fixture's P2 default, own voice
	Players.set_solo(false)


func test_a_refused_zap_gets_a_gentle_oops_in_their_own_voice() -> void:
	assert_str(Audio._pack_file("jeff", "oops")).is_equal("res://tests/fixtures/voice/oops.ogg")
	var jeff := zapper(Players.P1, "jeff")
	await get_tree().physics_frame
	Audio.clock = 16000.0
	Audio.history.clear()
	assert_str(jeff.reactions.own_zap(false, true)).is_equal("roster:jeff")
	assert_str(jeff.reactions.last_reaction).is_equal("oops")
	# Past every bark gap but inside OOPS_GAP: mashing at the size cap never nags.
	Audio.clock = 16000.0 + Audio.VOICE_LINE_MAX + Audio.BARK_GAP + 0.1
	assert_str(jeff.reactions.own_zap(false, true)).is_equal("")
	Audio.clock = 16000.0 + jeff.reactions.OOPS_GAP + Audio.VOICE_LINE_MAX
	assert_str(jeff.reactions.own_zap(false, true)).is_equal("roster:jeff")
	# A zap that worked is never an oops.
	Audio.clock += 30.0
	jeff.reactions.last_reaction = ""
	jeff.reactions.own_zap(true, false)
	assert_str(jeff.reactions.last_reaction).is_not_equal("oops")


func test_a_long_stand_still_gets_one_wait_line_in_their_own_voice() -> void:
	var jeff := zapper(Players.P1, "jeff")
	await get_tree().physics_frame
	Audio.clock = 17000.0
	Audio.history.clear()
	var r := jeff.reactions
	# Standing still, short of WAIT_LINE_AFTER: idle bits only, no line.
	for i in int((r.WAIT_LINE_AFTER - 0.5) / 0.25):
		r.tick(0.25, false, true)
	assert_bool(Audio.played("roster:jeff")).is_false()
	for i in 4:
		r.busy_left = 0.0
		r.tick(0.25, false, true)
	assert_bool(Audio.played("roster:jeff")).is_true()   # "I'll just look at this rock."
	assert_str(r.last_reaction).is_equal("wait")
	# Still standing there, long past every gate: never a second one in the same stretch.
	Audio.history.clear()
	Audio.clock += 60.0
	for i in 120:
		r.busy_left = 0.0
		r.tick(0.25, false, true)
	assert_bool(Audio.played("roster:jeff")).is_false()
	# He moves, then stands still again: a new stretch may have its line.
	r.tick(0.25, true, true)
	Audio.clock += 60.0
	for i in int(r.WAIT_LINE_AFTER / 0.25) + 4:
		r.busy_left = 0.0
		r.tick(0.25, false, true)
	assert_bool(Audio.played("roster:jeff")).is_true()
