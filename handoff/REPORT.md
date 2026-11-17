# jyz-hitch-4: S-18 steady 1%-low (Gary lane, 2026-11-17)

Branch `feature/jyz-hitch-4` off dev cc09753 (v0.1.7-dev.4). Not pushed. Ended: **partial**. One fix built, measured
headless and tested. I don't claim it reaches the 1060 target (1%-low >= 50, worst < 25 ms) alone. See "Expected on the 1060".

## Findings (full numbers: `handoff/hitch4-findings.md`)
Method: a per-frame probe on the real `--bench --graphics=high` route (headless, wall clock). It splits each frame into
all `_process` callbacks, all `_physics_process` callbacks and the Jolt step + flush. A temporary timer wrapped every
`_process` / `_physics_process` / `_integrate_forces` in the game to attribute the time (reverted, not committed).

1. **No script or physics step makes a 25 ms frame here.** Headless busy time (scripts + physics) on the bench route:
   median 1.3 ms, p90 3.7, p99 5.9, max 12.4 ms. Every slow-1% frame contains a physics step. The worst single script
   call is a zap (`Zapper._press`, max 4-6.5 ms), but that cost is spread over the size step (2.2), the bark (1.8),
   the zapped listeners (1.8) and Audio (1.4 ms), so there's no single culprit, and it's rare (44 ms in total over 60 s).
   Jolt step + flush: median 0.5, p99 1.2-1.5 ms. There are no in-play shader compiles headless.
2. **Steady waste: same-value transform writes.** Godot 4.7 doesn't skip a same-value `position` / `scale` /
   `rotation` write (checked: 10 writes of the same scale -> 10 child notifications). Each write re-sends the
   transform of every render instance under the node. `PhysicsObject` wrote its art's scale **every physics step,
   asleep or not** (1299 of the yard's 1719 visual instances sit under object art). `ObjectFace` wrote its 13 parts
   **every frame** (46 faces, 736 instances). On the bench route that re-sent 694 instances a frame on frames without a
   physics step and 1152 on frames with one. It was also the biggest script cost: ObjectFace 0.7 ms a frame, more than
   all the physics callbacks together.
3. **Renderer cost of a re-sent instance** (godot-render micro-bench, 1288 instances, shadowed sun, per-thread CPU):
   main thread 0.82 -> 1.32 ms a frame, other Godot threads +0.44 ms: about 0.7 us an instance on this i5-8500T.

## What changed
- `scripts/physics/physics_object.gd` `_physics_process`: write `_visual.scale` only when the value changes.
- `scripts/physics/object_face.gd` `_pose`: every eye / pupil / brow / mouth / sweat write goes through
  `_put_pos` / `_put_scale` / `_put_rot`, which write only on a change. The brow's `rotation_degrees` became the
  same angle in radians.

The same values are written when they change, so nothing seen changes in either tier (export frames at low and
high: `handoff/shots/`). No art, particle, light, shadow or render-scale change. Sleep-when-still logic,
render_prewarm and the hitch-3 merge are untouched.

### A/B, headless bench route, 40 s back to back (base dev cc09753 / fix)
| | base | fix |
| --- | --- | --- |
| render instances re-sent a frame (mean) | 884 | 322 |
| frames without a physics step (median) | 694 | 37 |
| frames with a step (median) | 1153 | 756 (bodies really moving under the stress) |
| busy p90 / p99 / max ms | 3.74 / 5.93 / 12.4 | 3.14 / 4.25 / 10.4 |
| Jolt step + flush mean / p99 ms | 0.34 / 1.49 | 0.17 / 0.69 |
| quiet yard: 51 sleeping objects over 30 steps | 31518 updates | 0 |
| headless BENCH low1 (wall clock, includes idle sleep) | 68.8 | 81.0 |

Another lane's test suite ran on this machine during most runs, so the absolute numbers are noisy. The counts are exact.

## Tests
- New `tests/test_hitch_4.gd` (3 tests). A sleeping crate's art gets 0 transform updates in 60 steps, and a squash
  still reaches it. A calm face's mouth gets 0 in 60 frames, and a mood change still moves it. In a quiet yard, every
  object asleep for the whole 30-step window gets 0 (51 objects counted). The crate is staged alone on open ground;
  the yard test only counts bodies that stayed asleep, so no pile decides it. **All 3 fail on the old code**
  (60 / 1488 / 31518 updates).
- Full suite `--continue`: **448 test cases, 0 errors, 0 failures, 0 orphans, 48 suites** (`handoff/test-output.txt`).
  test_sleep_when_still passes, as do test_hitch / _2 / _3.
- Clean import (`.godot` removed): exit 0. The only lines are the usual "resources still in use at exit" and
  "ObjectDB leaked at exit".
- Export (`handoff/export_runs.sh`): the pack is written; Godot's own exit is 134 after savepack (known, PF-6, same as
  hitch-3). Booting the export with `--demo`: 0 script errors at the auto tier (low on this software GPU), 0 at
  `--graphics=high`, 0 in the wide beat. Headless `--bench --graphics=high` from the export: `BENCH avg=144.7 low1=75.5
  worst_ms=20.1` (CPU only; a headless frame includes Godot's idle sleep, so this isn't a GPU number; `handoff/bench-export.txt`).

## The frame I looked at
`handoff/shots/demo_high/t010.0s.png` (export, `--demo --graphics=high`, 10 s, 1080p, lavapipe). Every face reads
correctly: eyes, brows and mouths in place. The bouncy balloon shows its smug face mid-wobble, so the wobble scale
still animates, and the crate under the green ring has its face on. Also `demo_auto/t004.0s.png`,
`demo_auto/t010.0s.png` (low tier) and `wide_auto/t010.0s.png`.

## Expected on the 1060
- Every frame does less main-thread work: ~560 fewer render instances re-sent a frame on average (~690 -> ~40 on a
  frame with no step). At ~0.7 us each here, plus the node-side notifications, that's about 0.5-1 ms a frame on this
  CPU and maybe 1-2 ms on the box. It falls most on the frames that carry a physics step, which are the slow ones.
- That's a few fps on the 1%-low at most (42 -> ~45-47 is my guess), not 42 -> 50. Headless busy time at p99 is
  only 4-6 ms here, so most of the box's 24 ms dip frames are render-side main-thread work or GPU, which this lane
  can't see. hitch-3's renderer probe had viewport render CPU at p99 2.4-3.6 ms.
- Cold run: nothing in the boot path changed, so the "no frame over 200 ms" result should hold.

## Next candidates (not done)
- On the box, log `Performance` and frame times with the renderer on, using the probe's split (`.scratch/p4_node.gd`
  works with a renderer too). If the dips are frames with 2 physics steps, look at physics interpolation or the
  step cost. If they're render CPU, profile with the Godot profiler on the box.
- Zap frames (`_press` 4-6 ms here): the bark line load and the zapped-signal listeners.
- Small same-value writers left: `yard_dressing` sky follow, `reset_sign_fx` bulbs' material every frame,
  `YardFan` blades `rotate_z(0)` while off.

## IDs moved
- **S-18**: stays `partial`. Note extended with the hitch-4 change, the numbers and the expected effect; evidence
  adds object_face.gd `_put_pos`, physics_object.gd `_physics_process`, test_hitch_4.gd.
- No other IDs moved.
