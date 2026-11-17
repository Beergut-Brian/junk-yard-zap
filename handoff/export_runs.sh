#!/usr/bin/env bash
# Export runs for jyz-hitch-3 (same as jyz-hitch-2): export, boot the export in --demo (script errors, one real frame), and a
# headless --bench from the export (CPU only). Scratch XDG (picks file + saves).
cd "$(dirname "$0")/.."
B="$PWD/build/junk-yard-zap.x86_64"
mkdir -p build
godot --headless --path . --export-release "Linux" "$B" > .scratch/export.log 2>&1; echo "export exit $?"
grep -cE "SCRIPT ERROR|^ERROR" .scratch/export.log | sed 's/^/export errors: /'
export XDG_DATA_HOME="$PWD/.scratch/xdg"   # after the export: the templates live in the real one
B="$PWD/build/junk-yard-zap.x86_64"
O="$PWD/handoff/shots"
mkdir -p "$O" build
export RUN_SECS=120
run-export "$B" -- --demo --shots=4,10 --shot-dir="$O/demo_auto" > .scratch/demo_run.log 2>&1
grep -E "^Graphics|^screenshot|^exit" .scratch/demo_run.log
grep -c "SCRIPT ERROR" .scratch/demo_run.log | sed 's/^/demo script errors: /'
run-export "$B" -- --demo --demo-beat=wide --shots=10 --shot-dir="$O/wide_auto" > .scratch/wide_run.log 2>&1
grep -E "^screenshot|^exit" .scratch/wide_run.log
grep -c "SCRIPT ERROR" .scratch/wide_run.log | sed 's/^/wide script errors: /'
echo "--- export, headless --bench 60 s (CPU only, no renderer)"
timeout 120 "$B" --headless -- --bench 2>&1 | grep -E "^bench|^BENCH|SCRIPT ERROR"
