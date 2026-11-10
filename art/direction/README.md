# Junk Yard Zap: art direction options

Options for Kaden to pick from, not final art. Start with `compare.png`. The same front-gate vignette is rendered in
Godot for each palette: Jeff zaps the cow with the balloon gun, the tyre underneath is bouncy, Chuck cheers,
and there's a goal card on the fence. It's lit like a toy diorama on a table: one key light, soft shadows, a painted
sky and cotton clouds on wires. Hex values are in `palettes.md`, swatch cards in `palette_{a,b,c}.png`.

| Option | Mood |
| --- | --- |
| **A. Golden Afternoon** (`frame_a.png`) | Sunny and dusty. Warm rust and sun-bleached planks under a clear teal sky, crisp shadows. The plan's "sunny junk yard". |
| **B. Candy Toy-Box** (`frame_b.png`) | Bright pastel toy wood and white enamel under a baby-blue sky. Softest, closest cousin of Spaceballs. |
| **C. Storybook Dusk** (`frame_c.png`) | Plum fence and rust under a violet sky fading to rose, low warm key light, gun effects glowing like lanterns. Cosy and the most dramatic. |
| **Flat** (`frame_flat.png`) | Option A in the plan's low-poly flat-shaded style with ink outlines, for comparing styles. |

Fixed in every option: P1 green `#3cc24a` and P2 red `#e4393c`, carried by the players' rings and gun tape. The
seven gun colours keep the same hue in every palette (grow orange, bouncy yellow, freeze ice, magnet blue,
grab violet, balloon magenta, glue bubblegum), so a gun's colour never changes whichever palette wins.

## Recommendation: A, in the smooth Jarling look

- **A reads best from the couch.** It has the strongest split between the cool sky and the warm junk, so the
  magenta balloon, the yellow bouncy stripes and both players stand out without help. It is also the plan's
  stated feel ("sunny junk yard", store hero "at golden hour").
- **B is charming but washes out.** The pale fence, sand and sky sit close in value, so objects lose their edges
  at TV distance. It also looks the most like Spaceballs, which works against giving game 2 its own identity.
- **C is the prettiest still, but the darkest.** Chuck's black shirt sits on a dark plum fence, and a whole
  session at dusk would feel sleepy. It would make a lovely store hero or a later "evening" yard variant.
- **Smooth, not flat.** The Jarlings are smooth-shaded models, so in the flat frame they look like they come from a
  different set than the faceted props. Keeping the smooth look matches Spaceballs, and the soft rim light already
  separates things from the background. The ink outlines do help readability, so a thin outline on props only is
  worth a later look check.

## Notes for whoever builds the real art

- **The magnet is blue-and-silver, not red-and-silver.** The plan's horseshoe is red, but red belongs to Chuck.
- **Watch Chuck's red on rust.** Grow orange (35° of hue from P2 red, but much lighter) and the rust in every
  palette sit closest to Chuck's red. The red ring and his cap still read, but keep large red-orange rust areas
  away from where players usually stand.
- **Faces read at this size.** Googly eyes with a white sclera plus a dotted mouth work on everything, including
  the bonnet and the tyre hub. A sleepy line or smug lids are the cheapest moods to add.

## Re-rendering

`art/tools/render_frames.sh` (all four frames, the cards, `palettes.md` and `compare.png`; about 3 min on the
producer box), or `art/tools/render_frames.sh b` for one frame. Edit colours in `palettes.json` only. The scene
is `art/preview/diorama.tscn` (`--palette=a|b|c`, `--style=flat`, `--out=`). `art/preview/` and `art/tools/`
are excluded from exports. `art/direction/` has a `.gdignore`, so Godot never imports these PNGs into a build.
