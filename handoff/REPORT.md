# Launch-readiness, second pass: report

Branch `feature/launch-ready-2`, based on `origin/dev` @ `cc2dec3` (after PR #37, roster v0.5.3).
`git merge origin/dev`: already up to date (fetch not needed; local origin/dev is current).
Resumed run (Gary, 2026-11-12 13:00): the first run of this pass stopped with uncommitted work; it was
checked, one flow bug fixed, and committed as `54932e7`.

## Audit (every PLAN-STATUS row against dev as it is now)

Dev since launch-ready-1 (f9ec4e4): PR #34 worm findings (docs), PR #35 yard-trophy (a PLAN-STATUS
reconcile only; dev still has one trophy shelf), PR #36 / #37 roster v0.5.2 and v0.5.3 (all 22
Jarlings now have a voice pack and a catchphrase; Chuck's "hey!" is his own voice).

| Row | Status | What this pass did / why it stays open |
| --- | --- | --- |
| C-14 | partial | Everything in the brief and playtest #1 is built and re-checked in real frames (below). Stays partial until playtest #2: **needs Kaden on the TV** |
| S-18 | partial | Soak on this machine below; the GTX 1060 number **needs the TV box** |
| C-15 | later | `v1.0.0` on the main tile after playtest #2 (**Kaden**) |
| C-20, G-12 | later | Out of scope for v1 (GAME.md) |
| L-11 | later | **Needs the TV box**: 60 fps on the GTX 1060, real pads, the real TV |
| P-11, M-06, A-12 | built | Notes were stale (roster v0.5.1, "18 of 22 voiced"); rewritten for v0.5.3: all 22 voiced, with proof |
| L-14 | built (new) | `GAME.md` (the family's first name, notes) no longer ships in the exported .pck; the launcher never reads it |
| L-15 | built (new) | The template's coloured-box placeholder player removed (never used); README updated |
| L-16 | built (new) | Chooser laps the whole v0.5.3 roster in the session flow: each Jarling says its own catchphrase |
| L-17 | built (new) | Session flow covers Select tap / hold reset; starts from default picks every run |
| Housekeeping | | The "do not merge yard-trophy" warning was stale (it merged as a reconcile); replaced |
| All other rows | built / superseded | Proofs still on dev: the full suite (below) runs every named test |

Playtest #1 rows re-checked in real frames this pass (`handoff/frames/`):
- U-20 gun icons and wheel: `playtest/wheel.png`, `flow/10_gun_wheel.png`
- U-21 switch preview and beams: `playtest/beams.png`
- G-19 goal cards and trophy shelf: `playtest/goal.png`, `playtest/trophy.png`
- S-27 Select-hold reset: `flow/12_select_tap_no_reset.png`, `flow/13_select_hold_ring.png`, `flow/14_select_hold_resets.png`, lit sign in every play frame
- S-28 variable jump: `playtest/jump.png`
Nothing looked rough.

## Session flow (scripted with synthetic pad events, real frames)

`scripts/tools/session_flow.sh handoff/frames/flow` (Forward+ on llvmpipe, 1920x1080):
**36 / 36 steps PASS, exit 0, 0 script errors**, 28 frames in `handoff/frames/flow/`, all looked at.
Boot -> lobby -> chooser (pick + catchphrase, then a full lap: 21 / 21 free Jarlings, 21 own
catchphrases, 0 wrong) -> lobby settings -> back -> lobby door (asks, stay) -> two players ready,
countdown -> play -> gun wheel -> zap and jump -> Select tap (nothing) -> Select hold (ring, reset)
-> P2 unplugged (tire pile) -> P2 back -> pause -> settings -> back -> resume (B) -> Reset Yard ->
Restart (to lobby) -> solo on (Select + Start 2 s) -> solo play -> swap -> solo off -> pause door
(asks) -> leave (quits). A window close on every screen (lobby, chooser, lobby settings, lobby door,
play, pause, pause settings, solo play) quits cleanly. No softlock; every screen has a way back.

Bugs found and fixed (both in the flow script, not the game):
- After the Select-hold reset, solo could not start: a synthetic pad is not in
  `Input.get_connected_joypads()`, so the Select release never reached `Players.hold_step` and the
  "this Select already reset" flag stayed set. The flow now feeds the release like the poll does.
  On a real pad the poll sees the release (test_controls covers the real rule).
- The full-lap check demanded a catchphrase from fixture Jarlings that have none (the game falls
  back to a bark, as designed). The check now follows the game's rule.
- The flow's own picks file survived a killed run, so the next run started from a leftover pick; the
  runner now wipes it first.

## Soak (30 real minutes, demo + stress)

`godot --headless --path . --max-fps 60 --profile=soak_lr2 -- --demo --soak` (scripts/tools/soak.gd:
two demo bots, a random zap every 0.4 s, glue / unglue now and then), 13:16-13:50, this machine
(6 cores, CPU only, no GPU). Log: `.scratch/soak.log` (lines below copied from it).

| t (s) | objects | nodes | orphans | ObjectDB | joints | effects on | zaps | frame ms (mean / worst) | process ms | physics ms | voices | memory MB |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 30 | 56 | 2934 | 0 | 7014 | 3 | 55 | 67 | 16.66 / 28.5 | 4.19 | 7.66 | 8 | 197.2 |
| 270 | 56 | 3342 | 0 | 7960 | 6 | 137 | 546 | 16.67 / 32.2 | 3.91 | 7.15 | 1 | 203.9 |
| 570 | 56 | 3334 | 0 | 8085 | 6 | 149 | 1125 | 16.67 / 36.8 | 3.86 | 9.25 | 0 | 205.6 |
| 870 | 56 | 3257 | 0 | 8016 | 6 | 149 | 1701 | 17.07 / 159.9 | 7.20 | 16.02 | 1 | 205.5 |
| 1170 | 56 | 3294 | 0 | 8096 | 6 | 149 | 2274 | 18.09 / 118.7 | 17.49 | 26.96 | 5 | 205.7 |
| 1470 | 55 | 3289 | 0 | 8092 | 6 | 140 | 2819 | 17.03 / 73.4 | 13.41 | 21.12 | 4 | 205.8 |
| 1770 | 56 | 3305 | 0 | 8144 | 6 | 151 | 3411 | 18.43 / 118.7 | 21.69 | 34.43 | 6 | 206.0 |
| 1981 | 56 | 3337 | 0 | 8160 | 6 | 150 | 3810 | 17.57 / 80.0 | 18.56 | 28.86 | 6 | 206.1 |

- **No errors**: 0 script errors, 0 engine errors or warnings in the whole log. 0 recalls.
- **No leaks**: 0 orphans throughout; nodes, ObjectDB, joints and memory level off after the yard
  fills with effects (nodes 3257-3350 from minute 4 on, memory +0.5 MB over the last 20 minutes);
  audio voices 0-9, inside the pool.
- **Frame time**: mean 16.7-18.4 ms (60 fps cap). The process / physics cost rose from minute 14,
  with the yard's state flat. The box was shared: other lanes' renders and soaks ran beside it (load
  average 13-23 on 6 cores). **Control**: a fresh 5-minute soak run straight after, under the
  same load, showed 13-18 ms process and 24-30 ms physics from minute 1 (`.scratch/soak_control.log`),
  against 4 / 7 ms in the quiet first part. So the rise is the shared box, not the game. The clean
  number is the quiet part: about 4 ms process and 7-9 ms physics per frame with 150 effects on. The
  GTX 1060 number is S-18 / L-11 (TV box).

## Tests and boot

- Clean import: 0 script errors.
- gdUnit4 (`--ignoreHeadlessMode --continue`), full suite: **317 test cases, 0 errors, 0 failures,
  0 orphans**, exit 0 (`handoff/test-output.txt`). The suite logs `Parameter "material" is null`
  from Godot's dummy (headless) renderer in test_jyz_chooser; it never shows up with a renderer (session
  flow and shots logs are clean).
- Headless boot (`--quit-after 600`): exit 0, 0 script errors.
- Tests use their own settings and picks files; the session flow uses `user://session_flow_*`
  and the soak its own `--profile`. The shared picks file (`~/.local/share/openjar/players.json`)
  was never written.

## Export

`godot --headless --path . --export-release "Linux" build/junk-yard-zap.x86_64`: exit 0, 121 MB,
embedded pck. The pack holds no `.md`, `tests/`, `playtests/` or `docs/` file (export log), and does
hold `store/*` and `data/roster.json`. Zipped the way `release.yml` does (one file at the zip root;
`zip` isn't installed here, so Python's zipfile built it), unzipped into `.scratch/zipcheck/out/`,
booted headless for 30 s of demo: exit 0, **0 errors, 0 warnings**. An earlier export in this run
aborted at exit right after writing the pack, while a software render ran beside it; the rerun was
clean and the binary from the aborted run booted fine too. Gary: if the CI export ever aborts at exit,
rerun it.

## Placeholders left

None reach the shipped game.
- `scripts/autoload/synth.gd` (code beep) and `Audio.gd` fallback: only when a cue has no file;
  every cue the game plays has one (test_audio, test_launch_ready::test_every_menu_cue_is_a_designed_file_not_the_synth).
- `scenes/ui/lobby_character.gd` (the template's lobby figure): only when a pick has no model and no
  pixel form; every v0.5.3 Jarling has both (test_launch_ready_2::test_every_roster_character_has_its_files).
- No TODO / FIXME in scenes/ or scripts/. No audio for Gary to make.

## Ship hygiene

- Version: lobby footer shows `v0.1.0` (`application/config/version`), stamped from the tag by
  `.github/workflows/release.yml` (seen in every lobby frame).
- Store: `store/grid.png`, `hero.png`, `jar.glb`, `clip.mp4` present.
- Credits: every file under `assets/` has a line in `assets/CREDITS.md` (script check: 0 missing).
  The 22 character voice packs and catchphrases are now credited as ElevenLabs output (as each
  character's own CREDITS.md in openjar-characters v0.5.3 says), via `sync_characters.sh`, so the next
  resync keeps it; the music was already. Kaden confirmed his plan covers release.
- README "How to play" matches the controls (Select hold, variable jump, solo, D-pad menus).
- Personal info: none in data, scenes or shipped text. Two code comments name Kaden (art_kit.gd,
  pictos.gd); scripts export as compressed binary tokens, which drop comments. `GAME.md` no longer
  ships (L-14). A strings search of the exported binary finds no name or email.

## Needs Kaden
- Playtest #2 of the S9 changes on the TV (closes C-14), then `v1.0.0` on the main tile (C-15).
- Optional: GAME.md "Decisions made without Kaden" still open for him to confirm.

## Needs the TV box (weekend)
- 60 fps at 1920x1080 on the GTX 1060, whole yard awake, F3 (S-18, L-11).
- Both real pads: first press is P1 green; unplug / replug P2; Select hold vs Select + Start on real pads.
- Launch from the launcher tile and Back to Open Jar; sound levels on the TV; cards readable from the sofa.

## Gary
Ship: merge `feature/launch-ready-2` into `dev`, tag the next dev build, boot it, promote after the TV check.
