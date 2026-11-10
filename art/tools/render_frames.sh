#!/usr/bin/env bash
# Art-direction options: render the sample frames, swatch cards, palettes.md and the comparison sheet.
#   art/tools/render_frames.sh            all of it (about 3 minutes on the producer box's software GPU)
#   art/tools/render_frames.sh b c        just those frames, then the sheets
# Frames come from art/preview/diorama.tscn in the real renderer (godot-render, or a real display), using
# art/direction/palettes.json. Outputs go to art/direction/. Needs an imported project (godot --headless --import).
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="$PWD/art/direction"
if command -v godot-render >/dev/null; then RUN=godot-render
elif [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then RUN=godot
else echo "render_frames.sh: no renderer here" >&2; exit 2; fi
[[ -d .godot ]] || godot --headless --path . --import >/dev/null 2>&1
KEYS=("$@"); [[ ${#KEYS[@]} -gt 0 ]] || KEYS=(a b c flat)
for k in "${KEYS[@]}"; do
  args=(--palette="$k"); [[ $k == flat ]] && args=(--palette=a --style=flat)
  "$RUN" --path . --resolution 1920x1080 res://art/preview/diorama.tscn -- "${args[@]}" --out="$OUT/frame_$k.png" 2>&1 \
    | grep -E "^frame:|SCRIPT ERROR|^ERROR" | grep -v fontconfig || true
done
python3 art/tools/palette_cards.py
python3 art/tools/palette_cards.py --compare
