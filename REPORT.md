# REPORT: fix/jyz-rules-followup-1 (feel-rules follow-up)

Follow-up to the feel-rules audit (PR #45, `fix/jyz-rules-audit-1`; its report: `git show 42491b1:REPORT.md`).
Base: `origin/dev` @ `42491b1` (`git fetch` + merge: already up to date). Builds the producer's call on
"Needs a gameplay decision" items 1 and 2 (Kaden's rule 5, every press answers). Items 3 (button hints in
play) and 4 (what New yard resets) are not touched.

**Tests:** `rm -rf .godot && godot --headless --import --path . ; godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --continue` → **Overall Summary: 387 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |** (log: handoff/test-output.txt).

## What changed

Gary's call (2026-11-13, now a dated line under GAME.md "Decisions made without Kaden"): a press that does
nothing gives a **soft refusal tick**, the same `"nope"` cue as the statue refusal, at most once every 0.25 s
per player.

| Press (in play) | Before | Now |
| --- | --- | --- |
| X, Y, LT, RT, L3, R3 (fresh press) | silent, nothing | `"nope"` tick, nothing else |
| Same, held down | silent | one tick at the press, no repeats |
| B in the air, past coyote time, no landing inside the jump buffer (0.15 s) | silent, nothing | `"nope"` tick when the buffer runs out (≤ 0.15 s after the press) |
| B that jumps: ground, coyote, buffered into the landing | jump sound | unchanged, silent apart from the jump |
| Anything in pause / menus | — | unchanged (refusals only when `Game.state == PLAYING`) |
| D-pad, stick, Start fresh, statue refusal, menus | — | unchanged |

- `scripts/players/zapper.gd`: `_read()` gets `"unbound"` from `_unbound_down()` (raw buttons X, Y, L3, R3 and both
  trigger axes > 0.5 on `Players.device_of(player)`; in solo only the focused player reads the pad, so one
  press never ticks twice; keyboard / virtual has none). `_soft_refusal()` plays `"nope"` and shares the
  statue refusal's 0.25 s gap (`_statue_nope`), so a player never ticks more than 4 times a second whichever
  path refuses. The air B is tracked by `_air_jump_pending`: set on a fresh B press when coyote time is spent,
  cleared when the jump (incl. buffered) fires, refused when the buffer runs out. `project.godot`'s input map
  is not touched (the buttons are read raw, like `Players.start_held()` reads Start).
- **No ice chips / no puff.** `_statue_refusals()` does have a puff, but it is the ice chips (the frozen
  player's cause); the brief rules out ice chips, so the soft refusal is the tick only.
- **Audio-only:** there is no visual to frame, so no real frame was taken. The cue is proven by the test suite
  (`Audio.history`), not by a frame.
- The demo bot (`--demo`) only presses B when stuck, which is on the ground, so the attract mode stays quiet in practice.

## Tests (tests/test_feel_rules.gd, fixed settings + picks files, fixture roster)

- `test_an_unbound_button_in_play_refuses_once_per_gap`: one tick; a second press 6 frames later does not tick;
  a press past the gap, held 30 frames, ticks once; the player did not move and the gun did not change.
- `test_an_unbound_button_is_silent_outside_play`: paused → no tick.
- `test_a_b_press_in_the_air_refuses`: falling from 6 m, B → one `"nope"`, no `"jump"`.
- `test_a_b_press_that_jumps_does_not_refuse`: a ground jump, then a buffered jump (dropped 0.4 m, B after
  coyote time, before the landing): a `"jump"` each, no `"nope"`.

## PLAN-STATUS

- **R-05 → built** (proof: test_feel_rules.gd::test_an_unbound_button_in_play_refuses_once_per_gap,
  ::test_a_b_press_in_the_air_refuses, ::test_a_b_press_that_jumps_does_not_refuse). Moved in the same commit as the code.
- **R-07 stays partial:** button hints in play are still Kaden's call (PF-4 "pictures only", kid-design no reading
  in gameplay). Nothing added to the HUD.
- Totals: 195 rows: **built 177 · partial 3 · missing 0 · superseded 11 · later 4 · dropped 0**.

## Note on the suite

The first full run (on commit 6055388, same code) had 2 failures in `test_exit_watchdog.gd::test_a_shutdown_that_never_ends_is_ended_by_the_watchdog`: the child Godot process it spawns did not reach its "PASS" line in time while the rest of the suite was running. That suite on its own: 5 / 0 errors / 0 failures, and the second full run was clean (the line above). The suite does not touch the zapper; it looks like a timing flake on the producer box under load, and it is worth watching if it comes back.

## Still needs a decision (unchanged from the audit)

1. Button hints in play (rule 7, R-07): Kaden.
2. What "New yard" resets (whole save vs keep the trophy shelf): Kaden.
