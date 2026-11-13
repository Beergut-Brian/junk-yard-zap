# Gap-close 5: PF-6 (hang at exit) and S-18 (sleep when still)

Lane jyz-gap-close-5, branch `feature/jyz-gap-close-5` (from `dev` @ `8c749f1`, after PR #43), 2026-11-13.
Not pushed. Commits:

- `bf1193d` systems: exit watchdog ends a hung shutdown after quit (PF-6)
- `1d3b947` gameplay: yard objects sleep when still (S-18)
- `f4533d9` gameplay: see-saw plank sleeps with what it rests on (S-18)
- docs commit: this report, handoff.json, test output, PLAN-STATUS

PLAN-STATUS rows moved: **PF-6 missing -> built**. **S-18 stays partial** (sleep is now built; the GTX 1060
frame rate is the weekend TV check). Totals: built 170 · partial 2 · missing 0.

## PF-6: the exported game hung at exit after an early close

### What hangs

Repro: the release export (`.scratch/b/game.x86_64`), a save present (a `first` run left one), then
`XDG_DATA_HOME=<scratch> run-export game.x86_64 -- --player-flow=close_early --flow-out=<dir>` (software
Vulkan, lavapipe on Xvfb). The close happens at frame ~12, 20-50 s after launch on this renderer, which runs
at about 1 fps while it compiles pipelines.

**Unfixed export: 12 of 19 valid early closes hung** (runs on a pty 3/4, probe runs 3/6, override-matrix
baseline 6/9; runs broken by my own harness, such as an X server killed mid-run, are not counted).

### Where it hangs (the evidence)

1. **Not the game's code.** Markers on every root child (`tree_exiting`, `tree_exited`, and a predelete node
   inside each autoload and Main) all print: every node leaves and is freed in about 0.2 s. The save is
   written before that (Game.quit -> Save.flush). The game has no threads, threaded loads, HTTP or
   processes of its own (grep).
2. **Inside the engine's shutdown, before `Main::cleanup` prints anything.** A clean close prints
   `XR: Clearing primary interface` about 1.5 s after the close; a hung one never does. A GDScript thread
   kept printing for 40 s during the hang, so script languages were still up.
3. **The main thread's stack.** A Python parent (Yama ptrace_scope=1 only lets an ancestor read
   `/proc/<pid>/mem` and `/syscall`) scanned the hung main thread's stack: `main()` ->
   (inlined `Main::cleanup`) -> `std::condition_variable::wait`. The disassembly at the return address
   (`0x42ba69`) is `WorkerThreadPool::exit_languages_threads()`: `if threads.size()`, lock, `_switch_runlevel(1)`,
   `while (num_idle != threads.size()) wait`, then `_switch_runlevel(2)` and a second loop. It is stuck in
   the first loop.
4. **The pool's state, read from the hung process.** WorkerThreadPool singleton: `threads.size = 6`,
   `num_idle_threads = 1`. All 6 workers have the same shallow stack: thread start -> `_thread_function` ->
   the idle condvar wait. None is running a task. A worker only counts as idle in that runlevel when both
   task queues are empty, so **a low-priority task is left queued that no thread will run** (the pool prints
   "6 threads, 1 max low-priority"). Queuing 12 no-op normal-priority tasks during the hang changed nothing
   (3 of 3 stayed hung), which fits: the normal queue isn't the blocked one.
5. **Config matrix** (override.cfg next to a copy of the export, never project.godot; 5-8 runs each):

   | override | hung / valid runs |
   | --- | --- |
   | none (baseline) | 6 / 9 |
   | `rendering_device/pipeline_cache/enable=false` | 3 / 5 |
   | `shader_compiler/shader_cache/enabled=false` | 4 / 5 |
   | navigation `map/region_use_async_iterations=false` | 4 / 6 |
   | `--disable-vsync` | 5 / 5 |
   | **`threading/worker_pool/low_priority_thread_ratio=0.5`** | **0 / 12** |

   GodotPhysics instead of Jolt still hung (1 of the 4 runs; the other 3 were crashed by a debug thread of
   mine, so they don't count either way).

So the cause is in the engine (Godot 4.7.2 WorkerThreadPool's low-priority queue at shutdown), seen when the
window closes while the software renderer is still busy right after launch. It never happened headless or on
a later close (the earlier lane's `lobby_quit`, window close in play, pause Leave).

### The fix (in the game, since the engine is not ours)

`Game.quit()` (scripts/autoload/Game.gd): `quit_requested` -> `Save.flush()` -> **`arm_exit_watchdog(6000)`** ->
`get_tree().quit(code)`. The watchdog is a plain `Thread`, not a WorkerThreadPool task, so the engine's shutdown
never waits for it. It sleeps in one native `OS.delay_msec(6000)`; if the process is still alive when it wakes,
it prints `Game: shutdown still running 6000 ms after quit(); ending the process (PF-6)` and calls
`OS.kill(own pid)`. On a clean shutdown the process is gone long before it wakes, so no script runs after
teardown (no crash, no warnings in the clean runs' logs).

**Proof on the real export (fixed build `.scratch/bf/game.x86_64`, same scratch save):**

| run | close at | process ended | how |
| --- | --- | --- | --- |
| 81 | 24.7 s | 30.9 s | watchdog (exit 137) |
| 82 | 19.5 s | 25.8 s | watchdog (exit 137) |
| 83 | 25.8 s | 28.2 s | clean, exit 0 |
| 84 | 49.0 s | 51.8 s | clean, exit 0 |
| 85 | 39.4 s | 41.9 s | clean, exit 0 |
| 86 | 28.3 s | 34.6 s | watchdog (exit 137) |
| 87 | 31.4 s | 37.7 s | watchdog (exit 137) |
| 88 | 27.2 s | 33.5 s | watchdog (exit 137) |

8 of 8 ended (before: 12 of 19 never did). The final HEAD's export (with the S-18 changes too), 2 more runs:
both ended by the watchdog 6.2 s after the close. The save parsed after every run. `lobby_quit` (Back to Open Jar ->
Leave) on the fixed build: 2 of 2 exit 0.

**Tests** (tests/test_exit_watchdog.gd, 5 cases): the save is on disk before the tree quits; the watchdog fires
after its grace and not before; the grace covers a clean shutdown; then two real child processes (headless
Godot on a scratch `XDG_DATA_HOME`, a save present): `close_early` **exits 0**, and `hang_exit` (a node whose
predelete blocks the main thread for 10 minutes, a shutdown that never ends on purpose) **is ended by the
watchdog** (about 9 s including boot). Negative control: with the watchdog call removed, the `hang_exit` test
fails ("still running after 90 s").

### Left open on PF-6

- **Exit code on a hung shutdown is 137, not 0.** docs/contracts.md asks for 0 on a clean quit. A killed process
  can't choose its code; the save is already written and the launcher gets its process end within ~6 s instead
  of never. If the launcher treats non-zero as a crash, it should treat this as a normal return (the launcher
  is out of my scope).
- **Engine-side cure for Systems:** `threading/worker_pool/low_priority_thread_ratio=0.5` in project.godot made
  12 of 12 early closes exit 0 here. I didn't apply it (project.godot is off-limits). With it, the watchdog
  would very likely never fire.
- **TV box:** does the engine hang happen on the GTX 1060 at all? Look for the "shutdown still running" line in
  the log after an early close. Either way the launcher now gets the process back.

## S-18: 60 fps on a GTX 1060; sleep when still

### Finding: nothing ever slept

Running the soak with a calm phase showed 55 of 56 bodies awake 55 s after the stress stopped. A staged quiet
yard (nothing touching it) had **55 of 55 awake** after 15 s, every resting body reading exactly
`v = 0.163 m/s` = g x dt. The yard's gravity is its own: `PhysicsObject._integrate_forces` adds it and writes
`state.linear_velocity` every step, and a write wakes a Jolt body, so `can_sleep = true` never had an effect.
(The old S-18 note, "balloons keep nothing else awake: 52 -> 55 awake bodies", was this: 52 awake without them.)

### Fix

`PhysicsObject._settled()` (scripts/physics/physics_object.gd): if the solver has held a body still
(|v| < 0.05, |w| < 0.05, on the plane) for 12 steps in a row, each time cancelling the gravity we applied (which
proves something holds it up), the body puts itself to sleep through the direct state. Never while we steer it
(grab, a size change and its clamp, the chute) or with gravity off. Jolt wakes it on any contact, zap or push as
before. Two details found by staging:

- **Woken without a push** (a stack-mate settling, a neighbour resized), a body gets one step of gravity before it
  can sleep again. If its support is gone, that step moves it and the count resets, so it never sleeps in mid-air.
- **Piles:** two touching bodies took turns, each falling asleep on the step the other woke it. Settled bodies
  now sleep only on even physics frames, so a pile falls asleep together.
- **The see-saw plank** (yard_level.gd, the yard's one plain RigidBody3D, engine gravity and a hinge) rests its
  low end on the hay. The first full-suite run caught it: the quiet-yard test saw "hay" awake again after the
  yard slept. The hay fell asleep on an even frame, the awake plank woke it by contact, and that waking kept the
  plank's own sleep timer from running out (plank asleep 0 of 120 frames). The plank now follows the same rule
  (`SeesawPlank`: still for 12 steps, sleep on an even frame): asleep 120 of 120, and the hay stays asleep.

### Headless proof (this machine, CPU only; frame times are not GTX 1060 numbers)

- **tests/test_sleep_when_still.gd** (4 cases): a quiet full yard is all asleep (but the 3 balloons, which bob by
  design, Y-11) at frame 496 (8.3 s) and stays asleep; a lone crate sleeps, wakes and moves when pushed, then
  sleeps again on the floor; a crate thrown up from 5 m never sleeps above the floor; a sleeping 2-crate stack whose
  bottom crate is knocked away: the top falls from 1.50 to 0.50 m (floor rest height 0.50), no hovering. Staged
  with `Stage.clear_all`, so no pile decides the outcome.
- **Stress soak, 35 simulated minutes** (`godot --headless --path . --fixed-fps 60 --quit-after 126000 -- --demo
  --soak --soak-calm=1800`, 11 min 46 s wall):

  | t (sim) | nodes | objects | orphans | joints | effects on | zaps / glues | frame ms (mean / worst) | memory |
  | --- | --- | --- | --- | --- | --- | --- | --- | --- |
  | 0 | 2696 | 6149 | 0 | 0 | 0 | 0 / 0 | - | 194.1 MB |
  | 300 | 4198 | 10232 | 0 | 6 | 135 | 609 / 104 | 5.67 / 16.1 | 213.5 MB |
  | 600 | 4556 | 11116 | 0 | 6 | 145 | 1165 / 210 | 5.00 / 15.2 | 217.0 MB |
  | 900 | 4741 | 11644 | 0 | 6 | 146 | 1735 / 316 | 5.94 / 18.7 | 218.9 MB |
  | 1200 | 5050 | 12288 | 0 | 6 | 157 | 2306 / 402 | 6.43 / 42.2 | 220.8 MB |
  | 1500 | 5069 | 12432 | 0 | 6 | 150 | 2850 / 490 | 5.18 / 10.5 | 221.3 MB |
  | 1800 | 5036 | 12432 | 0 | 6 | 139 | 3417 / 578 | 5.44 / 15.7 | 221.3 MB |

  0 orphans the whole run, 0 recalls, no script errors. Nodes, objects and memory grow with the stacked
  effects (each carries its own visuals) and are flat over the last 10 minutes (5050 -> 5036 nodes, 221 MB).
  At exit: "10 ObjectDB instances leaked / 5 resources still in use"; that's `--quit-after` skipping the
  game's quit. A 2-minute soak run before the Game.gd and physics changes printed the same kind of line
  ("11 resources still in use at exit"). The stress test
  `test_more_objects.gd::test_stress_whole_yard_stays_clean` passes in the full suite.
- **Calm after the stress, effects left on** (`--soak-calm=600`): 45-54 awake, and **every one has an effect
  acting on it** (`plain=0 fx=45..54`: magnets, glue joints, balloon lift and bouncy push them every step), so
  they are not still. Correct as is.
- **Calm after Reset Yard** (`--soak-calm=30 --soak-calm-reset`, after the see-saw fix): **56 -> 10 awake in 5 s,
  4 by 10 s, and 4 for the remaining 45 s**: the 3 balloons and the crane hook (by design), with one TV blip at
  75 s. Before the see-saw fix the same calm had a few more (hay, pumpkin, and floaters after a 10-minute stress,
  `--soak-calm=600 --soak-calm-reset`: 4-11 awake).

### Not claimed

**60 fps at 1920x1080 on the GTX 1060.** Not measurable here. Weekend TV check: F3 overlay with the whole yard
awake, both pads, the real TV. Row note says so.

## Tests

`godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --continue --ignoreHeadlessMode`:
see the last lines of handoff/test-output.txt (the run finished after this report's numbers; the summary
line is copied into handoff.json). New: test_exit_watchdog.gd (5), test_sleep_when_still.gd (4). The first full run (before the see-saw fix) had one
failure, the quiet-yard test ("hay" awake again): a real bug, fixed at the cause above, not by a longer wait.

## Still open

- C-14 (playtest #2), S-18's GTX 1060 frame rate, PF-6 on the TV box (whether the engine hang happens there):
  all wait on Kaden or the TV box.
- For Systems: `low_priority_thread_ratio=0.5` (see PF-6). For whoever owns the launcher: a 137 after
  "shutdown still running" is a normal return.

No frames this lane: no visual change.
