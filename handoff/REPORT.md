# Report: jyz-player-flow-1

Lane: player-flow QA + fix, Junk Yard Zap. Branch `fix/jyz-player-flow-1`, from `origin/dev` @ `8646fd0`
(after PR #40). 2026-11-12, 22:25 to 00:00 (stopped inside the 100 minutes). Not pushed.

## What I did

Played the **exported** build as a new player and as a returning player with a save. I drove it with
synthetic pad events through two new export flags: `--session-flow` (the existing 30-step session
script) and `--player-flow=<phase>` (new: one process per phase, so saves, settings and picks have to
survive a real quit and relaunch). I looked at every frame. Every run pointed `XDG_DATA_HOME` at
`.scratch/`, so the save, settings.json and the shared players.json never touched the family's files.

The full path table, with a frame for each row, is in **`handoff/PLAYER-FLOW.md`**. The frames are in
`handoff/shots/` (49 PNGs, untracked: `handoff/` is in this clone's `.git/info/exclude`, as with earlier
lanes' frames).

## Found and fixed (most noticed first)

| ID | Fail | Fix |
| --- | --- | --- |
| PF-5 | Start on the title screen did nothing after joining; a lone player had to find "hold A" | A joined player's Start readies them. A ready player's Start starts the countdown if nobody else is still choosing (B cancels). Status line: "Press Start or hold A to start solo" |
| PF-3 | The pause bar "Restart" (goes to character select) sat under "Reset Yard" | The bar says **Main Menu**. Same place, same action |
| PF-4 | No controls shown anywhere once playing (LB / RB, the Select hold) | Controls line on the pause card, with new `[lb]` / `[rb]` glyphs in the UI kit |
| PF-1 | A second controller was ignored while one pad played solo | Solo ends, P1 keeps the pad, the new pad is P2 |
| PF-2 | A hard stop (box off, process killed) lost up to 30 s of play | A zap saves the yard 3 s later |

Each fix has its own commit and its own tests in `tests/test_player_flow.gd` (10 cases). Each was
checked again in a frame (PF-3, PF-4, PF-5) or an export run (PF-1, PF-2).

## Found, not fixed

- **PF-6 (missing):** closing the window on the title screen a few seconds after launch, with a save
  present, hangs the exported game at exit. The save is written first. Then the main thread blocks on a
  futex and the process never ends, so the launcher would wait. It happened twice (`close_early`,
  `killed`). The same paths exit 0 headless. A menu quit from the title screen later on, a window close
  in play, and the pause menu's Leave all exit 0 on the export. It was found at the end of the lane and
  only on the software renderer, and no thread of the game's own is involved. So it needs the TV box
  before any fix (fallback: a quit watchdog in `Game.quit()` after the save). Repro is in PLAYER-FLOW.md.
- **Rough, left for Kaden or Art:** Solo playtest is the one setting that doesn't stick (on purpose)
  under a "Saved on this TV" caption. "Solo" means two things (start alone vs one pad drives both). The
  READY! stamp covers the podium's "STARTING SOLO" tag (Art).

## Checks

- **Clean import:** `godot --headless --path . --import`, exit 0, 0 script errors.
- **Full suite:**
  `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode --continue`
  - exit 0, **344 test cases, 0 errors, 0 failures, 0 orphans** (`handoff/test-output.txt`).
  - The suite ran before the last tool-only commit (33ac5cc: two player-flow phases in
    scripts/tools/player_flow.gd, no game code). Import and export were re-run after it.
- **Export:** `godot --headless --path . --export-release Linux .scratch/b/game.x86_64`, exit 0 (final run
  after `handoff/.gdignore`: no handoff files packed).
  This lane's first export hit the known abort at exit (134) after `savepack DONE`; the rerun exited 0.
- **Export boot:** `RUN_SECS=60 run-export .scratch/b/game.x86_64 -- --demo` (scratch `XDG_DATA_HOME`).
  It ran the full 60 s with **0 script errors and 0 errors**.
- **Export session flow:** steps 1-22 rendered (`handoff/shots/flow_*.png`). The run hit its 25-minute
  cap on the shared software renderer before the solo and door steps. Those run headless in the suite
  (test_launch_ready.gd).

## Commits

```
33ac5cc flow: player-flow phases for quitting from the title screen
e9612d3 flow: add uids for the player-flow tool and tests
2924e6f flow: Start on the title screen readies, then starts a lone player (PF-5)
825be1f flow: pause card shows the play controls with LB/RB glyphs (PF-4)
672beca flow: the pause bar to the lobby says Main Menu, not Restart (PF-3)
12c565e flow: a zap saves the yard within 3 s, not 30 (PF-2)
ca067cd flow: a second pad takes P2 out of solo mode (PF-1)
ae7b798 flow: run the session and player flows on a release export
```

Plus the docs commit with this report, PLAYER-FLOW.md, PLAN-STATUS.md (PF-1..PF-6, S14, totals 184
rows: built 166, partial 2, missing 1) and handoff.json.

## Notes for review

- `handoff/.gdignore` (new): without it, a `--import` with frames in `handoff/shots/` imports them, and the
  export (`export_filter="all_resources"`) packed all 45 into the game. Caught on this lane's final export
  and re-exported: 0 handoff files packed, boot clean. Earlier lanes' `handoff/frames/` would have done the same.

- The label change (PF-3) is only the text in this game's pause_menu.tscn. The node is still `Restart`,
  and docs/contracts.md still names the bar "Restart (`to_lobby()`)".
- The `[lb]` / `[rb]` glyphs (PF-4) are added to `scenes/ui/kit/ui_style.gd`. If the kit is shared
  upstream, they should go there too.
- PF-5 adds `_input` to the lobby. It runs before Players, so a pad's first press still only joins
  (and readies), as before.
