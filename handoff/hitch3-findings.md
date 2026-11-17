# jyz-hitch-3 findings (S-18 steady 1%-low, GTX 1060 warm high)

## Method
- Probe: `.scratch/p3_node.gd` booted by `.scratch/probe.tscn` (adds itself to root, then main.tscn).
  Logs every frame: wall ms, root-viewport measured render time CPU / GPU
  (`viewport_set_measure_render_time`), and `viewport_get_render_info` for the VISIBLE and SHADOW passes:
  objects, primitives, draw calls. A census of GeometryInstance3D every 40 frames.
- Run: `godot-render --path . --resolution 480x270 --fixed-fps 30 res://.scratch/probe.tscn -- --demo --soak
  --graphics=high --probe-start=30 --probe-route=60` = the bench's route by frame count (BenchProbe times
  wall clock, and a lavapipe frame is ~0.6 s, so the real `--bench` gets one frame per third): 30 warmup
  frames, then 60 follow / 60 wide (CameraRig.overview) / 60 follow, the soak's stress on, high tier.
  Scratch XDG (`.scratch/xdg`), warm cache on both runs.
- Census of the yard's meshes: `.scratch/census.gd` (headless, triangles by owner and mesh).
- lavapipe times are only relative. The counters are exact and don't depend on the GPU.

## Baseline (dev 6392ed1), median / p90
| third | frames | objects (colour) | draw calls (colour) | primitives (colour) | objects (shadow) | draw calls (shadow) | primitives (shadow) | render CPU ms | lavapipe GPU ms |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| follow | 121 | 773 / 980 | 403 / 507 | 546k / 624k | 415 | 269 | 634k | 1.6 / 2.0 | 636 / 778 |
| wide | 60 | 2092 / 2138 | 1055 / 1094 | 1051k / 1068k | 864 | 601 | 699k | 2.8 / 3.8 | 631 / 1113 |

- The slow third is the wide one, as hitch-2 suspected, but not as GPU time: lavapipe's GPU time is the
  same in both (median 636 vs 631), although the wide shot draws 2x the triangles. Fill and the fixed passes
  (4-split shadow maps, SSAO, glow) are the same in both thirds; triangles aren't what grows the cost.
- What grows: objects 2.7x and draw calls 2.6x in the colour pass, +330 draws in the shadow pass,
  and render-thread CPU 1.75x (1.6 -> 2.8 ms here, faster CPU than the box). That's CPU-side
  submission work per instance, which a GTX 1060 box with a desktop quad-core pays on its render thread
  alongside the main thread.
- Why so many: every yard object is built from 10-50 separate ArtKit parts, each its own MeshInstance3D
  (1746 in the tree, 266 with the outline next_pass). The dressing already uses MultiMeshes (28 MMIs,
  1186 instances). Forward+ already instances runs of identical mesh + material (draw calls ~ half the
  objects), so the win from merging is in objects and in parts that differ.
- Slow single frames in the baseline run: frames 93-97 (the cut to wide), 2.0-6.0 s against a 0.67 s
  median. The fix run had none (worst 0.77 s), but it ran on a warmer cache, so I don't credit the merge
  with that.
- Not in the slow frames: particle bursts (3-7 CPUParticles3D at a time), glow, a light change.

## Fix: ObjectArt.merge_static (per object, per material)
| third | objects (colour) | draw calls (colour) | primitives (colour) | objects (shadow) | draw calls (shadow) | render CPU ms |
| --- | --- | --- | --- | --- | --- | --- |
| follow | 773 -> 452 | 403 -> 268 | 546k -> 473k (camera framing differs a little) | 415 -> 394 | 269 -> 264 | 1.6 -> 1.4 |
| wide | 2092 -> 1677 | 1055 -> 921 | 1051k -> 1052k | 864 -> 701 | 601 -> 537 | 2.8 -> 2.5 |

The wide shot's primitives are unchanged: the same triangles are drawn, with fewer instances.
Headless counts (test_hitch_3): object draws 895 -> 549, whole yard 1919 -> 1543. Tree: 1746 -> 1447
MeshInstance3D, outlined 266 -> 198.

## What's left (next candidates)
- Outlined parts with a scale (unit spheres / cylinders scaled into place) can't be baked: the outline
  grows in the mesh's own space. Baking an explicit outline shell per object (one ink draw an object)
  would remove most of the remaining outline passes. That needs a new ink material without grow, and the
  shadow pass behaviour of next_pass has to be checked against the shell. Not done here.
- Players (Jeff 22.7k, Chuck 18.6k tris, outlined): 40k tris each, but only a few draws.
