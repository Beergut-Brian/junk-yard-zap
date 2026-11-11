# Worm-readiness findings 1: report

Branch `docs/jyz-worm-findings-1`, based on `origin/dev` @ 12a5b41 (`git merge origin/dev`: already up to date). Docs only.

## What was done
- Wrote `handoff/worm-readiness-rows.md`: 13 rows `| need | built by | note |`, all `built by: Junk Yard Zap`, each with the file, the tuning number(s) and the test.
- PLAN-STATUS.md: S-22 missing -> built (proof: handoff/worm-readiness-rows.md), header line, totals recounted from the Status column (173 rows: built 156 · partial 2 · missing 0 · superseded 11 · later 4 · dropped 0), Next up item 4 now says "copy the rows".

## Where each row came from
| Row | Source lines read |
| --- | --- |
| Gravity as a function | scripts/physics/yard.gd `G`, `DOWN`, `center`, `gravity_at`, `flat_gravity`, `radial_gravity`, `up_at`; physics_object.gd `_ready` (`gravity_scale = 0.0`), `_integrate_forces`; tests/test_physics_proto.gd::test_gravity_comes_from_yard_gravity_at |
| Jolt setup and units | project.godot `[physics] 3d/physics_engine="Jolt Physics"` (no tick-rate key); physics_object.gd `_ready` (contact_monitor comment, `continuous_cd`, `can_sleep`), `LAND_DV`, `LAND_COOLDOWN`; test_jolt_is_the_3d_physics_engine |
| Runtime scaling | physics_object.gd header, `SCALE_TIME`, `CLAMP_GRACE`, `BLOCK_INSET`, `BLOCKED_GIVE_UP`, `_scale_step`, `_rebuild_shape`; object_data.gd `step_factor := 1.3`; yard.gd `SCALE_CHANGE_MAX_SPEED`; four test_physics_proto tests |
| Mass scaling | physics_object.gd `volume_mass()` and its comment; yard.gd line 24 `static var mass_exponent := 0.5`, line 70 `return pow(volume_mass, mass_exponent)`, `MASS_MIN`/`MASS_MAX`; GAME.md decision 2026-11-09 (Gary); three tests |
| Glue | effects.gd `class Glue` (`JOIN_GAP`, `PULL_ACCEL`, `PULL_TIME`, `tick`, `_make_joint`); physics_object.gd `refresh_mass()`; yard.gd `GLUE_MASS_RATIO`; three tests |
| Plane spring | yard.gd `PLANE_K`, `PLANE_DAMP`, `PLANE_CREEP`, `plane_accel`; physics_object.gd `_integrate_forces`, `_physics_process` (wake off-plane sleepers); scripts/players/zapper.gd:92 `axis_lock_linear_z`; test_plane_spring_keeps_z_small |
| Caps and recall | yard.gd `MAX_SPEED`, `MAX_SPIN`, `DEFAULT_BOUNDS`, `DEFAULT_GATE`; physics_object.gd NaN guard, `recall()`; test_recall_when_out_of_bounds, test_more_objects.gd::test_stress_whole_yard_stays_clean (seed 20261110) |
| EffectStack | effect_stack.gd, body_props.gd; PLAN-STATUS S-21; test_undo_restores_exactly, test_every_pair_of_effects_composes |
| ObjectData | object_data.gd `mass`, `step_factor`, `scale_for_step`, `density`; PLAN-STATUS C-14 (49 types) |
| Buoyancy | yard.gd `WATER_DENSITY`, `WATER_DRAG`, `water`; physics_object.gd water block; test_greybox.gd::test_water_floats_light_things_and_sinks_heavy_ones |
| Magnet | effects.gd `class Magnet`; test_magnet_switches_itself_off, test_tiny_magnet_under_a_giant_is_not_crushed |
| Fx juice | scripts/fx/fx.gd header and `impact()`; test_audio.gd::test_impact_band_follows_mass |
| Determinism pin | tests/fixtures/physics_clock.gd (`HZ := 60`, `MAX_STEPS := 8`, time_scale 1), used by 12 suites (grep `_clock.pin()`); tests/fixtures/stage.gd; scripts/proto/stress.gd `SEED := 20261109`, `--fixed-fps 60`; merge a92996b (PR #32) |

## Not sure, so kept out of the table (or flagged in a note)
- Whether any of this ports to Godot 2D physics: JYZ is all `RigidBody3D` on Jolt; nothing here was tried in 2D. Each row says so where it matters.
- Radial gravity is unit-checked as a function only; the game never ran with `gravity_at` switched to it.
- No test asserts the Fx shake number (only Fx.bursts for card fireworks in test_greybox.gd).
- The GTX 1060 frame rate is unmeasured (S-18 partial), so no "many bodies at 60 fps on the 1060" row.
- Worm needs JYZ did not build: render-to-texture "eat" effect, C# hot path, bigger-eats-smaller rule. Not written as JYZ rows.

## Flag for Gary
`handoff/` is excluded by `.git/info/exclude` (line 7) in the shared clone, and no earlier commit tracks it. The brief asks the diff to show the handoff folder and S-22 cites `handoff/worm-readiness-rows.md`, so this commit force-adds the four handoff files. If you'd rather keep handoff out of `dev`, drop them from the commit and point S-22 at the ledger once you've copied the rows.
