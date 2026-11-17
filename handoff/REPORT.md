# jyz-hitch-3: S-18 steady 1%-low (GTX 1060, warm, high)

Lane jyz-hitch-3 (Gary), branch `feature/jyz-hitch-3` from `origin/dev` @ `6392ed1` (after PR #54), 2026-11-17.
Not pushed. The previous report (jyz-hitch-2) is in git history (`git show 6392ed1:handoff/REPORT.md`).

**Moved IDs: none.** S-18 stays `partial`, and its note now says what changed and what to expect on the 1060.
S-29 is unchanged. The low tier gets the same merge, and nothing it shows changes.

## The gap
Gary's 1060 bench of v0.1.7-dev.3 (`--bench`, high, 60 s): the cold stall is gone, but on a warm cache the
1%-low is 39.4-42.8 fps and the worst frame is 38.6-43.3 ms (avg 66.5-69.0). Goal: 1%-low >= 50, worst
under ~25 ms warm, and the cold run kept (no frame over ~200 ms).

## 1. Findings (before changing anything)
Full notes are in `handoff/hitch3-findings.md` (a copy of `.scratch/hitch3-findings.md`).

I ran a per-frame probe (`.scratch/p3_node.gd`) on the bench route with a renderer (`godot-render`, lavapipe,
Forward+, high tier, 480x270, `--fixed-fps 30`). It drives the route by frame count: 30 warmup frames,
then 60 follow, 60 wide, 60 follow, with the soak's stress on. BenchProbe's wall-clock route only gets one
lavapipe frame per third, which is why I didn't use it. Each frame the probe logs the root viewport's
measured render CPU and GPU time, plus objects, primitives and draw calls for the colour pass and the
shadow pass. lavapipe timings are only good for comparisons; the counters are exact.

| baseline, median | objects | draw calls | primitives | shadow objects | shadow draws | render CPU | lavapipe GPU |
| --- | --- | --- | --- | --- | --- | --- | --- |
| follow (121 frames) | 773 | 403 | 546k | 415 | 269 | 1.6 ms | 636 ms |
| **wide** (60 frames) | **2092** | **1055** | 1051k | 864 | **601** | **2.8 ms** | 631 ms |

- **Hitch-2's suspicion was half right.** The wide third is the heavy one, but not because of GPU fill or
  triangles. lavapipe's GPU time doesn't change between the thirds even though the wide shot has twice the
  triangles. What does grow is the instance count. The wide third draws 2.7x the objects, 2.6x the draw
  calls in the colour pass and +330 shadow draws, and render-thread CPU almost doubles (1.6 to 2.8 ms on
  this CPU). On the box, that CPU work shares a desktop quad-core with the main thread.
- **Where the instances come from:** every yard object is 10-50 separate ArtKit parts, each its own
  MeshInstance3D. That's 1746 in the tree, 266 of them with the outline pass. The dressing already uses
  MultiMeshes (28, holding 1186 instances), and Forward+ already instances runs of identical mesh and
  material, so the objects' many small parts are what's left.
- The slow single frames in the baseline (frames 93-97, the cut to wide, 2-6 s against 0.67 s) didn't
  come back in the fix run. That run had a warmer cache, so I don't credit the merge with it.
- The slow frames don't come from particles (3-7 CPUParticles3D at a time), glow, or a light or shadow
  setting changing.

## 2. The fix: `ObjectArt.merge_static` (nothing seen changes, both tiers)
When an object is built (`ObjectArt.build`), its still parts that share a material are baked into one
ArrayMesh, in place. The triangles, normals, material (outline pass included), shadow setting and layers
all stay the same. The parts' own boxes are kept as the mesh's custom AABB, and as a `parts_aabb` meta that
`PhysicsObject._art_bounds` reads, so the effect look wraps the same box. That's a 2-line change in
physics_object.gd, away from the sleep-when-still code.

These are left as separate parts:
- named parts (a balloon's Body and Knot are found by name)
- anything under a gag pivot (Y-19, those swing)
- inside an instanced model (the cow's glb)
- scripted parts, parts with children, parts with an overlay
- see-through or textured materials
- outlined parts that have a scale. The outline grows in the mesh's own space, so baking the scale in
  would change the ink line's width.

Merged meshes are cached by their parts, so a Reset Yard or a recall reuses them (117 meshes for 49
object types, and they don't grow on rebuild). The first build costs ~5 ms an object at yard load, behind
the lobby or warmup. A cached rebuild adds ~0.3 ms an object.

## 3. Measured here (same route, same probe, warm)
| median | objects | draw calls | primitives | shadow objects | shadow draws | render CPU |
| --- | --- | --- | --- | --- | --- | --- |
| follow | 773 -> 452 | 403 -> 268 | 546k -> 473k | 415 -> 394 | 269 -> 264 | 1.6 -> 1.4 ms |
| **wide** | **2092 -> 1677** | **1055 -> 921** | 1051k -> 1052k | 864 -> 701 | **601 -> 537** | **2.8 -> 2.5 ms** |

- The wide shot's primitives are the same: it's the same geometry in fewer instances. (Follow's
  primitives move because the bots' camera framing differs between runs.)
- Headless counts (test_hitch_3): object draws 895 -> 549, whole yard 1919 -> 1543 (outline passes counted).
- **The look:** all 49 art objects rendered with parts vs merged, 1920x1080, same camera and light. They
  differ in 101 of 2,073,600 pixels (mean channel diff 0.002). The diff sits on the cow, which isn't merged
  (its glb idles), and a few pixels of depth tie on the cannon's fuse dot. See `handoff/shots/lineup_parts.png`,
  `lineup_merged.png`, `lineup_diff_cow.png` and `lineup_diff_cannon.png`.
- **This is a modest cut, not a halving.** Wide colour draws drop 13%, shadow draws 11% and render CPU 11%.
  The rest of the wide shot's draws are mostly the outlined parts that have a scale, plus the dressing and
  the players.

## 4. What to expect on the 1060 (not measured here)
- **Warm high:** the wide third's slow frames should shrink by the render-thread work saved (about 10-15%
  of the per-instance cost). Expect the 1%-low to rise by a few fps from 39-43. **I don't claim 1%-low >= 50.**
  If the box still shows 1%-low < 50 after this, the next step is an outline shell per object: bake every
  outlined part's grown shell into one ink mesh, so an object's outline is one draw. That takes most of the
  remaining wide-shot draws. It needs a new ink material with no grow, and a check of how next_pass outlines
  behave in the shadow pass. It isn't done here because it can change the look if that check is wrong.
  Then check F3's render-thread time against the main thread on the box: if the box's CPU is the limit,
  draw-count work is the right lever.
- **Cold run:** unchanged. The merge adds no new material or shader. The baked meshes use the parts' own
  materials, which RenderPrewarm and the load frame already compile. There should be no frame over 200 ms
  after the warmup.

## 5. Tests
`tests/test_hitch_3.gd` (6 cases):
- every art object keeps the same triangle count, corner-position sum and normal sum per material and
  shadow setting, and its draws drop below 70%
- gag parts, named parts and instanced models stay
- outlined parts with a scale aren't baked; details and unscaled outlined parts are
- the effect look wraps the same box, merged or not
- a second build reuses the merged meshes
- the yard's draw count stays under a ceiling of 1600 (1543 now) and below the unmerged count

The physics-outcome tests (test_sleep_when_still.gd 4 / 4) pass unchanged. I added no physics test, so
there was nothing to stage.

## Results
- **Import:** `godot --headless --path . --import` exit 0, 0 script errors. This worktree had no `.godot`,
  so it was a full import, then a re-import after the edits.
- **Full suite** (`-a tests --continue --ignoreHeadlessMode`): **445 / 445 passed**, 0 errors, 0 failures,
  0 orphans, exit 0 (`handoff/test-output.txt`). That's 439 before plus 6 new.
- **Export:** `--export-release "Linux"` wrote the pack with 0 script errors. The editor then aborts on its
  own exit (134), which is known (PF-6, earlier reports). Commands are in `handoff/export_runs.sh`.
- **Boot the export with `--demo`** (Xvfb + lavapipe, auto low tier): exit 0, **0 script errors**, for both
  the demo run and `--demo-beat=wide`.
- **Export, headless `--bench` 60 s** (CPU only): `BENCH avg=143.2 low1=54.9 worst_ms=41.8`
  (`handoff/bench-export.txt`). Hitch-2 measured 83.7 here, but this box was shared during the run: another
  lane's lavapipe was at 371% CPU, with load average 6-11 on 6 cores. An interleaved A/B under that load,
  merge off vs on from the project (`handoff/bench-ab.txt`), gave low1 49.7 vs 52.9, then 10.8 vs 30.7 as
  the load rose. The merge costs nothing per frame, and these headless numbers say nothing about the 1060.
- **The frame I looked at:** `handoff/shots/demo_auto/t010.0s.png`, from the export at 10 s of `--demo`.
  It shows Jeff with the balloon gun and Chuck by the crate stack. The crates' planks, the wheelbarrow, the
  tyre, the gnome and the cone all have their parts and ink lines, and both HUD rings (green P1, red P2),
  the hints and the goal card are there. Also `wide_auto/t010.0s.png` (the whole yard, every object in place)
  and `demo_auto/t004.0s.png`.
- Commits: `perf: merge each yard object's still parts per material` (code + the S-18 note),
  `tests: pin S-18 part merge (...)`, `perf: hitch-3 handoff (...)`.
