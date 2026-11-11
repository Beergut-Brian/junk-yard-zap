#!/usr/bin/env bash
# The whole session, scripted with synthetic pad events, in real frames (scripts/tools/session_flow.gd).
#   scripts/tools/session_flow.sh <out_dir> [renderer]   -> <out_dir>/NN_<step>.png + flow.txt
# renderer: godot-render (software Vulkan) when present, else godot on $DISPLAY; "headless" = no frames.
set -euo pipefail
OUT="$(realpath -m "${1:-$PWD/.scratch/flow}")"; RUN="${2:-}"
mkdir -p "$OUT"
if [[ -z "$RUN" ]]; then
  if command -v godot-render >/dev/null; then RUN=godot-render; else RUN=godot; fi
fi
if [[ "$RUN" == headless ]]; then
  godot --headless --path . res://scripts/tools/session_flow.tscn -- --flow-out="$OUT"
else
  "$RUN" --path . --resolution 1920x1080 res://scripts/tools/session_flow.tscn -- --flow-out="$OUT"
fi
