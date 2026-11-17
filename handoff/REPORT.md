# jyz-hitch-1: S-18 frame spikes (60 fps on a GTX 1060)

Lane jyz-hitch-1 (Gary), branch `feature/jyz-hitch-1` from `origin/dev` @ `82a9a59` (after PR #52), 2026-11-17.
Not pushed. The previous lane's report (jyz-igpu-1) is in git history (`git show 82a9a59:handoff/REPORT.md`).

**Moved IDs: none.** S-18 stays `partial`; its note now says what changed and what to expect on the 1060.
The 1060 BENCH line after the ship decides it.

## The gap
GTX 1060 bench 2026-11-17 (high, 60 s `--bench`): avg 68.5 fps, **1%-low 33.5, worst frame 43-45 ms**.
Low tier: avg 57.6, 1%-low 27.7. Goal: no spikes past ~25 ms, 1%-low >= 50.

## 1. Finding the hitches (before changing anything)
Full notes: `.scratch/hitch-findings.md` (not committed; `.scratch/` is ignored). Method: the bench route
(`--bench`, seeded bots, the soak's stress) headless on this machine, plus a scratch probe scene that boots
main.tscn and logs every frame: wall ms, process-script ms, physics wall ms, physics-script ms, and every
node created that frame. A second pass used temporary timers (reverted) around the physics scripts, Fx,
GunHits, EffectLook, ArtKit.rbox, Audio and Effects.zap.

Headless only shows main-thread CPU (no renderer). Before: 40 s, mean 6.92 ms, slowest 1% 15.4 ms,
worst 23-33 ms, 29 frames > 15 ms. The render / idle part stayed flat in the slow frames, and so did
the Jolt step (~1 ms). **The spikes were GDScript running inside a physics tick at the moment of a zap or a
landing.** In the slow frames the physics-script time was 7-21 ms, against a 0.76 ms mean:

| Cause | Cost here | Fixed |
| --- | --- | --- |
| Every `Audio.play()` started an Ogg Vorbis file, and `AudioStreamPlayer.play()` builds a new Vorbis decoder on the main thread | 0.7 ms idle, 1.5 ms mean (3.1 max) in a running game; a busy frame plays 3-4 cues = 4-8 ms | yes |
| The first effect look (bouncy / freeze / magnet / grab) on an object built its rounded boxes (`ArtKit.rbox`, SurfaceTool in GDScript) in the frame | 1-2.5 ms per box, up to 6 per look; one look took 8.4 ms | yes |
| Every `Fx.burst` / GunHits burst made a new sphere or box mesh plus a material, and every ring a new 64x32 torus | 0.1-0.7 ms CPU here; on the 1060 each one is also a new mesh upload and material | yes |
| A voice-pack bark loads its line from disk (`load()`) | 0.8-3.3 ms, at most one per zap (bark gate) | no (see Left) |
| Grow steps (`_scale_step` shape queries + `_rebuild_shape`), now and then | 4-7 ms | no |

One zap frame shows how they stacked: `zapper.phys = 18.6 ms` = Effects.zap 5.5 (rounded boxes 4.9) +
three Audio.play 8.1 + a bark 3.3 + GunHits 0.7.

## 2. The fix (smallest that proves it; nothing seen or heard changes, both tiers)
- **Audio.gd: SFX play from PCM.** At boot the main thread loads every `assets/audio/sfx/*.ogg` (307 files).
  Loading inside the worker deadlocked the engine's shutdown on an early close, so the load stays on the
  main thread. A WorkerThreadPool task then decodes each file once into a 16-bit AudioStreamWAV at the
  mixer's rate (`decode_pcm`), in 1.6 s. `_start()` plays `pcm(stream)`: the decoded copy once it exists,
  else the Ogg as before. Cost of one play: **1548 us -> 21 us**. It's the same sound: the samples
  match the Ogg decoder's output to 16-bit rounding (test), at the same length, pitch and volume.
  Music, voice packs and synth beeps are untouched. Memory: about 20 MB of PCM. `_exit_tree` stops and
  waits for the worker.
- **ArtKit / EffectLook: rounded boxes prewarmed off the main thread.** `ArtKit.rbox` is split into the
  pure `rbox_arrays()` and the cache. `prewarm_rboxes()` builds the arrays on a worker, and `rbox()` takes
  them from there, so only the ArrayMesh is made on the main thread (microseconds). `EffectLook.rbox_specs()`
  is now the single source of every box `_build()` makes, so the prewarm and the build can't drift
  apart. `YardLevel.spawn_layout()` calls `EffectLook.prewarm()` for every object it spawns (Reset Yard too;
  boxes already built are skipped). `_exit_tree` claims the task.
- **Fx / GunHits: bursts and rings share meshes.** A burst's dot mesh plus its flat material is cached by
  (radius, colour). GunHits caches its sphere and box templates by size, plus one coloured copy per colour.
  The cache is bounded at 256, because fireworks pick random hues. Both rings use one shared torus each.
  Each ring keeps its own material, because it fades its own alpha. Same shapes and colours, just reused.
- The sleep-when-still logic is untouched (test_sleep_when_still.gd: 4 / 4 pass).

## 3. Tests
`tests/test_hitch.gd` (7 cases):
- every SFX file is decoded at boot
- `Audio.play` starts the PCM copy, which has the Ogg's length at the mixer rate
- the decoded samples match the Ogg decoder's output to 16-bit rounding
- looping streams, null streams and synth beeps are left alone
- once the yard has spawned, building every look on every object builds **0** rounded boxes in the frame
- a prewarmed box has the same vertices as one built on the spot, and is cached from then on
- the second burst or gun hit of a kind builds no mesh, a new colour gets its own mesh, and rings share
  the torus but not the material

No physics outcome is tested here, so no staging was needed.

Full suite, `--continue`: see "Results" below and `handoff/test-output.txt`.

## 4. Measured here (headless, CPU only) and what to expect on the 1060
Same route, 40 s `--bench --bench-seconds=40`. Three runs before and three after (frame times from the
probe, BENCH line from bench.gd, format unchanged):

| | worst frame | slowest 1% | frames > 15 ms | frames > 12 ms | BENCH low1 |
| --- | --- | --- | --- | --- | --- |
| before | 23.0-33.2 ms | 15.4 ms | 29 | 106 | 61.3-67.8 |
| after | 14.6-17.9 ms | 11.9-13.4 ms | 0, 2, 9 | 26-50 | 72.4-84.6 |

The averages here mean nothing (headless paces at ~6.9 ms). The 60 s export bench is in "Results".

**Expect on the 1060:** the spikes were main-thread CPU at zaps and landings. The 43-45 ms worst frames
should drop toward the 25 ms goal, and the 1%-low should rise well above 33.5. The box's CPU and the
renderer's own share decide by how much, and this lane can't measure either. Not claimed: that the
1%-low reaches 50, or anything about the low tier (its 27.7 also has HD 530 GPU limits). Run
`bench-game.sh junk-yard-zap` on the 1060 after the ship and set S-18 from its BENCH lines. If spikes remain,
the next suspects are the two left below and shader first use, which can't be seen headless.

## Left (not fixed, noted in S-18)
- A voice-pack bark still `load()`s its line from disk: 198 files, ~5 MB Ogg, about 30 MB as PCM, so they
  weren't decoded wholesale. At most one per zap.
- Grow steps' shape queries plus shape rebuild: 4-7 ms now and then.

## Results
- **Import:** `godot --headless --path . --import` exit 0, 0 script errors. This was an incremental import over
  the worktree's `.godot`, not a delete-and-reimport: the 60-minute limit didn't leave time for that.
- **Full suite** (`-a tests --continue`): **435 / 435 passed**, 0 errors, 0 orphans, exit 0
  (`handoff/test-output.txt`; 428 before + 7 new). The first full run had 1 failure:
  test_exit_watchdog `close_early` was killed by the exit watchdog. The decode worker was `load()`ing
  files while the main thread waited on it at shutdown. Moving the loads to the main thread fixed it
  (3 / 3 direct runs exit 0, then the whole second suite run). test_sleep_when_still 4 / 4.
- **Export:** `--export-release "Linux"` wrote the pack (`savepack DONE`). The editor process then aborts
  on its own exit, which is known (PF-6, previous REPORTs). Commands: `handoff/export_runs.sh`.
- **Boot the export with `--demo`** (Xvfb + lavapipe; the software renderer auto-picks the low tier):
  exit 0, **0 script errors**, in both the demo run and the `--demo-beat=wide` run.
- **Export, headless `--bench` 60 s** (CPU only, same line format):
  `BENCH avg=144.9 low1=82.0 frame_ms=6.90 worst_ms=17.0 frames=8696 seconds=60.0 tier=high cap=0`.
  No 5 s window had a worst frame over 17 ms. Before this lane's fix, the source build's 60 s run here
  was `low1=66.0 worst_ms=22.1`.
- **The frame I looked at:** `handoff/shots/demo_auto/t010.0s.png`, from the export at 10 s of `--demo`.
  It shows the yard, Jeff on a cloud with his gun, Chuck in yellow by the junk pile with a beam, both HUD
  rings (green P1, red P2) with their button hints, and the goal card top right. Nothing is missing or
  broken; it looks like the igpu-1 shots. Also `demo_auto/t004.0s.png` and `wide_auto/t010.0s.png`.
