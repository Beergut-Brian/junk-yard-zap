# jyz-hitch-5 findings (S-18 steady 1%-low, GTX 1060 warm high, render side)

## Method
- Probe `.scratch/p5_node.gd` (booted by `.scratch/probe5.tscn`, which adds main.tscn next to itself). One CSV row
  per frame: wall ms, `RenderingServer.get_frame_setup_time_cpu()`, root viewport measured render time CPU / GPU,
  `viewport_get_render_info` (VISIBLE and SHADOW passes: objects, draw calls, primitives), the five
  `RENDERING_INFO_PIPELINE_COMPILATIONS_*` counters as per-frame deltas, texture / buffer memory deltas (uploads
  and new buffers), VisualInstance3D added / removed (tree signals, with names), GeometryInstance3D material-override,
  mesh and visibility changes (a tree walk each frame), emitting particles and their amount, positional lights
  (with shadows), physics steps.
- Run: `godot-render --path . --resolution 480x270 --fixed-fps 30 res://.scratch/probe5.tscn -- --demo --soak
  --graphics=high --probe-start=30 --probe-leg=60` = the bench's route by frame count (30 warm, 60 follow, 60 wide,
  60 follow; the soak's stress on; the bots are seeded, so runs repeat). Scratch XDG, warm shader cache.
- Measured render time is reported with a frame or two of lag, so an event is matched to the max over the next 4
  frames in the micro scene (`.scratch/micro5.gd`: sun + environment from YardLight, a camera, RenderPrewarm at
  boot, then 5 reps each of: a gun swap, freeing 17 instances, a new-size freeze look, a new-size grab look,
  3 bursts, nothing).
- lavapipe numbers are relative only. The counters are exact.

## Baseline (dev 500bcaa), bench route, two runs (same result)
| | follow median / p90 / max | wide median / p90 / max |
| --- | --- | --- |
| render CPU ms | 1.42 / 1.95 / 2.34 | 2.31-2.38 / 2.58-3.02 / **23.6-24.1** |
| frame setup ms | 0.40 / 0.49 / 1.0 | 0.36 / 0.49 / 0.60 |
| objects (colour) | 563 / 827 / 1692 | 1683 / 1700 / 1703 |
| draw calls (colour) | 338 / 475 / 943 | 914 / 943 / 948 |
| objects / draws (shadow) | 356 / 252 | 702 / 536 |
| pipeline compiles in play (180 frames) | surface 4, specialization 9, draw 0 | |
| instances added / removed a frame | 0 / 0 (p90 3-9 / 2, max 34 / 36) | |
| material-override changes a frame | 0 (p90 19: the Reset sign's chasing bulbs) | |
| visibility changes | 0 (two frames of 172) | |
| emitting particles | 2-3 (max 13, 131 particles) | |
| positional lights | 1 (the Reset sign lamp), 0 with shadows | |

- Only one frame in 180 is slow on the render side, the same frame on both runs: 23.6 / 24.1 / 25.5 ms render CPU
  (median 2.3). Nothing else on the route goes above 3.8 ms. GPU-side counts (objects, draws, primitives, shadow
  pass) are smooth. Uploads happen (up to 650 KB of new buffers a frame) but don't line up with slow frames.
  Per-frame material writes (19 bulbs) and particle counts don't either.
- In the frames around it: an object's **grab look** is built (an rbox shell + a torus), a gun swap, a freeze look,
  the glue recoil, bursts. There's also 1 surface + 1 specialization pipeline compile.

## Micro scene: render CPU of the frame each thing first shows (max over the next 4 frames)
| event | before: 1st / reps 2-5 | after the fix: 1st / reps 2-5 |
| --- | --- | --- |
| grab look, new size | **23.8** / 0.19-0.23 | 0.22 / 0.20-0.42 |
| freeze look, new size | **614** / 0.20-0.23 | 0.22 / 0.22-0.26 |
| gun swap (packed gun) | **582** / 0.21-0.26 | 0.29 / 0.23-0.40 |
| free 17 instances | 0.23 | 0.33 |
| 3 bursts | 0.24 | 0.26 |
| nothing | 0.17 | 0.21 |
| pipeline compiles after boot | 61 -> 67 over those events | 94 -> 94 (none) |

(The 582 / 614 ms are cold shaders in a bare scene. In the yard those shaders already exist, so only the pipeline
is left: the 24 ms.)

## Cause
A Godot pipeline is per material kind AND per vertex format. RenderPrewarm (hitch-2) drew each play-made kind on a
SphereMesh: positions, normals, tangents, UVs (format 23). The effect looks' rounded boxes (ArtKit.rbox: bouncy
bands, ice, the grab shell, magnet parts), the guns' grips and ObjectArt.merge_static's baked art (where the tint
overlay is drawn) have positions and normals only (format 7). So the first look on a rounded box, or the first
tint over merged art, compiled a pipeline in the frame it showed.

## Fix
RenderPrewarm also draws every kind, and the overlay, on a 1 mm rounded box built from ArtKit.rbox_arrays (format 7),
in the same 6 frames behind the lobby. Same materials kept. No look change.

## After the fix (bench route, same probe)
| | before | after |
| --- | --- | --- |
| in-play pipeline compiles (surface / specialization / draw) | 4 / 9 / 0 | 0 / 3 / 0 |
| wide render CPU median / p90 / max ms | 2.31 / 2.58 / 23.6-25.5 | 2.37 / 2.91 / 4.72 |
| follow render CPU median / p90 / max ms | 1.42 / 1.95 / 2.34 | 1.55 / 2.04 / 11.4 (*) |

(*) One follow frame (f 66) at 11.4 ms: no compile, no instance added, no upload in it, and it wasn't slow on
either baseline run. That run overlapped the gdUnit suite and the micro scene on this CPU (the medians are higher
too), so it looks like contention.
The 3 specialization compiles left are background (ubershader) ones and didn't make a slow frame.

## Also seen, not changed
- project.godot has `window/vsync/vsync_mode=1` (on) for high, yet the 1060 averages 72 fps. So either the TV runs
  above 60 Hz or the present mode isn't plain FIFO (gamescope on Bazzite). With FIFO at 120 Hz, frame times round
  up to 8.3 ms steps: a 17 ms frame shows as 25 ms, and 33 / 42 ms match the 35-41 ms worst frames. The BENCH line
  now prints `vsync=… hz=…` so the next box run says which.
- FenceCard keeps a 512x512 SubViewport on UPDATE_ALWAYS (a 2D card redrawn every frame), and the Reset sign
  re-sets 19 bulbs' material_override every frame. Both are steady and small. They don't line up with slow frames.
