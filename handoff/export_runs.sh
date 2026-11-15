#!/usr/bin/env bash
# Export runs for jyz-igpu-1: screens high vs low, the auto pick, a short bench. Scratch XDG (picks file + saves).
cd "$(dirname "$0")/.."
export XDG_DATA_HOME="$PWD/.scratch/xdg"
B="$PWD/build/junk-yard-zap.x86_64"
O="$PWD/handoff/shots"
mkdir -p "$O"
export RUN_SECS=180
for t in high low; do
  run-export "$B" -- --demo --graphics=$t --shots=10 --shot-dir="$O/demo_$t" 2>&1 | grep -E "^Graphics|^screenshot|SCRIPT ERROR|^exit"
  run-export "$B" -- --demo --demo-beat=wide --graphics=$t --shots=10 --shot-dir="$O/wide_$t" 2>&1 | grep -E "^Graphics|^screenshot|SCRIPT ERROR|^exit"
  run-export "$B" -- --graphics=$t --shots=6 --shot-dir="$O/lobby_$t" 2>&1 | grep -E "^Graphics|^screenshot|SCRIPT ERROR|^exit"
done
echo "--- auto pick + bench (export, no flag)"
run-export "$B" -- --bench --bench-seconds=15 2>&1 | grep -E "^Graphics|^bench|^BENCH|SCRIPT ERROR|ERROR|^exit"
