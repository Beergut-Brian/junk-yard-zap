#!/usr/bin/env python3
"""Swatch cards and palettes.md from art/direction/palettes.json (art direction options, not game content).
   python3 art/tools/palette_cards.py            -> art/direction/palette_{a,b,c}.png + palettes.md
   python3 art/tools/palette_cards.py --compare  -> art/direction/compare.png from frame_{a,b,c,flat}.png
"""
import colorsys
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "art/direction"
PAL = json.loads((DIR / "palettes.json").read_text())
FONT = str(ROOT / "assets/fonts/fredoka/Fredoka-Variable.ttf")
GUNS = ["grow", "bouncy", "freeze", "magnet", "grab", "balloon", "glue"]
GUN_LOOK = {"grow": "dish: boing ring", "bouncy": "bellows: stripes", "freeze": "snow globe: ice crust",
            "magnet": "horseshoe: sparks", "grab": "cone: player glow", "balloon": "funnel: balloon tie",
            "glue": "glue bottle: blob"}
ROWS = [
    ("Sky and water (cool)", ["sky_top", "sky_horizon", "cloud", "sun", "pond"]),
    ("Junk (rusty, warm)", ["rust", "rust_dark", "car", "crate", "metal", "enamel", "rubber"]),
    ("Yard, animals, set", ["ground", "ground_dark", "fence", "fence_dark", "cow", "cow_spot", "ink", "table"]),
]
P1, P2 = PAL["players"]["p1_green"], PAL["players"]["p2_red"]
JEFF_HOODIE, CHUCK_CAP = "#f0be2a", "#2c5fd6"  # sampled from the Jarling textures, for the pop test only


def font(size, weight="Bold"):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lum(h):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(v) for v in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def hue(h):
    return colorsys.rgb_to_hsv(*(v / 255 for v in rgb(h)))[0] * 360


def hue_gap(a, b):
    d = abs(hue(a) - hue(b)) % 360
    return min(d, 360 - d)


def text_on(h):
    return "#ffffff" if lum(h) < 0.35 else "#1d1620"


def card(key):
    p = PAL[key]
    W, H = 1920, 1080
    im = Image.new("RGB", (W, H), p["card"])
    d = ImageDraw.Draw(im)
    # Header band: the palette as a tiny yard (sky gradient, heap, fence line, ground).
    band = 300
    top, hor = rgb(p["sky_top"]), rgb(p["sky_horizon"])
    for y in range(band):
        t = min(1, y / (band * 0.85))
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (hor[i] - top[i]) * t) for i in range(3)))
    d.ellipse((1500, 40, 1640, 180), fill=p["sun"])
    for cx, cy, rw in [(250, 90, 120), (330, 70, 90), (900, 60, 100), (980, 85, 80)]:
        d.ellipse((cx - rw, cy - rw * 0.45, cx + rw, cy + rw * 0.45), fill=p["cloud"])
    for i, cx in enumerate(range(980, 1920, 95)):
        col = [p["rust"], p["metal"], p["rust_dark"], p["car"], p["crate"]][i % 5]
        hh = 70 + (i * 37) % 60
        d.rounded_rectangle((cx, band - 40 - hh, cx + 130, band), 22, fill=col)
    for i, x in enumerate(range(0, W, 46)):
        d.rounded_rectangle((x, band - 70 - (i * 13) % 18, x + 40, band), 8, fill=p["fence"] if i % 9 != 4 else p["rust"])
    d.rectangle((0, band, W, band + 26), fill=p["ground"])
    d.rectangle((0, band + 26, W, band + 34), fill=p["ground_dark"])
    title = f"{key.upper()}  {p['name']}"
    tf = font(76)
    tw = d.textlength(title, font=tf)
    d.rounded_rectangle((40, 40, 80 + tw, 150), 30, fill=p["card"])
    d.text((60, 46), title, font=tf, fill=p["ink"])
    d.text((60, 352), p["mood"], font=font(30, "Medium"), fill=p["ink"])

    y = 420
    lf, hf = font(26, "SemiBold"), font(22, "Medium")
    for label, keys in ROWS:
        d.text((60, y + 34), label, font=lf, fill=p["ink"])
        for i, k in enumerate(keys):
            x = 380 + i * 166
            d.rounded_rectangle((x, y, x + 152, y + 110), 22, fill=p[k], outline=p["ink"], width=3)
            d.text((x + 12, y + 8), k.replace("_", " "), font=hf, fill=text_on(p[k]))
            d.text((x + 12, y + 76), p[k], font=hf, fill=text_on(p[k]))
        y += 135
    # Guns: big chips, each with the minimum hue distance from P1/P2 (all must be far from both).
    d.text((60, y + 50), "Gun effects", font=lf, fill=p["ink"])
    d.text((60, y + 82), "never green/red", font=hf, fill=p["ink"])
    for i, g in enumerate(GUNS):
        x = 380 + i * 166
        col = p["guns"][g]
        d.rounded_rectangle((x, y, x + 152, y + 150), 26, fill=col, outline=p["ink"], width=3)
        d.text((x + 12, y + 8), g, font=font(30), fill=text_on(col))
        d.text((x + 12, y + 46), col, font=hf, fill=text_on(col))
        gap = min(hue_gap(col, P1), hue_gap(col, P2))
        d.text((x + 12, y + 116), f"{gap:.0f}° off P1/P2", font=font(17, "Medium"), fill=text_on(col))
    # Pop test: P1 green / P2 red rings and Jeff's hoodie / Chuck's cap on every zone colour.
    x0 = 1740 - 0
    d.text((1735, 420), "Players pop", font=font(24, "SemiBold"), fill=p["ink"])
    for i, k in enumerate(["sky_top", "sky_horizon", "ground", "rust", "fence", "pond"]):
        yy = 460 + i * 98
        d.rounded_rectangle((x0, yy, x0 + 150, yy + 86), 16, fill=p[k], outline=p["ink"], width=2)
        for j, col in enumerate([P1, JEFF_HOODIE, P2, CHUCK_CAP]):
            cx = x0 + 22 + j * 35
            d.ellipse((cx - 13, yy + 30, cx + 13, yy + 56), fill=col, outline=p["ink"], width=2)
    out = DIR / f"palette_{key}.png"
    im.save(out)
    print("card:", out)


def md():
    lines = ["# Junk Yard Zap: palette options", "",
             "Generated from `palettes.json` by `art/tools/palette_cards.py`. Swatch cards: `palette_{a,b,c}.png`.",
             f"Fixed in every option: P1 green `{P1}`, P2 red `{P2}`. Gun hues keep the same order in every option "
             "(grow orange, bouncy yellow, freeze ice, magnet blue, grab violet, balloon magenta, glue bubblegum), so a gun "
             "keeps its colour whichever palette wins; only the tone shifts.", ""]
    for key in "abc":
        p = PAL[key]
        lines += [f"## {key.upper()}. {p['name']}", "", p["mood"], "", "| Role | Hex | Role | Hex |", "| --- | --- | --- | --- |"]
        keys = [k for _, ks in ROWS for k in ks]
        for i in range(0, len(keys), 2):
            a = keys[i]
            b = keys[i + 1] if i + 1 < len(keys) else None
            lines.append(f"| {a} | `{p[a]}` | {b or ''} | {'`' + p[b] + '`' if b else ''} |")
        lines += ["", "| Gun | Effect colour | Signature | Hue gap to P1 / P2 |", "| --- | --- | --- | --- |"]
        for g in GUNS:
            col = p["guns"][g]
            lines.append(f"| {g} | `{col}` | {GUN_LOOK[g]} | {hue_gap(col, P1):.0f}° / {hue_gap(col, P2):.0f}° |")
        lines += ["", f"Lighting: key `{p['key']}` at {p['key_energy']}, pitch {p['key_pitch']}°; ambient `{p['ambient']}`; "
                  f"glow {p['glow']}, effect emission {p['emit']}.", ""]
    lines += ["Note for Gameplay/Art: the plan's magnet is a red-and-silver horseshoe. Red belongs to Chuck, so the "
              "magnet here is a blue-and-silver horseshoe with blue sparks.", ""]
    (DIR / "palettes.md").write_text("\n".join(lines))
    print("md:", DIR / "palettes.md")


def compare():
    W, H = 1920, 1080
    im = Image.new("RGB", (W, H), "#17131c")
    d = ImageDraw.Draw(im)
    tiles = [("frame_a.png", "A  " + PAL["a"]["name"]), ("frame_b.png", "B  " + PAL["b"]["name"]),
             ("frame_c.png", "C  " + PAL["c"]["name"]), ("frame_flat.png", "A, flat-shaded + outlines (plan's style)")]
    for i, (f, label) in enumerate(tiles):
        t = Image.open(DIR / f).convert("RGB").resize((W // 2 - 12, H // 2 - 12), Image.LANCZOS)
        x, y = (i % 2) * (W // 2) + 6, (i // 2) * (H // 2) + 6
        im.paste(t, (x, y))
        lf = font(34)
        tw = d.textlength(label, font=lf)
        d.rounded_rectangle((x + 14, y + 12, x + 40 + tw, y + 62), 20, fill="#17131ccc")
        d.text((x + 27, y + 15), label, font=lf, fill="#ffffff")
    im.save(DIR / "compare.png")
    print("compare:", DIR / "compare.png")


if __name__ == "__main__":
    if "--compare" in sys.argv:
        compare()
    else:
        for k in "abc":
            card(k)
        md()
