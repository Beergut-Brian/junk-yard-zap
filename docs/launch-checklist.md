# Launch checklist: Junk Yard Zap

Kaden, 2026-11-10: "I would like to have Spaceballs, Junk Yard Zap, and the Launcher done besides
running it on the TV hardware." Checked by the launch-readiness lane (launch-ready-1) on
2026-11-11; details and numbers in `handoff/REPORT.md` of that lane, rows L-01..L-13 in
`PLAN-STATUS.md`.

## Verified (on the producer box)

- [x] Everything in the brief and in playtest #1 is built: PLAN-STATUS has no missing rows
      (S-27 reset button and S-28 variable jump were built in PR #26; the file had lost them).
- [x] The playtest #1 changes, re-checked in real frames: gun wheel and effect icons, switch
      preview, beams, goal cards, trophy shelf, Select-hold reset ring, the lit sign, variable jump.
- [x] Whole session, scripted with pad events and in real frames
      (`scripts/tools/session_flow.sh`): boot, lobby, chooser and catchphrase, settings, both doors,
      two players, play, drop-out and drop-in, pause, settings, Reset Yard, Restart, solo on / swap
      / off, back to Open Jar. A window close on every screen quits cleanly (exit code 0). No softlock;
      every screen has a way back (B).
- [x] Menus move with the stick **and the D-pad**.
- [x] 30-minute demo soak: no script errors, no orphans, node / object / memory counts level off,
      audio voices stay within the pool.
- [x] No placeholder sounds reach the game: every cue the game plays has a designed file (the 12
      menu cues were added).
- [x] Version label: the lobby footer shows `application/config/version`, which the release
      workflow now stamps from the tag.
- [x] Store art: `store/grid.png`, `store/hero.png`, `store/jar.glb`, `store/clip.mp4` (the clip was missing; rendered from the demo).
- [x] Credits: every file in `assets/` has a line in `assets/CREDITS.md`; the ElevenLabs music is
      cleared for release (Kaden confirmed his plan covers it).
- [x] README has this game's play instructions.
- [x] No personal info or real places in the game's text, objects or art.
- [x] Export (`--export-release "Linux"`) builds and the binary boots headless with zero script errors.
- [x] gdUnit4 suite green.

## Needs the TV box (weekend)

- [ ] 60 fps at 1920x1080 on the GTX 1060 with the whole yard awake: F3 overlay, stack effects on
      every object in the yard for a minute (S-18, L-11).
- [ ] Both real pads: the first pad to press is P1 (green); unplug and replug P2 mid-game (he goes
      back to the tire pile, any button wakes him).
- [ ] Hold Select 1.5 s to reset; Select + Start 2 s for solo; neither triggers the other on real pads.
- [ ] Launch from the launcher tile, play, Back to Open Jar: the launcher resumes.
- [ ] Sound levels on the TV speakers: music under the chaos, the menu cues not too loud.
- [ ] Read the cards and gun icons from the sofa.

## Needs Kaden

- [ ] Playtest #2 of the S9 changes (closes C-14), then `v1.0.0` on the main tile (C-15).
- [ ] Optional: the "Decisions made without Kaden" in GAME.md are still open for him to confirm.

## Needs Gary

- [ ] Merge `feature/launch-ready-1` into `dev`, tag the next dev build, promote after the TV check.
- [ ] S-22: log the physics findings in `~/openjar/WORM-READINESS.md` (outside the repo).
- [ ] `GAME.md` ships inside the exported build (`export_presets.cfg` include filter, from the
      template). It holds the family's first name and planning notes. Drop it from the filter unless
      the launcher reads it.
- [ ] Do not merge `origin/feature/yard-trophy` (a second trophy shelf).
