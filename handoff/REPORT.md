# Gap-close lane 3: Junk Yard Zap (`feature/jyz-gap-close-3`)

2026-11-12. Based on `origin/dev` @ `ad2ddec` (after PR #39). `git fetch` + merge: already up to date.
Four commits, not pushed.

## Sync first (commit `7bc0207`)

- **Partial rows:** only C-14 (playtest #2) and S-18 (GTX 1060 fps). Both still need Kaden or the TV
  box, so they stay partial. There are no stick-only rows, so nothing was dropped.
- **Priority rows** Y-12, K-10, A-06, U-15, Y-11, G-13 and V-11 were re-checked against the code and
  real frames (each zone, plus the beams beat). All of them are built.
- **One real gap found:** GAME.md "The yard" says "the fridge door flaps". All 9 faceless vehicles and
  machines only rattled as one rigid piece, and the fridge door was just a painted seam. I added this
  as **Y-19** (missing).

## Built: what Kaden will see

1. **Machines move a part when zapped** (Y-19, `2023218`). Every reaction (any gun, a throw) plays
   for 1.2 s on top of the old rattle:
   - The fridge door flies open on a lit inside (shelves, milk, cheese) and swings shut.
   - The washer's porthole opens on the drum, with a red sock inside.
   - The car's door swings open.
   - The TV's antennae wobble.
   - The toast pops up.
   - The tractor's exhaust cap pops with a puff of smoke that drifts up.
   - The cannon's barrel nods, with a puff.
   - The boat's oar rows.
   - The wheelbarrow tips forward as if dumping.

   None of them has a face; the producer rule still holds. The parts are generic (`ObjectArt.gag`
   with the kinds swing, wiggle and pop, plus `ObjectArt.puff`), so the Content and Art lanes can add
   more from a builder. To see them: `--demo --demo-beat=gags-<zone>`.
2. **Faces watch you** (Y-12, K-10, `83351ad`). Every calm object face now turns its eyes toward the
   nearest player within 7 m and glides back to looking ahead when they walk off.
   - Reactions (wide-eyed, dizzy, smug and so on) still win over watching.
   - Patience the cow keeps her own atlas face, so her eyes don't follow.

**Tried and rejected: V-11 store hero.** I rendered 3/4 perspective framings so the gate end of the
yard would fill the frame. The diorama is built for a front view: from an angle, the table top, the
plinth sides and the sky card's edge take over the frame. I reverted the change, and `store/hero.png`
is unchanged (frame `v11_hero_perspective_tried_rejected.png`).

## IDs moved

- **Y-19:** added (missing), then built. It is new, from GAME.md's "the fridge door flaps".
- **Notes updated:** Y-12 and K-10.
- **Totals:** 178 rows: built 161 · partial 2 (C-14, S-18) · missing 0 · superseded 11 · later 4.

## Frames (`handoff/frames/gap3/`, real Forward+ frames, looked at; `handoff/` is git-excluded)

- `y19_before_scrap_heap_rattle_only.png`: before the change. The machines are rigid.
- `y19_scrap_heap_doors_open.png`: the fridge door is open on its lit inside, the car door is open,
  the antennae are mid-wobble, the toast is up, and the washer door is swinging.
- `y19_closeup_car_tv_fridge_toaster_washer.png`: crops of the same frame.
- `y19_other_zones_grid.png`: the front gate (the wheelbarrow tipping), the pond (the boat), the barn,
  and the tower (the tractor and the cannon).
- `y19_closeup_tractor_cannon_wheelbarrow.png`: the tractor cap is up and the wheelbarrow is tipped.
- `y19_tractor_cap_and_puff.png`: the exhaust cap pops and smoke puffs drift up (at 1.1 s and 1.3 s).
- `y12_eyes_follow_before_top_after_bottom.png`: the front gate before (eyes ahead) and after (the
  balloon, bucket and crates look toward Chuck).
- `y12_eyes_follow_front_gate.png`: the full after-frame.
- `v11_hero_perspective_tried_rejected.png`: the rejected hero framings.

## Tests

- **New file:** `tests/test_gap_close_3.gd`, 8 cases.
  - Its own settings file `user://test_settings_gap_close_3.json` and save profile
    `gdunit_gap_close_3`.
  - It uses the fixture roster `tests/fixtures/roster_two.json`, never the real roster.
- **Command:**
  `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --ignoreHeadlessMode`
- **Result:** exit 0, **334 test cases, 0 errors, 0 failures, 0 orphans** (`handoff/test-output.txt`).
- **Before each commit:** a clean `--import` (0 script errors) and a headless `--demo` boot (0 script
  errors).

## Export

- `godot --headless --path . --export-release "Linux" .scratch/build/game.x86_64`:
  - The first run aborted at exit after `savepack DONE`. This is the known abort.
  - The rerun exited 0 (113 MB).
- `RUN_SECS=40 run-export .scratch/build/game.x86_64 -- --demo`: it ran the full 40 s with
  **0 script errors and 0 errors**.

## Needs other lanes

- **Audio (optional):** the machine moves reuse each object's existing voice (the fridge rattle, the
  car honk, ...). A door-creak and slam pair, or a toaster "ding", would add to them. No audio was
  generated here.
- **TV box:** C-14 (playtest #2) and S-18 (GTX 1060 fps) are unchanged.
