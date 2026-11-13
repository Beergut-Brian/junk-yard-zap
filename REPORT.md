# REPORT: feature/jyz-faceless-audit-1 (Faceless audit)

Rule (Kaden, standing): vehicles and machines never get faces or eyes. Base: `origin/dev` @ `8646fd0`
(gap-close-3 merged).

**Result: no face was left to remove.** The vehicle-faces lane (`feature/jyz-vehicle-faces-1`, already
merged into dev) and gap-close-1/3 had removed every face on a vehicle or machine. This lane checked
every place a face could hide and found none. Then it closed one way a face could come back
(`build_data.gd`), fixed three stale comments that still said "face", and added a test that reads the
list from the code.

## Locked files check
All 7 `feature/jyz-*` branches on origin (controls-1, gap-close-1/2/3, goal-physics-1, ui-1,
vehicle-faces-1) have an empty `git diff --stat origin/dev...<branch>`: they are all merged. No file
was off-limits.

## The vehicle and machine list (from the code)
The code marks a vehicle or machine in two ways: `has_face = false` in `data/objects/*.tres`, and an
`ObjectArt.gag` moving part in its builder (Y-19). Both give the same 9 types. The crane hook
(`contraptions.gd`, `d.has_face = false`) and the dressing crane (`yard_dressing.gd`) are machines too.

| Object | data `has_face` | 3D art (`scripts/art/objects/`) | Pictos (live cards) | card_art / baked PNG | Face found? |
| --- | --- | --- | --- | --- | --- |
| car | false | wheels, cream headlight (a light), rust; door gag | no face (`draws_face`) | silhouette, `return` before face; b1_tiny_car, b2_car_over_fence, b3_raft PNGs have no face | no |
| tractor | false | cap + smoke gag | no face | silhouette, no face; b1_tiny_tractor, b3_tractor_loft PNGs have no face | no |
| boat | false | oar gag | no face | via Pictos | no |
| wheelbarrow | false | tip gag | no face | via Pictos | no |
| washing_machine | false | porthole gag, 3 knobs | no face | via Pictos | no (see below) |
| tv | false | antennae gag, 2 dials | no face | via Pictos | no |
| toaster | false | toast pop gag | no face | via Pictos | no |
| fridge | false | door swing gag | no face | drawn, no face; b1_magnet_fridge PNG has no face | no |
| cannon | false | nod + puff gag | no face | via Pictos | no |
| crane hook (contraption) | false (code) | metal hook | n/a | n/a | no |
| crane (yard dressing) | n/a (dressing) | cab, glass, jib | n/a | n/a | no |

Searched for face textures: no `*face*` image under `assets/` belongs to a vehicle or machine (the only
face material is Patience the cow's `cow_face`, which stays). No vehicle or machine uses a `.glb`
(`mesh` is unset in all 9 `.tres`), so none has a material that could carry a face.

Kept as they are: the cow (Patience), every Jarling, the animals and the calm faces on props.
Judgment call: the **kettle** (old stovetop, enamel and rust) and the **piano** are props with
personality, not machines, so they keep their faces. Logged in GAME.md "Decisions made without Kaden".

## What changed
- `scripts/tools/build_data.gd`: the retired grey-box generator would have rewritten every object
  `.tres` with the default `has_face = true`. A rerun would have put faces back on all 9. It now keeps
  `has_face = false` where data/ already has it.
- Stale comments: `car.gd` ("the face sits on the side of the hood"), `wheelbarrow.gd` ("Face on the
  tray side"), `card_art.gd` `thing()` doc. Comments only, no geometry changed.
- The leftover `face_at` / `face_size` values in the 9 `.tres` are unused while `has_face = false`.
  I left them alone to keep the Content lane's files untouched.

## Frames (real, Forward+ on llvmpipe)
`handoff/frames/` (not tracked by git; in this worktree):
- `lineup_sheet.png`: car, tractor, boat, wheelbarrow, washing machine, TV, toaster, fridge, cannon,
  kettle (the kettle is the control with a face). One PNG per object as well (`car.png`, ...).
- `vehicle_cards_sheet.png`: the 6 baked goal-card PNGs that show a vehicle or the fridge.

No before/after pair: nothing visible changed, so the dev frames are the after frames. The 3 objects
I looked at most closely were the car (headlight reads as a light, not an eye), the washing machine
and the TV. None of them reads as a face.

## Test added
`tests/test_faceless_audit.gd` (4 cases):
- `test_the_vehicle_and_machine_list_comes_from_the_code_and_agrees_with_itself`: the list is
  `has_face = false` OR an `ObjectArt` gag (no typed list). Each one must be both faceless and have a
  moving part. The list has at least 9 entries. The cow, chicken, piano and kettle are not on it.
- `test_no_vehicle_or_machine_has_a_face_node_or_face_texture`: builds each one as a `PhysicsObject`
  and scans it for `ObjectFace`, a node or script named `*face*`, and any material, override or albedo
  texture whose name or path holds "face". It also checks `Pictos.draws_face`.
- `test_the_scan_finds_the_cows_face`: the control. The same scan must find the cow's and the
  chicken's faces.
- `test_the_crane_hook_contraption_has_no_face`.

Mutation check: with `car.tres` set to `has_face = true`, 2 of the 4 cases went red ("car has a moving
part but has_face = true", "car has a face: node Face"). I reverted it.

## Tests
Full suite: see `handoff/test-output.txt` and the summary in `handoff/handoff.json`.
Clean import first: `godot --headless --import` left no untracked PNGs under `assets/` (the
generated-textures fix on dev holds).

## Needs Gary
- Nothing required. Optional: on the TV, the washing machine's two teal knobs sit side by side above
  the round porthole. Look from the sofa. If it reads as a face to you or the kid, the fix is to spread
  or recolour the knobs. That is an Art change, so I did not make it.
