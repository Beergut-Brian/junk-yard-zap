# jyz-hitch-5: S-18 steady 1%-low, render side (Gary lane, 2026-11-17)

Branch `feature/jyz-hitch-5` off `origin/dev` @ `500bcaa` (after PR #56). Not pushed.
Starting point (Gary, the box, v0.1.7-dev.5, `--bench --graphics=high`, warm): avg 71.7-75.4, 1%-low 42.9-45.9,
worst 35-41 ms. Headless CPU isn't it (busy p99 4-6 ms); hitch-3 already ruled out draw calls and batching.

## Findings (full table: `handoff/hitch5-findings.md`; probe, micro scene, analysis script and CSVs: `handoff/hitch5-probe/`, run from `.scratch/`)
I probed the renderer per frame on the bench route: lavapipe through `godot-render`, high tier, warm cache, the
bench's follow / wide / follow route by frame count, the soak's stress on. Each frame logged render-thread CPU and
frame setup, objects / draw calls / primitives in the colour and shadow passes, all five pipeline-compilation
counters, buffer and texture uploads, instances added / removed (by name), material / mesh / visibility changes,
emitting particles and lights.

- Steady state is smooth on the render side. Render CPU median is 1.4 ms (follow) and 2.3 ms (wide), p90 is
  1.9 / 2.6-3.0 ms. Object and draw counts match hitch-3's merged numbers (wide 1683 objects, 914 draws, +702 / 536
  in the shadow pass). Uploads, per-frame material writes (the Reset sign's 19 bulbs), particles (2-3 emitting,
  13 at most) and lights (1 lamp, no positional shadows) don't line up with slow frames.
- **One frame in 180 takes 23.6-25.5 ms of render CPU, the same frame on all three runs.** It's where an object's
  grab look first shows (a gun swap, a freeze look and a glue recoil are around it too), and it has a surface + a
  specialization pipeline compile in it. In-play compiles over the route: surface 4, specialization 9, draw 0.
- Micro scene (`.scratch/micro5.gd`: the yard's light and environment plus RenderPrewarm, then 5 reps of each event):
  the first grab look costs **23.8 ms** of render CPU, the first freeze look 614 ms, the first gun 582 ms (cold
  shaders in a bare scene). Reps 2-5 cost 0.2 ms each. Freeing 17 instances, 3 bursts or nothing cost 0.17-0.24 ms.
- **Cause.** A Godot pipeline is per material kind and per vertex format. hitch-2's RenderPrewarm drew every
  play-made kind on a SphereMesh: positions, normals, tangents, UVs. ArtKit's rounded boxes (the bouncy bands, ice,
  the grab shell, magnet parts, the guns' grips) and hitch-3's merged object art (where the effect-tint overlay is
  drawn) carry positions and normals only. So the first look on a rounded box, or the first tint over merged art,
  compiled a pipeline in the frame it showed.
- **Also seen.** project.godot asks for vsync (`vsync_mode=1`), yet the box averages 72 fps. So either the TV runs
  above 60 Hz or the present mode isn't plain FIFO (gamescope on Bazzite). With FIFO at 120 Hz, a frame rounds up to
  8.3 ms steps: a 17 ms frame shows as 25 ms, and 33 / 42 ms fit the 35-41 ms worst frames. I can't check this from
  here.

## What changed
1. `perf: prewarm play materials on the rounded-box vertex format too` (cedf88b).
   `scripts/fx/render_prewarm.gd` also draws every kind, and the overlay, on a 1 mm rounded box built from
   `ArtKit.rbox_arrays`. That's the positions + normals format, shared by every rbox and every merged mesh. It uses
   the same kept materials and the same 6 frames behind the lobby / the bench warmup. Nothing seen changes, in both
   tiers. Not touched: the mesh merge, the transform guard, sleep-when-still, the art, particles, lights, shadows,
   render scale.
2. `perf: print the present mode and refresh rate in the BENCH line` (56dfb2b). Diagnostic only. The BENCH line
   now ends `... cap=0 vsync=on hz=60 adapter="..."` (`BenchProbe.display()`).

### Before / after on the bench route (lavapipe, same probe)
| | before (2-3 runs) | after |
| --- | --- | --- |
| in-play pipeline compiles: surface / specialization / draw | 4 / 9 / 0 | **0 / 3 / 0** |
| wide render CPU median / p90 / max ms | 2.31-2.38 / 2.58-3.02 / **23.6-25.5** | 2.37 / 2.91 / **4.72** |
| follow render CPU median / p90 / max ms | 1.42 / 1.95 / 2.34 | 1.55 / 2.04 / 11.4 (*) |
| micro: first grab look / freeze look / gun, ms | 23.8 / 614 / 582 | 0.22 / 0.22 / 0.29 |
| micro: pipeline compiles after boot | +6 over those 3 events | 0 |

(*) One follow frame at 11.4 ms. It had no compile, no added instance and no upload, and the same frame wasn't
slow on either baseline run. The after run overlapped the gdUnit suite and the micro scene on this 6-core CPU, and
its medians are up too, so I read it as contention. Not claimed as a regression or as fixed. The 3 specialization
compiles left run in the background (ubershader) and didn't make a slow frame.

## Tests
- `tests/test_hitch_5.gd` (new, 4 tests): every material each look kind builds (bouncy, balloon, freeze, magnet,
  splat, grab) is prewarmed on its own vertex format; rbox and merged art share the flat format, which differs from
  the sphere's; the tint overlay is prewarmed on both formats; the BENCH line has `vsync=` / `hz=`.
  **On the old prewarm: 16 failures** (`bouncy: ... on format 7 not prewarmed (kit formats [23])`).
- `tests/test_hitch_2.gd`: kit count updated (2 x kinds + 2 overlays).
- Full suite `--continue` on the final tree (56dfb2b): **452 test cases, 49 suites, 0 errors, 0 failures, 0 orphans**,
  0 script errors (`handoff/test-output.txt`, 11 min 17 s). test_sleep_when_still passes, as do test_hitch / _2 / _3 / _4 / _5.
- Clean import (no `.godot`): exit 0. The only lines are the usual "resources still in use at exit" and
  "ObjectDB leaked at exit".
- Export (`handoff/export_runs.sh`): the pack is written. Godot's own exit is 134 after savepack (known, PF-6, same as
  hitch-3 and -4). Booting the export with `--demo`: **0 script errors** at the auto tier (low on this software GPU),
  0 at `--graphics=high`, 0 in the wide beat. Headless `--bench --graphics=high` from the export:
  `BENCH avg=144.7 low1=72.7 worst_ms=33.4 ... vsync=on hz=-1` (`handoff/bench-export.txt`). That's CPU only, and it
  ran while the suite was running: the 33 ms worst is in the 5 s window where the suite was busiest, so it isn't a
  1060 number.

## The frame I looked at
`handoff/shots/hitch5_demo_high/t010.0s.png`: the export, `--demo --graphics=high`, 10 s in. The yard, both players
and the HUD are normal. The bouncy ball's yellow bands (a look on a rounded box, the format the fix now warms) render
as before, and nothing from the prewarm is left on screen. Also in `handoff/shots/`: `hitch5_demo_auto/` (4 s, 10 s)
and `hitch5_wide_auto/` (the yard-wide beat).

## Expected on the 1060
- The first grab / freeze / bouncy / magnet look in a run, and the first tint over merged art, no longer compile a
  pipeline in play. On lavapipe that frame cost 24 ms of render CPU. On the box with a warm NVIDIA pipeline cache
  each compile should be cheaper, so I expect the **worst frame to drop from 35-41 ms toward the 20s**. How far is
  the box's to say.
- The 1%-low (43 frames out of ~4300) is more than a handful of first-use frames. **I don't claim 1%-low >= 50.**
  The steady render side is smooth here, so if the box's 1%-low stays in the mid-40s, the next suspect is the
  present mode. Paste the whole BENCH line: if it says `vsync=on` at `hz=120` (or 144), frames are being rounded to
  refreshes, and the honest fix is a cap or a present-mode choice, which is a producer call, not a hitch.
- Cold run: the prewarm adds 16 more 1 mm meshes to its 6 frames behind the lobby, so the cold-run single-frame result
  (< ~200 ms) should hold. Not measured on the box.

## Next candidates (not done)
- If the box shows `vsync=on hz>60`: test `--max-fps` / mailbox on the box (a producer call: no look change).
- FenceCard's 512x512 SubViewport is UPDATE_ALWAYS for a card that only changes on a stamp or flip;
  UPDATE_WHEN_VISIBLE / ONCE would save a pass a frame. It's small and steady, not a hitch.
- The Reset sign re-sets 19 bulbs' material_override every frame (same value 2/3 of the time). Small and steady.

## IDs moved
None. S-18 stays **partial** (note updated with the change and expected effect; the 1060 bench is the open half).
