# Launch checklist: Junk Yard Zap

Kaden, 2026-11-10: "I would like to have Spaceballs, Junk Yard Zap, and the Launcher done besides
running it on the TV hardware." Kaden, 2026-11-12: every game "in launch ready state besides testing
on 1060 device".

**Checked against `origin/dev` @ `b70c955`** (PR #48, press answers, on top of #49 hint panel, the
pause door, the rules audit, hub refusal and the plan syncs of 2026-11-13) by the launch-readiness
third pass (`feature/jyz-launch-ready-3`, 2026-11-14). Earlier passes: launch-ready-1 (2026-11-11),
launch-ready-2 (2026-11-12). Numbers and frame notes: `REPORT.md`. Rows: `PLAN-STATUS.md` (L-01..L-18).

Status: **launch-ready except the TV box.** PLAN-STATUS has 0 missing rows; the two partial rows are
C-14 (needs playtest #2 on the TV) and S-18 (needs the GTX 1060 frame rate).

## Standing rules

| Rule | Yes / no | Proof |
| --- | --- | --- |
| No stick-only requirement (D-pad everywhere) | yes | R-01: `tests/test_dpad_moves.gd`; L-02: `test_launch_ready.gd::test_the_d_pad_moves_the_lobby_cursor_and_the_pause_menu`; session flow drives every menu with the D-pad |
| No auto-steering the player | yes | R-06: `test_dpad_moves.gd` (an idle pad's player never moves). Aim assist snaps the beam, not the player |
| Gear is worn | yes | P-03: `test_jyz_chooser.gd::test_gear_equips_on_the_picked_body`, `test_art.gd::test_every_gun_is_gear_with_a_muzzle_and_player_tape` (gun on `hand_r`, belt on `waist`) |
| Progress is earned behind visible barriers | n/a (yes by design) | Nothing in the yard is locked or gated (GAME.md "No fail state"); the only progress is the goal-card deck, shown on the sign and the trophy shelf (G rows) |
| Each vehicle or tool has a job only it can do | yes | U-01 seven guns, one effect each (GAME.md "The guns"); `test_greybox.gd::test_belt_has_seven_guns_in_belt_order` and one test per gun (`test_greybox.gd`, `test_balloons.gd`, `test_gap_close_4.gd`) |
| Anything that changes play shows its cause | yes | R-08, Y-20..Y-22: `tests/test_gap_close_4.gd`; partner effects ring in the zapper's colour |
| No real places or personal details | yes | L-14: `test_launch_ready_2.gd::test_shipped_data_names_no_one_real`, `::test_the_export_never_ships_the_design_doc_or_any_notes` |
| Solo is session-only, never restored at boot | yes | S-25 / R-04: `test_lobby.gd::test_saved_solo_stays_off_at_boot`, `test_feel_rules.gd::test_solo_remembered_in_settings_is_off_at_boot`; frame `handoff/frames/launch3/solo_flag_boot.png` (`--solo`) and `handoff/frames/flow3/*solo_on*.png` (Select+Start 2 s) |
| Saved toggles never restore at boot | yes for the mode toggle (solo); see "Needs Kaden" for Screen shake | Settings has one mode toggle (Solo, above) and one comfort toggle (Screen shake), which is kept like the volume sliders |
| Continue and New from the menu; New asks first and keeps the old save as a backup | yes | R-02: `test_fresh_start.gd::test_a_saved_yard_shows_continue_and_new_yard_and_loads_as_left`, `::test_new_yard_asks_with_a_hold_then_keeps_the_old_save_as_a_backup`, `::test_settings_restore_brings_the_old_yard_back_and_deletes_nothing` |
| The pause menu has a big icon back to the launcher | yes | R-03: `test_lobby.gd::test_pause_door_asks_then_quits`; frame `handoff/frames/flow3/*_pause.png` (Back to Open Jar bar with the door glyph) |
| Quit never needs a force-close | yes | PF-6: `test_exit_watchdog.gd`; session flow steps `menu_door_leave_quits`, `pause_door_leave_quits`, and a window close on every screen |
| Every press answers (sound and visual) | yes | R-05, M-07: `tests/test_press_answers.gd`, `test_feel_rules.gd` |
| Show the buttons that matter | yes | R-07: `tests/test_hint_panel.gd` |

## Verified on the producer box (2026-11-14, dev @ b70c955)

- [x] Full gdUnit suite green after a clean import, with `--continue` (count in `REPORT.md`).
- [x] Whole session in real frames (`scripts/tools/session_flow.sh handoff/frames/flow3`): boot,
      chooser, settings, both doors, two players ready, play, Select tap / hold, drop-out / drop-in,
      pause, settings, Reset Yard, Main Menu, **one player ready and hold A alone**, **Back to Open Jar
      from the main menu quits**, solo on (Select+Start 2 s) / swap / off, pause door quits.
- [x] `--solo` boots with the solo marker and both players in.
- [x] 30-minute demo soak (`--fixed-fps 60 --quit-after 108000 -- --demo --soak`): 0 script errors.
- [x] No placeholder text, no debug switch on a pad: F3 (FPS) and F12 (screenshot) are keyboard only;
      stdout prints are not on screen.
- [x] Title, lobby, hub and pause text read as finished (`JUNK YARD ZAP`, Play / Continue, New yard,
      Settings, Back to Open Jar; PAUSED, Resume, Reset Yard, Main Menu, Settings, Back to Open Jar).

## Needs the TV box (weekend, Kaden)

- [ ] **60 fps on the GTX 1060** (S-18, L-11): launch from the tile, both pads in, press F3 on a
      keyboard; zap every object in the yard with grow, balloon, bouncy and magnet for a minute and
      glue a few pairs. Pass: the F3 number stays at 60 (note the lowest you see).
- [ ] **First pad is P1 (green)**: with both 8BitDo pads on, press A on the pad you want as P1 first.
      Pass: that pad's podium is green; the other pad's A makes P2 red.
- [ ] **Drop-out / in**: mid-game, switch P2's pad off. Pass: P2 goes to the tire pile asleep; switch it
      on and press A: P2 wakes up where they were.
- [ ] **Select hold vs Select+Start**: hold Select 1.5 s (ring fills, the yard resets); hold
      Select+Start 2 s (solo icon top left). Pass: neither does the other's job.
- [ ] **Hold A alone**: one pad, press A on Play, then hold A. Pass: the bar fills and the game starts
      without the second player.
- [ ] **Launcher round trip**: start from the tile, play, pause, Back to Open Jar, Leave. Pass: the
      launcher is back within a few seconds with no force-close; also close the game on the title
      screen in the first few seconds (PF-6).
- [ ] **Sound on the TV speakers**: music under the zaps, menu cues not too loud.
- [ ] **Read from the sofa**: the goal cards, gun icons and the in-play hint glyphs.

## Load steps for the build

1. Gary merges `feature/jyz-launch-ready-3` into `dev` and tags the next `vX.Y.Z-dev.N`; the release
   workflow tests, stamps the version, exports Linux, smoke-tests the binary and attaches
   `junk-yard-zap-<tag>-linux.zip` to the Release.
2. On the TV box the launcher picks up the dev release on its `(dev)` tile (hold LB+RB on the launcher
   to show dev tiles for that run).
3. Check the lobby footer shows the tag, then run the TV-box list above.
4. After the TV check and playtest #2, Hermes promotes to `main` (`v1.0.0`, C-15).

Local build without the launcher:
`godot --headless --path . --export-release "Linux" build/game.x86_64`, then `build/game.x86_64`.

## Needs Kaden

- [ ] Playtest #2 of the S9 changes (closes C-14), then `v1.0.0` on the main tile (C-15).
- [ ] Screen shake is a saved on/off and comes back at boot, like the volume sliders. Keep it
      (a comfort preference), or reset it every boot like solo?
- [ ] Optional: the "Decisions made without Kaden" in GAME.md are still open for him to confirm.
