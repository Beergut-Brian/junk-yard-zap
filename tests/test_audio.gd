## Audio lane: every cue in CUES.md has a file, variants rotate, pitch follows scale, the music
## crossfade and bright-layer timing, the voice rate cap, bark gates, ducking and a bounded pool.
class_name TestAudio
extends GdUnitTestSuite

const CUES_MD := "res://assets/audio/CUES.md"
const KINDS := ["react", "grabbed", "thrown", "landed"]

var world: Node3D
var _bands: Array = []
var _real_settings := ""


func _on_big(_p: Vector3, band: String) -> void:
	_bands.append(band)


func before_suite() -> void:
	# Never the player's real settings file (a test that changes a slider must not touch it).
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_audio.json"


func after_suite() -> void:
	if FileAccess.file_exists(Save.settings_path):
		DirAccess.remove_absolute(Save.settings_path)
	Save.settings_path = _real_settings


func before_test() -> void:
	Audio.history.clear()
	Audio.clock = -1.0
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	Audio.clock = -1.0
	Audio.stop_music(0.01)
	if is_instance_valid(world):
		world.free()


## Cue names from the CUES.md tables: the first cell of every row, in backticks.
func cue_rows() -> Array[String]:
	var out: Array[String] = []
	var f := FileAccess.open(CUES_MD, FileAccess.READ)
	assert_object(f).is_not_null()
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("| `"):
			var cell := line.split("|")[1].strip_edges()
			out.append(cell.trim_prefix("`").trim_suffix("`"))
	return out


func test_every_cue_in_cues_md_resolves_to_a_file() -> void:
	var cues := cue_rows()
	assert_int(cues.size()).is_greater(60)
	for cue in cues:
		if cue.ends_with("_*"):   # an object voice set: all four kinds
			for kind in KINDS:
				var v: String = cue.trim_suffix("*") + kind
				assert_bool(Audio.has_cue(v)).override_failure_message("no file for %s" % v).is_true()
			continue
		var ok := Audio.has_cue(cue) or ResourceLoader.exists(Audio.MUSIC_DIR + cue + ".ogg")
		assert_bool(ok).override_failure_message("no file for %s" % cue).is_true()


func test_every_game_cue_has_a_file() -> void:
	# The GAME.md table plus every cue the code plays during play.
	var cues := ["zap_size", "zap_grab", "zap_bouncy", "zap_balloon", "zap_freeze", "zap_glue", "zap_magnet",
		"grow", "shrink", "grab", "throw", "drop", "impact_light", "impact_medium", "impact_heavy", "impact_huge",
		"splash", "card_view", "card_done", "card_skip", "reset_yard", "reset_hold", "wheel_move", "sparkle",
		"nope", "boing", "squelch", "crack", "jump", "land", "recall", "snort", "snore", "unglue", "glue_pick",
		"solo_swap", "solo_on", "solo_off", "player_join", "round_start", "round_end", "pause", "ui_confirm",
		"bark", "bark_cheer", "bark_zap", "bark_delight"]
	for cue in cues:
		assert_bool(Audio.has_cue(cue)).override_failure_message("no file for %s" % cue).is_true()
	for g in Zapper.load_guns():
		assert_bool(Audio.has_cue(g.zap_cue())).override_failure_message(g.zap_cue()).is_true()


func test_every_object_has_a_voice_set() -> void:
	var dir := DirAccess.open("res://data/objects/")
	var n := 0
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var d: ObjectData = load("res://data/objects/" + f)
		n += 1
		for kind in KINDS:
			var cue := "%s_%s" % [d.voice_cue(), kind]
			assert_bool(Audio.has_cue(cue)).override_failure_message("no voice %s" % cue).is_true()
	assert_int(n).is_greater_equal(40)


func test_music_files_exist() -> void:
	assert_bool(ResourceLoader.exists("res://assets/audio/music/music_yard.ogg")).is_true()
	assert_bool(ResourceLoader.exists("res://assets/audio/music/music_yard_bright.ogg")).is_true()
	var a: AudioStream = load("res://assets/audio/music/music_yard.ogg")
	var b: AudioStream = load("res://assets/audio/music/music_yard_bright.ogg")
	assert_float(absf(a.get_length() - b.get_length())).is_less(0.05)


func test_variants_rotate_never_repeat() -> void:
	for cue in ["zap_size", "impact_light", "splash", "bark"]:
		var n := Audio.variants(cue)
		assert_int(n).is_greater_equal(2)
		var seen := {}
		var last := -1
		for i in n * 3:
			Audio.play(cue)
			var v: int = Audio.last_variant[cue]
			assert_int(v).is_not_equal(last)
			last = v
			seen[v] = true
		assert_int(seen.size()).is_equal(n)


func test_pitch_follows_scale() -> void:
	var o := PhysicsObject.new(ObjectData.make(&"cow", ObjectData.Shape.BOX, Vector3.ONE, 1.0, Color.WHITE))
	world.add_child(o)
	Audio.clock = 1000.0
	o.current_scale = 4.0
	o.speak()
	assert_float(Audio.last_pitch["voice_cow_react"]).is_between(0.5 * 0.94, 0.5 * 1.06)
	Audio.clock = 1001.0
	o.current_scale = 0.25
	o.speak("grabbed")
	assert_float(Audio.last_pitch["voice_cow_grabbed"]).is_between(2.0 * 0.94, 2.0 * 1.06)
	# Impacts: bigger = lower and louder.
	Audio.play("impact_huge", null, 0.5)
	assert_float(Audio.last_pitch["impact_huge"]).is_less(0.6)


func test_voice_rate_cap_one_per_object_per_half_second() -> void:
	Audio.stop_all()
	var a := Node.new()
	var b := Node.new()
	world.add_child(a)
	world.add_child(b)
	Audio.clock = 2000.0
	assert_bool(Audio.voice("voice_duck", "react", a)).is_true()
	Audio.clock = 2000.3
	assert_bool(Audio.voice("voice_duck", "thrown", a)).is_false()
	assert_bool(Audio.voice("voice_duck", "react", b)).is_true()
	Audio.clock = 2000.55
	assert_bool(Audio.voice("voice_duck", "landed", a)).is_true()
	assert_bool(Audio.played("voice_duck_landed")).is_true()
	assert_bool(Audio.played("voice_duck_thrown")).is_false()


func test_voice_falls_back_to_react_then_base() -> void:
	Audio.stop_all()
	Audio.clock = 3000.0
	Audio.synth_fallback = false
	Audio.voice("voice_cow", "no_such_kind")
	assert_bool(Audio.played("voice_cow_react")).is_true()
	Audio.voice("voice_zz_nothing", "react")
	assert_bool(Audio.played("voice_zz_nothing")).is_true()
	Audio.synth_fallback = true


func test_music_crossfades_and_brightens_for_ten_seconds() -> void:
	Audio.music("music_yard", 0.2)
	assert_str(Audio.music_track).is_equal("music_yard")
	await get_tree().create_timer(0.4).timeout
	assert_float(Audio.music_mix().x).is_equal_approx(1.0, 0.01)
	assert_float(Audio.music_mix().y).is_equal_approx(0.0, 0.01)
	Audio.play("card_done")
	assert_float(Audio.bright_left).is_equal_approx(Audio.BRIGHT_SECS, 0.05)
	await get_tree().create_timer(Audio.BRIGHT_FADE * 0.5).timeout
	var mid := Audio.music_mix()
	assert_float(mid.x).is_between(0.1, 0.9)
	assert_float(mid.y).is_between(0.1, 0.9)
	await get_tree().create_timer(Audio.BRIGHT_FADE * 0.7).timeout
	assert_float(Audio.music_mix().y).is_equal_approx(1.0, 0.01)
	assert_float(Audio.music_mix().x).is_equal_approx(0.0, 0.01)
	# Hold for the rest of the 10 s (fast-forward the timer), then fade back.
	assert_float(Audio.bright_left).is_greater(Audio.BRIGHT_SECS - 2.0)
	Audio.bright_left = 0.05
	await get_tree().create_timer(0.1 + Audio.BRIGHT_FADE * 1.2).timeout
	assert_float(Audio.bright_left).is_equal(0.0)
	assert_float(Audio.music_mix().x).is_equal_approx(1.0, 0.01)
	assert_float(Audio.music_mix().y).is_equal_approx(0.0, 0.01)


func test_buses_limiter_and_ducking() -> void:
	for bus in ["Music", "SFX", "Voice"]:
		assert_int(AudioServer.get_bus_index(bus)).is_not_equal(-1)
	var master := AudioServer.get_bus_index("Master")
	var lim := false
	for i in AudioServer.get_bus_effect_count(master):
		lim = lim or AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter
	assert_bool(lim).is_true()
	_bands.clear()
	Audio.big_impact.connect(_on_big)
	Audio.play("impact_huge", Vector3(1, 2, 0), 1.0)
	Audio.big_impact.disconnect(_on_big)
	assert_array(_bands).contains(["impact_huge"])
	assert_float(Audio.duck_db()).is_less_equal(Audio.DUCK_IMPACT_DB + 0.01)
	await get_tree().create_timer(Audio.DUCK_HOLD + 1.0).timeout
	assert_float(Audio.duck_db()).is_equal(0.0)


func test_bark_gate_one_at_a_time() -> void:
	Audio.clock = 4000.0
	var who := Node.new()
	world.add_child(who)
	assert_bool(Audio.can_bark(who)).is_true()
	assert_str(Audio.bark("nobody_here", "zap", who)).is_equal("bark_zap")
	assert_bool(Audio.can_bark(who)).is_false()
	Audio.clock = 4000.0 + Audio.BARK_ANY_GAP + 0.05
	assert_bool(Audio.can_bark("someone_else")).is_true()   # someone else may speak now
	assert_bool(Audio.can_bark(who)).is_false()         # but not the same speaker yet
	Audio.clock = 4000.0 + Audio.BARK_GAP + 0.05
	assert_bool(Audio.can_bark(who)).is_true()
	assert_bool(Audio.bark_style("jeff", "delight")).is_true()
	assert_bool(Audio.bark_style("jeff", "narrate")).is_false()
	assert_bool(Audio.bark_style("chuck", "narrate")).is_true()


func test_pool_stays_bounded_under_spam() -> void:
	for i in 400:
		Audio.play(["impact_huge", "zap_magnet", "splash", "voice_cow_react"][i % 4])
	assert_int(Audio.active_voices()).is_less_equal(Audio.POOL_SIZE + Audio.VOICE_POOL)
	var same := 0
	for p in Audio.get_children():
		if p is AudioStreamPlayer and p.playing and p.get_meta(&"cue") == "impact_huge":
			same += 1
	assert_int(same).is_less_equal(Audio.MAX_SAME_CUE)


## A-01: one zap cue per gun, all seven different, each with its own files.
func test_every_gun_has_its_own_zap_cue() -> void:
	var seen := {}
	for g in Zapper.load_guns():
		var cue: String = g.zap_cue()
		assert_bool(seen.has(cue)).override_failure_message("%s shared" % cue).is_false()
		seen[cue] = true
		assert_int(Audio.variants(cue)).override_failure_message(cue).is_greater_equal(2)
	assert_int(seen.size()).is_equal(7)


## A-04: four mass bands; light and heavy things never share a landing sound.
func test_impact_band_follows_mass() -> void:
	assert_str(Audio.impact_band(0.2)).is_equal("light")
	assert_str(Audio.impact_band(0.999)).is_equal("light")
	assert_str(Audio.impact_band(1.0)).is_equal("medium")
	assert_str(Audio.impact_band(8.0)).is_equal("heavy")
	assert_str(Audio.impact_band(60.0)).is_equal("huge")
	assert_str(Audio.impact_band(5000.0)).is_equal("huge")
	for band in ["light", "medium", "heavy", "huge"]:
		assert_bool(Audio.has_cue("impact_" + band)).override_failure_message(band).is_true()


func test_light_and_heavy_objects_land_in_different_bands() -> void:
	Audio.synth_fallback = false
	var egg := PhysicsObject.new(ObjectData.make(&"egg", ObjectData.Shape.BOX, Vector3.ONE * 0.3, 0.3, Color.WHITE))
	var anvil := PhysicsObject.new(ObjectData.make(&"anvil", ObjectData.Shape.BOX, Vector3.ONE, 20.0, Color.WHITE))
	world.add_child(egg)
	world.add_child(anvil)
	egg._on_landed(1.0)
	anvil._on_landed(1.0)
	Audio.synth_fallback = true
	assert_bool(Audio.played("impact_light")).is_true()
	assert_bool(Audio.played("impact_heavy")).is_true()
	assert_str(Audio.impact_cue(egg.volume_mass())).is_not_equal(Audio.impact_cue(anvil.volume_mass()))
	# The same egg grown 4x is 64x the mass: a bigger band, and a lower landing.
	egg.current_scale = 4.0
	assert_str(Audio.impact_cue(egg.volume_mass())).is_not_equal("impact_light")


## A-02: the smaller the object, the higher it sounds (voice, landing and the grow / shrink boing).
func test_grow_and_shrink_boing_pitch_follows_size() -> void:
	assert_float(Audio.size_pitch(1.0)).is_equal_approx(1.0, 0.001)
	assert_float(Audio.size_pitch(0.25)).is_greater(Audio.size_pitch(1.0))
	assert_float(Audio.size_pitch(4.0)).is_less(Audio.size_pitch(1.0))
	var o := PhysicsObject.new(ObjectData.make(&"cow", ObjectData.Shape.BOX, Vector3.ONE, 1.0, Color.WHITE))
	world.add_child(o)
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	world.add_child(z)
	z._size_latched = o
	assert_bool(z._size_step(1)).is_true()
	var big_pitch: float = Audio.last_pitch["grow"]
	z._size_step(-1)
	z._size_step(-1)
	var small_pitch: float = Audio.last_pitch["shrink"]
	assert_float(o.target_scale).is_less(1.0)
	assert_float(small_pitch).is_greater(big_pitch)
