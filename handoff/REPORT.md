# Gap-close lane 2: Junk Yard Zap (`feature/jyz-gap-close-2`)

2026-11-12. Based on `origin/dev` @ `438e8ad` (after PR #38; `git fetch` + merge: already up to date).
Four commits, not pushed.

## Sync first (commit `a58cd34`)

- **Partial rows:** only C-14 (playtest #2) and S-18 (GTX 1060 fps). Both still need Kaden or the TV
  box, so they stay partial. No `missing` rows. No stick-only rows exist, so there was nothing to drop.
- **The brief's priority rows were already built on dev.** I re-checked each one against the code
  and against real frames:
  - **Y-12, K-10, A-06:** 49 object types. 40 have faces; the 9 vehicles and machines rattle
    instead. 48 voice sets cover all 49 types (the loose balloon borrows the beach ball's).
  - **U-15:** the 7 guns have distinct silhouettes, colours and sounds (`guns.png`).
  - **Y-11:** every listed loose object is in `data/objects/`.
  - **G-13:** the trophy shelf flips through done cards (`trophy.png`).
  - **V-11:** `store/hero.png` exists.
- **Stale notes fixed:**
  - Y-12 had a duplicated paragraph and an out-of-date "the HUD car still has a face".
  - K-10 said 39 faced types; it is 40.
  - A-06 said 48 types; it is 49.

## Built: what Kaden will hear

Every character's in-game voice was the generic synth. That is the most noticeable gap I found.

1. **Delight and zap barks now use the character's own voice** (A-12, P-05, P-06; `bfff955`).
   - **The bug:** `Audio.bark("delight")` and `bark("zap")` looked for `delight.ogg` and `zap.ogg`
     in the voice packs. The library packs don't ship those (they ship cheer, win, oops, ready,
     join, swap_in, wait, lose and catchphrase). So Jeff's clap, Chuck's "that was me" and every
     other pick's reactions fell back to the same generic formant beep.
   - **The fix:** `Audio.PACK_KINDS` maps delight to cheer or win, and zap to win or cheer.
   - **Overlap:** a spoken line is 2-3 s, so it now holds the bark gate until it ends. Nobody
     talks over anybody.
   - **Proof:** the same real-roster 55 s `--demo` run, probed with a scratch script.
     - Before: `{bark_zap: 8, bark_delight: 1}`, all generic synth.
     - After: `{roster:chuck: 3, roster:jeff: 1}`, all their own voices.
2. **Drop-in says hello, and the solo swap says "I'm in"** (`b106be2`). Both use the pack's
   `join` and `swap_in` lines.
   - P2 waking in the tire pile still snorts first, then says the `join` line about 0.55 s later.
   - A character with no pack gets the plain generic bark.
3. **Refused zaps say "oops", and a long idle gets one "wait" line** (`4050e0a`).
   - **Chuck's blame:** it was a random plain line, which could be a cheer on a failure. It is now
     his `oops` line ("Oh! That wasn't me.").
   - **Jeff on a refused zap:** he tilts his head and says his own `oops`, at most once every 8 s
     so mashing at the size cap never nags.
   - **Idle:** after standing still for 12 s, a character says one `wait` line per still stretch
     ("I'll just look at this rock."). It is idle chatter, never a hurry-up.

All lines come from the vendored library packs through `Audio.bark` and `Roster`. No audio was
generated. `docs/contracts.md` is updated for `bark`, `can_bark` and the new `Zapper.say`.

## IDs moved

No status changes; all 177 rows keep their status (built 160, partial 2, superseded 11, later 4).
Notes were updated on these rows:
- **Sync:** Y-12, K-10, A-06.
- **Voice work:** A-12, P-06, P-07.

## Tests

- **New file:** `tests/test_gap_close_2.gd`, 9 cases.
- **Fixtures only:** `tests/fixtures/roster_comedy.json`, plus copies of Zorp's join, swap_in,
  oops and wait lines in `tests/fixtures/voice/` (documented in its README). Settings go to
  `user://test_settings_gap_close_2.json`.
- **Changed suite:** `test_comedy.gd` now runs on the fixture roster instead of the real one, and
  its expectations moved from generic barks to the characters' own lines.
- **Command:**
  `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode`
- **Result:** exit 0, **326 test cases, 0 errors, 0 failures, 0 orphans**
  (`handoff/test-output.txt`).
- **Before every commit:** clean `--import`, the full suite, and a headless `--demo` boot with zero
  script errors.

## Export

- `godot --headless --path . --export-release "Linux" .scratch/build/game.x86_64`:
  - The first run aborted at exit after `savepack DONE`. This is the known abort the previous lane
    reported.
  - The rerun exited 0 (113 MB).
- `RUN_SECS=40 run-export .scratch/build/game.x86_64 -- --demo`: ran the full 40 s
  (`exit 124` = the timeout) with **no output at all: 0 script errors, 0 errors**.

## Frames (`handoff/frames/sync/`, gitignored, real Forward+ frames via `scripts/tools/shots.sh`)

- `wide.png`: the whole yard from fence to fence. Every zone is dressed.
- `zone-pond.png`: ducks, the swim ring, the surfboard and the fish all have faces; the washing
  machine has none.
- `zone-barn.png`: the cow (Patience), pig, sheep, chickens, hay and pumpkin all have faces.
- `zone-tower.png`: the anvil, bowling pin, armchair, kettle and piano have faces; the tractor and
  cannon have none.
- `rattle.png`: the faceless TV, fridge and car next to faced objects (the bathtub and toolbox).
- `trophy.png`: the trophy shelf flipped up with a done card. G-13 is built.
- `guns.png`: the 7 guns side by side, each with its own nozzle and colour (U-15).
- `objects.png`: all 49 object types.

The voice work is audio. Its only visual is a small head tilt (oops and wait), which has no demo
beat to frame. The proof is the tests plus the before/after probe above.

## Needs other lanes

- **Characters (openjar-characters):** Patience has no voice yet (`proposals/cow/voice/` is empty),
  so the yard cow still moos with the synth (Y-17).
- **TV box:** S-18 and L-11 (60 fps on the GTX 1060 with F3). C-14 needs playtest #2 with Kaden.
- **Systems lane, heads-up:** this lane edited `scripts/autoload/Audio.gd`, `scripts/players/`
  and one line in `scenes/main.gd` (the solo swap line). The contract change is in
  `docs/contracts.md`.
