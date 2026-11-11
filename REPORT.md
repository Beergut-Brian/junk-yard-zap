# REPORT: fix/jyz-generated-textures-1 (Systems)

## The writer
No game code wrote these files. They came from **Godot's glTF importer**. Its default
`gltf/embedded_image_handling = 1` (Extract Textures) pulls every image embedded in a `.glb` out
into a PNG beside the `.glb` on import. It names each one `<glb>_<image>.png` and imports it
(`chuck/chuck_chuck_tiedye.png`, `chuck_chuck_trex.png`, `boxbot_boxbot_box_torso.png`, ...).
`*.import` is gitignored, so every clean checkout, `godot --import`, test run or shot started
from the default again.

A clean `godot --headless --import` reproduced it with no game code running. It left **45 untracked PNGs**:
43 under `assets/characters/<id>/` (22 Jarlings: faces, shirt/pants patterns, Chuck's tie-dye and
T-rex, Boxbot's torso) and 2 under `assets/models/patience/` (`cow_cow_coat.png`,
`cow_cow_face.png`). The barn cow has the same bug.

I checked the code that does write files (`save_png`, `ResourceSaver.save`). It is
`Debug.gd` (screenshots go to `user://`), `scripts/tools/ui_sheet.gd`, `build_theme.gd`,
`build_data.gd` and `scripts/goals/bake_card_art.gd`. All are deliberate offline tools that
write tracked assets, and no test or shot runs them. None of them is involved.

## The fix (ported from the-hill PR 23, `e8aded9`)
- `project.godot`: `[importer_defaults] scene={"gltf/embedded_image_handling": 3}` (Embed as
  Uncompressed). The images stay inside the imported scene in `.godot/imported/`, Godot's own
  cache, and appear as sub-resources (`jeff.glb::ImageTexture_...`). Nothing goes into `res://`.
  This covers every `.glb` in the project, the cow included.
- No `.gitignore` backstop. After a clean import, the fix alone keeps the folder clean (shown below).
- One limit: the setting only applies to *new* imports. A machine that already has
  `assets/**/*.glb.import` files from before the fix keeps extracting until those files and
  `.godot/` are deleted and the project is re-imported. The new test catches this case and says
  what to do.
- Wording: `scripts/tools/sync_characters.sh` (its header and the credits line it generates) and
  the 23 matching lines in `assets/CREDITS.md` used to say "Godot extracts its textures
  (`<id>_*.png`) on import". They now say "its textures stay embedded on import (no extracted
  files)". That is the only change under `assets/`, and `CREDITS.md` belongs to the Art lane, so
  it should look at it. Nothing in `assets/characters/`, `scenes/` or `data/roster.json` changed.
- `tests/fixtures/standin/` keeps its own tracked `standin.glb.import` and
  `standin_generic7_face.png`. It is a fixture, and I left it alone.

## Test
`tests/test_generated_textures.gd` (4 cases):
- `test_project_default_embeds_gltf_images`: the project setting is 3.
- `test_every_glb_imported_with_embedded_images`: every character `.glb.import` and the cow's
  `.glb.import` say 3. It fails on stale imports.
- `test_no_extracted_textures_beside_glbs`: no `<stem>_*.png` sits beside any of those `.glb` files.
- `test_a_run_writes_nothing_into_res_assets_characters`: lists every file under
  `res://assets/characters` and the cow's folder, then loads all 23 models. It checks that each
  has textures with a size and none is a `.png` file. Then it runs `scenes/main.tscn` for 10
  frames and fails if any file was added.

Checked against the bug: with the old `project.godot` and a clean import, 3 of the 4 cases fail
(113 failures, one per stale `.import` and per stray PNG). With the fix, all 4 pass.

## Full suite
From a clean import (`rm -rf .godot`, deleted every `assets/**/*.glb.import`, ran `godot --headless --import`):
`godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests --continue`
→ **304 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans**.
I did not touch the physics tests.

## git status after a run
After the clean import, the full test run and three scripted runs (`scripts/tools/shots.sh`
of `main.tscn --demo --demo-beat=blame`), `git status --short` lists only this branch's own
changes. There is nothing untracked under `assets/`:
```
 M assets/CREDITS.md
 M project.godot
 M scripts/tools/sync_characters.sh
?? tests/test_generated_textures.gd
?? tests/test_generated_textures.gd.uid
```
(These were committed afterwards.) Before the fix, the same import alone left 45 `??` lines.

## Frames
`scripts/tools/shots.sh res://scenes/main.tscn 4 <dir> --demo --demo-beat=blame` (Forward+ on llvmpipe):
(`handoff/` is gitignored, so these PNGs are on disk in this worktree, not in the commit.)
- `handoff/frames/gentex_before_full.png`: before the fix (extracted PNGs in place).
- `handoff/frames/gentex_after_full.png`: after the fix, the same beat (this save's picks: Bloom P1, Chuck P2).
- `handoff/frames/gentex_after_ana_snooze_full.png`: after the fix, `--p1-char=astro_ana --p2-char=snooze`.
- `handoff/frames/gentex_crops_before_after.png`: close-ups. Left column before, middle after,
  right Astro Ana and Snooze after.

Faces, eyes, shirt patterns, Chuck's tie-dye and T-rex shirt, and Snooze's striped hat all render
the same before and after. The two full frames differ elsewhere only because of demo timing
(the junk pile, the ring colour, the expression).

## PLAN-STATUS
No row is about this, so PLAN-STATUS has no changes.

## Also seen (not this repo)
`~/openjar/the-hill/assets/characters/jeff/jeff_jeff_face.png` still exists there. It is
probably left over from before their fix, on a machine with stale `.import` files.
