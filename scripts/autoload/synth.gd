## Placeholder sound: a short synthesised beep per cue, so every action is audible before the Audio
## lane delivers files. Deterministic per cue name; a few cue families get a recognisable shape
## (grow rises, shrink falls, zaps buzz, voices wobble). Swap for real files in assets/audio/sfx/.
class_name Synth
extends RefCounted

const RATE := 22050
enum Wave { SINE, SQUARE, SAW, NOISE }

static var _cache := {}


## [start Hz, end Hz, seconds, wave, volume]
static func shape_of(cue: String) -> Array:
	var h := absi(cue.hash())
	var base := 220.0 + float(h % 600)
	match cue:
		"grow": return [300.0, 900.0, 0.25, Wave.SINE, 0.5]
		"shrink": return [900.0, 300.0, 0.25, Wave.SINE, 0.5]
		"nope": return [180.0, 120.0, 0.25, Wave.SQUARE, 0.3]
		"sparkle": return [1800.0, 2600.0, 0.12, Wave.SINE, 0.25]
		"jump": return [400.0, 700.0, 0.1, Wave.SINE, 0.3]
		"land": return [140.0, 80.0, 0.08, Wave.NOISE, 0.2]
		"grab": return [200.0, 600.0, 0.3, Wave.SAW, 0.3]
		"throw": return [900.0, 200.0, 0.25, Wave.NOISE, 0.4]
		"splash": return [600.0, 200.0, 0.4, Wave.NOISE, 0.45]
		"reset_yard": return [1200.0, 150.0, 0.9, Wave.NOISE, 0.5]
		"card_done": return [520.0, 1560.0, 0.6, Wave.SQUARE, 0.35]
		"card_skip": return [160.0, 90.0, 0.45, Wave.SAW, 0.4]
		"snort": return [90.0, 260.0, 0.35, Wave.NOISE, 0.5]
		"wheel_move": return [1400.0, 1400.0, 0.04, Wave.SQUARE, 0.25]
	if cue.begins_with("zap_"):
		return [base * 1.5, base * 0.75, 0.18, Wave.SQUARE, 0.3]
	if cue.begins_with("voice_") or cue.begins_with("bark_"):
		return [base, base * 1.3, 0.3, Wave.SAW, 0.3]
	if cue.begins_with("impact_"):
		return [120.0 + base * 0.2, 60.0, 0.15, Wave.NOISE, 0.4]
	if cue.begins_with("ui_"):
		return [base * 2.0, base * 2.0, 0.05, Wave.SINE, 0.25]
	return [base, base, 0.12, Wave.SINE, 0.3]


static func beep(cue: String) -> AudioStreamWAV:
	if _cache.has(cue):
		return _cache[cue]
	var sh := shape_of(cue)
	var n := int(RATE * float(sh[2]))
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = cue.hash()
	for i in n:
		var t := float(i) / n
		var f: float = lerpf(sh[0], sh[1], t)
		if cue.begins_with("voice_"):
			f *= 1.0 + 0.08 * sin(t * 40.0)
		phase = fmod(phase + f / RATE, 1.0)
		var v := 0.0
		match int(sh[3]):
			Wave.SINE: v = sin(phase * TAU)
			Wave.SQUARE: v = 1.0 if phase < 0.5 else -1.0
			Wave.SAW: v = phase * 2.0 - 1.0
			Wave.NOISE: v = rng.randf_range(-1.0, 1.0) * 0.6 + sin(phase * TAU) * 0.4
		var env := minf(1.0, t * 40.0) * pow(1.0 - t, 1.5)
		data.encode_s16(i * 2, int(clampf(v * env * float(sh[4]), -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	_cache[cue] = w
	return w
