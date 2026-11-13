# REPORT: feature/pause-door-adopt-1 (pause-door adoption)

Junk Yard Zap's pause menu now ends with the template's big door icon (IconButton, 128 px, 140 px
focused) and "BACK TO OPEN JAR" beneath it, in place of the old text bar. Based on `origin/dev`
@ `42491b1` (after PR #45; `git merge origin/dev` was already up to date).

## Read this first: two things in the brief did not hold

1. **The template door is not on template `dev` as this box sees it.** In `~/openjar/openjar-template`,
   `origin/dev` (e57d4ec) still has the text-bar pause menu. `git fetch` failed (no GitHub credentials
   here), so I can't tell whether upstream `dev` has moved on since. The door work exists only on the
   local, unmerged branch **`feature/template-pause-door-1` @ `69ab14a`** (commits 30b4cbd door,
   17c04c5 test, also checked out at `~/openjar/work/openjar-template--feature_template-pause-door-1`).
   I adopted from that branch exactly (real template code, nothing invented). **Gary: check that the
   template PR merged without review changes.** If it changed, re-sync `scenes/ui/icon_button.gd`
   and the `Card/Door` nodes.
2. **There is no door art file.** The template has no `art/ui/` directory on any branch. The door is
   drawn in code by `scenes/ui/icon_button.gd` (`Icon.DOOR`). So no file was copied into `assets/` and
   no CREDITS line was needed. If an art file is coming, `IconButton.texture` takes it without any
   change to the scene.

## What changed

| File | Change |
| --- | --- |
| `scenes/ui/icon_button.gd` | Replaced with the template branch's version, word for word (`class_name IconButton`, `focus_scale`, `disabled`, `slam_in()`, a bigger door). Before this, it matched template `origin/dev` and nothing in this game used it. |
| `scenes/ui/pause_menu.tscn` | `Card/Buttons/Door` text bar removed. New `Card/Door` holds `Icon` (IconButton, door, 128 px, focus_scale 140/128) and `Label` "Back to Open Jar" (centred beneath). Same layout as the template. The four bars are packed a little tighter (top 384, gap 16) so the door fits under them. The play-controls line (PF-4) moved from bottom left to bottom right, just above the hint strip, because the door now takes the bottom-left corner. |
| `scenes/ui/pause_menu.gd` | `_buttons[DOOR]` is now the icon. Glyph setup skips it (it draws itself). `apply_skin()` tints it with this game's `UiStyle.accent` (orange `#ffb23e`, not the template's yellow). The label is cream and big when focused and softer when not. The label slides in with the door. The game's look stays: PAUSED title, pauser stripe, Reset Yard / Main Menu bars. |
| `scenes/ui/kit/ui_preview.gd` | A `--ui=pause-door` state (same as the template's), used for the frame. |
| `tests/test_pause_door.gd` | New: 6 tests (listed below). |
| `tests/test_controls.gd` | `test_pause_menu_has_a_reset_yard_entry_that_resets_at_once` assumed every pause entry is a text bar with a glyph. It now accepts the door IconButton and checks that its icon is DOOR. |
| `docs/ui.md`, `PLAN-STATUS.md` | Pause description and row R-03. |

Kept as before: Resume, Reset Yard, Main Menu, Settings. A selects, B resumes (or backs out of
Settings / the question). D-pad and stick move the cursor through `MenuInput`. Moving down past the
door bumps the end. The quit path still asks first, then `Game.quit()` saves and leaves, with the
PF-6 exit watchdog. It never force-closes. The solo marker is untouched. `project.godot` is untouched.

## Tests

- Clean import (`rm -rf .godot && godot --headless --import --path .`), then the full suite with `--continue`:
  **`Overall Summary: 389 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`**
  (full log: `handoff/test-output.txt`).
- The first full run had 1 error, the `test_controls.gd` assumption above. Fixed, then the clean
  rerun gave the result above.
- `tests/test_pause_door.gd` uses its own profile (`gdunit_pause_door`), settings file and picks file,
  and boots `main.tscn` with real pad events (devices 5 and 6):
  - `test_door_icon_is_in_the_pause_scene`: an IconButton, DOOR, 128 px, 140 px focused, the label
    centred beneath and on screen, the old bar gone
  - `test_door_wears_this_games_accent`
  - `test_door_icon_takes_the_focus`: focusable, bumps the end, leaves on up
  - `test_dpad_reaches_the_door`: real d-pad presses from either pad, through MenuInput
  - `test_a_on_the_door_asks_first_then_quits_saved`: A opens the question and nothing quits; B in
    the question stays; A then Leave quits, and the save is not dirty
  - `test_b_on_the_door_resumes`

## Frame

`handoff/frames/pause_door_focused.png` (`scripts/tools/shots.sh "" 1.5 .scratch/shots --ui=pause-door`,
Forward+ on llvmpipe). Frames are not tracked in git; it is in this worktree.

What I saw: the dark pause wedge on the left with PAUSED and a red "PLAYER 2 PAUSED" tag. Below are four
unfocused bars (Resume, Reset Yard, Main Menu, Settings), each with its picture. Under them is the door,
focused: a round orange disc with a white ring and a brown door with a black knob, fully inside the
frame. Under it, "BACK TO OPEN JAR" in big cream slanted capitals, readable, centred, and not clipped
(it ends about 40 px above the bottom edge). On the right, over the blurred yard: the controls line
"A Zap, B Jump, LB RB Gun, Hold Select Reset", readable cream with glyphs, sitting above the dark hint
strip "Move / Select / Resume". Nothing overlaps.

## PLAN-STATUS

The brief expected a `partial` row. **R-03 was already `built`** (the rules audit counted the text bar
plus door glyph as built). I kept it `built` and rewrote its proof to the door icon, `test_pause_door.gd`
and `pause_door_focused.png`, noting where the door came from. I recounted from the Status column:
195 rows, built 176 · partial 4 · missing 0 · superseded 11 · later 4 · dropped 0, so no change.

## Not done / for Gary

- Confirm the template PR merged as-is (see the top of this report). Not pushed. The producer pushes.
- Moving the controls line to the right is a small layout call inside the pause scene. If Kaden would
  rather have it back on the left, the door has to move instead.
