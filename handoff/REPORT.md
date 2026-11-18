# jyz-hitch-7: S-18, the process time in the 1060's slow frames (Gary lane, 2026-11-18)

Branch `feature/jyz-hitch-7` off `origin/dev` @ `690ce18` (after PR #60, jyz-hitch-6). Not pushed.

**Starting point:** Gary ran this on the 1060 box on 2026-11-18 at 09:19: v0.1.7-dev.8, `--bench --graphics=high --bench-trace`, with the 60 cap.
- Run 1: avg 59.2, 1%-low 37.9, worst 45 ms. 21 of 3550 frames went over 25 ms.
  - Slow frames, median 28.9 ms: physics 5.0, process 16.3, draw 6.1, idle 1.0, gpu 7.6.
  - All frames, median: process 8.0, draw 4.0.
- Run 2: avg 58.8, 1%-low 37.1. 27 of 3527 frames went over 25 ms.
  - Slow frames, median 29.3 ms: process 16.4, physics 5.0, draw 6.1, gpu 7.5.

The trace said `cause=process`, so this is the game's own script work.

## BENCH-ready
On the box, warm, twice: `./junk-yard-zap.x86_64 -- --bench --graphics=high --bench-trace --bench-scripts`, then paste the `BENCH`, `BENCH-TRACE` and `BENCH-SCRIPTS` lines.
It's confirmed if the slow-frame `process=` drops from ~16 ms and the all-frames `process=` from ~8 ms. The `BENCH-SCRIPTS` lines then name what's left, per script, on the 1060 itself.

## What I measured (labelled; none of these are 1060 numbers)
- **The tool.** `--bench-scripts` is new, used with `--bench --bench-trace`, in `scripts/tools/script_trace.gd`.
  - It groups every processing node by script (or native class). Each group gets its own process priority, kept in the original priority order, with a marker node before it.
  - It gives two numbers per group:
    - **own**: the group's `_process` time.
    - **defer**: the deferred work the group queued, measured between two deferred stamps the markers queue. A `queue_redraw()` is a deferred call, so this holds the whole redraw, `_draw` included.
  - The flag reorders nodes only inside one original priority. Without the flag the node doesn't exist.
- **Headless doesn't show it.** Headless (no renderer), process was only ~1.3 ms a frame. Two reasons:
  - The trace's headless process column ends before the deferred flush.
  - The dummy renderer makes canvas drawing almost free.
  So I measured on **lavapipe** (`godot-render`, Forward+ on llvmpipe, 320x180, about 1.4 fps). There, frame times mean nothing, but the main thread's process CPU per frame is real.

**Lavapipe, before** (`b_lvp4`): process median 7.2 ms per frame. Per frame, the deferred flush after `_process` was 4.8 ms, and the per-script split was:

| what | ms per frame (mean) | p99 | how often |
| --- | --- | --- | --- |
| `hud.gd` redraw (deferred) | **2.90** | **11.7** | 1.06 redraws per frame |
| `hint_panel.gd` redraws (2 panels, deferred) | **2.42** | 3.5 | 2.12 per frame |
| `object_face.gd` `_process` (48 faces) | **0.90** | 1.1 | every face, every frame |
| soak.gd (the bench's stress) | 0.19 | 1.1 | |
| everything else | < 0.07 each | | |

The first three are 6.2 of the 7.2 ms. All three ran every frame, whatever changed:
- The HUD redrew everything every frame, the whole goal card in vector art included.
- Both hint rows redrew every frame.
- Every face recomputed its whole pose every frame.

The HUD's p99 of 11.7 ms fits the 1060's slow frames, which had about 8 ms of extra process work. The HUD redraws a lot in the bench because the demo bots cycle guns all the time (wheel, badge punch, first-fire beats).

The top three causes, then: the HUD redraw, the hint-row redraws, the face poses. Physics (5.0) and draw (6.1) on the box's slow frames are not what grew, so I changed nothing there.

## What changed and why
1. **`perf: pose an object face only when its pose would change`** (98e7779), `scripts/physics/object_face.gd`.
   - `_pose()` is a pure function of the mood, the look, the blink and (only when dizzy or panicking) the clock. `_pose_changed()` skips the whole pose when those are the same as at the last pose.
   - The face's basis inverse is now built only once a player is within range.
   - Counters: `ObjectFace.poses` and `ObjectFace.part_writes`.
2. **`perf: redraw a hint row only when the row would look different`** (326d06e), `scenes/ui/hud/hint_panel.gd`.
   - `draw_key()` holds every value `_draw` reads:
     - the hint (context, glyphs, blink, iced, nope)
     - the viewport size, the player, solo and focus, and the accent
     - the shake time while noped
     - the clock while the sleeper breathes or the sun turns
     - the held gun and the belt's next gun
     - the ready blink's screen spot and on/off
   - The panel queues a redraw only when the key changes. Counter: `HintPanel.redraws`.
3. **`perf: redraw the HUD on change; the goal card on its own layer`** (7d643be), `scenes/ui/hud/hud.gd`.
   - `draw_key()` and `card_key()` work the same way, and `redraw_if_changed()` replaces the HUD's every-frame `queue_redraw()`.
   - The goal card, its events and the done-pile stars used to open the HUD's `_draw`. They now draw on a child `_CardLayer` with `show_behind_parent`, through the same code. So they are still drawn first, under everything else, and the hint rows stay on top.
   - Now a wheel or a beat over a player doesn't redraw the card, and a card event doesn't redraw the rest.
   - Counters: `Hud.redraws` and `Hud._CardLayer.redraws`.
4. **`perf: add --bench-scripts, a per-script split of the bench's process`** (d1d8e79).
   - The new script `scripts/tools/script_trace.gd`.
   - `scripts/tools/bench_trace.gd` adds the process frame to each row (the CSV is unchanged).
   - `scenes/main.gd` wires the flag.

Nothing seen or heard changes. There is no art, particle, light, shadow, render-scale or colour change, and no change to the cap, vsync or the present mode.

**After, on lavapipe** (`b_lvp5`, same route):
- Process median: 7.2 → **4.8 ms**.
- Hint rows: 2.42 → **0.95 ms** (0.78 redraws a frame. With 8 physics steps per lavapipe frame the players move more per frame than on a real 60 fps run).
- Faces: 0.90 → **0.41 ms** (15 poses a frame instead of 48).
- HUD: 2.90 → **2.62 ms**, p99 11.7 → **7.5 ms**. The card layer redraws 0.02 times a frame.

**After, headless** (`b5`): process median 1.2-1.5 → 0.8 ms. Hint redraws 2.01 → 0.20 a frame, faces 1.1-1.7 → 0.40 ms.

Probe lines and CSVs are in `handoff/hitch7-probe/`.

## The frames I looked at
`handoff/shots/hitch7_trophy/`, taken with `--demo --demo-beat=trophy`, real 1080p frames:
- At 3.5 s (the next card, still), the corner card region is **pixel-identical** to hitch-6's frame at 3.5 s.
- At 0.6 s the card is mid "done" event: gold stamp, glow and confetti, with the done-pile stars beside it. It matches hitch-6's frame (`corner_hitch6_vs_hitch7_t0.6.png`). Only the confetti positions differ, because the shot lands at a slightly different moment (the 3D differs too).

## Tests
`tests/test_hitch_7.gd` (new, 12 tests, all pass). Events are counted through draw signals and per-call counters, never by polling. The tests that boot main use a scratch profile, settings and players path.
- Faces:
  - `test_a_still_face_skips_its_pose_and_writes_nothing`: a settled face poses 0 times and writes 0 parts over 120 frames. A flash and a blink each pose in their call.
  - `test_a_dizzy_or_panicked_face_still_moves_every_frame`.
  - `test_a_face_looks_the_same_as_posing_every_frame`: one face posed only on change, one posed every frame (the old code). Each frame they are compared part by part (position, scale, rotation, visible) through all 8 moods, flashes, blinks from the same RNG state, and a player walking up and away from a face turned to one side. They match on every frame.
- HUD and hint rows:
  - `test_the_goal_card_draws_on_a_layer_behind_the_hud`.
  - `test_a_still_hud_and_hint_rows_do_not_redraw`.
  - `test_a_card_event_redraws_the_card_every_frame_until_it_ends`.
  - `test_every_hud_change_redraws_in_its_frame`: the wheel, the badge punch, a beat, the done pile and solo.
  - `test_a_refused_press_shakes_the_hint_row_every_frame`.
  - `test_a_hint_row_redraws_when_its_context_changes`.
- Tracer:
  - `test_script_trace_flag`.
  - `test_script_trace_splits_process_by_script`: a node that burns 1.5 ms comes first, and every priority is put back when the tracer leaves.
  - `test_script_trace_flag_runs_with_the_bench_and_prints_its_lines`: a child process on a scratch `XDG_DATA_HOME`.
- **They bite.** With the three gates forced back to every frame, 5 of the 12 tests fail (10 failures).
- Clean import (`rm -rf .godot`, `godot --headless --path . --import`), then the full suite with `--continue` (`handoff/test-output.txt`):
- Clean import: **exit 0** (`handoff/hitch7-probe/clean_import.log`; the only lines are the usual "resources still in use at exit" and "ObjectDB instances were leaked at exit").
- Full suite `--continue`, right after: **478 test cases, 0 errors, 0 failures, 0 flaky, 0 orphans. Exit 0.** test_hitch_7 (12), test_hitch_6, test_ui_clarity and test_hint_panel all pass.

## Not done
- No 1060 numbers. The producer benches after the ship (see BENCH-ready).
- **The HUD still costs about 2.6 ms a frame on lavapipe** in the bench, because there it really animates nearly every frame. Per redraw, a temporary timer measured the gun wheel at 1.18 ms, the two corner badges at 0.74 ms and the beat at 0.29 ms (`b_lvp6`, removed).
  - The badges can't move to a layer of their own without changing what draws over what: P1's beat edge flash or wheel can cover P2's badge. So I left them.
  - In real play the wheel shows only when a kid flicks guns, so the HUD now mostly sits still.
  - If the box's `BENCH-SCRIPTS` still has `hud.gd` on top, the next step is cheaper wheel or token drawing that looks the same (fewer triangulated polygons), and that needs its own pixel test.
- I didn't change the cap, vsync or the present mode (D117, a producer call).
- `face_part_writes` is unchanged (~45 a frame on lavapipe). Those writes are real movement: eyes following players, dizzy and panicked faces. Only the pose math for still faces went away.

## IDs moved
None. S-18 and S-29 stay **partial**. I updated both notes and the PLAN-STATUS header: what was found, what changed, and the box run that decides.
