#!/usr/bin/env bash
# Fragility audit for the goal-card physics tests: reruns a suite across physics rates and put-down
# jitters, optionally pinned to one niced core (a slow CI box), and prints one line per failing test.
#   tests/goal_audit.sh [suite=tests/test_goal_deck.gd] ; env: HZ="30 60 120" JIT="0 -0.12 ..." SLOW=1
cd "$(dirname "$0")/.." || exit 1
suite="${1:-tests/test_goal_deck.gd}"
out=.scratch/audit; mkdir -p "$out"
pre=(); [ "${SLOW:-0}" = 1 ] && pre=(taskset -c 0 nice -n 19)
for hz in ${HZ:-30 60 120}; do for j in ${JIT:-0 -0.12 -0.06 0.06 0.12}; do
	log="$out/$(basename "$suite" .gd)_hz${hz}_j${j}_slow${SLOW:-0}.log"
	GOAL_HZ=$hz GOAL_JITTER=$j "${pre[@]}" godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
		-a "$suite" --ignoreHeadlessMode --continue >"$log" 2>&1
	fails=$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E "FAILED|ERROR" | grep -oE "test_[a-z0-9_]+" | sort -u | tr '\n' ' ')
	echo "hz=$hz jitter=$j slow=${SLOW:-0}: ${fails:-all pass}"
done; done
