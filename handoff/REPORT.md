# jyz-hitch-2: S-18 cold-start stalls and the steady 1%-low (GTX 1060)

Lane jyz-hitch-2 (Gary), branch `feature/jyz-hitch-2` from `origin/dev` @ `5d6a184` (after PR #53), 2026-11-17.
Not pushed. The previous report (jyz-hitch-1) is in git history (`git show 5d6a184:handoff/REPORT.md`).

**Moved IDs: none.** S-18 stays `partial`. Its note now says what changed and what to expect on the 1060.
S-29 is unchanged: the low tier is untouched, and the HD 530 BENCH line is still its open half.

## The gap
Gary's 1060 bench of v0.1.7-dev.2 (`--bench`, 60 s): on a warm cache, high tier averages 67.5-68.4 fps with a
1%-low of 31.6-31.7 and worst frames of 45-57 ms. The first run on a fresh build stalls in single frames:
2328 ms on low, 3940 ms on high. Goal: 1%-low >= 50 and worst < ~25 ms warm; no frame > ~200 ms cold.

## 1. Findings (before changing anything)
Full notes: `.scratch/hitch2-findings.md` (not committed; `.scratch/` is ignored).

Headless has no renderer, so it can't show shader or pipeline work. I used `godot-render` instead (Xvfb +
Mesa lavapipe, Forward+, CPU) at 480x270, low tier, on the bench route. A scratch per-frame probe logged
wall ms, the RenderingServer **pipeline-compilation counters by source** (canvas / mesh / surface / draw /
specialization), and the nodes added each frame. Cold = fresh `XDG_DATA_HOME` and `XDG_CACHE_HOME` under
`.scratch/` (no Godot shader cache, no Vulkan or Mesa pipeline cache), which matches the box after a fresh
seed. Warm = the same directories on a second run. lavapipe frame times aren't fps. What counts is which
frames compile and how they compare with their neighbours.

A "draw" compilation is a pipeline the renderer didn't have at draw time, built inside that frame. That's
the stutter.

| frame (bench route, dev) | cold | warm | draw / spec compiles | new that frame |
| --- | --- | --- | --- | --- |
| first yard frame | 29.2 s | 8.3 s | 15 / 20 | the yard loads (that's load) |
| second | 12.7 s | 2.0 s | 9 / 12 | the first burst particles |
| later, warm | | 0.7-11.9 s | 3, 5, 2, 1, 1, 1 | bursts, first effect looks (bouncy, freeze, grab), a ball |

- **Cold stalls:** the same frame costs 12.7 s cold and 2.0 s warm. The difference is the shader itself.
  Each material kind made only during play (burst dots, dust, rings, glue, tint overlay, puffs, the effect
  looks) compiles its shader from source in the frame it's first drawn, then compiles its pipelines. On
  the 1060 box that's the 2-4 s first-run stall.
- **Warm runs still compile in play:** 21 draw-time compiles after the first two frames of a 40 s run, in
  6 frames. On a real driver each costs a few to tens of ms. That fits the 45-57 ms worst frames.
- These frames don't come from physics, audio, GDScript allocations or a resource load. hitch-1 cleared
  the main-thread spikes (headless worst frame 15-18 ms), and the stall frames add only a few nodes.
- **The 1%-low isn't just this.** About 32 fps is the mean of the slowest ~40 of ~4000 frames. A handful of
  compile frames can't account for all of them. The rest is probably GPU time in the "yard wide" third
  (every object on screen, high tier), which this machine can't measure.

## 2. The fix (nothing seen changes, both tiers)
- **`scripts/fx/render_prewarm.gd` (RenderPrewarm).** `main.gd` runs it at boot, behind the lobby. It draws
  one of each play-made material kind in front of the camera, both as a 1 mm mesh and as a 1-particle
  CPUParticles3D (particles are a multimesh, which has its own pipelines), with shadow casting on, for 6
  frames. Then the kit frees itself. The materials stay referenced for the session (`RenderPrewarm.keep`),
  so a transient ring or puff never has to bring its shader back from nothing. In `--demo` and `--bench`
  there's no lobby, so the prewarm falls in the bench's 3 s warmup.
- The kinds come from the same factories play uses. The inline materials moved to static functions
  without change: `Fx.ring_mat`, `Effects.Glue.glow_mat`, `Refusal.strand_mat`, `PhysicsObject.overlay_mat`
  (in `_tint_art`; the sleep-when-still code isn't touched), `LooseBalloon.puff_mat`. Plus `Fx.flat_mat`,
  `Refusal.flat_mat` and the ArtKit `mat` / `glow` / `glass` kinds the effect looks use.
- No art, particle, light or shadow change. The kit is 1 mm, 0.5 m past the near plane, for 6 frames.

## 3. Measured here (lavapipe, warm cache)

| run | draw compiles in play | frames with one |
| --- | --- | --- |
| bench route, dev | 21 | 6 |
| bench route, prewarm v1 (fx, glue, refusal, overlay, puff) | 15 | 4 |
| bench route, this branch (+ the look materials) | 14 | 5 |
| lobby first, then play, kit removed before it draws | 5 | 4 |
| lobby first, then play, this branch | 3 | 3 |

The load frame takes on the moved work (draw compiles 15 -> 26 on the bench route, 21 -> 32 lobby-first).
"Lobby first" is a scratch probe that boots to the lobby, waits 12 frames, then starts the same bots. That's
how the game really starts. The lobby's own sparkles already warm most particle pipelines, so the bench's
big second frame (8-9 compiles) comes from `--bench` skipping the lobby. It falls in the warmup and isn't
counted.

**Not measured:** cold in-play numbers. A cold lavapipe frame takes 10-40 s, so a 40 s run draws only 2-4
frames. What the kit does on a cold cache is by construction: every listed kind's shader compiles from
source in the lobby's first frame, not at the first ring, glue, look or puff in play.

## 4. What to expect on the 1060
- **Cold first run:** the multi-second single frames should move into the warmup (bench) or the lobby's
  first frame (play). If a stall over 200 ms is left after the warmup, it's a kind the kit misses. The
  likely ones are a player spawn and a gun's sparks, which still compile 1-2 pipelines in play here.
- **Warm:** a few fewer compile frames, so worst frames should drop somewhat. **Not claimed: 1%-low >= 50.**
  That most likely needs GPU time in the wide shot, which this lane can't see. If the warm worst frame
  stays at 45-57 ms after this, profile the wide third on the box (F3 monitors, GPU time per frame).

## 5. Tests
`tests/test_hitch_2.gd` (4 cases):
- every material play makes (bursts, dust, gun hits, rings, glue, refusals, tint overlay, puffs, the
  effect looks' kinds) has a prewarmed kind with the same shader flags
- each kind is drawn as a mesh and as emitting particles, inside the camera's view, at 1 mm
- the kit leaves after its frames and the materials stay; a second boot replaces the set and doesn't grow it
- `main.tscn` runs the prewarm when it boots

No physics outcome is tested, so no staging was needed. test_sleep_when_still.gd passes 4 / 4, and
test_hitch.gd passes 7 / 7.

## Results
- **Import:** `godot --headless --path . --import` exit 0, 0 script errors. This worktree had no `.godot`,
  so it was a full import from nothing, then incremental re-imports after each edit.
- **Full suite** (`-a tests --continue --ignoreHeadlessMode`): **439 / 439 passed**, 0 errors, 0 failures,
  0 orphans (`handoff/test-output.txt`; 435 before + 4 new). The process's own exit status went to a task
  log this lane can't read. gdUnit exits 0 when nothing fails, and the targeted run of test_hitch_2,
  test_hitch and test_sleep_when_still exited 0. The "Cannot convert argument 1 from Object to Object" line
  in the output comes from `UiPreview.run.call_deferred` in lobby.gd. It's already in hitch-1's test output
  (5 times), not from this change.
- **Export:** `--export-release "Linux"` wrote the pack (`savepack DONE`, no script errors). The editor then
  aborts on its own exit (exit 134), which is known (PF-6, earlier reports). Commands: `handoff/export_runs.sh`.
- **Boot the export with `--demo`** (Xvfb + lavapipe, auto low tier): exit 0, **0 script errors**, in both
  the demo run and the `--demo-beat=wide` run.
- **Export, headless `--bench` 60 s** (CPU only):
  `BENCH avg=144.9 low1=83.7 frame_ms=6.90 worst_ms=22.1 frames=8695 seconds=60.0 tier=high cap=0`.
  hitch-1 got low1 82.0 / worst 17.0. This run shared the CPU with the full suite, so its worst frame
  isn't comparable. The prewarm adds no per-frame work after its 6 frames.
- **The frame I looked at:** `handoff/shots/demo_auto/t010.0s.png`, from the export at 10 s of `--demo`.
  It shows the yard, Jeff on a cloud with his gun beam, Chuck in yellow by the junk pile, both HUD rings
  (green P1, red P2) with their button hints, and the goal card top right. Nothing stray from the
  prewarm, and nothing missing. Also `demo_auto/t004.0s.png` and `wide_auto/t010.0s.png`.
- Commits: `perf: prewarm play-made materials behind the lobby` (code + the S-18 note),
  `tests: pin S-18 render prewarm (...)`, `perf: hitch-2 handoff (...)`.
