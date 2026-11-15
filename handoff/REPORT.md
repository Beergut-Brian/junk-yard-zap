# jyz-igpu-1: playable on the TV box's Intel HD 530

Lane jyz-igpu-1 (Systems), branch `feature/jyz-igpu-1` from `origin/dev` @ `4866951` (after PR #50), 2026-11-14.
Not pushed. Previous lane's report (jyz-launch-ready-3) is in git history (`git show 4866951:handoff/REPORT.md`).

## What was built

1. **Graphics tiers in data**: `data/graphics.json`. `high` is `{}` (no overrides, today's look, the GTX 1060).
   `low` (the HD 530):
   - no MSAA (project default is 2x), FXAA instead
   - 0.75 render scale with FSR 1 (the 3D only; HUD and menus stay at full 1080p)
   - one shadow cascade (orthogonal) at 45 m instead of 4 splits at 140 m; 2048 atlas; soft-very-low filter
   - SSAO, SSIL, SSR, SDFGI, glow, volumetric fog off (the yard only had SSAO and glow on)
   - LOD threshold 4 (the default is 1)
   - half the particles in every burst
   - 60 fps cap, vsync on
   - SubViewports (lobby podiums, menu backdrop, fence cards): MSAA off, LOD 4
2. **Auto-pick**: new first autoload `Graphics` (`scripts/autoload/Graphics.gd`). It reads
   `RenderingServer.get_video_adapter_name()`, the vendor and the type:
   - NVIDIA, or AMD discrete: high
   - Intel, AMD integrated, software or unknown: low
   - headless (tests, tools): high
   - `--graphics=low|high` overrides the pick (it works on either side of `--`)

   The pick is logged once, e.g. `Graphics: tier=low (auto: Intel) adapter="..." vendor="..." type=1`.
   Dev and debug builds show the tier next to the lobby version (`v0.1.0  ·  low`), and F3 shows it too.
   In low, the autoload tunes the root viewport, the engine caps and every SubViewport, WorldEnvironment,
   DirectionalLight3D, Camera3D and particles node that enters the tree, so no other lane's code reads
   the tier. In high it connects nothing and touches nothing. Contract: `docs/contracts.md` "Graphics".
3. **Benchmark**: `-- --bench` (`scripts/tools/bench.gd`, hooked in `scenes/main.gd`; Game treats it as
   a demo). Both demo bots play with the soak's stress on (an effect every 0.4 s, glue made and undone).
   Everything is seeded.
   - After a 3 s warm-up that isn't counted, it times 60 s of wall clock: 20 s on the shared camera,
     20 s on the yard-wide shot (every object on screen, the worst case), then 20 s on the shared camera.
   - Every 5 s it prints `bench: t=… seg=… fps=… low1=… frame_ms=… worst_ms=…`.
   - At the end it prints `BENCH avg=… low1=… frame_ms=… worst_ms=… frames=… seconds=… tier=… cap=… adapter="…"`
     and quits with code 0.
   - `--bench-seconds=<s>` shortens the run.
   - The demo never writes the family's save.
4. **Look check from the export**: high vs low, `handoff/shots/`:
   - `demo_*` is the follow camera
   - `wide_*` is the yard-wide shot
   - `lobby_*` is the start screen

   The picture holds. Low is a little softer (FXAA at 0.75 scale) and the shadows are a bit softer and
   shorter, but the shapes, colours, sky, faces and HUD are the same.
5. **High is exactly today**: `test_high_is_todays_look_exactly` pins it:
   - the high tier's settings are `{}`, and the project's MSAA 2x, Forward+ and vsync are unchanged
   - the root viewport is unchanged and there is no fps cap
   - the Golden Afternoon environment is the same, property for property, after a high tune
   - the key light keeps 4 splits at 140 m and blur 1.5

## One thing tried and taken out

The brief asked for a shorter draw distance with fog to hide it. The first low export did that (camera
far 170, depth fog in the horizon colour), and `wide_low` came out wrong:
- the painted sky is 95 m behind the fence and the yard-wide camera sits about 150 m from it, so the far
  cut the sky off and left the flat background colour
- the fog tinted the whole diorama teal

The yard is a closed diorama with nothing beyond the sky to cull, so low keeps the full far. Graphics
still supports `camera_far` and `fog_depth_*` (tested); they're just not in low. This is recorded in
`data/graphics.json` `_doc` and on PLAN-STATUS S-29. The shots in `handoff/shots/` are from the fixed export.

## Not claimed

**The HD 530 frame rate.** This machine renders in software (llvmpipe), so its fps numbers mean nothing.
The export's own bench on it says `BENCH avg=0.5 … tier=low`, which only proves the mode runs, picks its
tier, reports and quits (`handoff/bench-export.txt`). Gary, on the box:

```
./junk-yard-zap.x86_64 -- --bench                     # ~65 s, quits by itself; first line: Graphics: tier=low (auto: Intel)
./junk-yard-zap.x86_64 -- --bench --graphics=high     # optional: today's look on the same box
```

Paste the `BENCH` line(s) into PLAN-STATUS S-29. Pass is `low1 >= 30`. If low misses 30, the next
lever is `scaling_3d_scale` 0.6 or `0.5` in `data/graphics.json`, which needs no code change. Then shadows
`"shadows": false`.

Two notes on the brief:
- The brief says "two players split screen". This game has one shared camera and never splits
  (GAME.md "Camera and controls"), so the bench is both players on one screen.
- Fixed route: the bots, the stress and the camera route are seeded and timed. Physics still steps
  with real frame time on a slow GPU, so two boxes won't see identical frames, but they run the same
  load.

## PLAN-STATUS

- **S-29 added** (S19, partial): playable on the Intel HD 530, with the low tier, the auto-pick and the bench.
  The open half is the box's BENCH line.
- **S-18** is linked to S-29 and stays partial (the GTX 1060).
- Totals: 198 rows, built 180 · partial 3 · missing 0 · superseded 11 · later 4.
- GAME.md producer note (2026-11-14) quotes the brief.
- `docs/launch-checklist.md` has a new box check.

## Evidence

- Tests: clean import (`rm -rf .godot`), then the full gdUnit suite with `--continue`, written to
  `handoff/test-output.txt`. The summary is in `handoff/handoff.json`.
  - New: `tests/test_graphics_tier.gd`, 13 cases:
    - Intel HD 530 and Mesa Intel pick low; the GTX 1060 picks high
    - AMD discrete picks high; AMD integrated, llvmpipe and unknown adapters pick low
    - the flag overrides the pick; headless stays high
    - low is applied to a viewport, a SubViewport, the yard environment, the key light, a camera, and
      through the node hook (particles 16 → 8)
    - high is pinned
    - the dev label shows the tier
    - bench stats (avg, 1%-low)
    - the bench route drives the camera follow → wide → follow and ends with the summary line
    - a real headless child `-- --bench --bench-seconds=3 --graphics=low` exits 0 and prints `BENCH avg=… tier=low`
  - Changed: `test_launch_ready.gd::test_the_lobby_footer_shows_the_project_version` now expects the dev
    tier suffix. It was the only red test in the first full run (428 cases, 1 failure).
- Export: `godot --headless --export-release "Linux" build/junk-yard-zap.x86_64`. The pack completes
  (`DONE`). The editor process then aborts on its own exit, which is known (previous REPORT, line 98).
  The export boots: 7 runs on the software renderer (6 shots + the bench), all `exit 0`, and none
  printed a `SCRIPT ERROR` line (`handoff/export_runs.sh`, `handoff/bench-export.txt`).
- Every scripted run used `XDG_DATA_HOME=<worktree>/.scratch/xdg`, so its `players.json` and saves were
  scratch. Tests point `Roster.picks_path` at `user://` (`test_graphics_tier.gd` `before()`); the bench
  child gets its own scratch `XDG_DATA_HOME`.

## Commits

See `handoff/handoff.json` "commits" (prefix `jyz:`).
