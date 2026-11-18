#!/bin/bash
cd "$(dirname "$0")/.."
uptime > .scratch/runs.log
godot --headless --path . --max-fps 60 res://.scratch/empty_limiter.tscn 2>&1 | grep EMPTY >> .scratch/runs.log
for i in 1 2; do
  godot --headless --path . --max-fps 60 -- --bench --bench-seconds=30 --bench-trace=$PWD/.scratch/trace_h$i.csv 2>&1 | grep -E "^BENCH" >> .scratch/runs.log
done
godot --headless --path . --max-fps 60 res://.scratch/empty_limiter.tscn 2>&1 | grep EMPTY >> .scratch/runs.log
uptime >> .scratch/runs.log
echo DONE >> .scratch/runs.log
