#!/usr/bin/env python3
"""Voice bloops for the yard objects added in feature/more-objects, in the game's placeholder synth
style (scripts/autoload/synth.gd: short pitched sweeps with a wobble), but each with its own shape so
the gnome never sounds like the rubber chicken. Stdlib only; ffmpeg encodes Vorbis.

    python3 art/tools/make_voices.py            # writes assets/audio/sfx/voice_<id>.ogg

Audio.play("voice_<id>", pos, pitch) pitches them by object size, so keep them centred mid-range.
Deterministic: same file every run (fixed seed per id). Original, synthesised from scratch.
"""
import math
import os
import random
import struct
import subprocess
import sys
import wave

RATE = 22050
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
TMP = os.path.join(ROOT, ".scratch", "voices")


def osc(kind, phase, rng):
    if kind == "sine":
        return math.sin(phase * math.tau)
    if kind == "square":
        return 1.0 if phase < 0.5 else -1.0
    if kind == "saw":
        return phase * 2.0 - 1.0
    if kind == "tri":
        return 4.0 * abs(phase - 0.5) - 1.0
    return rng.uniform(-1.0, 1.0)


def tone(f0, f1, secs, kind="sine", vol=0.5, wob=0.0, wob_hz=0.0, noise=0.0, curve=1.0, rng=None):
    """A sweep from f0 to f1 Hz with optional vibrato (wob, fraction) and a breath of noise."""
    rng = rng or random.Random(1)
    n = int(RATE * secs)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * (t ** curve)
        f *= 1.0 + wob * math.sin(t * secs * wob_hz * math.tau)
        ph = (ph + f / RATE) % 1.0
        v = osc(kind, ph, rng) * (1.0 - noise) + rng.uniform(-1, 1) * noise
        env = min(1.0, t * 40.0) * (1.0 - t) ** 1.5
        out.append(v * env * vol)
    return out


def gap(secs):
    return [0.0] * int(RATE * secs)


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def voices():
    r = random.Random
    return {
        # Squeezed squeak toy: a nasal saw that squeals up and wheezes down.
        "rubber_chicken": tone(700, 1500, 0.16, "saw", 0.35, 0.06, 30, 0.15, rng=r(1))
        + tone(1400, 520, 0.28, "saw", 0.35, 0.1, 22, 0.25, rng=r(2)),
        # A stony little "hm-hmm!" from the gnome: two low hums, the second rising.
        "garden_gnome": tone(170, 150, 0.14, "tri", 0.6, 0.03, 9, rng=r(3)) + gap(0.04)
        + tone(150, 240, 0.22, "tri", 0.6, 0.04, 9, rng=r(4)),
        # A wobbly bloop with a slosh under it.
        "kiddie_pool": mix(tone(520, 220, 0.34, "sine", 0.55, 0.12, 14, rng=r(5)),
                           tone(900, 300, 0.3, "noise", 0.18, rng=r(6))),
        # Sproing: a rising sine with a fast springy vibrato.
        "trampoline": tone(260, 760, 0.42, "sine", 0.55, 0.14, 26, curve=0.6, rng=r(7)),
        # A rubbery creak and a low boop, like the old swing complaining.
        "tire_swing": tone(330, 300, 0.2, "square", 0.25, 0.08, 40, 0.1, rng=r(8))
        + tone(240, 160, 0.2, "sine", 0.55, 0.05, 8, rng=r(9)),
        # Squeaky inflatable: two quick high squeaks.
        "swim_ring": tone(900, 1300, 0.1, "sine", 0.45, 0.04, 30, rng=r(10)) + gap(0.03)
        + tone(1000, 1500, 0.13, "sine", 0.45, 0.04, 30, rng=r(11)),
        # A kazoo honk, plastic-bird style.
        "lawn_flamingo": tone(440, 520, 0.12, "square", 0.3, 0.05, 18, 0.05, rng=r(12))
        + tone(520, 400, 0.2, "square", 0.3, 0.07, 18, 0.05, rng=r(13)),
        # A swooshy "wheee" bloop: a breathy rise and a soft drop.
        "surfboard": mix(tone(380, 820, 0.3, "sine", 0.5, 0.03, 6, curve=0.7, rng=r(14)),
                         tone(1200, 500, 0.36, "noise", 0.16, rng=r(15)))
        + tone(640, 420, 0.12, "sine", 0.4, rng=r(16)),
    }


def write_wav(path, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = min(1.0, 0.9 / peak)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32000)) for s in samples))


def main():
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    for oid, samples in voices().items():
        wav = os.path.join(TMP, "voice_%s.wav" % oid)
        ogg = os.path.join(OUT, "voice_%s.ogg" % oid)
        write_wav(wav, samples)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4",
                        "-map_metadata", "-1", ogg], check=True)
        print("wrote", os.path.relpath(ogg, ROOT), "%.2fs" % (len(samples) / RATE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
