# Junk Yard Zap (Open Jar Games #2)

A two-player couch sandbox: a toy-diorama junk yard full of physics junk and a belt of seven silly
guns. Grow the cow, balloon the bathtub, glue a chicken to the car. No rounds, no fail state, no
timer: the yard saves as you leave it. Optional picture cards on the fence ("float the car") turn
it into a little puzzle whenever you want one. Built in Godot 4 for the family TV.

## How to play

1. Start it from the Open Jar launcher (or `godot --path .`). The lobby comes up over the yard.
2. Each player presses **A** to join and get ready (or **B** to join without readying).
   **Left / right** on your podium picks who you play as; they say their catchphrase.
   Player 1 is always **green**, player 2 always **red**, whoever you pick.
3. When everyone is ready the countdown runs and the yard opens. Hold **A** on Play to start alone.
   A second player can join any time: their character is asleep in the tire pile, any button wakes them.

| Button | Does |
| --- | --- |
| Left stick | Walk; aim while zapping (the beam snaps to the nearest thing) |
| **A** | Zap with the current gun. Hold for grow / shrink and to carry with the grab gun |
| **B** | Jump: tap for a hop, hold to go higher |
| **RB / LB** | Next / previous gun (a big picture wheel shows what it does) |
| **Start** | Pause: Resume, Reset Yard, back to the lobby, Settings, back to Open Jar |
| **Select** (hold 1.5 s) | Reset the yard (a ring fills first; a tap does nothing). Or hold **A** on the lit sign |
| **Select + Start** (hold 2 s) | Solo mode: one pad plays both; LB + RB + Select swaps who you drive |

Menus: stick or D-pad to move, **A** to pick, **B** to go back. Every screen has a way back, and the
door ("Back to Open Jar") always asks first.

The guns: **size** (grow / shrink), **grab** (carry and throw), **bouncy**, **balloon**, **freeze**,
**glue** (zap two things), **magnet**. Zap the same thing again with the same gun to undo it.

## Run, test, export

```
godot --path .                                                              # play
godot --path . -- --solo                                                    # one pad plays both
godot --path . -- --demo                                                    # bots play (attract mode)
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode --continue
godot --headless --path . --export-release "Linux" build/game.x86_64       # export
scripts/tools/session_flow.sh .scratch/flow                                 # whole session, real frames
```

The version in the lobby footer is stamped from the release tag by `.github/workflows/release.yml`.
Credits for every asset: `assets/CREDITS.md`.

---

## Template notes

Starter repo for every Open Jar Games title: small, loud, two-player couch games built in
Godot 4 by a producer agent (Hermes) and parallel agent lanes, played on the family TV box.

**Start here:** `CLAUDE.md` (rules for agents) → `GAME.md` (this game's design doc) →
`docs/lanes/<your lane>.md`.

## New game

1. "Use this template" → `Beergut-Brian/<game-slug>`, then create a `dev` branch and add the
   `openjar-game` topic.
2. `scripts/tools/rename_project.sh "<Game Name>" <game-slug>`
3. Design sprint with Kaden → fill `GAME.md` and `docs/art-direction.md`.
4. Systems lane builds the grey-box on `dev`, tags `v0.0.1-dev.1`.
5. All lanes go parallel. Reviewer merges to `dev`; Hermes promotes `dev` → `main` after a playtest.

## What is in the box

| Path | Purpose |
| --- | --- |
| `CLAUDE.md` | Agent guardrails: Godot 4 syntax, lanes, branches, tests, sound-on-every-action |
| `GAME.md` | Design-doc template; Hermes owns it |
| `docs/lanes/` | One file per agent lane: owns / never touches / hand-off / done |
| `docs/contracts.md` | Shared signals and autoload APIs lanes code against |
| `docs/kid-design.md` | The checklist every gameplay/UI PR must pass |
| `docs/art-direction.md` | House style + this game's technique and palette |
| `docs/setup.md` | Godot, docs, gdUnit4, submodule, export templates |
| `playtests/_TEMPLATE.md` | What Hermes fills from Kaden's voice note |
| `project.godot` | 1080p, Forward+, input map for P1/P2 (Xbox layout, 0.15 dead zone), autoloads |
| `scripts/autoload/` | `Players` (join, green/red), `Roster` (who you play as), `Game` (state machine), `Save`, `Audio`, `Debug` |
| `scenes/main.tscn` | Boot scene: press any button → spawn → round |
| `scenes/players/player.tscn` | Placeholder coloured-box player with move/jump/action + squash |
| `tests/test_smoke.gd` | gdUnit4: scene loads, input map complete, round cycle, save roundtrip |
| `export_presets.cfg` | Linux x86-64, embedded pck |
| `.github/workflows/release.yml` | Tests on PR; on `v*` tag, export + zip + GitHub Release (pre-release for `-dev`) |
| `.gitattributes` | Git LFS for png/glb/ogg/wav/mp4/ttf |

## Players

P1 is green (`#3cc24a`), P2 is red (`#e4393c`). First pad to press a button is P1.
Each player picks a character on their podium in the lobby (the chooser, `Roster`); Jeff is the P1
default and Chuck the P2 default. Picks are remembered across every Open Jar game and the launcher.
The roster is vendored from `openjar-characters` by `scripts/tools/sync_characters.sh` (`docs/roster.md`).
