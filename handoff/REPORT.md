# Gap-close 4 (jyz-gap-close-4): every refusal shows its cause

Branch `feature/jyz-gap-close-4`, off `origin/dev` @ `73c5dea` (after PR #42). Not pushed.

## Audit

Every open row on dev waits only on Kaden or the TV box, so per the brief all three were skipped:

- **C-14** partial: playtest #2 (Kaden on the TV)
- **S-18** partial: 60 fps on the GTX 1060 (TV box)
- **PF-6** missing: hang at exit on the software renderer; needs to be tried on the TV box first

So I audited the code against the standing rule "every curse or penalty shows its cause". I found
four refusals a kid hits all the time that were just a "nope" sound or nothing at all. They are
three new rows, Y-20..Y-22, all built here:

| Row | Before | Now |
| --- | --- | --- |
| Y-20 | A grow blocked by a roof, a wall or a frozen thing stalled for 0.4 s, then quietly shrank back | A bonk star pops where the bigger shape hit, "nope" plays, the object goes wide-eyed, a frozen blocker flashes in the freeze colour, and the size ladder shows the step coming back down |
| Y-21 | A size zap at the biggest or smallest size was a bare "nope". A grab on what the partner holds, or glue on a pair already stuck, also just said "nope" | Every size zap shows a nine-square ladder over the object (pictures only, no numbers), lit in orange up to the size now. At a cap the end square blinks, a stop bar stands past it and the ladder shakes "no". A refused grab rings in the holder's colour. Refused glue pulses the pair's blob |
| Y-22 | Glue whose pair couldn't meet let go after 3 s with no sound and nothing to see | While glue pulls, a pink string runs between the two objects, drawn over anything in the way. It thins as it stretches and shivers near the end. If the pair can't meet, it snaps: an "unglue" sound, both halves whip back into the objects, a pink ring on each, wide eyes |

No art assets, audio files or `project.godot` were touched. The ladder, star and string are drawn
from code with existing palette colours (size orange, glue pink, cream, deep brown). The sounds
use cues that already exist (`nope`, `unglue`). Nothing here has a face on a machine. You don't
need the stick for any of it.

## Files

- `scripts/fx/refusal.gd` (new): `Refusal` with `blocked`, `bonk_star`, `size_ladder` /
  `SizeLadder`, `held`, `already_glued`, `snapped`, `recoil`. Tests read `Refusal.shown` and
  `Refusal.recoils`, not pixels.
- `scripts/physics/physics_object.gd`: `block_contact()` finds the static or frozen blocker and the
  contact point. The refusal now emits after the step-back.
- `scripts/physics/effects.gd`: `Glue` string (`string_mesh`, `_pose_string`, `string_ends`); the
  snap calls `Refusal.snapped`.
- `scripts/players/zapper.gd`: the ladder on every size step; the cause on a refused grab or glue.
- `scenes/main.gd`: demo beats `bonk`, `cap`, `glue-snap` (for frames).
- `tests/test_gap_close_4.gd` (new, 9 cases). Every scene is staged on the flat strip: one object
  on the ground, blockers are static slabs or frozen bodies, nothing piled.

## Frames (handoff/frames/, untracked; I looked at every one)

- `y20_bonk_before.png`: crate under a frozen plank, before the grow.
- `y20_bonk_star.png`: the bonk star at the plank, the ladder over the crate.
- `y21_ladder_full.png`: the cow grown to +4, ladder fully lit.
- `y21_ladder_cap_stop.png`: one more grow: the stop bar past the biggest square.
- `y22_glue_string.png`: the pink string drawn across the frozen fridge between two crates.
- `y22_string_shiver.png`, `y22_snap_recoil.png`, `y22_snap_rings.png`: the snap. Both halves whip
  back, pink rings go out, the crates go wide-eyed.

Rebuild them with `scripts/tools/shots.sh "" <times> <dir> --demo --demo-beat=bonk|cap|glue-snap`.

A fix found from the frames: in the first glue-snap frames, the snap burst spawned inside the frozen
fridge and the crates, so the string just vanished. I added the whipping halves and the rings
(drawn over everything) and a test check that both halves spawn
(`test_glue_that_cannot_meet_shows_a_string_then_snaps`).

## Tests

- `tests/test_gap_close_4.gd`: 9/9 green.
- Full suite (fresh run on the final code, `--ignoreHeadlessMode`): **357 test cases, 0 errors, 0 failures, 0 flaky, 0 orphans** (`handoff/test-output.txt`).

## Still open

- C-14, S-18, PF-6: Kaden and the TV box, unchanged.
- Worth a TV look in playtest #2: is the size ladder big enough to read from the couch, and does it
  get in the way when both players zap at once? (It fades after 1.4 s.)
