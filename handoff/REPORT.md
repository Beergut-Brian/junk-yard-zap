# jyz-hitch-6: S-18 steady 60 on the 1060 (Gary lane, 2026-11-18)

Branch `feature/jyz-hitch-6` off `origin/dev` @ `cb62858` (after PR #59, the 60 fps cap). Not pushed.
Starting point (Gary, the box, v0.1.7-dev.7, `--bench` at high with the 60 cap): avg 58.5-58.9, 1%-low 37.8-41.4.

## BENCH-ready
On the box, warm, twice: `./junk-yard-zap.x86_64 -- --bench --graphics=high --bench-trace` and paste both the `BENCH` and the `BENCH-TRACE` lines (the per-frame CSV is `~/.local/share/godot/app_userdata/Junk Yard Zap/bench_trace.csv`).
`cause=physics|process` means the game's own work, so it's the next hitch lane's. `cause=idle`, or `cause=draw` with a small `gpu=`, means the limiter or the present held the frame, so it's the cap or the present mode, which is a producer call.

## What changed and why
1. **`perf: render the fence card once per change, not every frame`** (80b9316). `scripts/levels/fence_card.gd`:
   the card's 512x512 SubViewport was `UPDATE_ALWAYS`. It cleared and redrew the whole Pictos card every frame
   for a face that only changes on a stamp, during the 0.3 s stamp slam, and on a flip. Now every change goes
   through `_redraw()`, which queues the face's draw and sets `UPDATE_ONCE` in the same frame, and between
   changes the card costs no pass. I chose `UPDATE_ONCE` over `UPDATE_WHEN_VISIBLE` because ONCE is exact:
   WHEN_VISIBLE depends on the renderer marking the texture as used, and a Sprite3D in a 3D pass doesn't
   reliably do that. The look is unchanged: same texture, same size, same draw code.
2. **`perf: write a Reset sign bulb only when it turns on or off`** (745a8c9). `scripts/levels/reset_sign_fx.gd`
   set all 19 bulbs' `material_override` every frame. Each write sends the material to the renderer and marks
   the instance dirty. The chase steps 6 times a second when idle, so most of those writes were the same value.
   Now a bulb is written only when its material changes. Over 115 frames that's 158 writes, down from 2185, and
   at every frame the pattern is the same as before.
3. **`perf: add --bench-trace, a per-frame split of the bench's frames`** (0270b18). `scripts/tools/bench_trace.gd`,
   wired in `scenes/main.gd`. Behind a flag, so nothing changes without it. It uses the engine's own signals to
   split every counted bench frame into four parts:
   - physics: the iteration's steps, with a step count
   - process: every `_process`, tweens and the deferred flush
   - draw: main-thread render CPU, including the waits on the GPU and the swapchain (the thread model is Safe)
   - idle: the 60 fps limiter's sleep and window events

   It also logs the GPU ms the viewport measured. It writes a CSV and prints
   `BENCH-TRACE slow=<n>/<frames> over=25ms slow_med: ... all_med: ... cause=<part>`, where `cause` is the
   part that grew in the frames over 25 ms.

Nothing seen or heard changes: no art, particle, light, shadow, render-scale or colour change, in both tiers.

## Item 3: what drives the frames over 25 ms (numbers from this machine, not the 1060)
This machine is an i5-8500T (6 cores), and it was **under heavy load the whole time**: four other lanes' sims at
100 % plus another Godot suite, load average 4.5-7.9. All runs are the bench route, 30 s, at the 60 cap
(`--max-fps 60`). Files are in `handoff/hitch6-probe/` (`runs.log`, `bench_lines.txt`, CSVs, `an6.py`; `runs.sh` and `empty_limiter.*` run from `.scratch/`).

| run | BENCH avg / low1 / worst | frames > 25 ms | what grew in them |
| --- | --- | --- | --- |
| headless 0 | 59.9 / 32.6 / 44.9 ms | 8 / 1796 | physics (1-2 steps of 23-28 ms); 3 were idle-held (limiter woke 20-42 ms late) |
| headless 1 | 59.9 / 32.4 / 61.4 ms | 6 / 1795 | physics, single steps of 20-31 ms, 4 of them within 1.1 s |
| headless 2 | 60.0 / 43.0 / 43.7 ms | 1 / 1799 | physics, one 29 ms step |
| **empty scene**, same cap (`empty_limiter.gd`) | 60.0 / **50.6** / 28.8 ms, then 59.9 / **39.8** / 65.0 ms | 1, then 3 | nothing: an empty `Node` |
| lavapipe, 480x270, high | 0.7 / 0.1 | 19 / 19 (every frame) | draw 1128 ms median, of which GPU 1099 ms: the software renderer, `cause=draw(all)` |

How I read it:
- **The local numbers don't point at a game fix, so I made none.** The slow frames come in bursts
  (4 within 1.1 s in one run). None of them recurs at the same route time across the three runs (`an6.py`: none
  within ±0.15 s). An empty scene with the same cap on the same machine drops its 1%-low to 39.8 with a 65 ms
  worst frame. Here, under this load, the 1%-low at the cap is set by the CPU scheduler, not by the yard. The
  physics spikes fit that: Jolt runs its jobs on worker threads, and on a loaded CPU a step waits for them.
- Steady cost is small: per frame the median is physics 1.8-2.0 ms, process 1.3-1.4 ms, and p99 is physics
  5.5-7.0 ms and process 4.4 ms. So the yard's main-thread work is far under 16.7 ms at the cap here.
- Lavapipe renders at 0.7 fps, so it can't say anything about 25 ms frames. That run only shows the trace works with
  a renderer (draw and GPU columns filled).
- **On the box.** Avg 58.5-58.9 under a 60 cap means frames lose time, not only that a few run slow. A 1%-low of
  38-41 means the slowest 1% average 24-26 ms. That's about three refreshes of a 120 Hz output, which fits a
  frame that just misses its second refresh. It also fits a real 20-25 ms frame. The trace tells these apart on
  the box. If it says `cause=idle`, or `draw` with a small `gpu`, the limiter or the present is the cause. That's
  the cap (D117) or the present mode, and a producer call, so I didn't change either.

## Tests
`tests/test_hitch_6.gd` (new, 12 tests):
- Fence card: `test_the_card_viewport_does_not_render_every_frame`, `test_a_stamp_draws_and_renders_in_the_same_frame`,
  `test_a_skip_stamp_draws_and_renders_in_the_same_frame`, `test_a_flip_to_the_next_card_draws_and_renders_in_the_same_frame`
  (draws are counted through the face's `draw` signal, renders through a per-call counter; a still card asks for
  no render over 60 frames).
- `test_with_a_renderer_a_stamp_and_a_flip_show_on_the_next_frame`: with a renderer, the card's texture pixels
  change in the frame after a stamp and after a flip, and stay put while still. It returns early in headless (no
  pixels). I ran it under `godot-render`, where all 12 tests pass.
  **It bites:** with `_redraw()` not arming `UPDATE_ONCE`, it fails with "the stamp did not show" and "the flip did not show".
- Reset sign: `test_the_reset_sign_writes_a_bulb_only_when_it_changes` (the count equals the bulbs that really
  changed, the pattern is right on every frame, and a frame inside a chase step writes 0),
  `test_the_reset_sign_still_races_after_a_reset`, `test_the_yard_sign_still_lights_its_bulbs`.
  **On the old sign code: 2 failures.**
- Bench trace: `test_bench_trace_flag_and_path`, `test_bench_trace_names_the_part_that_grew_in_the_slow_frames`,
  `test_bench_trace_splits_every_counted_frame_and_writes_its_csv` (physics + process + draw + idle = the frame,
  and the CSV goes to a `user://` scratch path, removed after), `test_bench_trace_flag_runs_with_the_bench_and_prints_its_line`
  (a child process on a scratch `XDG_DATA_HOME`, the same pattern as the bench test).
- Clean import (`rm -rf .godot`, `godot --headless --path . --import`): **exit 0**. The only lines are the usual
  "resources still in use at exit" and "ObjectDB leaked at exit".
- Full suite `--continue`, run right after that clean import on the code at 0270b18: **466 test cases, 50 suites,
  0 errors, 0 failures, 0 orphans, 0 script errors**. Exit 0, 11 min 38 s under the load
  (`handoff/test-output.txt`). test_sleep_when_still and test_hitch / _2 / _3 / _4 / _5 / _6 all pass.

## The frames I looked at
- `handoff/shots/hitch6_trophy/` (`--demo --demo-beat=trophy`, real frames, 1080p). At 0.6 s the fence card shows
  its done stamp. At 3.5 s it shows the next card (truck), the same card as the HUD. The stamp and the flip both reach
  the screen.
- `handoff/shots/hitch6_sign/`: the Reset sign's bulbs chase, about 2 of 3 lit.

## Not done
- No 1060 numbers: the producer benches after the ship (see BENCH-ready).
- I didn't measure the card's and bulbs' savings on a GPU. Lavapipe on this loaded machine runs the yard at 0.7 fps,
  so a 512x512 2D pass is below its noise. Both are small and steady (hitch-5 said so too). Neither is the 25 ms frame.
- I didn't change the cap, vsync or the present mode (producer call). If the box trace says `idle` / `draw` with a small `gpu`,
  the options are: a cap of 0 (uncapped) with vsync at 120 Hz (back to D117's question), mailbox, or `max_fps` 0 with vsync at a 60 Hz output mode.
- The trace's `idle` also holds the first physics step's sync and `_integrate_forces` callbacks, because the engine
  gives no signal before them. hitch-4 measured step + flush p99 at 0.7 ms, so idle is mostly the limiter.

## IDs moved
None. S-18 and S-29 stay **partial**. I updated both notes: what changed, the trace, and the box run that decides.
