# jyz-hitch-4 findings (S-18 steady 1%-low, GTX 1060 warm high)

## Method
- Probe `.scratch/p4_node.gd` (booted by `.scratch/probe.tscn`, which then loads main.tscn) on the real
  `--bench --graphics=high` route, headless, real wall clock. Two stamp nodes (process priority -100000 /
  +100000, same for physics) split each frame into: `sp` = all `_process` callbacks, `ph` = all
  `_physics_process` callbacks, `st` = from the last physics callback to the next stamp (Jolt step + the next
  sync / flush_queries: `_integrate_forces`, contact signals). Plus steps per frame, nodes, emitting particles.
  `busy = sp + ph + st`. Headless frames carry Godot's forced idle sleep when no window can draw (the median
  frame is exactly 6.9 ms), so the wall-clock frame time headless is not CPU time; `busy` is.
- Attribution: a temporary script (`.scratch/instrument.py`, reverted after) wrapped every `_process`,
  `_physics_process` and `_integrate_forces` in the game with a timer, then zapper's sub-calls, then `_press`'s.
- Re-sent render instances: watcher nodes (`NOTIFICATION_TRANSFORM_CHANGED`) under every object's art root
  (weighted by its VisualInstance3D count, face excluded) and under every face part. Count per frame.
- Renderer cost per re-sent instance: `.scratch/xbench.gd` under godot-render (lavapipe, 64x36), 56 parents x
  23 boxes, a shadowed sun, three alternating 200-frame phases of "none" / "write the same scale every frame";
  CPU time per thread from `/proc/self/task/*/stat` (llvmpipe raster threads reported apart).
- This machine (i5-8500T, 6 cores) had another lane's gdUnit suite running during most runs, so late-run frames
  are inflated across the board; A/B runs were back to back.

## What the CPU does on the bench route (headless, dev cc09753, 40-60 s)
| | median | p90 | p99 | max |
| --- | --- | --- | --- | --- |
| busy (sp+ph+st) ms | 1.33 | 3.74 | 5.93 | 12.4 |
| sp (all _process) ms | 1.15 | 1.35 | 1.89 | 4.7 |
| ph (all _physics_process, step frames) ms | 1.42 | | 3.77 | 8-9.8 |
| st (Jolt step + flush, step frames) ms | 0.53 | | 1.24-1.49 | 3.4-6.0 |

- Every slow-1% frame has a physics step in it (86 of 86 in run 1). No frame has 2 steps headless (144 fps).
- Script time per frame by owner (60 s totals): ObjectFace._process 6.2-6.5 s (0.7 ms a frame, 46 faces, max
  2.6-4.0 ms), PhysicsObject._physics_process 2.1-2.2 s (52 bodies, max 2.7-2.9 ms a step), Zapper 1.5 s
  (_update_target 0.8 s steady, max 2.4 ms; _press: rare, max 4.3-6.5 ms, spread over size step 2.2,
  own_zap bark 1.8, zapped listeners 1.8, Audio 1.4 ms: no single culprit), _integrate_forces 0.8-0.9 s,
  EffectLook 0.6-0.7 s, contraptions 0.2-0.5 s each. Nothing near 25 ms; the worst single script call is ~6 ms.
- No shader compile in play headless; particles 0-17 emitting; nodes 2500 -> 3200 over the run (the stress's
  effects; soak shows it flat from min 20).

## The waste: same-value transform writes
Godot 4.7 does not skip a same-value `position` / `scale` / `rotation` write (`.scratch/xf_test.gd`: 10 writes
of `Vector3.ONE` -> 10 child notifications). Each one sends NOTIFICATION_TRANSFORM_CHANGED down the subtree and
every VisualInstance3D in it re-sends its transform to the renderer (bounds, cull tree, light pairing).
- PhysicsObject._physics_process wrote `_visual.scale` every step, asleep or not: 1299 of the yard's 1719
  visual instances live under objects' art.
- ObjectFace._pose wrote 13 parts every frame: 46 faces, 736 instances.
- Bench route, re-sent instances per frame: no-step frames 694, step frames 1152 (mean 884, of 1719).
- Renderer cost (xbench, this CPU): 1288 re-sent instances a frame = main thread 0.82 -> 1.32 ms a frame,
  other godot threads +0.44 ms a frame: ~0.7 us an instance.

## Fix and A/B (headless, 40 s each, back to back)
| | base | fix |
| --- | --- | --- |
| re-sent / frame, mean | 884 | 322 |
| re-sent, no-step frames (median) | 694 | 37 |
| re-sent, step frames (median) | 1153 | 756 (bodies really moving under the stress: 30-38 awake) |
| busy p90 / p99 / max ms | 3.74 / 5.93 / 12.4 | 3.14 / 4.25 / 10.4 |
| ph mean / p99 ms | 0.65 / 2.76 | 0.54 / 2.09 |
| st mean / p99 ms | 0.34 / 1.49 | 0.17 / 0.69 |
| quiet yard, 51 sleeping objects, 30 steps (test) | 31518 updates | 0 |
| BENCH low1 (headless, wall clock incl. idle sleep) | 68.8 | 81.0 |

## What it doesn't explain
Headless busy p99 is 4-6 ms on this CPU; the 1060 box's 1%-low frames are ~24 ms. Even at 2x slower CPU the
script + physics side is ~10 ms at p99, so most of the 24 ms is render-side (in Godot's default thread model,
on the main thread) or GPU, which headless can't see. hitch-3's renderer probe: viewport render CPU median
1.4 / 2.5 ms (follow / wide), p99 2.4 / 3.6 ms, with rare 24-65 ms single frames.
