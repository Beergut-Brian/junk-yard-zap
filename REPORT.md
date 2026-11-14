# REPORT: feature/jyz-launch-ready-3 (launch-readiness, third pass)

Base and checked head: `origin/dev` @ `b70c955` (PR #48 press answers, on top of PR #49 hint panel and
the 2026-11-13 merges: pause door, rules audit, hub refusal, plan syncs). Not pushed. The previous root
REPORT.md (press-answers-adopt-1) is at `git show b70c955:REPORT.md`.

**Verdict: Junk Yard Zap is launch-ready except the TV-box checks.** Nothing open needs code. The two
partial rows are C-14 (playtest #2 on the TV) and S-18 (GTX 1060 frame rate), both Kaden's weekend item.

## What changed

- `scripts/tools/session_flow.gd`: six new steps between Restart and Solo. **Ready-up alone:** P2 unplugs,
  P1 readies, holds A on Play until the bar fills, plays alone, Main Menu back to the lobby. **Quit from
  the main menu:** Back to Open Jar asks "Leave the game?", Leave calls `Game.quit` (no force-close).
  Two harness notes in the code: the hold drives P1's bound action (a synthetic pad is not in
  `Input.get_connected_joypads()`, the same limit the Select-hold step already works around), and it
  waits for the bar rather than 1.5 s of wall clock (on the software renderer frames lag the clock;
  headless it fills in 1.5 s as designed: probe printed hold 0.41 / 0.81 / 1.22 s, then the countdown).
- `PLAN-STATUS.md`: header (checked against b70c955), source S18, row **L-18** added as built, totals.
- `docs/launch-checklist.md`: rewritten (standing rules yes/no with proof, TV-box checks with the exact
  test and pass condition, load steps, the dev head).
- No game code changed: the audit found nothing in the game to fix.

## Rows moved

| Row | Move | Proof |
| --- | --- | --- |
| L-18 | added, **built** | session_flow.gd steps `ready_p1_alone` .. `menu_door_leave_quits`; `test_launch_ready.gd::test_the_whole_session_flows_with_a_way_back_from_every_screen`; frames `handoff/frames/flow3/24_hold_a_alone_starts.png`, `27_menu_door_asks.png` |
| Totals | corrected | 197 rows: built 180 · partial 2 · missing 0 · superseded 11 · later 4. The line before had missed M-07 (PR #48) |

Open rows re-audited, not moved: **C-14** partial (needs playtest #2 on the TV, a playtest result is not
invented here); **S-18** partial (sleep-when-still is built and tested; the GTX 1060 number needs the
TV box). Later rows untouched: C-15 (v1.0.0 after playtest #2), C-20, G-12 (after v1), L-11 (TV box).

## Skipped (and why)

- **C-14**: playtest #2 on the TV; Kaden's.
- **S-18, L-11**: GTX 1060 frame rate, the TV box, the 8BitDo pads on the TV; Kaden's weekend item.
- **C-15**: v1.0.0 promotion after playtest #2; Hermes.
- **C-20, G-12**: out of scope for v1 / update decks.
- **Art rows (none open, none touched)**: art, palette, logo, store art and jar rows follow the Art
  Director process. Not re-checked or rebuilt here: V rows, A-13, Y-04 art passes, `store/grid.png`,
  `store/hero.png`, `store/jar.glb`, `store/clip.mp4` (L-13), the lobby title logo. They are all built on
  dev already; this pass did not judge them.
- Nothing is waiting on a Docket pick.

## Placeholders, debug prints, dev switches

- No TODO / FIXME / placeholder / lorem text in shipped scenes, scripts or data (the three "placeholder"
  hits are code comments about the kit's fallback, never reached: L-04).
- `print` lines (`Chooser voice:`, `Audio soak:`, `Audio: no file for cue`) go to stdout only; nothing on
  screen. Left in: they are the soak and chooser logs the tools read.
- Debug: F3 (FPS overlay) and F12 (screenshot) are bound to keyboard keys only; no pad button reaches
  them. F3 is the tool for the GTX 1060 check, so it stays.
- Dev flags (`--demo`, `--soak`, `--solo`, `--screenshot-after`) are command-line only; a player can't hit them.
- Title, lobby and pause text read as finished (frames below).

## Session flow (real frames, software Vulkan, 1920x1080)

`scripts/tools/session_flow.sh handoff/frames/flow3`: **42 / 42 steps pass** (34 framed checks + 8
window-close checks, each a clean `Game.quit`). Headless run of the same flow: 42 / 42. Frames are in
this worktree, `handoff/frames/flow3/` (16 MB, untracked); six are tracked (23, 24, 27, 17, 29 and `launch3/solo_flag_boot.png`, listed in `handoff/handoff.json`). What each shows (I looked
at every one):

- 01 boot_lobby: title "JUNK YARD ZAP", Play / Settings / Back to Open Jar, two dim podiums "A JOIN", v0.1.0.
- 02 chooser: P1 joined, Astro Ana on the green podium. 03 full lap: back at Astro Ana after 21 / 21 Jarlings, each said its own catchphrase.
- 04 lobby settings: Music, Sound, Screen shake on/off, Solo playtest on/off, "Saved on this TV". 05 closed. 06 Back to Open Jar asks "Leave the game?" (Stay first). 07 stayed.
- 08 both ready: green Astro Ana and red Chuck "READY!", "Starting in 2", Continue / New yard shown (a save exists).
- 09 the "ZAP TIME! / THE YARD IS OPEN" card (the check fires during the wipe into play). 10 gun wheel popped over P1, both hint panels in the corners. 11 zap and jump.
- 12 Select tap: nothing. 13 Select hold ring filling. 14 yard reset.
- 15 P2 unplugged: asleep at the tire pile; P2's corner shows only "A" with a sun (press A to wake). 16 P2 back in: a sun burst over P2, P2's hint panel back.
- 17 pause: "PAUSED / PLAYER 1 PAUSED", Resume, Reset Yard, Main Menu, Settings, **Back to Open Jar bar with the door glyph**. 18-19 pause settings and back. 20 resumed with B.
- 21 Reset Yard from pause. 22 Main Menu back to the lobby, both still joined.
- 23 **ready alone**: P1 ready, P2 "A JOIN", footer "Press Start or hold A to start solo". 24 **hold A alone**: "PLAYER 1 READY 3 / Starting in 3", 1P tag. 25 "ZAP TIME!" card into play. 26 back to the lobby.
- 27 **main menu door**: "LEAVE THE GAME? Progress is saved. You'll go back to Open Jar." Stay / Leave. 28 after Leave (`Game.quit` fired once; the harness keeps the process alive, so the lobby is still drawn).
- 29 **solo on** (Select+Start 2 s): solo marker (green and red dots) top left, both podiums ready. 30 "ZAP TIME!" into play. 31 solo swap: the pad drives the other zapper. 32 **solo off**: marker gone.
- 33 pause door asks. 34 Leave quits (`Game.quit`).

Also: `handoff/frames/launch3/solo_flag_boot.png` (`--solo` at boot, 4 s): solo marker top left, both
zappers in the yard, both hint panels. Solo turns on only from the flag or the hold; a saved "on"
never restores (S-25 tests).

Drop-in / drop-out are 15-16 above; quitting from the menu without a force-close is 27-28 and 33-34,
plus the window close on 8 screens.

## Soak

`godot --headless --path . --fixed-fps 60 --quit-after 108000 -- --demo --soak` (30 simulated minutes,
this machine, software): **0 script errors**, 0 engine errors in play. The only ERROR line is the
engine's exit notice "1 resources still in use at exit" (the same line the clean import prints).
3382 zaps, 561 glues, 133-161 effects stacked, 0 orphans in every log line, 56 objects, 0 recalls. From
minute 20, nodes stay between 5094 and 5260 and follow the stacked-effect count; memory 223.1 -> 224.1 MB
over the last 10 minutes. Frame 6-11 ms mean (simulated time on a software box, not a frame-rate claim).

## Export

`godot --headless --path . --export-release "Linux" .scratch/b/game.x86_64` wrote the pack ("savepack
DONE"), then the editor process aborted on its own exit (core dump after DONE; the export is complete
and the binary runs). That is the engine shutdown issue PF-6 works around for the game; it does not
affect the release workflow's output, but CI should be watched. The binary: `--headless --quit-after 600
-- --demo` exit code 0, 0 script errors.

## Tests

Clean import (`rm -rf .godot && godot --headless --path . --import`), then
`godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode --continue`:
**415 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans**, exit code 0 (run twice:
once before the flow change while the soak and the rendered flow loaded the CPU, once after the
change on a fresh import). Log: `handoff/test-output.txt`.

- Roster and chooser tests use fixtures (`tests/fixtures/roster_three.json`, `roster_standin.json`,
  `roster_two.json`, `roster_voice.json`, `roster_comedy.json`). The one real-data test,
  `test_roster.gd::test_real_roster_is_jeff_and_chuck`, checks only the shipped defaults (Jeff P1, Chuck
  P2, no residents, every file present), never a count. The session flow's full lap counts the live
  roster on purpose (it is the real-game check, not a unit test).
- Physics-outcome tests in the full yard bench the bodies they are not about (`tests/fixtures/stage.gd`
  in test_balloons, test_greybox, test_playtest1, test_polish, test_sleep_when_still). The others do not
  depend on a pile: test_controls builds its own bare world, test_more_objects checks effect stacks and
  undo, and test_goal_deck either builds its own boxes on a `YardStrip` or carries the card's object by
  hand along waypoints and fails if it gets stuck.

## Needs Kaden

- **Screen shake** is a saved on/off that comes back at boot, like the volume sliders. The standing rule
  "saved toggles never restore at boot" came from mode toggles (the launcher's dev toggle, solo), and
  solo follows it. Keep shake as a comfort preference, or reset it every boot? Left as it is until he says.
- Playtest #2 on the TV (C-14), then v1.0.0 (C-15).
- The TV-box list in `docs/launch-checklist.md` (GTX 1060 at F3, both 8BitDo pads, hold A alone, Select
  hold vs Select+Start, launcher round trip, sound levels, read from the sofa).
