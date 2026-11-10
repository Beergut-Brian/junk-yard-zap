## Sound on every action. Autoload: Audio.
## play("cue") looks for assets/audio/sfx/cue.ogg, or cue_1.ogg..cue_N.ogg and picks one.
## Missing cues warn once, never crash, and play a placeholder synth beep instead (Synth) so every
## action is audible before the Audio lane lands files. pitch: object voices follow size.
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICE_DIR := "res://addons/openjar/characters/"
const POOL_SIZE := 12

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _warned := {}
var _cache := {}
## Own RNG for pitch wobble and variant picks, so playing sounds never shifts a seeded simulation.
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	set_volume("Music", Save.get_setting("music_volume", 0.8))
	set_volume("SFX", Save.get_setting("sound_volume", 1.0))


## bus: "Music" or "SFX"; linear 0..1 (the Settings sliders). 0 mutes.
func set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.0)


func get_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	if i == -1 or AudioServer.is_bus_mute(i):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(i))


## Every cue played, newest last (tests and the demo log read it). Capped.
var history: PackedStringArray = []
## Off: missing cues stay silent (tests that only care about history).
var synth_fallback := true


func play(cue: String, _position = null, pitch := 1.0) -> void:
	history.append(cue)
	if history.size() > 256:
		history = history.slice(128)
	var stream := _resolve(SFX_DIR, cue)
	if stream == null:
		if not synth_fallback:
			return
		stream = Synth.beep(cue)
	var player: AudioStreamPlayer = _pool[0]
	for p in _pool:
		if not p.playing:
			player = p
			break
	player.stream = stream
	player.pitch_scale = clampf(pitch * _rng.randf_range(0.95, 1.05), 0.25, 4.0)
	player.play()


## True if the game has a recorded file for cue (cue.ogg or cue_1.ogg in SFX_DIR). No warning, no
## synth: callers use it to choose between a character's own cue and a generic one.
func has_cue(cue: String) -> bool:
	return ResourceLoader.exists(SFX_DIR + cue + ".ogg") or ResourceLoader.exists("%s%s_1.ogg" % [SFX_DIR, cue])


## True if cue was played since the history was last cleared (tests).
func played(cue: String) -> bool:
	return history.has(cue)


func music(track: String, fade: float = 0.5) -> void:
	var stream := _resolve(MUSIC_DIR, track)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(func():
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	tw.tween_property(_music, "volume_db", 0.0, fade)


func stop_music(fade: float = 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(_music.stop)


func bark(character: String, bark_name: String) -> void:
	var stream := _resolve("%s%s/voice/" % [VOICE_DIR, character], bark_name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0
			p.play()
			return


func _resolve(dir: String, cue: String) -> AudioStream:
	var key := dir + cue
	if _cache.has(key):
		var variants: Array = _cache[key]
		return variants[_rng.randi() % variants.size()] if not variants.is_empty() else null
	var variants: Array = []
	if ResourceLoader.exists(dir + cue + ".ogg"):
		variants.append(load(dir + cue + ".ogg"))
	else:
		var i := 1
		while ResourceLoader.exists("%s%s_%d.ogg" % [dir, cue, i]):
			variants.append(load("%s%s_%d.ogg" % [dir, cue, i]))
			i += 1
	_cache[key] = variants
	if variants.is_empty():
		if not _warned.has(key):
			_warned[key] = true
			print("Audio: no file for cue '%s' in %s, using a synth beep" % [cue, dir])
		return null
	return variants[_rng.randi() % variants.size()]
