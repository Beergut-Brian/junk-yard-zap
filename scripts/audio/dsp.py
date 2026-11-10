"""DSP primitives for the Junk Yard Zap synth cues. Python stdlib only.

Copied from spaceballs/assets/audio/tools/make_cues.py (Open Jar Games, project's own code),
which adapted them from openjar-launcher. Everything is mono float lists at SR.
"""
import math
import random
import re
import struct
import subprocess
import wave

SR = 44100
TAU = 2.0 * math.pi
PARTIAL_CEILING = 9500.0

# ---------------------------------------------------------------- primitives

def midi(n):
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


def silence(sec):
    return [0.0] * int(round(sec * SR))


def mix(dst, src, at=0.0, gain=1.0, wrap=False):
    """Add src into dst at `at` seconds. wrap=True folds overhang back to the start (loops)."""
    o = int(round(at * SR))
    n = len(dst)
    if wrap:
        for i, s in enumerate(src):
            dst[(o + i) % n] += s * gain
    else:
        for i in range(max(0, -o), min(len(src), n - o)):
            dst[o + i] += src[i] * gain
    return dst


def osc(dur, freq, partials=((1, 1.0, 1.0),), decay=None, attack=0.002, amp=None):
    """Additive oscillator. freq: Hz or f(t). partials: (ratio, gain, decay_scale); partial k
    decays as exp(-t * decay_scale / decay). amp: optional overall envelope f(t).
    Partials above PARTIAL_CEILING are skipped."""
    n = int(dur * SR)
    out = [0.0] * n
    ph = [0.0] * len(partials)
    fixed = not callable(freq)
    for i in range(n):
        t = i / SR
        f = freq if fixed else freq(t)
        s = 0.0
        for k, (r, g, ds) in enumerate(partials):
            fk = f * r
            ph[k] += TAU * fk / SR
            if fk < PARTIAL_CEILING:
                s += (g if decay is None else g * math.exp(-t * ds / decay)) * math.sin(ph[k])
        a = min(1.0, t / attack) if attack > 0 else 1.0
        if amp is not None:
            a *= amp(t)
        out[i] = s * a
    return fades(out, 0.0, 0.003)   # never stop a ringing partial dead


def noise(sec, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(sec * SR))]


def envelope(x, fn):
    return [v * fn(i / SR) for i, v in enumerate(x)]


def svf(x, fc, q=0.707, mode="low", circular=False):
    """TPT state-variable filter. fc: Hz or f(t). circular: run twice so the state at the
    start equals the state at the end (seamless loops)."""
    k = 1.0 / q
    ic1 = ic2 = 0.0
    out = [0.0] * len(x)
    moving = callable(fc)

    def coeffs(f):
        g = math.tan(math.pi * min(f, SR * 0.45) / SR)
        a1 = 1.0 / (1.0 + g * (g + k))
        return a1, g * a1, g * g * a1

    a1, a2, a3 = coeffs(fc) if not moving else (0, 0, 0)
    for _ in range(2 if circular else 1):
        for i, v in enumerate(x):
            if moving:
                a1, a2, a3 = coeffs(fc(i / SR))
            v3 = v - ic2
            v1 = a1 * ic1 + a2 * v3
            v2 = ic2 + a2 * ic1 + a3 * v3
            ic1 = 2.0 * v1 - ic1
            ic2 = 2.0 * v2 - ic2
            out[i] = v2 if mode == "low" else (k * v1 if mode == "band" else v - k * v1 - v2)
    return out


def soft(x, fc, circular=False):
    """4-pole low-pass (two cascaded SVFs): keeps noise sources out of the top octave."""
    return svf(svf(x, fc, circular=circular), fc, circular=circular)


def dc_block(x, circular=False):
    r = 0.9972  # ~20 Hz
    x1 = y1 = 0.0
    out = [0.0] * len(x)
    for _ in range(2 if circular else 1):
        for i, v in enumerate(x):
            y1 = v - x1 + r * y1
            x1 = v
            out[i] = y1
    return out


def fades(x, fade_in=0.001, fade_out=0.02):
    n = len(x)
    fi, fo = max(1, int(fade_in * SR)), max(1, int(fade_out * SR))
    for i in range(min(fi, n)):
        x[i] *= i / fi
    for i in range(min(fo, n)):
        x[n - 1 - i] *= (i / fo) ** 2
    return x


def limit(x, threshold, lookahead=0.002, release=0.06):
    """Lookahead peak limiter: shaves transients so loudness can rise under the peak ceiling."""
    n = len(x)
    la = int(lookahead * SR)
    need = [min(1.0, threshold / abs(v)) if v else 1.0 for v in x]
    gain = [1.0] * n
    for i in range(n):   # n is small (SFX only), so a plain window minimum is fine
        gain[i] = min(need[max(0, i - la):i + la + 1])
    rel = math.exp(-1.0 / (release * SR))
    g = 1.0
    for i in range(n):
        g = gain[i] if gain[i] < g else gain[i] + (g - gain[i]) * rel
        gain[i] = g
    return [v * gain[i] for i, v in enumerate(x)]


def peak_normalise(x, peak=0.5):
    m = max(abs(v) for v in x) or 1.0
    return [v * peak / m for v in x]


# ---------------------------------------------------------------- instruments

MARIMBA = ((1, 1.0, 1.0), (3.98, 0.30, 3.0), (9.85, 0.06, 6.0))
XYLO = ((1, 1.0, 1.0), (3.0, 0.28, 2.5), (6.1, 0.07, 5.0))
BELL = ((1, 1.0, 1.0), (2.76, 0.40, 1.8), (5.40, 0.12, 3.0), (8.93, 0.04, 4.0))
WOOD = ((1, 1.0, 1.0), (2.57, 0.35, 1.6), (4.80, 0.12, 2.6))


def mallet(rng, fc=3000.0, sec=0.005, gain=0.25):
    n = int(sec * SR)
    x = [rng.uniform(-1, 1) * (1 - i / n) ** 2 for i in range(n)]
    return [v * gain for v in svf(x, fc)]


def struck(f, decay, rng, partials=MARIMBA, vel=1.0, click=0.2):
    """Marimba / xylophone / bell note: decaying partials plus a mallet tick."""
    x = osc(min(decay * 7.0, 3.0), f, partials, decay=decay, attack=0.0015)
    mix(x, mallet(rng, fc=min(4000.0, f * 4.0)), 0.0, click)
    return [v * vel for v in x]


def formant(x):
    return (0.25 + math.exp(-((x - 650) / 260) ** 2) + 0.6 * math.exp(-((x - 1700) / 420) ** 2)
            + 0.25 * math.exp(-((x - 2800) / 500) ** 2))


def kazoo(f, sec, vib_rate=5.5, vib_depth=0.012, attack=0.015, release=0.06):
    """Buzzy, voice-like toy horn: band-limited saw shaped by fixed formants, with vibrato."""
    parts = []
    n = 1
    while n * f < PARTIAL_CEILING:
        parts.append((n, formant(n * f) / n, 0.0))
        n += 1
    total = sec

    def amp(t):
        return min(1.0, (total - t) / release) if t > total - release else 1.0

    def freq(t):
        return f * (1.0 + vib_depth * min(1.0, t / 0.12) * math.sin(TAU * vib_rate * t))

    return osc(sec, freq, tuple(parts), attack=attack, amp=amp)


def chirp(f0, f1, sec, partials=((1, 1.0, 0.0),), attack=0.004):
    """Pitch glide f0 -> f1 (exponential) with a rounded envelope."""
    return osc(sec, lambda t: f0 * (f1 / f0) ** min(1.0, t / sec), partials, attack=attack,
               amp=lambda t: math.sin(math.pi * min(1.0, t / sec)) ** 0.6)


def sparkle(rng, count, start, end, gain=0.12, notes=(96, 98, 100, 103, 105)):
    """A few quiet glockenspiel pings from a high C-major pentatonic."""
    out = silence(end + 0.3)
    for _ in range(count):
        mix(out, struck(midi(rng.choice(notes)), 0.05, rng, BELL, click=0.05),
            rng.uniform(start, end), gain * rng.uniform(0.6, 1.0))
    return out


def chord(notes, decay, rng, partials=MARIMBA, vel=1.0):
    out = silence(min(decay * 7.0, 3.0) + 0.01)
    for n in notes:
        mix(out, struck(midi(n), decay, rng, partials, click=0.12), 0.0, vel / len(notes) ** 0.5)
    return out


# ---------------------------------------------------------------- spaceballs primitives

# Cartoon formants (F1, F2, F3), a little brighter than an adult voice so it reads as a Jarling.
VOWELS = {"a": (820, 1250, 2650), "e": (520, 1900, 2650), "i": (330, 2350, 3050),
          "o": (520, 880, 2500), "u": (360, 760, 2400), "l": (320, 1100, 2600)}
METAL = ((1, 1.0, 1.0), (2.41, 0.6, 1.4), (3.93, 0.4, 2.0), (5.33, 0.25, 3.0), (6.9, 0.12, 4.0))


def saw(freq, sec):
    """PolyBLEP sawtooth (cheap, nearly alias-free); freq: Hz or f(t)."""
    n = int(sec * SR)
    out = [0.0] * n
    ph = 0.0
    fixed = not callable(freq)
    for i in range(n):
        dt = (freq if fixed else freq(i / SR)) / SR
        ph += dt
        if ph >= 1.0:
            ph -= 1.0
        v = 2.0 * ph - 1.0
        if ph < dt:
            x = ph / dt
            v -= x + x - x * x - 1.0
        elif ph > 1.0 - dt:
            x = (ph - 1.0) / dt
            v -= x * x + x + x + 1.0
        out[i] = v
    return out


def ar(total, attack=0.01, release=0.05):
    """Attack / release envelope as f(t)."""
    def f(t):
        a = min(1.0, t / attack) if attack > 0 else 1.0
        return a * (max(0.0, (total - t) / release) if t > total - release else 1.0)
    return f


def voice(f0, sec, vowel="a", amp=None, rng=None, breath=0.04, scale=1.0, rough=0.0,
          gains=(1.0, 0.55, 0.22), qs=(4.0, 7.0, 9.0)):
    """Formant voice: a saw through three band-pass filters. vowel: key of VOWELS, a tuple, or
    f(t) -> (F1, F2, F3) for glides (\"mi-a-ow\"). rough: amplitude flutter for croaks."""
    src = saw(f0, sec)
    if rng is not None and breath:
        src = [v + breath * rng.uniform(-1, 1) for v in src]
    if rough:
        src = [v * (1.0 - rough + rough * abs(math.sin(math.pi * 38.0 * i / SR)))
               for i, v in enumerate(src)]
    out = [0.0] * len(src)
    for k in range(3):
        if callable(vowel):
            fc = (lambda t, k=k: vowel(t)[k] * scale)
        else:
            fc = (VOWELS[vowel] if isinstance(vowel, str) else vowel)[k] * scale
        mix(out, svf(src, fc, qs[k], "band"), 0.0, gains[k])
    env = amp or ar(sec)
    return fades([v * env(i / SR) for i, v in enumerate(out)], 0.002, 0.01)


def glide(a, b, t0, t1):
    """Vowel glide a -> b between t0 and t1 as f(t) -> formants."""
    va, vb = VOWELS[a], VOWELS[b]

    def f(t):
        u = min(1.0, max(0.0, (t - t0) / (t1 - t0)))
        return tuple(x + (y - x) * u for x, y in zip(va, vb))
    return f


def burst(rng, sec, fc, q=1.0, decay=0.01, mode="band"):
    """Filtered noise hit with an exponential tail: cracks, slaps, claps, ticks."""
    x = svf(noise(sec, rng), fc, q, mode)
    return fades([v * math.exp(-i / SR / decay) for i, v in enumerate(x)], 0.0005, 0.004)


def thump(f0, f1, sec, decay):
    """Sine with a falling pitch: the body of every kick and landing."""
    return osc(sec, lambda t: f1 + (f0 - f1) * math.exp(-t / (decay * 0.6)), decay=decay,
               attack=0.001)


def rumble(rng, sec, fc, decay, attack=0.003):
    x = soft(noise(sec, rng), fc)
    return fades([v * min(1.0, i / SR / attack) * math.exp(-i / SR / decay)
                  for i, v in enumerate(x)], 0.0, 0.05)


def whistle(f0, f1, sec, rng, curve=1.3, vib=0.018, breath=0.06):
    """Slide whistle: a near-sine rising f0 -> f1 with vibrato and a little breath."""
    def freq(t):
        u = min(1.0, t / sec) ** curve
        return f0 * (f1 / f0) ** u * (1.0 + vib * math.sin(TAU * 6.0 * t))
    x = osc(sec, freq, ((1, 1.0, 0.0), (2, 0.07, 0.0), (3, 0.02, 0.0)), attack=0.03,
            amp=lambda t: min(1.0, (sec - t) / 0.08) if t > sec - 0.08 else 1.0)
    air = svf(noise(sec, rng), (f0 + f1) * 0.6, 2.0, "band")
    return [v + breath * a for v, a in zip(x, air)]


def notes_seq(seq, rng, partials=MARIMBA, decay=0.12, vel=1.0):
    """[(midi_note, at_seconds), ...] of struck notes."""
    end = max(at for _, at in seq)
    out = silence(end + min(decay * 7.0, 3.0) + 0.02)
    for n, at in seq:
        mix(out, struck(midi(n), decay, rng, partials, click=0.12), at, vel)
    return out


def brass(f, sec, rng, wah=None, vib=0.0, scoop=0.0, bright=2200.0):
    """Toy trombone / fanfare horn: saw, brightness follows the envelope (wah: f(t) 0..1)."""
    def freq(t):
        s = 1.0 - scoop * math.exp(-t / 0.04)
        return f * s * (1.0 + vib * min(1.0, t / 0.4) * math.sin(TAU * 5.0 * t))
    src = saw(freq, sec)
    w = wah or (lambda t: 1.0)
    x = svf(src, lambda t: 250.0 + bright * w(t), 1.2)
    env = ar(sec, 0.02, 0.08)
    return [v * env(i / SR) for i, v in enumerate(x)]


def clap(rng):
    x = burst(rng, 0.06, rng.uniform(1100, 1700), 1.4, 0.008)
    mix(x, burst(rng, 0.06, rng.uniform(700, 900), 2.0, 0.012), 0.0, 0.4)
    return x


# ---------------------------------------------------------------- ffmpeg

def write_wav(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(3)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<i", int(round(max(-1.0, min(1.0, v)) * 8388607)))[:3]
                               for v in x))


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True, check=True)


def measure(path, tile=1):
    """(integrated LUFS, true peak dBTP) via ebur128. tile > 1 loops the input first."""
    cmd = ["ffmpeg", "-hide_banner", "-nostats"]
    if tile > 1:
        cmd += ["-stream_loop", str(tile - 1)]
    cmd += ["-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"]
    err = run(cmd).stderr
    summary = err[err.rfind("Summary:"):]
    num = r"(-?inf|-?\d+(?:\.\d+)?)"
    lufs = float(re.search(r"I:\s+" + num + r" LUFS", summary).group(1))
    peak = float(re.search(r"True peak:\s+Peak:\s+" + num, summary).group(1))
    return lufs, peak


def rms_db(path, highpass=None):
    af = "astats=metadata=0"
    if highpass:
        af = "highpass=f=%d,highpass=f=%d,highpass=f=%d," % ((highpass,) * 3) + af
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", af, "-f", "null", "-"]).stderr
    return float(re.findall(r"RMS level dB:\s+(-?inf|-?\d+(?:\.\d+)?)", err)[-1])


def dc_offset(path):
    err = run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "astats=metadata=0",
               "-f", "null", "-"]).stderr
    return float(re.findall(r"DC offset:\s+(-?\d+(?:\.\d+)?)", err)[-1])


def duration(path):
    out = run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-count_packets",
               "-show_entries", "stream=duration_ts,sample_rate,duration", "-of",
               "default=nw=1", path]).stdout
    return float(re.search(r"duration=([\d.]+)", out).group(1))


def decoded_samples(path):
    raw = run_bytes(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-"])
    return struct.unpack("<%df" % (len(raw) // 4), raw)


def run_bytes(cmd):
    return subprocess.run(cmd, capture_output=True, check=True).stdout


def encode(wav, ogg, gain_db):
    run(["ffmpeg", "-y", "-hide_banner", "-v", "error", "-i", wav, "-af", "volume=%.2fdB" % gain_db,
         "-ar", str(SR), "-c:a", "libvorbis", "-q:a", "5", "-map_metadata", "-1",
         "-fflags", "+bitexact", "-flags:a", "+bitexact", ogg])


