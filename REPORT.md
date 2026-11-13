# REPORT: feature/press-answers-adopt-1 (press-answers adoption)

Kaden's standing rule 5 (every press answers): a menu press that does nothing must say so. The template
fixed its menu kit on `feature/template-press-answers-1` (openjar-template commit `9d99f29`). This lane
adopted that fix into Junk Yard Zap's own menu kit and gave this game's own menu screens the same
refusal.

Base: `origin/dev` @ `42491b1` (after PR #45). `git fetch origin && git merge origin/dev` was already up to
date. The previous root REPORT.md (feel-rules audit, jyz-rules-audit-1) is at `git show 4156c43:REPORT.md`.

## PLAN-STATUS: no FR rows here

This game's PLAN-STATUS has no rows named FR-5 or FR-3. Kaden's feel rules are the rows R-01..R-08:
- **Rule 5 is R-05.** It stays **partial**. Its open half is in play (X, Y, LT, RT and the stick clicks
  do nothing in play, and B in mid-air does nothing), and that needs a gameplay decision this lane must
  not make. Its note now says the menu half is built (M-07).
- **Rule 3 is R-03** (pause and back out). It was already built; this lane did not touch it.

**Rows moved:** **M-07** added as **built** (S17, the menu half of rule 5). **R-05**: the note was
updated and the status stays partial. Totals: 196 rows, built 177, partial 4.

## What changed

The template commit was merged file by file with `git merge-file`: the base was the template before the
fix (`9d99f29~1`), "ours" was this game's file and "theirs" was the template after the fix. No `.tscn`
was changed, and nothing changes in gameplay code, art, audio files or the save format.

| File | How |
| --- | --- |
| `scenes/ui/kit/menu_input.gd` | Merged by hand. This game's D-pad edge code stays (it is solo-focus aware, and R-01's D-pad also feeds the move actions). Added from the template: `other` and `button` in `read()`, `refuse()`, `owned_elsewhere()`, `_other()` (triggers count once per pull, a join press is not a refusal, the solo hold is not a refusal, a button already held when a menu opens is not a press). `_other()` is cached per frame, so a second `read()` in the same frame sees the same press. **`REFUSE_CUE` is `"nope"`** (see below). |
| `scenes/ui/kit/menu_item.gd`, `scenes/ui/icon_button.gd` | `wobble()`, `pose_wobble()`, `is_wobbling()` and `wobbles` from the template. The template's `slam_in` vars were not taken for `icon_button` (this game's icon button has no slam). |
| `scenes/ui/kit/ui_sound.gd` | Took the `plays` counter that tests read. **Left out** the template's synth `honk` cue (see below). |
| `scenes/ui/pause_menu.gd`, `settings_panel.gd`, `confirm_dialog.gd` | Template refusals, merged cleanly. |
| `scenes/ui/lobby.gd` | Template refusals, merged (the header conflict kept both notes). **Changed for this game:** Start already has a job in the lobby (PF-5: ready, then start), so `_process` never refuses `"start"`. Instead, `press_start()` refuses when Start has nothing to do: counting down already, or ready and waiting for the other player (before, that press was silent). |
| `scenes/ui/settings_panel.gd` (game-only row) | **Restore old yard**: left/right and X, Y, LB, RB, LT, RT, L3, R3, Select and Start (in the lobby) used to return silently. Now they refuse and the row wobbles. A still asks. |
| `scenes/ui/fresh_card.gd` (game-only screen) | The **New yard / Restore question** card: stick or D-pad moves and the same unused buttons were silent. Now they refuse and the whole card shakes (`wobble()`, 3 shakes, 16 px, 0.32 s, the same feel as a bar). Nothing else changes: the ring keeps its fill, A-hold and B work as before. |
| `scenes/ui/kit/ui_preview.gd`, `scripts/tools/shots.sh` | `--ui=lobby-refuse` and `--ui=pause-refuse` from the template (`pause-refuse` was adapted: this game's Door is the fifth bar, not an icon). New: `--ui=lobby-fresh-refuse`. |
| `docs/press-answers.md` (new), `docs/ui.md` | The before and after tables for this game, the `nope` cue row, the "Every press answers" section, the new screenshot states. |
| `tests/test_press_answers.gd` (new) | 13 tests (below). |
| `PLAN-STATUS.md` | S17, M-07, the R-05 note, the header and the totals. |

### The refusal sound is `nope`, not `honk` (please check this)

The template plays `honk`, which is a game's own `honk.ogg` if it has one, or else a synth stand-in.
Junk Yard Zap has no `honk.ogg`. Its `test_launch_ready.gd::test_every_menu_cue_is_a_designed_file_not_the_synth`
requires every `UiSound` cue to be a real file, so it **failed** with the template's synth `honk` in the
cue list (first full run: 391 cases, 1 failure). Adding audio is off-limits for this lane. So the menus
here play the yard's own refusal, **`nope`** (`nope_1/2.ogg`, 0.35 s, the same sound the zapper makes on
a refused press). The game now has one "no" sound. If Kaden wants a separate menu honk, that is a job
for the Audio lane: add `assets/audio/sfx/honk.ogg`, put the `honk` cue back in `UiSound.CUES`, and set
`MenuInput.REFUSE_CUE = "honk"`.

## Screen by screen (after)

| Input | Lobby (start menu) | Pause list | Settings | Leave the game? | New yard / Restore card (game-only) |
| --- | --- | --- | --- | --- | --- |
| X, Y, LB, RB, LT, RT, L3, R3 | refuse | refuse | refuse (also on Restore old yard) | refuse | refuse, the card shakes |
| Up / down | move (unchanged) | move (unchanged) | row (unchanged) | move (unchanged) | refuse, the card shakes |
| Left / right | chooser (unchanged); locked podium: refuse | step the list (right = down); past the end: refuse | step (unchanged); Restore old yard: refuse | move (unchanged) | refuse, the card shakes |
| Start | ready, then start (PF-5, unchanged); nothing to do: refuse | resume (Game, unchanged) | in pause: resume; in the lobby: refuse | in pause: resume; in the lobby: refuse | refuse, the card shakes |
| Select | solo: switch podium (unchanged); otherwise refuse | refuse | refuse | refuse | refuse, the card shakes |
| B | un-ready / back to Play (unchanged); not ready on Play: refuse | resume (unchanged) | close (unchanged) | Stay (unchanged) | keep the yard (unchanged) |

The full before / after table is in `docs/press-answers.md`.

## Tests

`tests/test_press_answers.gd` has **13 tests**, at least one per menu screen. Each one sends real pad
events (devices 5 and 6) to a booted `main.tscn`, then checks that the refusal counted, the `nope` cue
played, the focused item wobbled, and nothing else changed (state, focus, ready, picks, settings values,
backups, and the question still open):
- Lobby: `test_lobby_unused_buttons_refuse_and_change_nothing`,
  `test_lobby_start_readies_then_refuses_when_it_has_nothing_to_do` (new for this game),
  `test_lobby_b_with_nothing_to_back_out_of_refuses`, `test_lobby_join_press_is_not_a_refusal`,
  `test_lobby_left_right_on_a_locked_podium_refuses`, `test_lobby_select_in_solo_still_switches`
- Pause: `test_pause_unused_buttons_refuse_and_change_nothing`,
  `test_pause_left_right_cycle_then_refuse_at_the_end` (five rows),
  `test_pause_start_still_resumes`
- Settings: `test_settings_unused_button_refuses_and_changes_nothing`,
  `test_settings_restore_row_refuses_left_right_and_unused_buttons` (game-only row)
- Leave the game?: `test_confirm_unused_button_refuses_and_stays_open`
- New yard card: `test_fresh_card_unused_presses_refuse_and_keep_the_question` (game-only screen)

The suite runs on its own profile (`gdunit_press_answers`), its own settings file
(`user://test_settings_press_answers.json`, which a test asserts), and its own picks file. It never uses
the real settings or save.

**Full suite** (clean import: `rm -rf .godot`, `godot --headless --path . --import`, then
`godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode`):
exit 0, `Overall Summary: 396 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`.
Before this lane: 383, all green. 383 + 13 new = 396. The suite log is `handoff/test-output.txt`.

## Frames (real renders, `scripts/tools/shots.sh`, Forward+ on the software GPU)

I looked at all three. The shake is held at 0.92 (`pose_wobble`), so the bar or card sits about 16 px
off its place. In a still frame a sideways shake reads weakly; the template notes the same.
- `handoff/frames/press_pause_refused_right_on_door.png` (`--ui=pause-refuse`): paused by P2, Back to
  Open Jar focused, right pressed (no row that way), the bar mid-shake.
- `handoff/frames/press_start_menu_refused_x_on_continue.png` (`--ui=lobby-refuse`): the start menu with
  a saved yard (Continue / New yard). P1 is ready and P2 is choosing. X was pressed, and the Continue bar
  is mid-shake.
- `handoff/frames/press_new_yard_card_refused_x.png` (`--ui=lobby-fresh-refuse`): "START A NEW YARD?"
  with X pressed, the card mid-shake (shifted right). Nobody is ready and New yard is focused behind it.

`handoff/` is in `.git/info/exclude`, and frames are untracked by this repo's convention (PLAN-STATUS
"Frame paths"). They are in this worktree.

## For the producer / Kaden

1. **`nope` instead of `honk`** for menu refusals (above). Please confirm, or send it to the Audio lane.
2. **Lobby Start now refuses** when it has nothing to do (ready and waiting for the other player, or
   counting down). Before, that press was silent; the status line already says "Waiting for Player 2".
3. **On the New yard card the footer still reads "Move / Select / Back".** That is the lobby's footer
   hint (R-07 area), and while the card is up a move now refuses. I did not change it; it is a small
   hint tweak if wanted.
4. **R-05 stays partial**: what is left is silent X, Y, LT, RT and stick clicks in play, plus B in
   mid-air. That needs a gameplay decision.
5. Pause left/right do not wrap (as in the template): they refuse at the ends.
6. Not pushed (the producer ships).
