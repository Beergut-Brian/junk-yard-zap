## Sound on every action. Autoload: Audio. Cue list and file rules: assets/audio/CUES.md.
##
## play("cue") plays assets/audio/sfx/cue.ogg, or rotates through cue_1.ogg..cue_N.ogg (never the
## same variant twice in a row). Missing cues warn once, never crash, and play a placeholder synth
## beep (Synth) so every action is audible. pitch: object voices and impacts follow size (callers
## pass 1 / sqrt(scale)); impacts also get louder with size.
##
## Buses: Music, SFX, Voice (made here if the project has no bus layout). Master has a hard
## limiter so nothing clips; the Music bus has a duck stage that dips under big impacts and barks.
##
## voice(base, kind, owner, pitch): object voices (react / grabbed / thrown / landed), at most one
## per object per VOICE_GAP seconds and MAX_OBJECT_VOICES at once.
## bark(character, kind): a player's bark on the Voice bus (game cue, then the character's voice
## pack, then the generic cue). can_bark() is the "one bark per zap, never talk over" gate.
## music("music_yard") loops the yard track; brighten() crossfades to music_yard_bright for
## BRIGHT_SECS (played automatically with card_done) and back.
extends Node

signal big_impact(position: Vector3, band: String)

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 16
const VOICE_POOL := 4
const MAX_SAME_CUE := 3           # one cue never stacks more than this many at once
const MAX_OBJECT_VOICES := 4      # object voices playing at once (a Reset lands 40 things)
const VOICE_GAP := 0.5            # seconds between two voices of the same object
const BARK_GAP := 1.6             # seconds between two barks of the same speaker
const BARK_ANY_GAP := 0.7         # seconds between any two barks (they never talk over each other)
const BRIGHT_SECS := 10.0
const BRIGHT_FADE := 1.0
const MUSIC_GAIN_DB := -2.0       # files are -20 LUFS; this keeps the loop under the chaos
const DUCK_IMPACT_DB := -8.0
const DUCK_BARK_DB := -5.0
const DUCK_HOLD := 0.35
const DUCK_RELEASE_DB_S := 14.0
const BRIGHTEN_ON := ["card_done"]
const DUCK_ON := {"impact_heavy": DUCK_IMPACT_DB * 0.6, "impact_huge": DUCK_IMPACT_DB, "card_done": -4.0, "reset_yard": -6.0}
## Which characters do what (GAME.md "Audio"): Jeff delights at big impacts, Chuck narrates his
## own zaps. Anyone else in the roster does both, politely (the gates still apply).
const BARK_STYLE := {"jeff": ["delight"], "chuck": ["narrate"]}

var _pool: Array[AudioStreamPlayer] = []
var _voice_pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _bright: AudioStreamPlayer
var _warned := {}
var _cache := {}
var _turn := {}                   # cue key -> next variant index (rotation)
var _last_voice := {}             # owner key -> time of its last voice
var _last_bark := {}              # speaker key -> time of its last bark
var _last_any_bark := -100.0
## Own RNG for pitch wobble, so playing sounds never shifts a seeded simulation.
var _rng := RandomNumberGenerator.new()
var _duck_amp: AudioEffectAmplify
var _duck_db := 0.0
var _duck_hold := 0.0
var _base_mix := 0.0              # music crossfade levels, linear 0..1
var _bright_mix := 0.0
var _mix_tween: Tween

## Every cue played, newest last (tests and the demo log read it). Capped.
var history: PackedStringArray = []
## Off: missing cues stay silent (tests that only care about history).
var synth_fallback := true
## Last variant index and pitch per cue (tests, the soak log).
var last_variant := {}
var last_pitch := {}
var music_track := ""
## Seconds of bright layer left (0 = base loop only).
var bright_left := 0.0
## Tests set this to drive the rate caps without waiting; < 0 = real time.
var clock := -1.0
var peak_voices := 0
var _soak_log := -1.0             # seconds to the next soak line (--soak only)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_ensure_effects()
	for i in POOL_SIZE:
		_pool.append(_player("SFX"))
	for i in VOICE_POOL:
		_voice_pool.append(_player("Voice"))
	_music = _player("Music")
	_bright = _player("Music")
	_apply_mix()
	if "--soak" in OS.get_cmdline_user_args():
		_soak_log = 30.0
	set_volume("Music", Save.get_setting("music_volume", 0.8))
	set_volume("SFX", Save.get_setting("sound_volume", 1.0))


func _exit_tree() -> void:
	if _mix_tween:
		_mix_tween.kill()
	for p in _pool + _voice_pool + [_music, _bright]:
		p.stop()
		p.stream = null
	_cache.clear()


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.set_meta(&"cue", "")
	p.set_meta(&"t", 0.0)
	add_child(p)
	return p


func _ensure_effects() -> void:
	var master := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for i in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		lim.pre_gain_db = 0.0
		AudioServer.add_bus_effect(master, lim)
	var mb := AudioServer.get_bus_index("Music")
	for i in AudioServer.get_bus_effect_count(mb):
		if AudioServer.get_bus_effect(mb, i) is AudioEffectAmplify:
			_duck_amp = AudioServer.get_bus_effect(mb, i)
	if _duck_amp == null:
		_duck_amp = AudioEffectAmplify.new()
		AudioServer.add_bus_effect(mb, _duck_amp, 0)


func _process(delta: float) -> void:
	if _duck_hold > 0.0:
		_duck_hold -= delta
	elif _duck_db < 0.0:
		_duck_db = minf(0.0, _duck_db + DUCK_RELEASE_DB_S * delta)
	if _duck_amp:
		_duck_amp.volume_db = _duck_db
	if bright_left > 0.0:
		bright_left -= delta
		if bright_left <= 0.0:
			bright_left = 0.0
			_crossfade(1.0, 0.0, BRIGHT_FADE)
	var n := active_voices()
	if n > peak_voices:
		peak_voices = n
	if _soak_log > 0.0:
		_soak_log -= delta
		if _soak_log <= 0.0:
			_soak_log = 30.0
			print("Audio soak: %s" % stats())


## bus: "Music" or "SFX" (Voice follows SFX); linear 0..1 (the Settings sliders). 0 mutes.
func set_volume(bus: String, linear: float) -> void:
	for b in ([bus, "Voice"] if bus == "SFX" else [bus]):
		var i := AudioServer.get_bus_index(b)
		if i == -1:
			continue
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(i, linear <= 0.0)


func get_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	if i == -1 or AudioServer.is_bus_mute(i):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(i))


func now() -> float:
	return clock if clock >= 0.0 else Time.get_ticks_msec() / 1000.0


# ------------------------------------------------------------------------------------------ SFX

func play(cue: String, _position = null, pitch := 1.0) -> void:
	_record(cue)
	var stream := _resolve(SFX_DIR, cue)
	if stream == null:
		if not synth_fallback:
			return
		stream = Synth.beep(cue)
	var vol := 0.0
	if cue.begins_with("impact_"):
		# Scaled by size: a giant lands lower (pitch) and louder; a tiny one quieter.
		vol = clampf(6.0 * log(1.0 / maxf(pitch, 0.05)) / log(2.0), -9.0, 3.0)
	_start(_pick(_pool, cue), stream, cue, pitch * _rng.randf_range(0.95, 1.05), vol)
	if DUCK_ON.has(cue):
		duck(DUCK_ON[cue])
		if cue == "impact_heavy" or cue == "impact_huge":
			big_impact.emit(_position if _position is Vector3 else Vector3.ZERO, cue)
	if BRIGHTEN_ON.has(cue):
		brighten()


func _record(cue: String) -> void:
	history.append(cue)
	if history.size() > 256:
		history = history.slice(128)


func _start(p: AudioStreamPlayer, stream: AudioStream, cue: String, pitch: float, vol_db := 0.0) -> void:
	p.stop()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = vol_db
	p.set_meta(&"cue", cue)
	p.set_meta(&"t", now())
	last_pitch[cue] = p.pitch_scale
	p.play()


## A free player; if none, the oldest one playing this cue (when it already has MAX_SAME_CUE
## going), else the oldest of all. The pool never grows.
func _pick(pool: Array[AudioStreamPlayer], cue: String) -> AudioStreamPlayer:
	var same: Array[AudioStreamPlayer] = []
	for p in pool:
		if p.playing and p.get_meta(&"cue") == cue:
			same.append(p)
	if same.size() >= MAX_SAME_CUE:
		return _oldest(same)
	for p in pool:
		if not p.playing:
			return p
	return _oldest(pool)


func _oldest(list: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	var best := list[0]
	for p in list:
		if float(p.get_meta(&"t")) < float(best.get_meta(&"t")):
			best = p
	return best


## True if the game has a recorded file for cue (cue.ogg or cue_1.ogg in SFX_DIR). No warning, no
## synth: callers use it to choose between a character's own cue and a generic one.
func has_cue(cue: String) -> bool:
	return ResourceLoader.exists(SFX_DIR + cue + ".ogg") or ResourceLoader.exists("%s%s_1.ogg" % [SFX_DIR, cue])


## True if cue was played since the history was last cleared (tests).
func played(cue: String) -> bool:
	return history.has(cue)


## Number of variant files a cue has (0 = synth beep).
func variants(cue: String) -> int:
	if not _cache.has(SFX_DIR + cue):
		_resolve(SFX_DIR, cue, false)
	return (_cache[SFX_DIR + cue] as Array).size()


## Stop every SFX and bark (tests; never the music).
func stop_all() -> void:
	for p in _pool + _voice_pool:
		p.stop()


## Players busy right now, all pools (the soak log watches this).
func active_voices() -> int:
	var n := 0
	for p in _pool + _voice_pool:
		if p.playing:
			n += 1
	return n


func stats() -> Dictionary:
	return {"active": active_voices(), "peak": peak_voices, "pool": POOL_SIZE + VOICE_POOL,
		"voice_owners": _last_voice.size(), "cached_cues": _cache.size(), "duck_db": _duck_db,
		"music": music_track, "bright_left": bright_left}


# ---------------------------------------------------------------------------------- object voices

## An object's voice. base: ObjectData.voice_cue() ("voice_cow"); kind: react, grabbed, thrown,
## landed. Plays base_kind, else base_react, else base (synth beep). pitch: 1 / sqrt(scale), so a
## giant cow moos low and a tiny one squeaks. Returns false when the rate cap held it back.
func voice(base: String, kind := "react", owner: Object = null, pitch := 1.0) -> bool:
	var key: Variant = owner.get_instance_id() if owner else base
	var t := now()
	if _last_voice.has(key) and t - float(_last_voice[key]) < VOICE_GAP:
		return false
	var busy := 0
	for p in _pool:
		if p.playing and String(p.get_meta(&"cue")).begins_with("voice_"):
			busy += 1
	if busy >= MAX_OBJECT_VOICES:
		return false
	_last_voice[key] = t
	if _last_voice.size() > 512:
		_prune_voices(t)
	var cue := "%s_%s" % [base, kind]
	if not has_cue(cue):
		cue = base + "_react" if has_cue(base + "_react") else base
	play(cue, null, pitch)
	return true


func _prune_voices(t: float) -> void:
	for k in _last_voice.keys():
		if t - float(_last_voice[k]) > VOICE_GAP * 4.0:
			_last_voice.erase(k)


# ----------------------------------------------------------------------------------------- barks

## Gate for barks: false while this speaker (or anyone) barked too recently. Call it once per
## zap / impact before bark(), so there is never more than one bark per zap.
func can_bark(speaker: Variant) -> bool:
	var t := now()
	if t - _last_any_bark < BARK_ANY_GAP:
		return false
	if _last_bark.has(speaker) and t - float(_last_bark[speaker]) < BARK_GAP:
		return false
	return true


## Does this character do `style` ("delight" at big impacts, "narrate" own zaps)?
func bark_style(character: String, style: String) -> bool:
	return style in BARK_STYLE.get(character, ["delight", "narrate"])


## A character's bark; returns the cue it used. Order: the game's own cue bark_<id>[_<kind>],
## then the character's voice pack (Roster.info(id).voice: <kind>.ogg, or any of its barks for a
## plain bark; history gets "roster:<id>"), then the generic bark[_<kind>]. Never another
## character's voice. Plays on the Voice bus and ducks the music.
func bark(character: String, kind := "", speaker: Variant = null) -> String:
	var tail := "_" + kind if kind != "" else ""
	var used := ""
	var stream: AudioStream = null
	var own := "bark_%s%s" % [character, tail]
	if has_cue(own):
		used = own
		stream = _resolve(SFX_DIR, own)
	else:
		var path := _pack_file(character, kind)
		if path != "":
			used = "roster:" + character
			stream = load(path)
		else:
			used = "bark" + tail
			stream = _resolve(SFX_DIR, used)
			if stream == null and synth_fallback:
				stream = Synth.beep(used)
	_record(used)
	var t := now()
	_last_any_bark = t
	_last_bark[speaker if speaker != null else character] = t
	if stream:
		_start(_pick(_voice_pool, used), stream, used, 1.0)
		duck(DUCK_BARK_DB)
	return used


## res:// path of the character's voice-pack file for kind ("" = a random plain bark), or "".
func _pack_file(character: String, kind: String) -> String:
	var who: Dictionary = Roster.info(character)
	if who.is_empty() or String(who.get("voice", "")) == "":
		return ""
	var dir := String(who.voice)
	if not dir.ends_with("/"):
		dir += "/"
	if kind != "":
		return dir + kind + ".ogg" if ResourceLoader.exists(dir + kind + ".ogg") else ""
	var barks: Array = who.get("barks", [])
	if barks.is_empty():
		return ""
	var path := "%s%s.ogg" % [dir, barks[_rng.randi() % barks.size()]]
	return path if ResourceLoader.exists(path) else ""


# ----------------------------------------------------------------------------------------- music

## Loop track (music/<track>.ogg); if music/<track>_bright.ogg exists it is loaded as the bright
## layer for brighten(). Same track again = no restart.
func music(track: String, fade: float = 0.5) -> void:
	if track == music_track and _music.playing:
		return
	var stream := _resolve(MUSIC_DIR, track)
	if stream == null:
		return
	music_track = track
	_loop(stream)
	var bright := _resolve(MUSIC_DIR, track + "_bright", false)
	if bright:
		_loop(bright)
	_bright.stream = bright
	_bright.stop()
	bright_left = 0.0
	_music.stream = stream
	_music.play()
	_base_mix = 0.0
	_bright_mix = 0.0
	_crossfade(1.0, 0.0, fade)


func stop_music(fade: float = 0.5) -> void:
	music_track = ""
	bright_left = 0.0
	_crossfade(0.0, 0.0, fade)
	_mix_tween.tween_callback(func() -> void:
		_music.stop()
		_bright.stop())


## Crossfade into the bright layer for secs, then back (a completed card calls it through
## card_done). Calling again while bright extends it. False if there is no bright layer.
func brighten(secs := BRIGHT_SECS) -> bool:
	if _bright.stream == null or not _music.playing:
		return false
	if not _bright.playing:
		var len_b := _bright.stream.get_length()
		var pos := _music.get_playback_position()
		_bright.play(fmod(pos, len_b) if len_b > 0.0 else 0.0)
	if bright_left <= 0.0:
		_crossfade(0.0, 1.0, BRIGHT_FADE)
	bright_left = secs
	return true


## Music crossfade levels (linear 0..1) of the base loop and the bright layer.
func music_mix() -> Vector2:
	return Vector2(_base_mix, _bright_mix)


func _crossfade(base: float, bright: float, secs: float) -> void:
	if _mix_tween:
		_mix_tween.kill()
	_mix_tween = create_tween().set_parallel(true)
	_mix_tween.tween_method(_set_base_mix, _base_mix, base, secs)
	_mix_tween.tween_method(_set_bright_mix, _bright_mix, bright, secs)
	_mix_tween.set_parallel(false)
	if bright <= 0.0:
		_mix_tween.tween_callback(func() -> void:
			if bright_left <= 0.0:
				_bright.stop())


func _set_base_mix(v: float) -> void:
	_base_mix = v
	_apply_mix()


func _set_bright_mix(v: float) -> void:
	_bright_mix = v
	_apply_mix()


func _apply_mix() -> void:
	# Equal-power-ish: sqrt keeps the crossfade from dipping in the middle.
	_music.volume_db = linear_to_db(maxf(sqrt(_base_mix), 0.0001)) + MUSIC_GAIN_DB
	_bright.volume_db = linear_to_db(maxf(sqrt(_bright_mix), 0.0001)) + MUSIC_GAIN_DB


## Dip the music by db (negative) for a moment; the deepest request wins, then it recovers.
func duck(db: float) -> void:
	_duck_db = minf(_duck_db, db)
	_duck_hold = DUCK_HOLD


func duck_db() -> float:
	return _duck_db


func _loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


# --------------------------------------------------------------------------------------- resolve

func _resolve(dir: String, cue: String, warn := true) -> AudioStream:
	var key := dir + cue
	if not _cache.has(key):
		var found: Array = []
		if ResourceLoader.exists(dir + cue + ".ogg"):
			found.append(load(dir + cue + ".ogg"))
		else:
			var i := 1
			while ResourceLoader.exists("%s%s_%d.ogg" % [dir, cue, i]):
				found.append(load("%s%s_%d.ogg" % [dir, cue, i]))
				i += 1
		_cache[key] = found
		_turn[key] = _rng.randi() % maxi(found.size(), 1)
	var list: Array = _cache[key]
	if list.is_empty():
		if warn and not _warned.has(key):
			_warned[key] = true
			print("Audio: no file for cue '%s' in %s, using a synth beep" % [cue, dir])
		return null
	# Rotate: each play takes the next variant, so the same file never plays twice in a row.
	var i: int = _turn[key] % list.size()
	_turn[key] = i + 1
	last_variant[cue] = i
	return list[i]
