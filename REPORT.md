# REPORT: fix/jyz-rules-audit-1 (Feel-rules audit)

Kaden's standing game-feel rules (first audited on Worm, 2026-11-13), checked against Junk Yard Zap on
`origin/dev` @ `f6e3b9b` (after PR #44), in code, in headless runs (main.tscn booted with a save present)
and in real frames. Two rules failed outright and are built here (D-pad in play, start fresh). Two are
partial and wait on a gameplay decision (below). PLAN-STATUS: new source S16, rows R-01..R-08.

**Tests:** `rm -rf .godot && godot --headless --import --path . ; godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --continue` → **Overall Summary: 383 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |** (full log: handoff/test-output.txt). New suites: test_dpad_moves.gd (6), test_fresh_start.gd (7), test_feel_rules.gd (4).

## Rules

| # | Rule | Before (dev @ f6e3b9b) | Now | Where |
| --- | --- | --- | --- | --- |
| 1 | D-pad everywhere | **Fail in play.** project.godot binds `p1_/p2_move_*` to the left stick and keys only; the player reads `Players.move_vector()` (Input.get_vector on those actions), so the D-pad moved nothing in play. With the fix switched off, test_dpad_moves.gd fails on all 8 move actions. Menus were fine: MenuInput (pause, Settings, the leave question) and the lobby chooser read the D-pad. No end card in this game | **Pass.** `Players.add_dpad()` at boot puts the D-pad beside the stick on all 8 move actions; `_rebind` keeps each pad on its own player and solo copies it like the stick. D-pad up / down are the stick's up / down (grow vs shrink, aim). Menus do not double-step (they assign the move, not add it) | scripts/autoload/Players.gd; tests/test_dpad_moves.gd (6: per pad slot 1 and 2, up/down, solo, pause cursor once per press, the map) |
| 2 | Start fresh | **Fail.** No Continue / New: the menu was Play, Settings, Back to Open Jar. Only Reset Yard (objects back; deck, trophies and guns kept). No backup, no Restore | **Pass.** With a yard saved: **Continue** and **New yard**. New asks first (hold A 1.5 s on a ring; a tap empties it with a back tick; B keeps the yard), saves the yard as it is, writes the whole save to `user://saves/backups/<profile>--<UTC stamp>-<n>.json` (never deleted), then the layout's yard and a new deck (shelf empty). **Settings > Restore old yard** (only in the lobby, only with a backup) brings the newest backup back after backing up the yard it replaces (a second Restore undoes the first). Pause > Main Menu reaches it. A save that cannot be backed up is never wiped | scripts/levels/fresh_start.gd, scenes/ui/fresh_card.gd, scenes/ui/lobby.gd, scenes/ui/settings_panel.gd, Save.gd `data()` / `replace()`, yard_level.gd `fresh_yard()` / `reload_from_save()`; tests/test_fresh_start.gd (7, main.tscn with a save present); frames below |
| 3 | Pause and back out | Pass: pause has Back to Open Jar with the door picture, asks first; Game.quit arms the PF-6 exit watchdog | Pass, unchanged (exit path not touched) | scenes/ui/pause_menu.gd; test_lobby.gd::test_pause_door_asks_then_quits; test_exit_watchdog.gd |
| 4 | Solo mode | Pass: `--solo`, Select + Start 2 s (either order), the solo marker, off by default, `solo_playtest` setting written but never read at boot; suites use their own settings files | Pass; now under test that a remembered "on" stays off at boot | Players.gd, solo_marker.gd, lobby.gd `_ready`; test_lobby.gd::test_select_start_hold_toggles_solo; test_feel_rules.gd::test_solo_remembered_in_settings_is_off_at_boot |
| 5 | Every action beeps | **Partial.** Zap, sparkle on nothing, refusals (Y-20..Y-22), jump, land, gun wheel, Select hold, pause, every menu move all sound. Silent: a frozen partner (statue, up to 1 s) ignored A, B, LB, RB without a sound; unbound buttons (X, Y, LT, RT, stick clicks) in play; B in mid-air after the jump buffer | **Partial.** Statue presses now refused out loud ("nope" + ice chips; a button already down when the freeze hit does not count; at most one per 0.25 s). The rest needs a decision (below) | scripts/players/zapper.gd `_statue_refusals()`; test_feel_rules.gd (2) |
| 6 | No forced movement | Pass: `velocity.x` comes only from the move vector; no snap or hop-to-target. Partner zaps (bouncy, balloon, grab) lift the partner up to 1 s with the zapper's beam and ring as the cause; aim assist snaps the beam, never the body | Pass, unchanged | zapper.gd `_physics_process`, `partner_zap` |
| 7 | Show the buttons that matter | **Partial.** Every menu has a glyph hint, but each was fixed text: the lobby always said "Move / Select / Back" (never "pick", "ready", "hold A to start"). Play shows no hints (PF-4 chose pictures only; the pause card lists the controls) | **Partial.** The lobby footer follows focus and join / ready ("[a] Join in", "[lr] Pick who you play [a] Ready", "Hold [a] Start [b] Not ready", "[a] New yard (asks first)"); Settings names Restore on its row. Play: needs a decision | scenes/ui/lobby.gd `hint_text()`, settings_panel.gd `_set_focus()`; test_feel_rules.gd::test_lobby_hint_follows_focus_and_readiness |
| 8 | Every cause shown | Pass: Y-20..Y-22 (held by someone else, size caps, glue limits) show their cause; reset shows the resetter's ring; partner effects show the zapper's ring | Pass; the refused statue press shows ice chips off the frozen player | test_gap_close_4.gd; zapper.gd |

## Frames (real, `scripts/tools/shots.sh`, software Forward+)

Staged by `-- --fresh-ui=<state> --profile=shots_fresh` (scripts/tools/fresh_preview.gd, yard-own; it refuses
to stage on `p1`). The throwaway profile's save, backup and settings were deleted afterwards; `p1.json` and
`settings.json` were not touched (mtimes 12:35 and 2026-11-10). Untracked, in this worktree:

- `handoff/frames/rules_start_menu_continue_new_yard.png`: Continue, New yard (focused), Settings, Back to Open Jar; footer "[a] New yard (asks first) [ud] Move [b] Back". The first shot had the 4th bar over the "PLAYER 1 READY" status; fixed (the bars tighten when there are four) and re-shot.
- `handoff/frames/rules_new_yard_hold_a_question.png`: "START A NEW YARD?", the ring 60 % full around the A glyph, "[a] Hold: new yard [b] Keep my yard".
- `handoff/frames/rules_settings_restore_old_yard.png`: Settings with the Restore old yard row focused; hint "[a] Restore (asks first)".
- `handoff/frames/rules_restore_hold_a_question.png`: "RESTORE YOUR OLD YARD?" over Settings.

## Found along the way

- **Continue appeared late on a first-time profile.** Leaving play saves the yard after the lobby has already opened, so the bars still said Play. The lobby now follows `Save.saved`. Caught by test_launch_ready's session flow; test_fresh_start.gd::test_a_save_made_while_the_lobby_is_open_shows_continue.
- **Suites share whatever save is in memory.** Changing `Save.profile` does not reload `Save._data`, so a suite's first save can be another suite's yard (or, before the first write, the box's own `p1` data in memory; nothing writes it, since `_path()` follows the profile). test_lobby.gd and test_launch_ready.gd now start every case with `Save.replace({})` on their own test profile; test_fresh_start.gd and test_feel_rules.gd use their own profiles.
- `scripts/tools/session_flow.gd` and `player_flow.gd` step down the lobby menu by count; both now step past New yard when a yard is saved.

## Needs a gameplay decision (not decided here)

1. **Unbound buttons in play (rule 5).** X, Y, LT, RT, L3 and R3 do nothing and say nothing. The rule says a press with no effect should say so; docs/kid-design.md allows "ignored or harmless and funny". Options: a soft refusal tick, a harmless gag (a burp, a wave), or leave them silent.
2. **B in mid-air (rule 5).** A B press in the air past coyote and buffer time does nothing, silently. A refusal there could feel like a scolding on every double-tap.
3. **Button hints in play (rule 7).** Play shows no button glyphs (PF-4: "pictures only"; kid-design: no reading in gameplay). Glyph-only hints are possible (an A glyph over the Reset Yard sign when a player stands at it, LB/RB by the gun badge for the first minute), but that changes the HUD's look and the kid-design call.
4. **What "New yard" resets.** Built as the whole save (yard, deck, trophy shelf, last guns), because "start fresh" reads as a new game and Reset Yard already covers "objects back". If Kaden wants New to keep the trophy shelf, it is one line in `YardLevel.fresh_yard()`.

## Template gaps (openjar-template)

- `project.godot` binds the move actions to the stick and keys only; every game must add the D-pad in code (The Hill, Worm, now this yard). The template should bind `JOY_BUTTON_DPAD_*` on `p1_/p2_move_*` itself.
- `scenes/ui/kit/ui_preview.gd` has no way for a game to add its own `--ui=` states; this lane added a yard-own `--fresh-ui=` instead.
- `HintLine` text is static per screen in the template's lobby / settings scenes; context hints are game code here.
- `SettingRow` has only SLIDER and TOGGLE; an action row (Restore) is a plain MenuItem here, so Settings' `adjust()` had to learn to skip it.
- `Save.profile` can change without `_data` reloading; tests that switch profile inherit the boot profile's data in memory. A `Save.use_profile(id)` that reloads would close it.

## Commits (not pushed)

- `0a4fac3` systems: the D-pad moves the character in play (feel rule 1)
- `eb590ba` systems: start fresh: Continue, New yard (held A, backup), Restore
- `669ec11` gameplay: a press on a statue beeps; menu hints follow focus
- `1e6d0fe` systems: four menu bars clear the status line; Start fresh shots tool
- `d2903e4` systems: Continue / New follow the save; test saves start empty
- the docs commit (REPORT.md, handoff/handoff.json, handoff/test-output.txt): `git log -1`
