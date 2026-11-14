# REPORT: feature/jyz-hint-panel-1 (in-play hint panel, R-07)

Base: `origin/dev` @ `baf2ce5` (after PR #46; `git fetch` + merge: already up to date). Closes the
gap R-07 left open: play itself showed no button hints (Kaden's rule 7, "Show the buttons that matter right now").

**Tests:** clean import (`rm -rf .godot/imported .godot/editor`, `godot --headless --path . --import`), then
`godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests` →
**Overall Summary: 402 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |** (387 before + 15 new) (log: `handoff/test-output.txt`).
New: `tests/test_hint_panel.gd`, 15 tests (own settings file `user://test_settings_hint.json`, own picks file
`user://test_hint_players.json`, fixture roster `roster_two.json`; the real ones are never touched).

## What changed

- **`scenes/ui/hud/hint_panel.gd`** (new, `HintPanel`): one panel per player, a child of the HUD (over play,
  under the menus). A row of 1-3 chips beside the player's gun badge in their bottom corner, each chip the
  lobby's own controller glyph (`UiStyle.draw_glyph`, the same drawing as the lobby footer / Settings hints)
  next to a picture of what the button does now, drawn in code from the HUD's existing pieces (`GunIcons`
  token / hand / crate, `UiGlyphs.reset_swirl`). No text, no new art files. Chips are edged in the slot colour
  (P1 green, P2 red, whoever they picked). Solo: the player the pad isn't driving shows a half-faded row.
  - **The rules are one pure function**, `HintPanel.hint_for_state(state: Dictionary) -> Dictionary`
    (`context`, `glyphs` [{tok, pic, lit}], `blink`, `iced`, `nope`). `HintPanel.state_of(zapper)` reads a Zapper
    into that input. Tests drive it with plain dictionaries, no scene.
  - **Ready blink:** a small A glyph (38 px, ringed in the slot colour) blinks above the player, behind their
    shoulder (away from the beam), when a grab gun is on something it can lift or a contraption is in the beam.
    It stands aside for the gun wheel and the Select reset ring, which use the same spot.
  - **Nope state:** a refused press (statue press, unbound button, air B, a zap / grab / grow / glue that
    can't happen) shakes the same row and greys its edges for 0.4 s. It is never a new hint: the glyphs stay
    the context's own (tested).
  - Never moves a character: it only reads the Zapper.
- **`scripts/players/zapper.gd`:** a `noped(player)` signal, emitted where the `"nope"` cue already plays
  (statue refusal, soft refusal, a refused press, a refused size step); a public `sizing()` accessor. No
  change to movement, physics, timing or sounds.
- **`scenes/main.gd`:** `_spawn` makes the player's panel (`HintPanel.make(z, camera, hud)`); a
  `--demo-beat=hints` staged run for the frames.
- **Docs:** `docs/ui.md` HUD table gets a Hint panel row; `GAME.md` a dated line under "Decisions made
  without Kaden"; `PLAN-STATUS.md` R-07 to built, header and totals.

Not touched: lobby, settings and pause menus, physics tuning, yard layout, goal cards, save format, any other repo.

## Context table

The game has no real fire cooldown, so "after a zap" is a 0.35 s beat where the A glyph sits sunk with a ring
in the slot colour, then pops back ready.

| Context (first match wins) | When | Row (glyph → picture) | Blink above player |
| --- | --- | --- | --- |
| HIDDEN | not playing (lobby, pause) | nothing | — |
| ASLEEP | waiting in the tire pile | A → sun (wake), breathing, in the badge's corner | — |
| FROZEN | partner freeze (statue) | A → gun, B → jump, RB → belt, all under ice | — |
| CARRYING | grab gun holding something | A (held, sunk) → crate dropping, stick ↔ → throw arc, B → jump | — |
| SIZING | holding A on the size gun | stick ↕ → small/big crate, A (held) → gun | — |
| COOLDOWN | ≤ 0.35 s after a zap that worked | A (sunk) → gun, B → jump, RB → belt | — |
| SIGN | by the Reset Yard sign | A → reset swirl, B → jump, RB → belt | no (the sign wipes the yard: shown, not invited) |
| GRAB_READY | grab gun on a liftable object | A → hand lifting a crate, B → jump, RB → belt | A |
| AIMING ("holding a gun") | anything else in the beam (object, partner, contraption) | A → held gun's token, B → jump, RB → belt | A for a contraption only |
| ON_FOOT | nothing in the beam | B → jump, RB → next gun | — |
| + nope (overlay) | a refused press, 0.4 s | same row, shaken, grey edges | unchanged |

Tests, one per context: `test_hidden_when_not_playing`, `test_asleep_shows_only_the_wake_glyph`,
`test_on_foot_shows_jump_and_belt`, `test_holding_a_gun_on_a_target_shows_fire`,
`test_a_contraption_in_the_beam_blinks_a`, `test_grab_gun_next_to_a_grabbable_object_is_ready`,
`test_carrying_shows_drop_throw_and_jump`, `test_sizing_shows_the_up_down_glyph`,
`test_after_a_zap_the_a_glyph_is_sunk_then_back`, `test_by_the_reset_sign_shows_the_swirl_without_blinking`,
`test_frozen_ices_the_row`; nope: `test_a_frozen_or_refused_press_is_the_nope_state_not_a_new_hint`; live:
`test_a_real_zapper_on_foot_then_frozen_then_nope`, `test_a_real_zapper_grab_ready_then_carrying`,
`test_the_game_gives_each_player_a_panel_in_their_colour`.

## Frames

`scripts/tools/shots.sh "" 2.3,4.0,4.9 <dir> --demo --demo-beat=hints` (software renderer, 1920x1080):

- `handoff/frames/hint_panel/hint_on_foot_and_grab_ready.png`: Jeff on foot (B jump, RB belt); Chuck's grab
  gun on the crate (A hand) with the A blinking behind his shoulder.
- `handoff/frames/hint_panel/hint_holding_gun_and_carrying.png`: Jeff's size gun on the cow (A + size token);
  Chuck carrying the crate (A drop, stick throw, B).
- `handoff/frames/hint_panel/hint_cooldown_and_frozen.png`: Jeff just froze Chuck (A sunk with a green ring);
  Chuck's row under ice.

Checked by eye: the rows sit on the dirt strip below the yard floor, beside the gun badges, clear of the
players and objects; nothing in them is words (the glyph letters are the lobby's button glyphs).

## Moved rows

- **R-07: partial → built.** Totals now 195 rows: built 178 · partial 2 · missing 0 · superseded 11 · later 4 · dropped 0.

## For Kaden at the next playtest

- Is the row big enough from the sofa, and is three chips per player the right amount? (`CHIP_W`, `GLYPH_H`
  in `hint_panel.gd`.)
- The blink is only for a grab or a contraption; the Reset Yard sign is shown in the row but never blinks, on purpose.
