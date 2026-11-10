# Junk Yard Zap

> Design doc and source of truth for this game. Gary (the producer) owns this file. Lanes read it before
> starting and quote it in PRs. If the game drifts from this doc, fix the doc or fix the game.
> Source: Kaden's plan "Junk Yard Zap — Game Design & Build Plan" (2026-11-09), kept nearly verbatim below,
> with the producer notes in the next section taking precedence where they differ.

## Producer notes (these supersede the plan text below where they differ)

- **Jeff and Chuck are Jarlings** from `openjar-characters` (v0.1.0+: rigged, 10 equipment slots). The gun belt and guns are **gear** on the equipment system (`hand_r` for the held gun, `waist` for the belt), not bespoke attachments. Look: the same Jarlings as Spaceballs, in a toy-diorama junk yard.
- **Template features every game has:** ready-up lobby + main menu (door back to the launcher), pause menu, solo playtest mode (`--solo` / Select+Start 2 s: one pad plays both; here the pad drives the active player and LB+RB+Select swaps who is active), `--demo`, `--shots=`, release smoke-boot, `store/jar.glb` launcher jar world. Drop-in by the sleeping-in-the-tire-pile gag happens from the lobby state too.
- **No personal info or real places, ever** (Kaden, 2026-11-09): all objects and landmarks are generic and invented.
- **Physics notes for later games (Life of a Worm):** write gravity as a function (`Yard.gravity_at(pos) -> Vector3`, used by the balloon/magnet effects and every object), keep the `EffectStack` and juice (`Fx`: shake scaled to impact mass, dust, flashes) generic enough to lift into `openjar-addons`, and log what works in `~/openjar/WORM-READINESS.md`.
- **Phase order:** Phase 1 risk prototype (Jolt runtime scaling + glue joints + plane spring, 10 boxes, 60 fps on lavapipe as a proxy) starts now; palette (three proposals, Kaden picks) and a look check come before any Art lane.

## Pitch

Jeff and Chuck have the run of a junk yard full of physics objects and a belt of ridiculous guns: grow, shrink, gravity-grab, bouncy, balloon, freeze, glue, magnet. Zap a cow and it is enormous. Glue a bathtub to a balloon and ride it. There is no win state; mayhem is the game. For Kaden there is a stack of optional picture-cards on the fence (get the ball in the bathtub, make the car fly) that turn the sandbox into a Rube Goldberg puzzle whenever he wants one.

A 2.5D side-view diorama: 3D objects with Jolt physics that tumble properly, but players and aiming live on one locked plane so a 5-year-old always knows that the thing above the car will land on the car.

Repo: `Beergut-Brian/junk-yard-zap` (from `openjar-template`). Build order: **game 2**, after Spaceballs (Kaden, 2026-11-09: Spaceballs, Junk Yard Zap, Dig & build, Life of a Worm, Smash Party rebuild, maybe Castle Defense).

**Kaden's original notes, kept verbatim as the north star**

- Physics toy / Rube Goldberg: place ramps, fans, balls; press go. No win state.
- We could get wacky with physics, including maybe some shrink and grow guns, gravity guns, etc.
- It needs to be simple and fun for a 5-year-old, but also still fun for me.
- 2.5D side-view, locked plane, diorama feel. Jeff and Chuck for now. Name: Junk Yard Zap.

## Players and characters

Jeff (P1, green) and Chuck (P2, red) from `openjar-characters`, player-locked as always, each with a gun belt. Both players share one screen and one yard; anything either of them zaps is zapped for both.

|  | Jeff (P1) | Chuck (P2) |
| --- | --- | --- |
| Gun look | Guns are junk-built: a hair dryer with a satellite dish, green duct tape | Guns are junk-built: a leaf blower with a traffic cone, red duct tape |
| Reaction to mayhem | Delighted by everything; applauds Chuck's disasters | Takes credit for everything that works, blames Jeff for everything that does not |
| Idle | Pokes at junk, hums | Kicks a tire, checks his hat |

**Co-op.** No one owns an object. If both players zap the same thing, both effects apply (a giant bouncy cow). Players cannot hurt each other; zapping your partner does something harmless and funny per gun (grow makes him briefly huge, balloon floats him, freeze makes him a statue for a second while he keeps talking). This is deliberately the funniest thing in the game and a 5-year-old will discover it in the first minute.

**Drop-in.** The second character is asleep in a tire pile; a button press wakes him up with a snort.

## Core loop

There is no round. A session is however long you want, and the game saves the yard as you leave it (every zapped cow stays zapped). The fun is layered so a 5-year-old and an adult are playing the same thing at different depths.

| Layer | Who it is for | What it is | Why it works |
| --- | --- | --- | --- |
| **1. Toy** | him | Fire any gun at anything and something visible and funny happens instantly | Zero learning. Zap, laugh, zap again. Twenty minutes at age five |
| **2. Goal cards** | Kaden | A stack of optional picture-cards on the fence. Walk up, look at the top card, do the thing, fireworks, next card | Turns the sandbox into a puzzle when he wants one, with no timer and no fail |
| **3. Emergence** | both | Guns stack and combine: glue + balloon + grow = a floating giant cow raft | Seven simple guns give a few hundred combinations; discovery is the long-term hook |

**A typical session**

1. Load into the yard as you left it. Jeff and Chuck wake up.
2. He grabs the grow gun and makes the cow huge. Chuck comments. The cow moos low.
3. Kaden glances at the fence: "Get the ball into the bathtub." He gravity-grabs a plank, freezes it as a ramp, balloons the bathtub to the right height.
4. He zaps the ball bouncy before Kaden can finish. It ricochets into the bathtub anyway. Fireworks. Both characters cheer. Next card flips.
5. Repeat until someone is hungry. A **Reset Yard** button (hold both triggers on the fence sign) puts everything back, with a big satisfying whoosh, for when the yard is too chaotic to use.

**No fail state.** Nothing breaks permanently, nothing dies, nothing runs out. Guns have no ammo. The only cost of anything is that the yard gets sillier.

## The guns

Seven guns at launch. Each does exactly one thing, instantly, with an unmistakable visual and sound, so a 5-year-old learns it in one zap. Each is also a lever Kaden can combine. One button cycles the belt (with a big icon wheel), one button fires, the stick aims. Guns are data: a `GunData` resource with the effect enum and its parameters, so adding gun 8 is a Content lane job.

| Gun | Effect (one thing) | Reads as | For him | For Kaden |
| --- | --- | --- | --- | --- |
| **Grow / Shrink** | Hold up: scale up a step. Hold down: scale down a step. 4 sizes each way. Mass and sound pitch follow | The object swells or shrinks with a boing; a giant cow moos low, a tiny car beeps high | The best gun. Everything huge or tiny is funny | Mass and size are a puzzle variable: a tiny car fits through a pipe, a giant tire is a wall |
| **Gravity grab** | Pick up the aimed object, carry it at arm's length, release to drop, release with flick to throw | Object glows player colour and floats in front of you | Carry the cow around | The building tool. Place, stack, throw |
| **Bouncy** | Toggle: the object becomes a trampoline (restitution near 1.0) | Rubbery wobble, stripes appear | Everything bounces, including Chuck | Ramps that launch; pinball yards |
| **Balloon** | Toggle: gravity scale goes negative, the object drifts up until it hits something or is popped by another zap | A balloon tie appears on top, object floats with a squeak | Floating cow | Lifts, counterweights, a way to park things in the air |
| **Freeze** | Toggle: the object becomes static where it is, mid-air included | Ice crust, a crack sound | Stairs out of frozen chickens | The structural tool: platforms and ramps exactly where you want them |
| **Glue** | Zap object A, then object B: a joint sticks them together. Zap a glued joint to split | Glue blob between them, squelch | Make a cow-car | Compound contraptions |
| **Magnet** | Toggle: the object attracts every other dynamic object within range for 5 seconds | Red-and-silver horseshoe appears, things fly toward it | Everything flies at the cow | Funnels and collectors |

**Rules that keep it readable**

- Effects stack in any order and each is visible: a bouncy, giant, balloon cow shows stripes, a balloon tie, and is large.
- Zapping with the same gun again undoes a toggle (bouncy off, balloon popped, unfrozen, unmagnet). Grow and shrink undo each other. Nothing is one-way.
- Zapping a player: harmless and funny per gun (see Players). Zapping the ground or fence: a sparkle and a dud sound.
- Aiming is a flat stick direction on the locked plane with a wide beam and a generous auto-snap to the nearest object in the cone, so he never misses what he is looking at.
- Every gun has a distinct silhouette, colour and sound, and the belt wheel shows a picture of its effect, not a name.

## How the guns combine

Each gun is one effect a 5-year-old learns in one zap, but effects stack, so the combinations are where Kaden's fun lives. None of the contraptions below are coded; they fall out of the effect stack.

&#91;embedded content: how guns combine · 7 guns, 4 example contraptions\]

The design rule that makes this work: every effect must compose with every other effect without special cases. If a new gun needs an exception ("magnet does not work on frozen things"), it is the wrong gun.

## The yard

One wide junk yard, about six screens long, scrolling sideways, with a fence at each end and a few fixed landmarks. Everything that is not ground, fence or landmark is a physics object that every gun works on.

| Zone | Fixed landmarks | Loose objects | Why it is there |
| --- | --- | --- | --- |
| Front gate | The fence with the goal-card stack, the Reset Yard sign, the tire pile where the sleeping player waits | Tires, crates, a wheelbarrow, a ball | Where you start; simple objects to learn the guns on |
| Scrap heap | A crane with a hanging hook (grab-able) and a conveyor belt that runs when you zap its button | Car, bathtub, fridge, washing machine, a pile of pipes | Big heavy things for grow/shrink and gravity grab |
| Pond | Water (floats light things, splashes everything) and a dock | Rubber duck, a boat, logs, a cow who wandered in | Water is a second physics medium and a great goal target |
| Barn | A hayloft with a drop, a see-saw, a trampoline | Chickens, the cow, hay bales, a tractor, a piano | Animals with faces and sounds; the see-saw and loft for contraptions |
| Tower | A tall junk tower with platforms, a pipe you can send things down, a wind fan you can zap on | Balloons, a kite, a cannon with a cannonball | Height for balloon and freeze play; the pipe is a classic Rube Goldberg element |

**What makes a good object here**

- It has a face or a voice. The cow moos, the car honks, the piano plays a chord when it lands, the fridge door flaps. Objects react to every gun with a sound and a face.
- It has an obvious size and weight so grow and shrink read instantly.
- It survives any combination of effects without breaking the sim (capped scale range, capped velocity, sleep when still).
- It is funny at both ends of the scale: a tiny tractor and a giant chicken are both good.
- About 40 object types at launch, defined as `ObjectData` resources (mesh, mass, sounds, face rig, size limits); the Content lane adds more without code.

**Persistence.** The yard saves every object's transform, scale and active effects on every autosave, so the yard you built is the yard you come back to. Reset Yard restores the default layout.

## Goal cards

A stack of picture-cards clipped to the front fence. The top card is the current goal. Walk up to the fence to see it big; it also sits small in a corner of the HUD. Completing it plays fireworks, both characters cheer, the card flips into a "done" pile with a stamp, and the next one shows. Cards are optional: nothing nags, nothing times out, and the yard is fully playable with the stack ignored forever.

**Data model (`GoalData` resource)**

| Field | Notes |
| --- | --- |
| `id`, `description` | description for Hermes and release notes only; never shown |
| `picture` | the card art: a simple pictogram of the goal (ball + arrow + bathtub) |
| `band` | 1 easy, 2 medium, 3 dad |
| `condition` | a small set of checkable predicates: `object_in_zone(ball, bathtub)`, `object_height_above(car, 10m)`, `stack_height(any, 3 objects, taller than barn)`, `object_has_effect(cow, balloon)`, `object_speed_over(duck, 15)`, `glued_pair(cow, car)` |
| `hint_objects` | objects that glow softly when the card is viewed, so he can find them |

**Example cards**

| Band | Card | Condition |
| --- | --- | --- |
| 1 | Make the cow big | `object_scale_at_least(cow, +2)` |
| 1 | Float a chicken | `object_has_effect(chicken, balloon)` |
| 1 | Put the duck in the bathtub | `object_in_zone(duck, bathtub)` |
| 2 | Get the ball into the bathtub from the barn loft | `object_in_zone(ball, bathtub)` and the ball was last touched in the barn zone |
| 2 | Stack three things taller than the barn | `stack_height(3, barn_roof)` |
| 2 | Make the car fly over the fence | `object_height_above(car, fence_top)` and `object_speed_over(car, 8)` |
| 3 | Send the piano down the tower pipe into the pond | sequence: `object_in_zone(piano, pipe_top)` then `object_in_zone(piano, pond)` |
| 3 | Build a cow-car-balloon raft that floats over the pond | `glued_pair(cow, car)` and `object_has_effect(any_in_pair, balloon)` and `object_in_zone(pair, pond_air)` |
| 3 | Chain reaction: knock the ball off the loft without touching the ball | `object_in_zone(ball, ground)` and the ball's last contact was an object, not a gun |

- The deck is ordered easy to hard but a card can be skipped by zapping it (it goes to the back with a raspberry sound). He will skip the dad cards; that is fine.
- 30 cards at launch, as `.tres` files. New decks can ship in updates (holiday deck, animals deck).
- Done cards stay in a pile he can flip through: his trophy shelf.
- Kaden can author cards by hand in minutes; the condition vocabulary is the whole puzzle language.

**The launch deck (30 cards, 2026-11-10).** 12 band 1, 10 band 2, 8 band 3, ordered by band, then
`rank`, then id; `b1_big_cow` stays first and the first five are all one-zap or one-carry. Every card
has `hint_objects` and a test that completes it in a real yard through the guns
(`tests/test_goal_deck.gd`). Condition vocabulary: `docs/contracts.md` "Goal conditions". The new
cards' pictures are baked from code (`scripts/goals/card_art.gd`); the first ten still use the
pictogram `Pictos` draws from the condition.

| Band | Card (id) | Condition |
| --- | --- | --- |
| 1 | Make the cow big `b1_big_cow` | scale_at_least(cow, +2) |
| 1 | Float a chicken `b1_float_chicken` | has_effect(chicken, balloon) |
| 1 | Make anything bouncy `b1_bouncy_any` | has_effect(any, bouncy) |
| 1 | Make the car tiny `b1_tiny_car` | scale_at_most(car, -1) |
| 1 | Freeze the cow `b1_freeze_cow` | has_effect(cow, freeze) |
| 1 | Magnet on the fridge `b1_magnet_fridge` | has_effect(fridge, magnet) |
| 1 | Ball in the bathtub `b1_tub_ball` | in_zone(ball, bathtub) |
| 1 | Duck in the bathtub `b1_duck_in_tub` | in_zone(duck, bathtub) |
| 1 | Glue two things `b1_glue_two` | glued_pair(any, any) |
| 1 | Sheep to the front gate `b1_sheep_to_gate` | in_zone(sheep, front_gate) |
| 1 | Pig in the pond `b1_pig_in_pond` | in_zone(pig, pond) |
| 1 | Make the tractor tiny `b1_tiny_tractor` | scale_at_most(tractor, -1) |
| 2 | Float the car `b2_float_car` | has_effect(car, balloon) |
| 2 | Cow-car `b2_cow_car` | glued_pair(cow, car) |
| 2 | Giant chicken `b2_giant_chicken` | scale_at_least(chicken, +3) |
| 2 | Three things in the tub `b2_three_in_tub` | in_zone(any, bathtub) x3 |
| 2 | Chicken stairs `b2_chicken_stairs` | all_of(has_effect freeze, height > 1 m) x3 chickens |
| 2 | Duck on top of the tower `b2_duck_on_tower` | in_zone(duck, tower_top) |
| 2 | Ball into the tub from the barn loft `b2_tub_from_loft` | in_zone(ball, bathtub), last touched in barn_loft |
| 2 | Knock the egg off the loft `b2_egg_off_loft` | sequence: resting in barn_loft, then below 1.5 m with no gun touch |
| 2 | Car over the fence `b2_car_over_fence` | all_of(height > 4.5 m, speed > 8) |
| 2 | Stack three taller than the barn walls `b2_stack_three` | stack_height(3, top above 7 m) |
| 3 | Really fast duck `b3_fast_duck` | speed_over(duck, 15) |
| 3 | Tractor in the loft `b3_tractor_loft` | all_of(in barn_loft, resting) |
| 3 | Cow higher than the tower `b3_cow_over_tower` | height_above(cow, 13 m) |
| 3 | Stack five `b3_stack_five` | stack_height(5) |
| 3 | Cannonball from the tower into the pond `b3_cannonball_pond` | in_zone(cannonball, pond), last touched in tower |
| 3 | Cow-car-balloon raft over the pond `b3_raft` | all_of(glued to car, balloon on the pair, over_pond) |
| 3 | Chain reaction off the loft `b3_chain_ball` | sequence: ball resting in barn_loft, then below 1.5 m with no gun touch |
| 3 | Piano down the tower pipe into the pond `b3_piano_pipe_pond` | sequence: pipe_top, pipe_bottom, pond |

## Camera and controls

2.5D: a 3D scene with real tumbling physics, viewed from the side by an orthographic-ish camera, with both players and all aiming locked to one plane. Depth is for looks only, so anything above a thing lands on that thing and the stick aims exactly where it points.

| Input | Does |
| --- | --- |
| Left stick | Move left/right; aim direction while firing (the beam follows the stick) |
| A (Action) | Fire the current gun. Hold for grow/shrink and gravity grab |
| B (Jump) | Jump. Low, floaty, forgiving. Both characters can hop onto most objects |
| RB / LB | Next / previous gun. A big icon wheel pops for half a second |
| Right stick | Also aims, for players who want it. Never required |
| Start | Pause |
| Select | Not used in play; the Reset Yard sign is in-world, hold A on it |

- Camera: shared, frames both players, zooms out as they separate, soft-locked to the yard bounds. Never splits. If one player wanders off-screen the camera leans toward them and a little arrow with their colour points the way.
- Objects can tumble in 3D but are nudged back toward the play plane by a gentle spring, so nothing drifts behind or in front of the players.
- Aim assist: the beam is a wide cone and snaps to the nearest object in it. Shooting at nothing produces a sparkle, not a miss sound.

## Art direction

A toy diorama: low-poly, flat-shaded 3D with thick outlines, lit like a model on a table, viewed from the side. Everything looks hand-made from junk and slightly too chunky. Palette from three Hermes proposals.

- **Technique:** low-poly flat-shaded 3D (same pipeline as Spaceballs), outline pass, soft shadows from one key light, a painted sky backdrop with parallax clouds. Camera slightly above eye level so the ground plane reads.
- **Reference feel:** diorama and stop-motion toy sets, Human: Fall Flat for soft physics comedy, Untitled Goose Game for flat-shaded clarity. Vibe only; original designs.
- **Palette:** Hermes proposes three. Constraints: junk is rusty and warm, the sky and pond are cool, and each gun has its own saturated effect colour that is never green or red (those belong to Jeff and Chuck).
- **Objects:** every object has a simple face (two dots and a mouth is enough) that reacts: wide-eyed when grabbed, dizzy when thrown, smug when bouncy, panicked when ballooning. Scale extremes get extra charm: a tiny cow is impossibly cute, a giant chicken is terrifying in a good way.
- **Guns:** junk-built, each with a signature silhouette (dish, cone, bellows, funnel, snow globe, glue bottle, horseshoe) and effect colour; Jeff's in green tape, Chuck's in red tape.
- **Effects:** scale change is a squash-and-stretch boing with a ring particle; balloon adds a floating tie; freeze adds an ice crust; glue adds a blob; bouncy adds stripes and wobble; magnet adds a horseshoe and sparks; grab adds a player-coloured glow.
- **Juice:** screen shake scaled to impact mass, dust on landings, splash in the pond, chord when the piano lands, fireworks on a completed card.
- **Store art:** grid is Jeff zapping a cow to giant size while Chuck rides a ballooned bathtub; hero is the whole yard at golden hour.

## Audio

Every zap, every impact, every object has a voice. Soundbox for SFX, Chatterbox for Jeff and Chuck, ElevenLabs for music and anything that needs polish.

| Cue | Plays when | Feel |
| --- | --- | --- |
| `zap_<gun>` | each gun fires (7 cues) | distinct per gun: boing, hum, rubber twang, squeak, crack, squelch, electric buzz |
| `grow`, `shrink` | scale step | rising / falling boing; object voice pitch follows size |
| `grab`, `throw` | gravity gun | hum up, whoosh |
| `impact_<mass>` | object lands, 4 mass bands | thud to boom; scaled by size |
| `splash` | pond |  |
| `object voices` | each object reacts to any gun | cow moo, car honk, piano chord, fridge rattle, chicken bawk, duck squeak |
| `card_view`, `card_done`, `card_skip` | goal cards | page flip, fireworks and cheer, raspberry |
| `reset_yard` | reset | big whoosh and a bell |
| `wheel_move` | gun wheel | click |

- Music: a lazy junk-yard loop (washboard, banjo, kazoo) that stays quiet under the chaos and brightens for ten seconds after a completed card.
- Barks: Jeff reacts to every big impact with delight; Chuck narrates his own zaps and blames Jeff for mishaps. One bark per zap maximum so they never talk over the physics.
- Rule from the kid-design checklist: no scary sounds. Even the biggest crash is a cartoon crash.

## Technical plan

Godot 4.7.2 from `openjar-template`, 3D with Jolt, players as `CharacterBody3D` on a locked Z plane, objects as `RigidBody3D` with per-object data, guns as one script each that mutates physics properties. Lowest technical risk in the library; the only things to prototype early are scale-change stability and glue joints under Jolt.

**Scenes**

| Scene | Lane | Notes |
| --- | --- | --- |
| `scenes/main.tscn` | Systems | From the template; swaps `Arena` for `scenes/levels/yard.tscn` |
| `scenes/levels/yard.tscn` | Gameplay | Zones, landmarks, spawn points, the fence with the card stack, Reset sign, plane-spring area |
| `scenes/players/zapper.tscn` | Systems | `CharacterBody3D` locked to Z=0, aim cone, gun belt, jump; inherits to `jeff.tscn` / `chuck.tscn` (Art) |
| `scenes/objects/physics_object.tscn` | Systems | `RigidBody3D` + `EffectStack` node + face rig + voice; configured by `ObjectData` |
| `scenes/guns/*.tscn` | Gameplay | One per gun: beam visual, target pick, `apply(target)` / `undo(target)` |
| `scenes/ui/gun_wheel.tscn`, `card_hud.tscn` | Systems (structure), Art (theme) |  |
| `scenes/fx/*.tscn` | Art | Per-effect attachments: balloon tie, ice crust, glue blob, stripes, horseshoe, glow |

**Effects as a stack**

- Every object carries an `EffectStack` (array of active effects). Each gun's `apply` pushes or toggles an effect and the stack recomputes the body: `scale`, `mass`, `gravity_scale`, `physics_material.bounce`, `freeze`, joints, magnet timer. Undo pops it. Visual attachments are driven from the same stack so what you see is always what the sim is doing.
- Scale changes re-create the collision shape and scale mass by volume, with a cap of 4 steps each way and a velocity clamp during the change. Prototype this first; Jolt handles runtime scaling but large jumps need the clamp.
- Glue is a `Generic6DOFJoint3D` (locked) between the two bodies; the joint node holds the blob visual. Splitting frees the joint.
- Magnet applies a central force toward the target to every dynamic body in a sphere for 5 seconds, capped per body so nothing goes ballistic.
- Plane lock: players have Z locked via `axis_lock_linear_z`; objects get a soft spring toward Z=0 each physics frame so tumbling looks 3D but nothing escapes the plane.

**Data (Content lane)**

- `data/guns/*.tres` as `GunData`: effect enum, parameters, icon, beam colour, cues.
- `data/objects/*.tres` as `ObjectData`: mesh, base mass, size limits, face rig, voice cues, zone of origin.
- `data/goals/*.tres` as `GoalData` (see Goal cards).
- `data/yard_layout.tres`: default object placement for Reset Yard.

**Game-specific contracts (add to `docs/contracts.md`)**

```gdscript
signal zapped(player: int, gun: StringName, target: Node3D)
signal effect_changed(target: Node3D, effect: StringName, on: bool)
signal object_landed(target: Node3D, impulse: float)
signal goal_completed(goal_id: StringName)
signal goal_skipped(goal_id: StringName)
signal yard_reset()
func Goals.check(goal: GoalData) -> bool
func Yard.objects_in_zone(zone: StringName) -> Array[Node3D]
```

**Save:** every object's transform, scale and effect stack; the goal deck position and done pile; last gun per player. Autosave every 30 seconds and on pause.

**Performance:** \~40 live rigid bodies with Jolt is trivial on the 1060. Watch the outline pass and particle counts, not physics. Sleep objects when still.

**Lanes active:** Systems, Gameplay, Art, Content, Audio, Reviewer. All six.

## Build phases

| Phase | Lanes | Output | Tag |
| --- | --- | --- | --- |
| 0. Design sprint | Hermes + Kaden | This doc becomes `GAME.md`; palette picked; repo `junk-yard-zap` created from the template (public, topic `openjar-game`, `dev` branch) |  |
| 1. Risk prototype | Systems, solo | Ten boxes, one gun with grow/shrink and one with glue, under Jolt; confirm scaling and joints are stable | `v0.0.1-dev.1` |
| 2. Grey-box | Systems, solo | Two capsule players on the locked plane, gravity grab and grow/shrink on primitive objects, gun wheel, every action beeps | `v0.0.2-dev.N` |
| 3. Parallel build | all lanes | Gameplay: all seven guns, zones, goal checker, reset. Art: Jeff, Chuck, guns, 40 objects with faces, effect attachments, yard. Content: objects, guns, 30 cards, layout. Audio: zaps, impacts, object voices, barks. Systems: save of the yard, HUD, drop-in | `v0.x-dev.N` |
| 4. First playable | Hermes promotes | Seven guns, ten objects, ten cards, placeholder art allowed; **Kaden and his son play it** | `v0.1.0` |
| 5. Polish | all lanes | Final art, full object set, full deck, music, store art, tuning from playtests | `v0.x` |
| 6. Release | Hermes | On the TV main tile | `v1.0.0` |

**First playable definition:** both players can walk, jump, cycle seven working guns and zap ten objects with every effect stacking and undoing cleanly; ten goal cards complete and skip; the yard saves and reloads; every action has a sound and a visual. Art may be boxes with faces.

## Kid-design checks specific to this game

On top of the template checklist in `docs/kid-design.md`.

- [ ] Every gun does something visible and audible on the first zap, with no setup.
- [ ] Every effect can be undone by zapping again; nothing is permanent except by choice.
- [ ] Aim assist means pointing roughly at a thing hits that thing.
- [ ] Zapping your partner is always funny and never hinders them for more than a second.
- [ ] Goal cards never nag, never time out, and can be skipped with one zap.
- [ ] Reset Yard is reachable in-world without a menu.
- [ ] Camera never splits and never loses a player.
- [ ] No object can be launched off the map or stuck inside geometry; clamps and a recall (objects that leave bounds respawn at the gate with a parachute).
- [ ] Giant and tiny extremes are capped so nothing fills the screen or vanishes.
- [ ] Every object has a face and a voice; nothing is a mute grey box in the shipped game.

## Out of scope and open questions

**Out of scope for v1**

- Building new objects or a level editor. The yard is the yard.
- More than one yard. A second yard (a beach, a space station) is a natural update.
- Online play, versus, scores.
- Guns beyond the seven, until the seven are perfect. Candidates for later: time-slow, paint, duplicate, rocket.

**Open questions for Kaden**

- [ ] Palette: pick one of three.
- [ ] Should the cow be a library character (a name, a personality, appears in other games) or stay a yard object? Recommendation: library character; a recurring cow is a gift that keeps giving.

## Decisions made without Kaden

- 2026-11-09 (Gary): physics bodies use `body_mass = volume_mass ^ 0.5` (`Yard.mass_exponent`); the logical mass by volume still drives cards, impact sounds and juice. Jolt sinks light bodies under heavy ones past ~25:1; this keeps "heavier is heavier" stable. Grow is refused (a "nope" boing) when it would push into static or frozen things; glue pulls the two objects together before locking and lets go after 3 s if they can't meet.
- 2026-11-10 (playtest #1 polish lane, for Gary/Kaden to confirm):
  - **Partner aim ring:** when your beam snaps to your partner, your ring circles his whole body at chest height. Before this it sat at his feet and read as a player ring in the wrong colour (the "red ring under Jeff"). A sleeping partner in the tire pile is not a target.
  - **Mouse pointer:** always hidden in gameplay. Nothing in the game uses a mouse, so it only reappears after the mouse moves while a menu (lobby, pause) is up, and hides again on the next pad or key press.
  - **Wide view:** the table now has a deep wooden apron with three drawers, and the camera never pitches below the apron's bottom edge (`CameraRig.min_y`). This applies to the lobby/overview shot and the widest play zoom.
  - **Ten goal cards** (the first-playable count), using the existing condition vocabulary: freeze the cow, ball in the bathtub (band 1), float the car, a cow-car (cow glued to car), a giant chicken (+3) (band 2). Content lane: replace or reorder freely. `b1_big_cow` stays the first card.
  - **Balloons park 6 m up** (`Effects.Balloon.MAX_RISE`) if nothing stops them first, so a ballooned cow stays on screen and in reach of a zap instead of floating up to the lid. Parked balloons stay parked across a save/reload.
  - **Reset Yard hold is 2.0 s** (was 1.2). The sign is 3 m from Jeff's spawn, and a kid holding A to grab or grow nearby must not wipe the yard by accident.
- 2026-11-10 (Showtime menus lane, for Gary/Kaden to confirm):
  - **Menus are the template's Showtime kit** (D48 d: "B Showtime + blurred game world + C squash"), skinned by `data/menu_skin.tres`: accent `#ffb21f`, sunburst `#ff6a2b`, deep `#33201a`, title "Junk Yard Zap" in the kit's Baloo face.
  - **Backdrop is `SCREEN`:** the menu blurs the yard the game already draws behind the lobby (the overview camera). No second yard is loaded (`SCENE` mode would run the yard's physics twice).
  - **Podiums:** Jeff (P1, green) and Chuck (P2, red) are the game's own Jarling rigs holding the size gun taped in their colour, turned three-quarters toward the menu so the gun points across the stage. Facing the camera, its dish read as a frisbee covering the body.
  - **Round card:** "ZAP TIME!" with a "THE YARD IS OPEN" strip under it. The kit draws the card title at a fixed size, and "THE YARD IS OPEN" as the title ran off both edges of the screen.
  - **Solo is never restored at boot.** The settings row still mirrors solo while it is on, but a saved "on" no longer turns it on next launch. Solo is `--solo` or Select+Start for 2 s only.
- 2026-11-10 (Systems, character chooser adoption, for Gary/Kaden to confirm):
  - **You play whoever you picked.** The lobby chooser (template) picks each player's Jarling; the yard spawns that character with the same belt, taped junk guns (P1 green, P2 red, whoever is picked), partner zaps, aim rings and drop-in. Jeff (P1) and Chuck (P2) stay the defaults. Older text that says "Jeff" for P1 and "Chuck" for P2 means "the P1 / P2 pick".
  - **Barks follow the character:** a character's own `bark_<id>` cue if the game has one, else their voice pack from `openjar-characters`, else a generic `bark` beep. Never another character's voice.
  - **The belt moved** to `assets/gear/belt.glb`: `assets/characters/` belongs to the sync tool, which removes anything not in the roster.
- 2026-11-10 (goal deck lane, for Gary/Kaden to confirm):
  - **"Taller than the barn" means the barn walls (7 m)**, not the ridge (about 10 m): three crates and a fridge on the loft get there; the ridge needed giant things stacked, a dad card at band 2.
  - **A "gun touch"** (for "from the loft" and the chain-reaction cards) is any zap on the object or holding it with gravity grab. Throws, magnets on *other* things, the see-saw and shoving with a held object are not touches, so bulldozing the egg off with a held hay bale counts as knocking it off.
  - **The piano card does not require the piano to slide down the pipe on its own.** Shrunk to fit, it slides part way and can wedge; a shove inside the pipe is fine. It must pass the pipe's top and bottom and then reach the pond.
  - **The deck checks the top card every 0.1 s** (was 0.25 s) so a car flying over the fence is not missed mid-arc. One card, at most 40 objects, no allocation beyond the group list.
  - **The first two "anything" cards now hint** (bouncy: ball and tire; glue: the two crates) so every card glows something.
