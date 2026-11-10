#!/usr/bin/env bash
# Store art from the real yard (art/preview/store.tscn), per GAME.md "Store art":
#   store/grid.png (600x900): the centre of a 1080p frame, cropped 2:3 and scaled.
#   store/hero.png (920x430): a 1080p frame cropped to 2.14:1 and scaled.
#   art/tools/render_store.sh [grid|hero] [out_dir]  renders one shot (default: both, into store/).
# Needs a renderer (godot-render or a display), an imported project, and python3 with Pillow.
set -euo pipefail
cd "$(dirname "$0")/../.."
if command -v godot-render >/dev/null; then RUN=godot-render
elif [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then RUN=godot
else echo "render_store.sh: no renderer here" >&2; exit 2; fi
[[ -d .godot ]] || godot --headless --path . --import >/dev/null 2>&1
SHOTS="${1:-grid hero}"; OUT="${2:-$PWD/store}"; mkdir -p "$OUT"
TMP="$(mktemp -d)"
for shot in $SHOTS; do
  "$RUN" --path . --resolution 1920x1080 res://art/preview/store.tscn -- --shot=$shot --out="$TMP/$shot.png" 2>&1 \
    | grep -E "SCRIPT ERROR" || true
done
python3 -I - "$TMP" "$OUT" <<'PY'
import os, sys
from PIL import Image
tmp, out = sys.argv[1], sys.argv[2]
if os.path.exists(f"{tmp}/grid.png"):
    g = Image.open(f"{tmp}/grid.png").convert("RGB")
    g.crop((600, 0, 1320, 1080)).resize((600, 900), Image.LANCZOS).save(f"{out}/grid.png")
    print(f"store: wrote {out}/grid.png 600x900")
if os.path.exists(f"{tmp}/hero.png"):
    h = Image.open(f"{tmp}/hero.png").convert("RGB")
    h.crop((0, 40, 1920, 937)).resize((920, 430), Image.LANCZOS).save(f"{out}/hero.png")
    print(f"store: wrote {out}/hero.png 920x430")
PY
rm -rf "$TMP"
