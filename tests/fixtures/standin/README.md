# Stand-in character (test only, never shipped)

`standin.glb` is a generic seed Jarling from the openjar-characters avatar kit at `v0.3.0`:

    blender -b --factory-startup -P avatar/kit/build_jarling.py -- --seed 7 --out standin.glb

It plays "Sprocket" in `tests/fixtures/roster_standin.json`, so the tests and the shots can show a
third standard-body Jarling zapping before the real new characters are synced. `tests/*` is in the
export exclude filter (`export_presets.cfg`), and `tests/test_jyz_chooser.gd` checks that.

`standin_boot.tscn` boots the game with this roster (for `scripts/tools/shots.sh`):

    scripts/tools/shots.sh res://tests/fixtures/standin/standin_boot.tscn 4,6 out --demo --p1-char=sprocket
