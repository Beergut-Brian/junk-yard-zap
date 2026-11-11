#!/usr/bin/env python3
"""Regenerate every Junk Yard Zap sound file from parameters. Python stdlib + ffmpeg only.

    python3 scripts/audio/make_cues.py                    # everything (parallel)
    python3 scripts/audio/make_cues.py zap_size_1 voice_cow_react
    python3 scripts/audio/make_cues.py --list             # stems and what they are
    python3 scripts/audio/make_cues.py --preview handoff/sfx_preview.ogg   # only the preview
    python3 scripts/audio/make_cues.py --manifest assets/audio/manifest.tsv

Every file is synthesised (additive partials, PolyBLEP saws through formant filters, filtered
noise, Karplus-Strong plucks), seeded per stem ("openjar-jyz:<stem>") so output is reproducible.
WAV sources go to .scratch/ (or a temp dir) and never into git. Loudness, like Spaceballs:
  - SFX of 0.6 s or more: -16 LUFS integrated; shorter SFX are measured looped 10x;
    a per-stem trim lets frequent cues (voices, clicks) sit a little lower.
  - music placeholders: -20 LUFS integrated, rendered as seamless loops (wrap-mixed tails).
  - everything: true peak <= -1 dBTP after encoding (Ogg Vorbis q5, 44.1 kHz mono).
Nothing above 9.5 kHz; no scary sounds (GAME.md: even the biggest crash is a cartoon crash).
"""
import argparse
import math
import multiprocessing
import os
import random
import shutil
import sys
import tempfile

sys.dont_write_bytecode = True   # no __pycache__ in the repo
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dsp import *  # noqa: E402,F401,F403
import dsp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUDIO_DIR = os.path.join(ROOT, "assets", "audio")
SFX_TARGET = -16.0
MUSIC_TARGET = -20.0
TP_CEILING = -1.0
SHORT_CUE = 0.6


# ---------------------------------------------------------------- junk-yard primitives

def cat(parts):
    """[(samples, at_seconds, gain), ...] mixed into one buffer long enough for all."""
    end = max(at + len(x) / SR for x, at, _ in parts)
    out = silence(end + 0.01)
    for x, at, g in parts:
        mix(out, x, at, g)
    return out


def boing(f0, f1, sec, wob=0.12, rate=16.0, decay=None, partials=((1, 1.0, 1.0), (2, 0.18, 2.0), (3, 0.05, 3.0))):
    """Cartoon spring: a glide f0 -> f1 with a wobble that dies away."""
    d = decay or sec * 0.45

    def freq(t):
        u = min(1.0, t / sec)
        return f0 * (f1 / f0) ** (u ** 0.7) * (1.0 + wob * math.exp(-t / (sec * 0.5)) * math.sin(TAU * rate * t))
    return osc(sec, freq, partials, decay=d, attack=0.003)


def pluck(f, sec, rng, damp=0.996, bright=0.5):
    """Karplus-Strong string (banjo, rubber band)."""
    n = int(sec * SR)
    p = max(2, int(SR / f))
    buf = [rng.uniform(-1, 1) for _ in range(p)]
    if bright < 1.0:
        buf = svf(buf, 800 + 6000 * bright)
    out = [0.0] * n
    j = 0
    for i in range(n):
        a = buf[j]
        b = buf[(j + 1) % p]
        buf[j] = damp * 0.5 * (a + b)
        out[i] = a
        j = (j + 1) % p
    return fades(out, 0.0005, 0.02)


def swoosh(rng, sec, f_lo, f_hi, q=1.2, peak=0.5):
    """Air whoosh: band-passed noise swept low -> high -> low, swelling at `peak` (0..1)."""
    def fc(t):
        u = t / sec
        s = math.sin(math.pi * min(1.0, u / peak / 2.0)) if u < peak else math.cos(math.pi * 0.5 * (u - peak) / (1 - peak))
        return f_lo + (f_hi - f_lo) * max(0.0, s)
    x = svf(noise(sec, rng), fc, q, "band")
    return [v * math.sin(math.pi * min(1.0, i / SR / sec)) ** 1.5 for i, v in enumerate(x)]


def tone(sec, freq, partials=((1, 1.0, 0.0),), attack=0.005, release=0.05):
    return osc(sec, freq, partials, attack=attack, amp=ar(sec, attack, release))


def am(x, rate, depth, shape="sin"):
    out = []
    for i, v in enumerate(x):
        ph = rate * i / SR
        m = 0.5 + 0.5 * math.sin(TAU * ph) if shape == "sin" else (1.0 if (ph % 1.0) < 0.5 else 0.0)
        out.append(v * (1.0 - depth + depth * m))
    return out


def lp(x, fc, q=0.707):
    return svf(x, fc, q)


def clang(f, decay, rng, vel=1.0):
    """Friendly tin clank (inharmonic metal partials, short)."""
    x = osc(min(decay * 6, 2.0), f, METAL, decay=decay, attack=0.001)
    mix(x, burst(rng, 0.02, min(4000, f * 3), 1.0, 0.004), 0.0, 0.3)
    return [v * vel for v in x]


def knock(f, rng, decay=0.06, vel=1.0):
    """Wood knock: WOOD partials + a click."""
    return struck(f, decay, rng, WOOD, vel=vel, click=0.35)


def crowd_yay(rng, n, sec, f_lo=240, f_hi=420):
    out = silence(sec + 0.2)
    for _ in range(n):
        f = rng.uniform(f_lo, f_hi)
        s = rng.uniform(sec * 0.6, sec)
        rise = rng.uniform(1.1, 1.35)
        v = voice(lambda t, f=f, s=s, r=rise: f * (1 + (r - 1) * min(1, t / (s * 0.4))) * (1 + 0.02 * math.sin(TAU * 6 * t)),
                  s, glide("a", "e", 0.05, s * 0.7), amp=ar(s, 0.04, 0.25), rng=rng, breath=0.06)
        mix(out, v, rng.uniform(0, 0.12), 1.0 / math.sqrt(n))
    return out


def claps(rng, count, start, end, gain=0.4):
    out = silence(end + 0.2)
    for _ in range(count):
        mix(out, clap(rng), rng.uniform(start, end), gain * rng.uniform(0.6, 1.0))
    return out


# ---------------------------------------------------------------- gun zaps (7 distinct)

def zap_size(f):          # boing
    def make(rng):
        pew = chirp(f * 5, f * 2.5, 0.06, ((1, 1.0, 0), (2, 0.2, 0)))
        return cat([(pew, 0.0, 0.25), (boing(f, f * 2.3, 0.5, 0.14, 14.0), 0.02, 1.0)])
    return make


def zap_grab(f):          # hum
    def make(rng):
        sec = 0.6
        src = saw(lambda t: f * (1 + 0.45 * min(1, t / sec)) * (1 + 0.01 * math.sin(TAU * 6 * t)), sec)
        sub = osc(sec, lambda t: f * 0.5 * (1 + 0.45 * min(1, t / sec)))
        x = svf(src, lambda t: 350 + 1500 * min(1, t / sec), 1.5)
        x = am([a + 0.6 * b for a, b in zip(x, sub)], 11.0, 0.35)
        return envelope(x, ar(sec, 0.06, 0.15))
    return make


def zap_bouncy(f):        # rubber twang
    def make(rng):
        sec = 0.55
        body = osc(sec, lambda t: f * (1 + 0.6 * math.exp(-t / 0.025)) * (1 + 0.05 * math.exp(-t / 0.2) * math.sin(TAU * 9 * t)),
                   ((1, 1.0, 1.0), (2, 0.35, 2.5), (3, 0.15, 4.0)), decay=0.18, attack=0.001)
        snap = burst(rng, 0.03, 2500, 1.5, 0.004)
        return cat([(body, 0.0, 1.0), (snap, 0.0, 0.3), (pluck(f * 2, 0.4, rng, 0.99, 0.4), 0.0, 0.25)])
    return make


def zap_balloon(f):       # squeak
    def make(rng):
        parts = []
        t = 0.0
        for k in range(3):
            s = rng.uniform(0.07, 0.12)
            a, b = f * rng.uniform(0.9, 1.1), f * rng.uniform(1.2, 1.6)
            if k % 2:
                a, b = b, a
            v = voice(lambda tt, a=a, b=b, s=s: a * (b / a) ** min(1, tt / s), s, "i", rng=rng, breath=0.02, scale=1.3, rough=0.25)
            parts.append((v, t, 1.0))
            t += s + rng.uniform(0.0, 0.03)
        return cat(parts)
    return make


def zap_freeze(f):        # crack
    def make(rng):
        crack = burst(rng, 0.05, 3200, 0.9, 0.006)
        crack2 = burst(rng, 0.04, 2400, 1.2, 0.008)
        fizz = envelope(svf(noise(0.5, rng), lambda t: 5000 - 3000 * t, 2.0, "band"), lambda t: 0.4 * math.exp(-t / 0.2))
        tink = sparkle(rng, 4, 0.05, 0.3, 0.5, notes=(f, f + 4, f + 7, f + 12))
        return cat([(crack, 0.0, 1.0), (crack2, 0.035, 0.7), (fizz, 0.03, 0.6), (tink, 0.04, 1.0),
                    (thump(220, 120, 0.08, 0.03), 0.0, 0.4)])
    return make


def squelch_sound(f, sec=0.4):
    def make(rng):
        x = svf(noise(sec, rng), lambda t: f + 2.4 * f * math.sin(math.pi * min(1, t / sec)) ** 2, 3.5, "band")
        x = envelope(x, lambda t: (0.6 + 0.4 * math.sin(TAU * 18 * t)) * ar(sec, 0.01, 0.12)(t))
        blop = osc(0.18, lambda t: f * 0.5 * (1 - 0.5 * t / 0.18), decay=0.06)
        return cat([(x, 0.0, 1.0), (blop, 0.02, 0.6)])
    return make


def zap_magnet(f):        # electric buzz (friendly: short, bouncy, sparkly)
    def make(rng):
        sec = 0.5
        src = saw(lambda t: f * (1 + 0.25 * t / sec), sec)
        x = svf(src, 1100, 1.2, "band")
        x = am(x, 28.0, 0.7)
        out = cat([(envelope(x, ar(sec, 0.01, 0.1)), 0.0, 1.0)])
        for _ in range(5):
            mix(out, burst(rng, 0.015, rng.uniform(2500, 4000), 2.0, 0.003), rng.uniform(0.02, sec - 0.05), 0.35)
        mix(out, chirp(1200, 2400, 0.06), sec - 0.08, 0.2)
        return out
    return make


# ---------------------------------------------------------------- size, grab, throw

def grow(f):
    def make(rng):
        notes = notes_seq([(f, 0.0), (f + 4, 0.07), (f + 7, 0.14)], rng, XYLO, 0.08)
        return cat([(boing(midi(f) / 2, midi(f) * 1.1, 0.42, 0.1, 13.0), 0.0, 1.0), (notes, 0.02, 0.35)])
    return make


def shrink(f):
    def make(rng):
        notes = notes_seq([(f + 7, 0.0), (f + 4, 0.07), (f, 0.14)], rng, XYLO, 0.08)
        return cat([(boing(midi(f) * 1.1, midi(f) / 2.2, 0.42, 0.1, 15.0), 0.0, 1.0), (notes, 0.02, 0.35)])
    return make


def grab_hum(f):
    def make(rng):
        sec = 0.42
        x = svf(saw(lambda t: f * (1 + 1.4 * (t / sec) ** 1.4), sec), lambda t: 400 + 1800 * t / sec, 1.3)
        x = envelope(am(x, 14, 0.3), ar(sec, 0.03, 0.06))
        lock = struck(midi(84), 0.05, rng, BELL, click=0.1)
        return cat([(x, 0.0, 1.0), (lock, sec - 0.03, 0.35)])
    return make


def throw_whoosh(lo, hi, sec):
    def make(rng):
        w = swoosh(rng, sec, lo, hi, 1.4, 0.35)
        wh = whistle(600, 1400, sec * 0.6, rng, vib=0.0, breath=0.0)
        return cat([(w, 0.0, 1.0), (envelope(wh, ar(sec * 0.6, 0.05, 0.15)), 0.02, 0.12)])
    return make


def drop(f):
    def make(rng):
        return cat([(chirp(f, f * 0.55, 0.14), 0.0, 0.8), (osc(0.12, lambda t: 300 + 600 * t / 0.12, decay=0.04), 0.13, 0.4)])
    return make


# ---------------------------------------------------------------- impacts (4 bands)

def impact_light(f):
    def make(rng):
        return cat([(knock(f, rng, 0.05), 0.0, 1.0), (thump(260, 140, 0.1, 0.04), 0.0, 0.5),
                    (burst(rng, 0.04, 1800, 1.0, 0.006), 0.0, 0.3)])
    return make


def impact_medium(f):
    def make(rng):
        return cat([(thump(f, 55, 0.3, 0.1), 0.0, 1.0), (knock(f * 2.2, rng, 0.07), 0.0, 0.55),
                    (burst(rng, 0.06, 1400, 0.9, 0.012), 0.0, 0.4), (rumble(rng, 0.25, 500, 0.06), 0.0, 0.5)])
    return make


def impact_heavy(f):
    def make(rng):
        parts = [(thump(f, 38, 0.7, 0.22), 0.0, 1.0), (rumble(rng, 0.6, 350, 0.18), 0.0, 0.8),
                 (burst(rng, 0.08, 1000, 0.8, 0.02), 0.0, 0.5)]
        t = 0.08
        for k in range(4):   # cartoon junk bouncing off
            parts.append((knock(rng.uniform(300, 700), rng, 0.05) if k % 2 else clang(rng.uniform(500, 900), 0.05, rng),
                          t, 0.35 * (0.8 ** k)))
            t += rng.uniform(0.07, 0.13)
        return cat(parts)
    return make


def impact_huge(f):
    def make(rng):
        parts = [(thump(f, 30, 1.1, 0.35), 0.0, 1.0), (rumble(rng, 1.0, 280, 0.3), 0.0, 0.9),
                 (burst(rng, 0.12, 900, 0.7, 0.04), 0.0, 0.6)]
        t = 0.12
        for k in range(7):   # tin cans and a pan clattering about
            parts.append((clang(rng.uniform(400, 1100), rng.uniform(0.04, 0.09), rng), t, 0.4 * (0.85 ** k)))
            t += rng.uniform(0.06, 0.12)
        parts.append((boing(160, 320, 0.45, 0.2, 11.0), t + 0.05, 0.45))        # a spring goes boing
        parts.append((sparkle(rng, 3, 0.0, 0.25, 0.35), t + 0.2, 1.0))           # and the stars
        return cat(parts)
    return make


def splash(sec):
    def make(rng):
        body = envelope(soft(noise(sec, rng), 2600), lambda t: min(1, t / 0.008) * math.exp(-t / (sec * 0.28)))
        hit = thump(180, 90, 0.12, 0.04)
        parts = [(body, 0.0, 1.0), (hit, 0.0, 0.5)]
        for _ in range(6):
            a = rng.uniform(250, 500)
            parts.append((chirp(a, a * rng.uniform(1.8, 2.8), rng.uniform(0.04, 0.08)), rng.uniform(0.05, sec * 0.8), 0.25))
        for _ in range(5):
            parts.append((struck(rng.uniform(1500, 2600), 0.02, rng, ((1, 1.0, 1.0),), click=0.0), rng.uniform(0.1, sec), 0.15))
        return cat(parts)
    return make


# ---------------------------------------------------------------- cards, reset, wheel

def card_view(f):
    def make(rng):
        a = swoosh(rng, 0.12, 1500, 4500, 1.0, 0.5)
        b = swoosh(rng, 0.09, 2000, 5000, 1.3, 0.3)
        tick = burst(rng, 0.02, 3000, 2.0, 0.003)
        return cat([(a, 0.0, 1.0), (b, 0.1, 0.8), (tick, 0.2, 0.4), (struck(midi(f), 0.06, rng, MARIMBA), 0.2, 0.25)])
    return make


def card_done(seed_notes):
    def make(rng):
        parts = []
        t = 0.0
        for k in range(2):   # two fireworks: whistle up, pop, crackle
            w = whistle(500, 1800, 0.35, rng, vib=0.0, breath=0.05)
            parts.append((envelope(w, ar(0.35, 0.02, 0.05)), t, 0.25))
            parts.append((burst(rng, 0.1, 900, 0.8, 0.03), t + 0.36, 0.8))
            parts.append((thump(140, 60, 0.25, 0.08), t + 0.36, 0.6))
            for _ in range(10):
                parts.append((burst(rng, 0.01, rng.uniform(2500, 5000), 2.0, 0.003), t + 0.4 + rng.uniform(0, 0.5), 0.25))
            t += 0.45
        parts.append((notes_seq([(n, i * 0.09) for i, n in enumerate(seed_notes)], rng, BELL, 0.18), 0.4, 0.5))
        parts.append((crowd_yay(rng, 7, 1.3), 0.55, 0.9))
        parts.append((claps(rng, 18, 0.6, 1.9), 0.0, 1.0))
        return cat(parts)
    return make


def raspberry(f, sec):
    def make(rng):
        src = saw(lambda t: f * (1 - 0.15 * t / sec) * (1 + 0.03 * math.sin(TAU * 7 * t)), sec)
        src = [v + 0.15 * rng.uniform(-1, 1) for v in src]
        src = am(src, 32.0, 0.85)
        out = [0.0] * len(src)
        for k, (fc, q, g) in enumerate(((450, 3, 1.0), (900, 5, 0.5), (2400, 6, 0.15))):
            mix(out, svf(src, fc, q, "band"), 0.0, g)
        return envelope(out, ar(sec, 0.03, 0.15))
    return make


def reset_yard(rng):
    w = swoosh(rng, 1.4, 200, 2400, 0.9, 0.55)
    w2 = swoosh(rng, 1.2, 400, 3200, 1.4, 0.6)
    bell = struck(midi(76), 0.35, rng, BELL, click=0.15)
    bell2 = struck(midi(83), 0.3, rng, BELL, click=0.1)
    return cat([(w, 0.0, 1.0), (w2, 0.15, 0.6), (bell, 1.05, 0.7), (bell2, 1.25, 0.4),
                (sparkle(rng, 5, 0.0, 0.6, 0.25), 1.1, 1.0)])


def reset_hold(rng):
    parts = [(burst(rng, 0.02, 1800 + 120 * k, 3.0, 0.004), 0.05 * k, 0.6 + 0.04 * k) for k in range(10)]
    parts.append((whistle(400, 900, 0.5, rng, breath=0.03), 0.0, 0.25))
    return cat(parts)


def click(f, fc):
    def make(rng):
        return cat([(burst(rng, 0.02, fc, 2.5, 0.003), 0.0, 1.0), (tone(0.03, f, release=0.02), 0.0, 0.25)])
    return make


# ---------------------------------------------------------------- small action cues

def sparkle_cue(notes):
    def make(rng):
        return cat([(notes_seq([(n, 0.045 * i) for i, n in enumerate(notes)], rng, BELL, 0.06), 0.0, 0.6),
                    (sparkle(rng, 3, 0.05, 0.2, 0.3), 0.0, 1.0)])
    return make


def nope(f):
    def make(rng):    # friendly "uh-uh", two kazoo-ish voice notes down
        a = voice(f, 0.12, "u", amp=ar(0.12, 0.01, 0.04), rng=rng)
        b = voice(lambda t: f * 0.8 * (1 - 0.1 * t / 0.18), 0.18, "u", amp=ar(0.18, 0.01, 0.08), rng=rng)
        return cat([(a, 0.0, 1.0), (b, 0.16, 1.0)])
    return make


def jump_cue(f):
    def make(rng):
        return cat([(chirp(f, f * 1.9, 0.12, ((1, 1, 0), (2, 0.15, 0))), 0.0, 1.0), (burst(rng, 0.03, 900, 1.0, 0.008), 0.0, 0.3)])
    return make


def land_cue(f):
    def make(rng):
        return cat([(thump(f, 60, 0.12, 0.04), 0.0, 1.0), (rumble(rng, 0.1, 800, 0.03), 0.0, 0.5)])
    return make


def recall(rng):
    return cat([(whistle(1400, 500, 0.35, rng, vib=0.01), 0.0, 0.6), (burst(rng, 0.03, 1200, 2.0, 0.008), 0.36, 0.8),
                (struck(midi(79), 0.08, rng, MARIMBA), 0.38, 0.4)])


def snort(rng):
    sec = 0.3
    src = [v * (0.5 + 0.5 * math.sin(TAU * 22 * i / SR)) for i, v in enumerate(noise(sec, rng))]
    x = cat([(svf(src, 500, 2.5, "band"), 0.0, 1.0), (svf(src, 1200, 3.0, "band"), 0.0, 0.4)])
    return envelope(x, ar(sec, 0.02, 0.1))


def snore(f):
    def make(rng):
        inh = envelope(am(svf(noise(0.6, rng), 350, 2.0, "band"), 25, 0.8), ar(0.6, 0.2, 0.15))
        exh = whistle(f * 1.2, f, 0.6, rng, curve=1.0, vib=0.02, breath=0.2)
        return cat([(inh, 0.0, 1.0), (envelope(exh, ar(0.6, 0.1, 0.25)), 0.7, 0.3)])
    return make


def pop(f):
    def make(rng):
        return cat([(burst(rng, 0.03, 1400, 2.0, 0.006), 0.0, 1.0), (chirp(f, f * 2, 0.08), 0.0, 0.4)])
    return make


def unglue(rng):
    stretch = voice(lambda t: 180 * (1 + 0.8 * t / 0.25), 0.25, "o", rng=rng, breath=0.1, rough=0.5, scale=0.8)
    return cat([(stretch, 0.0, 0.6), (pop(600)(rng), 0.24, 1.0)])


def glue_pick(rng):
    return cat([(struck(midi(81), 0.05, rng, MARIMBA), 0.0, 0.6), (squelch_sound(500, 0.15)(rng), 0.02, 0.6)])


def two_notes(a, b, partials=MARIMBA, gap=0.09, decay=0.1):
    def make(rng):
        return notes_seq([(a, 0.0), (b, gap)], rng, partials, decay)
    return make


def player_join(rng):
    return cat([(pop(700)(rng), 0.0, 0.6), (notes_seq([(72, 0.05), (76, 0.11), (79, 0.17), (84, 0.23)], rng, MARIMBA, 0.08), 0.0, 1.0)])


def round_start(rng):
    def toot(sec):
        return envelope(am(osc(sec, 2000, ((1, 1, 0), (2, 0.1, 0))), 40, 0.5), ar(sec, 0.01, 0.03))
    return cat([(toot(0.1), 0.0, 1.0), (toot(0.35), 0.15, 1.0), (burst(rng, 0.02, 3000, 1, 0.005), 0.0, 0.1)])


def round_end(rng):
    return notes_seq([(72, 0.0), (76, 0.1), (79, 0.2), (84, 0.32)], rng, MARIMBA, 0.16)


def solo_swap(rng):
    puff = envelope(soft(noise(0.15, rng), 1500), ar(0.15, 0.01, 0.1))
    return cat([(puff, 0.0, 0.8), (chirp(500, 1200, 0.1), 0.06, 0.5)])


# ---------------------------------------------------------------- barks (generic Jarling voices)
# Wordless, cheerful cartoon vocals. Characters with their own voice pack never use these.

def bark_word(f, sylls, rng, scale=1.15):
    """sylls: [(vowel_a, vowel_b, sec, pitch_mul_start, pitch_mul_end), ...]"""
    parts = []
    t = 0.0
    for va, vb, sec, p0, p1 in sylls:
        v = voice(lambda tt, sec=sec, p0=p0, p1=p1: f * (p0 + (p1 - p0) * min(1, tt / sec)) * (1 + 0.015 * math.sin(TAU * 6 * tt)),
                  sec, glide(va, vb, 0.0, sec * 0.8), amp=ar(sec, 0.012, min(0.08, sec * 0.4)), rng=rng, scale=scale)
        parts.append((v, t, 1.0))
        t += sec + 0.03
    return cat(parts)


def bark(kind, k):
    def make(rng):
        f = 250 + 30 * k
        if kind == "plain":
            return bark_word(f, [[("e", "a", 0.16, 1.0, 1.25)], [("u", "u", 0.22, 0.9, 1.4)],
                                 [("a", "u", 0.1, 1.1, 1.0)], [("o", "u", 0.28, 1.2, 0.9)]][k % 4], rng)
        if kind == "cheer":
            return cat([(bark_word(f, [("i", "a", 0.12, 1.0, 1.2), ("a", "e", 0.38, 1.25, 1.5)], rng), 0.0, 1.0),
                        (claps(rng, 5, 0.1, 0.5, 0.25), 0.0, 1.0)])
        if kind == "zap":   # Chuck narrating his own zap: "bzz-HA!", "pew-pew!", "zip!"
            return bark_word(f, [[("i", "u", 0.09, 1.3, 1.0), ("a", "a", 0.16, 1.2, 1.4)],
                                 [("e", "u", 0.08, 1.4, 1.2), ("e", "u", 0.1, 1.4, 1.1)],
                                 [("i", "i", 0.12, 1.1, 1.6)]][k % 3], rng)
        if kind == "delight":   # Jeff at a big crash: "whoa-ho!", "woooow!", "hee-hee-hee"
            return bark_word(f, [[("u", "a", 0.2, 1.0, 1.3), ("o", "o", 0.22, 1.3, 1.1)],
                                 [("u", "a", 0.45, 1.0, 1.5)],
                                 [("i", "i", 0.08, 1.5, 1.4), ("i", "i", 0.08, 1.6, 1.5), ("i", "i", 0.1, 1.7, 1.5)]][k % 3], rng)
        raise ValueError(kind)
    return make


# ---------------------------------------------------------------- object voices
# Each object has react / grabbed / thrown / landed. KIND: (pitch mul, length mul).
KIND = {"react": (1.0, 1.0), "grabbed": (1.15, 0.85), "thrown": (1.25, 1.3), "landed": (0.82, 0.7)}


def with_kind(fn):
    """Wrap an archetype so thrown gets a whoosh under it and landed a small bump."""
    def arche(base, **kw):
        def kinded(kind):
            def make(rng):
                pm, dm = KIND[kind]
                x = fn(rng, base * pm, dm, kind, **kw)
                if kind == "thrown" and fn.__name__ not in ANIMALS:
                    x = cat([(x, 0.0, 1.0), (swoosh(rng, 0.4, 300, 1800, 1.3, 0.4), 0.0, 0.25)])
                if kind == "landed":
                    x = cat([(thump(180, 70, 0.1, 0.035), 0.0, 0.3), (x, 0.02, 1.0)])
                return x
            return make
        return kinded
    return arche


ANIMALS = {"v_moo", "v_oink", "v_baa", "v_bawk", "v_quack_squeak", "v_blub", "v_gnome", "v_flamingo", "v_rubber_chicken"}


def contour(kind, sec):
    """Pitch contour per kind for animal voices: grabbed rises (surprise), thrown is a long
    'wheee' up, landed falls (oof), react is a gentle arch."""
    if kind == "grabbed":
        return lambda t: 1.0 + 0.35 * min(1, t / sec)
    if kind == "thrown":
        return lambda t: 1.0 + 0.6 * math.sin(math.pi * 0.5 * min(1, t / sec))
    if kind == "landed":
        return lambda t: 1.1 - 0.35 * min(1, t / sec)
    return lambda t: 1.0 + 0.12 * math.sin(math.pi * min(1, t / sec))


@with_kind
def v_moo(rng, f, dm, kind):
    sec = 0.75 * dm
    c = contour(kind, sec)
    return voice(lambda t: f * c(t) * (1 + 0.01 * math.sin(TAU * 5 * t)), sec, glide("u", "o", 0.1, sec * 0.8),
                 amp=ar(sec, 0.08, 0.25), rng=rng, breath=0.05, scale=0.75, rough=0.08)


@with_kind
def v_oink(rng, f, dm, kind):
    n = 1 if kind == "landed" else 2
    c = contour(kind, 0.3)
    parts = []
    for k in range(n):
        s = 0.12 * dm
        v = voice(lambda t, k=k: f * c(t + k * 0.15) * (1 - 0.15 * t / s), s, "o", rng=rng, breath=0.25, rough=0.4, scale=1.0)
        parts.append((v, k * (s + 0.05), 1.0))
    return cat(parts)


@with_kind
def v_baa(rng, f, dm, kind):
    sec = 0.55 * dm
    c = contour(kind, sec)
    return voice(lambda t: f * c(t) * (1 + 0.04 * math.sin(TAU * 9 * t)), sec, glide("e", "a", 0.05, 0.25),
                 amp=lambda t: ar(sec, 0.03, 0.15)(t) * (0.75 + 0.25 * math.sin(TAU * 9 * t)), rng=rng, rough=0.2)


@with_kind
def v_bawk(rng, f, dm, kind):
    c = contour(kind, 0.4)
    sylls = [(0.05, 1.0), (0.05, 1.05), (0.16 * dm, 1.3)] if kind != "landed" else [(0.06, 1.0), (0.12, 0.85)]
    parts = []
    t = 0.0
    for s, p in sylls:
        v = voice(lambda tt, p=p, t0=t, s=s: f * p * c(t0 + tt) * (1 - 0.2 * tt / s), s, glide("a", "o", 0, s), rng=rng, rough=0.3, scale=1.4)
        parts.append((v, t, 1.0))
        t += s + 0.025
    return cat(parts)


@with_kind
def v_quack_squeak(rng, f, dm, kind):
    sec = 0.22 * dm
    c = contour(kind, sec)
    v = voice(lambda t: f * c(t) * (1 + 0.3 * math.sin(math.pi * min(1, t / sec))), sec, "i", rng=rng, breath=0.03, scale=1.6, rough=0.15)
    if kind in ("grabbed", "thrown"):
        v = cat([(v, 0.0, 1.0), (voice(lambda t: f * 1.2 * c(t), sec * 0.7, "e", rng=rng, scale=1.6), sec + 0.03, 0.8)])
    return v


@with_kind
def v_blub(rng, f, dm, kind):
    parts = []
    for k in range(3 if kind != "landed" else 2):
        a = f * rng.uniform(0.8, 1.2) * (1 + 0.2 * k)
        parts.append((chirp(a, a * 2.2, 0.06 * dm), k * 0.08, 1.0))
    if kind == "landed":   # floppy flap
        parts.append((burst(rng, 0.05, 900, 1.5, 0.015), 0.15, 0.6))
    return cat(parts)


@with_kind
def v_honk(rng, f, dm, kind, two_tone=1.26, sec=0.28):
    """Car / tractor horn: two detuned buzzy tones."""
    s = sec * dm
    times = {"react": [(0, s)], "grabbed": [(0, s * 0.5), (s * 0.6, s * 0.5)], "thrown": [(0, s * 1.4)], "landed": [(0, s * 0.6)]}[kind]
    parts = []
    for t0, d in times:
        src = [a + b for a, b in zip(saw(f, d), saw(f * two_tone, d))]
        x = svf(src, 1400, 1.5)
        x = envelope(x, ar(d, 0.01, 0.04))
        parts.append((x, t0, 1.0))
    return cat(parts)


@with_kind
def v_engine(rng, f, dm, kind):
    sec = 0.6 * dm
    rate = {"react": 9, "grabbed": 14, "thrown": 18, "landed": 6}[kind]
    out = silence(sec)
    t = 0.0
    while t < sec - 0.05:
        mix(out, thump(f * 2, f, 0.06, 0.025), t, 1.0)
        mix(out, burst(rng, 0.04, 600, 1.2, 0.01), t, 0.4)
        t += 1.0 / rate
    toot = envelope(svf(saw(f * 4, 0.15), 1200, 1.2), ar(0.15, 0.01, 0.04))
    return cat([(out, 0.0, 1.0), (toot, sec, 0.6)]) if kind == "react" else out


@with_kind
def v_foghorn(rng, f, dm, kind):
    sec = 0.6 * dm
    c = contour(kind, sec)
    x = svf(saw(lambda t: f * c(t), sec), 600, 1.0)
    return envelope(x, ar(sec, 0.06, 0.2))


@with_kind
def v_piano(rng, f, dm, kind, chord_=(0, 4, 7)):
    root = 12 * math.log2(f / 440.0) + 69
    if kind == "landed":   # piano chord on landing: big friendly cluster-chord
        return chord([root - 12, root, root + 4, root + 7, root + 12], 0.4, rng, MARIMBA, 1.2)
    if kind == "thrown":   # glissando up
        return notes_seq([(root + s, 0.035 * i) for i, s in enumerate((0, 2, 4, 5, 7, 9, 11, 12, 14, 16))], rng, MARIMBA, 0.12)
    if kind == "grabbed":
        return notes_seq([(root + 7, 0.0), (root + 12, 0.08)], rng, MARIMBA, 0.15)
    return chord([root + s for s in chord_], 0.25, rng, MARIMBA)


@with_kind
def v_rattle(rng, f, dm, kind, metal=True):
    """Fridge, toolbox: bottles / tools rattling."""
    sec = 0.4 * dm
    n = {"react": 6, "grabbed": 8, "thrown": 10, "landed": 5}[kind]
    out = silence(sec + 0.3)
    for k in range(n):
        g = rng.uniform(0.5, 1.0)
        if metal:
            mix(out, clang(f * rng.uniform(0.8, 1.6), 0.03, rng), rng.uniform(0, sec), g)
        else:
            mix(out, struck(f * rng.uniform(0.9, 1.5), 0.04, rng, BELL, click=0.3), rng.uniform(0, sec), g)
    if not metal:   # fridge hum
        mix(out, envelope(osc(sec, 120, ((1, 1, 0), (2, 0.5, 0), (3, 0.2, 0))), ar(sec, 0.05, 0.1)), 0.0, 0.25)
    return out


@with_kind
def v_slosh(rng, f, dm, kind, ding=True):
    """Washing machine / kiddie pool: water slosh (+ a ding)."""
    sec = 0.5 * dm
    x = svf(noise(sec, rng), lambda t: f + f * math.sin(TAU * 3 * t) ** 2, 2.0, "band")
    x = envelope(x, lambda t: ar(sec, 0.05, 0.15)(t) * (0.5 + 0.5 * math.sin(TAU * 4 * t) ** 2))
    parts = [(x, 0.0, 1.0)]
    if ding and kind in ("react", "landed"):
        parts.append((struck(midi(84), 0.2, rng, BELL), sec * 0.7, 0.4))
    return cat(parts)


@with_kind
def v_toaster(rng, f, dm, kind):
    spring = boing(400, 900, 0.18 * dm, 0.2, 25)
    parts = [(burst(rng, 0.02, 2000, 2.0, 0.004), 0.0, 1.0), (spring, 0.01, 0.6)]
    if kind != "landed":
        parts.append((struck(midi(88), 0.15, rng, BELL), 0.12, 0.5))
    return cat(parts)


@with_kind
def v_kettle(rng, f, dm, kind):
    sec = 0.45 * dm
    c = contour(kind, sec)
    w = whistle(f * c(0), f * c(sec), sec, rng, vib=0.03, breath=0.2)
    return envelope(w, ar(sec, 0.08, 0.12))


@with_kind
def v_tv(rng, f, dm, kind):
    if kind == "landed":
        return cat([(envelope(soft(noise(0.2, rng), 5000), ar(0.2, 0.005, 0.1)), 0.0, 0.5), (tone(0.08, f * 0.5), 0.05, 0.6)])
    seq = {"react": (1.0, 1.25), "grabbed": (1.0, 1.5), "thrown": (1.0, 1.25, 1.5, 2.0)}[kind]
    parts = [(tone(0.07, f * s, ((1, 1, 0), (3, 0.2, 0))), 0.08 * i, 0.7) for i, s in enumerate(seq)]
    parts.append((envelope(soft(noise(0.08, rng), 5000), ar(0.08, 0.005, 0.04)), 0.0, 0.25))
    return cat(parts)


@with_kind
def v_clang(rng, f, dm, kind):
    """Anvil, cannonball, milk can, bucket, watering can: friendly metal clank, a ring."""
    d = {"react": 0.18, "grabbed": 0.1, "thrown": 0.12, "landed": 0.25}[kind] * dm
    parts = [(clang(f, d, rng), 0.0, 1.0)]
    if kind == "grabbed":
        parts.append((clang(f * 1.12, d, rng), 0.08, 0.6))
    return cat(parts)


@with_kind
def v_bong(rng, f, dm, kind):
    """Oil drum, pipe: hollow bong with a low body."""
    d = 0.25 * dm
    body = osc(min(1.2, d * 5), lambda t: f * (1 + 0.04 * math.exp(-t / 0.05)), ((1, 1.0, 1.0), (1.51, 0.5, 1.4), (2.2, 0.3, 2.0), (3.1, 0.12, 3.0)), decay=d)
    return cat([(body, 0.0, 1.0), (burst(rng, 0.02, 1200, 1.0, 0.005), 0.0, 0.3)])


@with_kind
def v_knock(rng, f, dm, kind, hollow=False):
    """Crate, log, plank, bowling pin, pumpkin: wood knocks (pin clatters, gourd thunks)."""
    n = {"react": 2, "grabbed": 1, "thrown": 2, "landed": 3}[kind]
    parts = []
    for k in range(n):
        x = knock(f * (1.0 if k == 0 else rng.uniform(0.9, 1.2)), rng, 0.05 * dm)
        if hollow:
            x = cat([(x, 0.0, 0.6), (thump(f * 0.6, f * 0.4, 0.15, 0.06), 0.0, 1.0)])
        parts.append((x, k * rng.uniform(0.07, 0.1), 1.0 * 0.75 ** k))
    return cat(parts)


@with_kind
def v_rubber(rng, f, dm, kind, squeak=True):
    """Ball, beach ball, tire, swim ring, trampoline: rubbery bwomp + squeak."""
    sec = 0.3 * dm
    c = contour(kind, sec)
    bw = boing(f * c(0), f * c(sec) * 1.3, sec, 0.15, 12)
    parts = [(bw, 0.0, 1.0)]
    if squeak and kind in ("grabbed", "thrown"):
        parts.append((voice(lambda t: f * 4 * c(t), 0.1, "i", rng=rng, scale=1.5, rough=0.3), 0.02, 0.5))
    return cat(parts)


@with_kind
def v_creak(rng, f, dm, kind, springs=True):
    """Armchair, mattress, wheelbarrow, tire swing: creaks and springs."""
    sec = 0.35 * dm
    cr = envelope(svf(am(noise(sec, rng), 60, 0.9, "sq"), lambda t: f * (1 + 0.4 * t / sec), 6.0, "band"), ar(sec, 0.03, 0.1))
    parts = [(cr, 0.0, 1.0)]
    if springs:
        parts.append((boing(f * 0.4, f * 0.6, 0.3 * dm, 0.25, 20), 0.05, 0.5))
    return cat(parts)


@with_kind
def v_rustle(rng, f, dm, kind):
    """Hay, kite: dry rustle / paper flutter with a tiny pitch."""
    sec = 0.4 * dm
    x = envelope(svf(noise(sec, rng), f * 4, 1.0, "band"), lambda t: ar(sec, 0.05, 0.15)(t) * (0.5 + 0.5 * abs(math.sin(TAU * 7 * t))))
    return cat([(x, 0.0, 1.0), (tone(0.1, f * 2, attack=0.01), 0.05, 0.15)])


@with_kind
def v_egg(rng, f, dm, kind):
    if kind == "landed":   # wobbly "tik-tik" but never breaks on screen: a little wobble
        return cat([(knock(f, rng, 0.02), 0.0, 1.0), (knock(f * 1.1, rng, 0.02), 0.07, 0.6), (boing(f / 3, f / 2.5, 0.25, 0.3, 9), 0.1, 0.4)])
    return cat([(knock(f, rng, 0.03), 0.0, 1.0), (chirp(f / 2, f / 1.5 * KIND[kind][0], 0.12), 0.05, 0.4)])


@with_kind
def v_cannon(rng, f, dm, kind):
    if kind == "react":   # cork pop + whistle
        return cat([(thump(f * 2, f, 0.25, 0.08), 0.0, 1.0), (pop(500)(rng), 0.0, 0.7)])
    return cat([(clang(f * 3, 0.15 * dm, rng), 0.0, 1.0), (thump(f * 1.5, f * 0.8, 0.15, 0.05), 0.0, 0.6)])


@with_kind
def v_tub(rng, f, dm, kind):
    """Bathtub: porcelain ring + a rubber squeak / glug."""
    parts = [(struck(f, 0.12 * dm, rng, BELL, click=0.2), 0.0, 0.7)]
    if kind == "react":
        parts.append((v_blub_raw(rng, f / 2), 0.05, 0.7))
    else:
        parts.append((voice(lambda t: f * 0.8 * KIND[kind][0], 0.12, "i", rng=rng, scale=1.5), 0.05, 0.5))
    return cat(parts)


def v_blub_raw(rng, f):
    return cat([(chirp(f * k, f * k * 2, 0.05), 0.07 * (k - 1), 1.0) for k in (1, 1.3, 1.6)])


@with_kind
def v_gnome(rng, f, dm, kind):
    """Garden gnome: a tiny gruff 'hm!' / giggle (wordless)."""
    if kind == "react":
        return bark_word(f, [("u", "u", 0.12, 1.0, 0.9)], rng, 0.9)
    if kind == "thrown":
        return bark_word(f, [("i", "i", 0.06, 1.5, 1.4), ("i", "i", 0.06, 1.6, 1.5), ("i", "i", 0.08, 1.7, 1.6)], rng, 1.1)
    if kind == "grabbed":
        return bark_word(f, [("o", "o", 0.14, 1.0, 1.4)], rng, 0.9)
    return bark_word(f, [("u", "u", 0.12, 1.1, 0.8)], rng, 0.9)


@with_kind
def v_flamingo(rng, f, dm, kind):
    sec = 0.25 * dm
    c = contour(kind, sec)
    return voice(lambda t: f * c(t), sec, glide("a", "u", 0, sec), rng=rng, scale=1.2, rough=0.35, breath=0.08)


@with_kind
def v_rubber_chicken(rng, f, dm, kind):
    sec = 0.4 * dm
    c = contour(kind, sec)
    return voice(lambda t: f * c(t) * (1 - 0.3 * (t / sec) ** 2), sec, glide("a", "e", 0, sec), rng=rng, breath=0.3, rough=0.5, scale=1.3)


@with_kind
def v_surf(rng, f, dm, kind):
    sec = 0.35 * dm
    return cat([(swoosh(rng, sec, f, f * 6, 1.2, 0.5), 0.0, 1.0), (burst(rng, 0.03, 1000, 1.2, 0.01), sec, 0.5)])


# id -> (archetype, base Hz, kwargs). Every object in data/objects/ (and the more-objects branch).
OBJECTS = {
    "cow": (v_moo, 115), "pig": (v_oink, 190), "sheep": (v_baa, 260), "chicken": (v_bawk, 420),
    "duck": (v_quack_squeak, 900), "fish": (v_blub, 380), "egg": (v_egg, 1400),
    "car": (v_honk, 330), "tractor": (v_engine, 70), "boat": (v_foghorn, 150), "cannon": (v_cannon, 90),
    "piano": (v_piano, 262), "fridge": (v_rattle, 1200, {"metal": False}), "toolbox": (v_rattle, 700),
    "washing_machine": (v_slosh, 500), "kiddie_pool": (v_slosh, 450, {"ding": False}),
    "toaster": (v_toaster, 1), "kettle": (v_kettle, 1300), "tv": (v_tv, 880),
    "anvil": (v_clang, 520), "cannonball": (v_clang, 300), "milk_can": (v_clang, 700), "bucket": (v_clang, 900),
    "watering_can": (v_clang, 1050), "oil_drum": (v_bong, 140), "pipe": (v_bong, 220),
    "crate": (v_knock, 420), "log": (v_knock, 240), "plank": (v_knock, 560), "bowling_pin": (v_knock, 760),
    "pumpkin": (v_knock, 300, {"hollow": True}), "traffic_cone": (v_knock, 520, {"hollow": True}),
    "ball": (v_rubber, 300), "beach_ball": (v_rubber, 420), "tire": (v_rubber, 120, {"squeak": False}),
    "swim_ring": (v_rubber, 360), "trampoline": (v_rubber, 180),
    "armchair": (v_creak, 400), "mattress": (v_creak, 300), "wheelbarrow": (v_creak, 1500, {"springs": False}),
    "tire_swing": (v_creak, 700, {"springs": False}), "hay": (v_rustle, 600), "kite": (v_rustle, 1200),
    "bathtub": (v_tub, 880), "garden_gnome": (v_gnome, 200), "lawn_flamingo": (v_flamingo, 520),
    "rubber_chicken": (v_rubber_chicken, 650), "surfboard": (v_surf, 300),
}


# ---------------------------------------------------------------- music placeholders
# A lazy junk-yard loop: washboard, banjo, tuba-ish bass, kazoo tune. 16 bars at 100 BPM, 4/4
# = 38.4 s. The bright layer is the same loop (same length, same chords) with the tune up an
# octave, a glockenspiel and a busier washboard, so a crossfade at the same position is seamless.

BPM = 100.0
BEAT = 60.0 / BPM
BARS = 16
LOOP = BARS * 4 * BEAT
PROG = [(48, (0, 4, 7)), (53, (0, 4, 9)), (48, (0, 4, 7)), (43, (0, 5, 10))] * 4   # C F C G7-ish
TUNE = [(76, 1), (74, 0.5), (72, 0.5), (74, 1), (76, 1), (77, 1), (76, 1), (74, 2), (72, 1), (74, 1),
        (76, 2), (79, 1), (77, 0.5), (76, 0.5), (74, 2)]


def music(bright):
    def make(rng):
        n = int(round(LOOP * SR))
        out = [0.0] * n
        for bar, (root, ch) in enumerate(PROG):
            t0 = bar * 4 * BEAT
            for b in range(4):   # bass on 1 and 3, a fifth on 2 and 4 (tuba oom-pah, soft)
                note = root - 12 + (0 if b % 2 == 0 else 7)
                bs = osc(BEAT * 0.8, midi(note), ((1, 1.0, 1.0), (2, 0.3, 1.5), (3, 0.1, 2)), decay=0.25, attack=0.01)
                mix(out, bs, t0 + b * BEAT, 0.55, wrap=True)
                for k, s in enumerate(ch):   # banjo strum on the off-beats
                    pl = pluck(midi(root + 12 + s), 0.6, rng, 0.993, 0.6)
                    mix(out, pl, t0 + b * BEAT + BEAT * 0.5 + 0.012 * k, 0.18, wrap=True)
            for e in range(8 if not bright else 16):   # washboard scrapes
                step = 4 * BEAT / (8 if not bright else 16)
                sc = burst(rng, 0.06, 3500, 1.0, 0.015 if e % 2 == 0 else 0.008)
                mix(out, sc, t0 + e * step, 0.12 if e % 2 == 0 else 0.07, wrap=True)
        # kazoo tune over bars 4..7 and 12..15 (bright: every bar pair, an octave up)
        reps = (4, 12) if not bright else (0, 4, 8, 12)
        for start in reps:
            t = start * 4 * BEAT
            for note, beats in TUNE:
                sec = beats * BEAT * 0.92
                k = kazoo(midi(note + (12 if bright else 0) - 12), sec)
                mix(out, k, t, 0.10 if not bright else 0.09, wrap=True)
                if bright:
                    mix(out, struck(midi(note + 12), 0.12, rng, BELL, click=0.1), t, 0.07, wrap=True)
                t += beats * BEAT
        out = dc_block(out, circular=True)
        return out
    return make


# ---------------------------------------------------------------- the file table
# stem -> (make(rng), kind, trim dB, description). kind: "sfx" or "music".
FILES = {}


def add(stem, make, desc, trim=0.0, kind="sfx"):
    FILES[stem] = (make, kind, trim, desc)


for i, f in enumerate((220, 250, 196), 1):
    add("zap_size_%d" % i, zap_size(f), "size gun: pew + springy rising boing")
for i, f in enumerate((110, 123, 98), 1):
    add("zap_grab_%d" % i, zap_grab(f), "gravity gun: tractor-beam hum, rising")
for i, f in enumerate((180, 200, 160), 1):
    add("zap_bouncy_%d" % i, zap_bouncy(f), "bouncy gun: rubber-band twang (bwoing)")
for i, f in enumerate((700, 800, 620), 1):
    add("zap_balloon_%d" % i, zap_balloon(f), "balloon gun: twisty balloon squeaks")
for i, n in enumerate((96, 98, 93), 1):
    add("zap_freeze_%d" % i, zap_freeze(n), "freeze gun: ice crack, fizz, tinkle")
for i, f in enumerate((300, 340, 260), 1):
    add("zap_glue_%d" % i, squelch_sound(f), "glue gun: wet squelch + blop")
for i, f in enumerate((98, 110, 87), 1):
    add("zap_magnet_%d" % i, zap_magnet(f), "magnet gun: short electric buzz + crackles, a zip at the end")
for i, n in enumerate((72, 74, 69), 1):
    add("grow_%d" % i, grow(n), "rising boing + xylophone up")
    add("shrink_%d" % i, shrink(n), "falling boing + xylophone down")
add("grab_1", grab_hum(90), "gravity grab: hum up, little bell 'lock'")
add("grab_2", grab_hum(100), "gravity grab: hum up, little bell 'lock'")
for i, (lo, hi, s) in enumerate(((300, 2200, 0.4), (250, 2600, 0.45), (350, 2000, 0.35)), 1):
    add("throw_%d" % i, throw_whoosh(lo, hi, s), "throw: whoosh with a faint rising whistle")
add("drop_1", drop(600), "let go: falling blip + plup", -2)
add("drop_2", drop(520), "let go: falling blip + plup", -2)
for i, f in enumerate((620, 700, 540), 1):
    add("impact_light_%d" % i, impact_light(f), "light landing: wood bonk", -2)
for i, f in enumerate((170, 150, 190), 1):
    add("impact_medium_%d" % i, impact_medium(f), "medium landing: thud + knock", -1)
for i, f in enumerate((120, 105, 130), 1):
    add("impact_heavy_%d" % i, impact_heavy(f), "heavy landing: boom + junk bouncing", -2.5)
# Heavy / huge trims (A-04): a giant landing gets up to +1.5 dB in Audio.play and ducks the music,
# so the files sit lower and the biggest crash still peaks under card_done, the loudest cue.
add("impact_huge_1", impact_huge(95), "huge landing: cartoon crash, clattering cans, a boing, stars", -3.5)
add("impact_huge_2", impact_huge(85), "huge landing: cartoon crash, clattering cans, a boing, stars", -3.5)
for i, s in enumerate((0.7, 0.8, 0.65), 1):
    add("splash_%d" % i, splash(s), "pond: sploosh + bubbles + droplets")
add("card_view_1", card_view(84), "goal card: page flip + soft marimba tick")
add("card_view_2", card_view(86), "goal card: page flip + soft marimba tick")
add("card_done_1", card_done((72, 76, 79, 84)), "card done: two fireworks, bell run, crowd 'yaaay' + claps")
add("card_done_2", card_done((74, 77, 81, 86)), "card done: two fireworks, bell run, crowd 'yaaay' + claps")
add("card_skip_1", raspberry(95, 0.7), "skip: friendly raspberry (pbbbt)")
add("card_skip_2", raspberry(110, 0.6), "skip: friendly raspberry (pbbbt)")
add("reset_yard", reset_yard, "reset: big whoosh, two bells, sparkles")
add("reset_hold", reset_hold, "holding at the Reset sign: ratchet ticks rising", -2)
add("wheel_move_1", click(1500, 3200), "gun wheel: click", -4)
add("wheel_move_2", click(1300, 2800), "gun wheel: click", -4)
add("gun_cycle", click(1100, 2500), "proto gun cycle: click", -4)
for i, notes in enumerate(((96, 100, 103), (98, 101, 105), (93, 98, 100)), 1):
    add("sparkle_%d" % i, sparkle_cue(notes), "zap at nothing: glockenspiel sparkle", -3)
add("nope_1", nope(220), "can't: friendly 'uh-uh'", -2)
add("nope_2", nope(200), "can't: friendly 'uh-uh'", -2)
add("boing_1", lambda rng: boing(150, 420, 0.45, 0.2, 12), "partner bounced: spring boing")
add("boing_2", lambda rng: boing(170, 470, 0.4, 0.2, 13), "partner bounced: spring boing")
add("squelch_1", squelch_sound(280), "partner glued: squelch")
add("squelch_2", squelch_sound(320), "partner glued: squelch")
add("crack_1", zap_freeze(96), "partner thaws: ice crack")
add("crack_2", zap_freeze(91), "partner thaws: ice crack")
add("jump_1", jump_cue(380), "player jump: tiny whoop", -3)
add("jump_2", jump_cue(420), "player jump: tiny whoop", -3)
add("land_1", land_cue(150), "player lands: soft thud", -4)
add("land_2", land_cue(130), "player lands: soft thud", -4)
add("action", pop(800), "proto action: pop", -2)
add("recall", recall, "object recalled to the gate: whistle in + pop + ding")
add("snort", snort, "a partner snorts")
add("snore_1", snore(600), "a sleeping partner snores (cartoon wheeze-whistle)")
add("snore_2", snore(520), "a sleeping partner snores")
add("unglue", unglue, "unglue: stretchy goo + cork pop")
add("glue_pick", glue_pick, "first glue pick: ding + little squelch", -1)
add("glue", squelch_sound(360, 0.3), "proto glue: squelch")
add("solo_swap", solo_swap, "solo mode swaps player: puff + pop")
add("solo_on", two_notes(72, 79), "solo playtest on: two notes up")
add("solo_off", two_notes(79, 72), "solo playtest off: two notes down")
add("player_join", player_join, "a pad joins: pop + arpeggio up")
add("round_start", round_start, "round start: soft pea-whistle toot-tooot")
add("round_end", round_end, "round end: marimba ta-da")
add("pause", two_notes(81, 76, XYLO), "pause / resume: two soft xylophone notes down")
add("ui_confirm", two_notes(72, 79, MARIMBA, 0.07), "menu select: two-note marimba up")
for k in range(4):
    add("bark_%d" % (k + 1), bark("plain", k), "generic bark (no voice pack): wordless 'hey!' / 'woo!' / 'hup!' / 'ooh!'", -1)
for k in range(3):
    add("bark_cheer_%d" % (k + 1), bark("cheer", k), "generic cheer: 'yi-yaaay!' + claps", -1)
    add("bark_zap_%d" % (k + 1), bark("zap", k), "generic zap narration (Chuck): 'bzz-HA!', 'pew-pew!', 'zip!'", -1)
    add("bark_delight_%d" % (k + 1), bark("delight", k), "generic big-impact delight (Jeff): 'whoa-ho!', 'woooow!', 'hee-hee-hee'", -1)
for oid, spec in OBJECTS.items():
    fn, base = spec[0], spec[1]
    kw = spec[2] if len(spec) > 2 else {}
    kinded = fn(base, **kw)
    for kind in KIND:
        add("voice_%s_%s" % (oid, kind), kinded(kind), "%s voice: %s" % (oid, kind), -3)
add("music_yard", music(False), "placeholder yard loop: washboard, banjo, oom-pah bass, kazoo (16 bars, 100 BPM)", 0, "music")
add("music_yard_bright", music(True), "placeholder bright layer: same loop, tune up an octave, glockenspiel, busier washboard", 0, "music")


# ---------------------------------------------------------------- build

def build(stem, tmp):
    make, kind, trim, _ = FILES[stem]
    rng = random.Random("openjar-jyz:" + stem)
    x = make(rng)
    if kind == "sfx":
        x = fades(dc_block(soft(x, 9500.0)), 0.001, 0.005)
    else:
        x = soft(x, 9500.0, circular=True)
    x = peak_normalise(x, 0.5)
    wav = os.path.join(tmp, stem + ".wav")
    write_wav(wav, x)
    secs = len(x) / SR
    tile = max(10, int(math.ceil(1.5 / secs))) if kind == "sfx" and secs < SHORT_CUE else 1
    target = (MUSIC_TARGET if kind == "music" else SFX_TARGET) + trim
    lufs, peak = measure(wav, tile)
    short_by = (target - lufs) - (TP_CEILING - 0.3 - peak)
    if short_by > 0.5:
        x = peak_normalise(limit(x, 0.5 * 10.0 ** (-min(short_by, 8.0) / 20.0)), 0.5) if kind == "sfx" else x
        write_wav(wav, x)
        lufs, peak = measure(wav, tile)
    gain = min(target - lufs, TP_CEILING - 0.3 - peak)
    out_dir = os.path.join(AUDIO_DIR, "music" if kind == "music" else "sfx")
    ogg = os.path.join(out_dir, stem + ".ogg")
    for _ in range(4):
        encode(wav, ogg, gain)
        lufs, peak = measure(ogg, tile)
        if peak <= TP_CEILING:
            break
        gain -= peak - TP_CEILING + 0.1
    file_lufs = measure(ogg)[0] if tile > 1 else lufs
    return (stem, kind, duration(ogg), file_lufs, lufs if tile > 1 else None, peak, target)


def _job(a):
    return build(*a)


def preview(order, out, gap=0.35):
    """Stitch decoded cues with `gap` seconds of silence (play order) into one ogg."""
    tmp = tempfile.mkdtemp(dir=os.path.join(ROOT, ".scratch"))
    try:
        buf = []
        for stem in order:
            buf.extend(decoded_samples(os.path.join(AUDIO_DIR, "sfx", stem + ".ogg")))
            buf.extend([0.0] * int(gap * SR))
        wav = os.path.join(tmp, "preview.wav")
        write_wav(wav, buf)
        encode(wav, out, 0.0)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return len(buf) / SR


PREVIEW = ["wheel_move_1", "zap_size_1", "grow_1", "voice_cow_react", "shrink_1",
           "zap_grab_1", "grab_1", "throw_1", "voice_car_thrown", "impact_heavy_1",
           "zap_bouncy_1", "voice_ball_grabbed", "zap_balloon_1", "voice_chicken_react",
           "zap_freeze_1", "voice_duck_react", "zap_glue_1", "zap_magnet_1", "voice_fridge_react",
           "voice_piano_landed", "impact_medium_1", "splash_1", "impact_huge_1",
           "bark_delight_1", "card_view_1", "card_done_1", "card_skip_1", "reset_yard"]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("only", nargs="*")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--preview")
    ap.add_argument("--keep-wav")
    ap.add_argument("-j", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    args = ap.parse_args()
    if args.list:
        for s, (_, k, t, d) in FILES.items():
            print("%-28s %-5s %5.1f  %s" % (s, k, t, d))
        return
    if args.preview and not args.only:
        print("preview %.1f s: %s" % (preview(PREVIEW, args.preview), ", ".join(PREVIEW)))
        return
    stems = args.only or list(FILES)
    unknown = [s for s in stems if s not in FILES]
    if unknown:
        sys.exit("unknown stem(s): " + ", ".join(unknown))
    os.makedirs(os.path.join(ROOT, ".scratch"), exist_ok=True)
    tmp = args.keep_wav or tempfile.mkdtemp(prefix="jyz-cues-", dir=os.path.join(ROOT, ".scratch"))
    os.makedirs(tmp, exist_ok=True)
    for d in ("sfx", "music"):
        os.makedirs(os.path.join(AUDIO_DIR, d), exist_ok=True)
    if not args.only:   # a stale cue.ogg would shadow cue_N.ogg variants: keep the dirs exact
        for d in ("sfx", "music"):
            for f in sorted(os.listdir(os.path.join(AUDIO_DIR, d))):
                if f.endswith(".ogg") and f[:-4] not in FILES:
                    print("removing stale %s/%s" % (d, f))
                    os.remove(os.path.join(AUDIO_DIR, d, f))
    try:
        with multiprocessing.Pool(args.j) as pool:
            rows = pool.map(_job, [(s, tmp) for s in stems], chunksize=1)
    finally:
        if not args.keep_wav:
            shutil.rmtree(tmp, ignore_errors=True)
    print("%-28s %-5s %7s %7s %7s %6s" % ("file", "kind", "sec", "LUFS", "active", "TP"))
    for stem, kind, sec, lufs, act, peak, target in rows:
        print("%-28s %-5s %7.3f %7.1f %7s %6.1f" % (stem, kind, sec, lufs, "%.1f" % act if act is not None else "-", peak))
    bad = [r[0] for r in rows if r[5] > TP_CEILING]
    if bad:
        sys.exit("true peak over %.1f dBTP: %s" % (TP_CEILING, ", ".join(bad)))


if __name__ == "__main__":
    main()
