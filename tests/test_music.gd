## Music-gaps lane (A-10, A-11): the yard starts its looping music, a finished card lifts it to the
## bright layer for ten seconds (in sync with the base loop) and back, a skipped card does not, and
## the music sits under the barks.
class_name TestMusic
extends GdUnitTestSuite

var world: Node3D
var _real_settings := ""


func before() -> void:
	Save.profile = "gdunit"   # never touch the family's yard
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_music.json"
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
	Audio.clock = -1.0
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	Audio.stop_music(0.01)
	Audio.clock = -1.0
	Audio._last_bark.clear()        # the bark test must not gate the next suite's barks
	Audio._last_any_bark = -100.0
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()
	await get_tree().create_timer(0.05).timeout


func level() -> YardLevel:
	var l := YardLevel.new()
	l.use_save = false
	l.layout = load(YardLevel.LAYOUT)
	world.add_child(l)
	var players := Node3D.new()
	players.name = "Players"
	l.add_child(players)
	return l


## Wait until the base loop is fully in (the yard fades it in over 0.5 s).
func settle() -> void:
	await get_tree().create_timer(0.7).timeout


func test_the_yard_starts_the_looping_music() -> void:
	Audio.stop_music(0.01)
	await get_tree().create_timer(0.05).timeout
	level()
	assert_str(Audio.music_track).is_equal("music_yard")
	assert_bool(Audio._music.playing).is_true()
	var base: AudioStreamOggVorbis = Audio._music.stream
	var bright: AudioStreamOggVorbis = Audio._bright.stream
	assert_object(base).is_not_null()
	assert_object(bright).is_not_null()
	assert_bool(base.loop).is_true()
	assert_bool(bright.loop).is_true()
	# Same length, so a layer started at the base's position stays on the beat lap after lap.
	assert_float(bright.get_length()).is_equal_approx(base.get_length(), 0.01)
	assert_float(base.get_length()).is_greater(20.0)
	await settle()
	assert_float(Audio.music_mix().x).is_equal_approx(1.0, 0.01)
	assert_float(Audio.music_mix().y).is_equal_approx(0.0, 0.01)
	assert_bool(Audio._bright.playing).is_false()   # no hidden second track until a card is done


func test_a_skipped_card_does_not_brighten() -> void:
	var l := level()
	await settle()
	l.deck.skip()
	assert_bool(Audio.played("card_skip")).is_true()
	assert_float(Audio.bright_left).is_equal(0.0)
	await get_tree().create_timer(1.2).timeout
	assert_float(Audio.music_mix().x).is_equal_approx(1.0, 0.01)
	assert_float(Audio.music_mix().y).is_equal_approx(0.0, 0.01)
	assert_bool(Audio._bright.playing).is_false()


func test_a_finished_card_lifts_the_music_in_sync() -> void:
	var l := level()
	await settle()
	l.deck.complete()
	assert_bool(Audio.played("card_done")).is_true()
	assert_float(Audio.bright_left).is_equal_approx(Audio.BRIGHT_SECS, 0.05)
	assert_bool(Audio._bright.playing).is_true()
	await get_tree().create_timer(0.3).timeout
	var len := Audio._music.stream.get_length()
	var gap := absf(Audio._bright.get_playback_position() - Audio._music.get_playback_position())
	gap = minf(gap, len - gap)    # either side of the loop point
	assert_float(gap).is_less(0.1)


func test_the_lift_holds_ten_seconds_then_fades_back() -> void:
	Audio.music("music_yard", 0.1)
	await get_tree().create_timer(0.3).timeout
	Audio.play("card_done")
	await get_tree().create_timer(Audio.BRIGHT_FADE + 0.2).timeout
	assert_float(Audio.music_mix().y).is_equal_approx(1.0, 0.01)
	await get_tree().create_timer(Audio.BRIGHT_SECS - Audio.BRIGHT_FADE - 1.0).timeout
	# ~9 s in: still bright.
	assert_float(Audio.bright_left).is_between(0.5, 1.6)
	assert_float(Audio.music_mix().y).is_equal_approx(1.0, 0.01)
	await get_tree().create_timer(1.0 + Audio.BRIGHT_FADE * 0.5).timeout
	# Fading back: both halfway, neither silent.
	var mid := Audio.music_mix()
	assert_float(mid.x).is_between(0.1, 0.95)
	assert_float(mid.y).is_between(0.05, 0.9)
	await get_tree().create_timer(Audio.BRIGHT_FADE).timeout
	assert_float(Audio.music_mix().x).is_equal_approx(1.0, 0.01)
	assert_float(Audio.music_mix().y).is_equal_approx(0.0, 0.01)
	assert_bool(Audio._bright.playing).is_false()


func test_a_second_card_extends_the_lift() -> void:
	Audio.music("music_yard", 0.1)
	await get_tree().create_timer(0.3).timeout
	Audio.play("card_done")
	await get_tree().create_timer(2.0).timeout
	Audio.play("card_done")
	assert_float(Audio.bright_left).is_equal_approx(Audio.BRIGHT_SECS, 0.05)
	assert_float(Audio.music_mix().y).is_equal_approx(1.0, 0.01)


func test_the_music_ducks_under_a_bark() -> void:
	Audio.clock = 5000.0
	Audio.music("music_yard", 0.1)
	Audio.bark("nobody_here", "zap", self)
	assert_float(Audio.duck_db()).is_less_equal(Audio.DUCK_BARK_DB + 0.01)
	await get_tree().create_timer(Audio.DUCK_HOLD + 1.0).timeout
	assert_float(Audio.duck_db()).is_equal(0.0)
