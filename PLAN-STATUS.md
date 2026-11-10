# Plan status: Junk Yard Zap

Checked 2026-11-10 against `dev` @ `dac1ce6` (tag `v0.0.2-dev.4`). Updated 2026-11-10 by the polish lane (jyz-polish-1, branch `feature/yard-polish`): S-16, A-13, K-08, Y-04, Y-05, Y-08, Y-10, M-03 to built; Y-11 and G-13 notes. Updated 2026-11-10 by the comedy lane (jyz-comedy-1, branch `feature/yard-comedy`): P-05, P-06, P-07, A-12 to built. Updated 2026-11-10 by the trophy lane (jyz-trophy-1, branch `feature/yard-trophy`): G-13 to built. Format: `~/openjar/lanes/plan-status-format.md`.
Lanes: update your rows in the same commit as the work. New briefs add rows; never delete or renumber.

Sources (newest last):
- S1 `~/openjar/JUNKYARD-PLAN-2026-11-09.md` (Kaden's original brief). GAME.md keeps it nearly verbatim; rows cite the S1 section.
- S2 GAME.md "Producer notes" (2026-11-09), plus the Kaden quotes in GAME.md: build order (Pitch) and "No personal info or real places, ever".
- S3 GAME.md "Decisions made without Kaden": 2026-11-09 (Gary), physics mass and grow/glue rules.
- S4 GAME.md "Decisions": 2026-11-10, playtest #1 polish lane.
- S5 GAME.md "Decisions": 2026-11-10, Showtime menus lane.
- S6 GAME.md "Decisions": 2026-11-10, Systems character-chooser adoption.
- S7 GAME.md "The launch deck (30 cards, 2026-11-10)" and "Decisions": 2026-11-10, goal deck lane.

GAME.md has no "Playtest ... changes" section yet: `playtests/` holds only `_TEMPLATE.md`, so Kaden hasn't played a build. Playtest #1 is tonight.

How this was checked: the full suite ran once from a fresh import (`--ignoreHeadlessMode`): **186/186 test cases green, 0 errors**. Real frames came from `scripts/tools/shots.sh` (`--demo --demo-beat=combo|goal|wide|rings|apart`, plus the lobby) into `.scratch/shots/<beat>/t004.0s.png` (lobby: `t002.0s.png`). That folder is gitignored, so re-run the script to see the frames. I looked at every frame. Test names are `file::test`, with files under `tests/`.

Area prefixes: C core loop, build phases, open questions · P players · U guns · Y yard and objects · G goal cards · S systems, camera, controls, save · M menus · V visuals · A audio · K kid-design checks.

## Core loop, phases, open questions

| ID | Source | Item (short, Kaden's words where possible) | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| C-01 | S1 Core loop | "There is no round. A session is however long you want" | built | test_playtest1.gd::test_a_whole_session_loops_cleanly_in_the_main_scene, scenes/main.gd header | |
| C-02 | S1 Core loop | Saves the yard as you leave it ("every zapped cow stays zapped") | built | test_greybox.gd::test_save_load_round_trip, test_playtest1.gd::test_balloon_parks_in_reach_and_a_reload_keeps_it_there | |
| C-03 | S1 Core loop | Layer 1 Toy: fire any gun at anything, something visible and funny happens instantly | built | test_greybox.gd::test_toggle_guns_zap_and_undo_with_a_sound, frame combo | |
| C-04 | S1 Core loop | Layer 3 Emergence: guns stack and combine | built | test_physics_proto.gd::test_every_pair_of_effects_composes, test_more_objects.gd::test_new_types_every_pair_composes_and_caps_hold, frame combo (giant bouncy balloon cow) | |
| C-05 | S1 Core loop | "Load into the yard as you left it. Jeff and Chuck wake up" | built | test_greybox.gd::test_players_who_ready_in_the_lobby_start_awake | |
| C-06 | S1 Core loop | Reset Yard puts everything back, with a big satisfying whoosh | built | test_greybox.gd::test_reset_yard_puts_everything_back, yard_level.gd:150-153 (cue + shake) | The whoosh is a synth placeholder (A-08) |
| C-07 | S1 Core loop | Reset Yard by "hold both triggers on the fence sign" | superseded | S1 Controls table ("hold A on it") and S4 (2.0 s hold); see S-08 | S1 contradicts itself; the controls table won |
| C-08 | S1 Core loop | No fail state: nothing breaks, nothing dies, guns have no ammo | built | scripts/guns/gun_data.gd (no ammo field; `ammo` appears nowhere in scripts/), test_playtest1.gd::test_objects_leaving_the_yard_come_back_at_the_gate | |
| C-09 | S1 Build phases | Phase 0: GAME.md, palette picked, repo with `dev` | built | GAME.md; palette D44 a in `~/openjar/HANDOFF-2026-11-10-morning.md` | GAME.md still shows the palette question as open (C-17) |
| C-10 | S1 Build phases | Phase 1 risk prototype, tag `v0.0.1-dev.1` | built | `git tag` v0.0.1-dev.1, scenes/proto/risk_proto.tscn, test_physics_proto.gd::test_proto_scene_loads | |
| C-11 | S1 Build phases | Phase 2 grey-box, `v0.0.2-dev.N` | built | tags v0.0.2-dev.1 … dev.4, test_greybox.gd | |
| C-12 | S1 Build phases | Phase 3 parallel build: Gameplay, Art, Content, Audio, Systems | partial | rows U, Y, G, S, V | Every lane ran except Audio: all SFX are placeholder beeps and there is no music (A rows) |
| C-13 | S1 Build phases | Phase 4 first playable `v0.1.0`: "**Kaden and his son play it**" | partial | the definition is covered by test_playtest1.gd::test_both_players_walk_and_jump, ::test_ten_objects_stack_every_effect_and_undo_cleanly, test_greybox.gd::test_ten_cards_all_skip_through_and_come_back, ::test_save_load_round_trip | No `v0.1.0` tag and no playtest report yet. "Every action has a sound" holds only with placeholder beeps |
| C-14 | S1 Build phases | Phase 5 polish: final art, full object set, full deck, music, store art, tuning from playtests | partial | 48 object types, 30 cards, store/grid.png, store/hero.png | Music missing (A-10); no playtest tuning yet |
| C-15 | S1 Build phases | Phase 6 release `v1.0.0` on the TV main tile | later | | v1.0.0 |
| C-16 | S1 Pitch | Build order: game 2, "or swapped" (recommendation: make it game 1) | superseded | S2 Pitch: Kaden 2026-11-09, **game 2** after Spaceballs | |
| C-17 | S1 Open questions | Palette: pick one of three | built | Kaden's D44 a (Golden Afternoon, smooth) in `~/openjar/HANDOFF-2026-11-10-morning.md`; art/direction/compare.png | GAME.md still lists it as an open question: tick it there |
| C-18 | S1 Open questions | Cow as a library character or a yard object (recommendation: library character) | missing | GAME.md "Open questions" still unchecked | Waiting on Kaden |
| C-19 | S1 Open questions | Must-have objects from Kaden's own junk yard or shop | superseded | S2 "No personal info or real places, ever"; GAME.md dropped the question | |
| C-20 | S1 Out of scope | Level editor, a second yard, online/versus/scores, guns beyond seven (time-slow, paint, duplicate, rocket) | later | GAME.md "Out of scope for v1" | After v1 |

## Players

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| P-01 | S1 Players | Jeff P1 green, Chuck P2 red | built | test_playtest1.gd::test_p1_is_jeff_and_green_p2_is_chuck_and_red, test_jyz_chooser.gd::test_defaults_are_jeff_p1_and_chuck_p2 | Now the defaults (P-02) |
| P-02 | S1 Players | Player-locked Jeff/Chuck | superseded | S6 "You play whoever you picked": test_jyz_chooser.gd::test_spawn_follows_the_pick_with_the_stand_in, ::test_swapped_picks_keep_the_slot_colours | |
| P-03 | S1 Players, S2 | Each player has a gun belt; guns are gear (`hand_r` gun, `waist` belt) on Jarlings | built | test_jyz_chooser.gd::test_gear_equips_on_the_picked_body, test_art.gd::test_every_gun_is_gear_with_a_muzzle_and_player_tape, assets/gear/belt.glb | |
| P-04 | S1 Players | Gun look: Jeff a hair dryer with a satellite dish, Chuck a leaf blower with a traffic cone | superseded | S1 Art direction "Guns" (one silhouette per gun, not per player): scripts/art/gun_art.gd:1-4 | Everyone gets the same hair-dryer body with a per-gun nozzle and their own tape colour. Chuck's leaf blower doesn't exist |
| P-05 | S1 Players | Jeff: "Delighted by everything; applauds Chuck's disasters" | built | test_comedy.gd::test_jeff_claps_at_a_big_impact_and_everyone_wobbles, ::test_bark_rate_cap_holds_back_a_burst_of_impacts, scripts/players/reactions.gd `big_impact()`, frames handoff/frames/p05_delight_hop.png, p05_delight_full.png | A heavy or huge landing within 30 m: Jeff claps (the rig's own `cheer` clip), hops, beams, throws gold sparks and barks `delight`. Everyone else awake does the wobble (V: the reaction clip). He claps at every big impact, not only Chuck's: nothing tracks who caused a landing |
| P-06 | S1 Players | Chuck: "Takes credit for everything that works, blames Jeff" | built | test_comedy.gd::test_one_bark_per_zap, ::test_chuck_blames_the_partner_when_a_zap_is_refused, reactions.gd `own_zap()`, `blame()`, frames handoff/frames/p06_chuck_narrates.png, p06_chuck_blames.png, p06_blame_full.png | Credit: his zap works, he puffs up, leans back, beams and barks `zap`. Blame: his zap gets a "nope", he turns on his partner, stamps, a ring in the partner's colour pops round the partner (whose face goes surprised) and he barks a plain `bark` ("hey!"): there is no blame cue. Any roster character who narrates also blames; Jeff never does |
| P-07 | S1 Players | Idles: Jeff pokes at junk and hums; Chuck kicks a tire and checks his hat | built | test_comedy.gd::test_jeff_pokes_the_junk_and_it_answers, ::test_chuck_kicks_a_tire_with_his_own_kick, ::test_a_missing_action_falls_back_to_idle, ::test_nothing_in_reach_turns_into_the_other_bit, ::test_a_still_player_idles_on_his_own_and_moving_stops_it, frames handoff/frames/p07_idles.png, p07_poke_kick_full.png, p07_hum_hat_full.png | After 4 s standing still, a bit every 4.5-7 s. Each bit asks the rig for its action (`JarlingRig.has_action`, the glb's clips) and falls back to idle with a lean, hop or tilt on top. The standard Jarling has only `kick`, so poke, hum and hat are idle + procedural. Other Jarlings do all four bits. Hum uses `sparkle` played low and the hat a `wheel_move` click (no hum or hat cue) |
| P-08 | S1 Players | Co-op: no one owns an object; both players' effects apply | built | test_physics_proto.gd::test_every_pair_of_effects_composes, frame combo (Jeff grows, Chuck bounces, the same cow) | |
| P-09 | S1 Players | Zapping your partner: harmless and funny for each gun (huge, floats, a statue that keeps talking) | built | test_greybox.gd::test_partner_zaps_are_funny_and_last_at_most_a_second, ::test_frozen_partner_is_a_statue_then_moves_again | |
| P-10 | S1 Players | Drop-in: second player asleep in the tire pile, a button press wakes him with a snort | built | test_greybox.gd::test_chuck_sleeps_in_the_tire_pile_and_wakes_with_a_snort, test_lobby.gd::test_late_joiner_wakes_up_in_the_tire_pile | S2: works from the lobby too |
| P-11 | S2 | Same Jarlings as Spaceballs, from openjar-characters | built | test_roster.gd, test_jyz_chooser.gd::test_main_spawns_the_picks_and_drop_in_sleeps_the_pick, frame goal | Roster synced to v0.4.0 |
| P-12 | S6 | Barks follow the character: own cue, else their voice pack, else a generic beep, never another character's voice | built | test_jyz_chooser.gd::test_barks_fall_back_to_generic_never_another_voice, ::test_a_character_with_own_cue_uses_it | |
| P-13 | S4 | Partner aim ring circles the partner at chest height; a sleeping partner is not a target | built | test_playtest1.gd::test_partner_aim_ring_circles_the_partner_not_his_feet, ::test_a_sleeping_partner_is_not_a_target | |

## Guns

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| U-01 | S1 Guns | Seven guns; guns are data (`GunData`), so gun 8 is a Content job | built | data/guns/1_size … 7_magnet.tres, test_greybox.gd::test_belt_has_seven_guns_in_belt_order | |
| U-02 | S1 Guns | Grow/Shrink: 4 sizes each way; mass and sound pitch follow | built | test_physics_proto.gd::test_grow_shrink_limits_and_mass_by_volume, physics_object.gd:586 (pitch 1/√scale) | |
| U-03 | S1 Guns | Grow/Shrink controls: "Hold up: scale up. Hold down: scale down" | built | test_greybox.gd::test_size_gun_tap_grows_stick_down_shrinks_hold_repeats | Built a little differently: tap A = bigger, A + stick down = smaller, hold repeats. The decision is in the grey-box lane report, not in GAME.md |
| U-04 | S1 Guns | Gravity grab: carry at arm's length, release to drop, flick to throw, glows in the player's colour | built | test_greybox.gd::test_grab_carries_at_arms_length_and_drops_on_release, ::test_flick_throws | |
| U-05 | S1 Guns | Bouncy: toggle, restitution near 1.0, stripes and wobble | built | test_greybox.gd::test_toggle_guns_zap_and_undo_with_a_sound, frame combo (yellow stripes) | |
| U-06 | S1 Guns, S4 | Balloon: drifts up until it hits something or is popped; tie on top. S4: parks 6 m up | built | test_playtest1.gd::test_balloon_parks_in_reach_and_a_reload_keeps_it_there, frame combo (balloon and tie) | |
| U-07 | S1 Guns | Freeze: static where it is, mid-air included; ice crust | built | test_greybox.gd::test_toggle_guns_zap_and_undo_with_a_sound, scripts/physics/effect_look.gd | Crack sound is a placeholder (A-01) |
| U-08 | S1 Guns, S3 | Glue: zap A then B to join them, zap the joint to split; blob. S3: pulls them together, lets go after 3 s | built | test_greybox.gd::test_glue_gun_sticks_two_things_and_the_blob_splits_them, test_physics_proto.gd::test_glue_pulls_distant_objects_together | |
| U-09 | S1 Guns | Magnet: toggle; attracts every dynamic object in range for 5 s | built | test_physics_proto.gd::test_magnet_switches_itself_off, ::test_tiny_magnet_under_a_giant_is_not_crushed | |
| U-10 | S1 Guns | Magnet horseshoe is "red-and-silver" | superseded | blue-and-silver (red is Chuck's): test_art.gd::test_gun_hues_stay_clear_of_the_players | Decided in the jyz-art-direction-1 report; not recorded in GAME.md |
| U-11 | S1 Rules | Effects stack in any order and each one is visible | built | test_physics_proto.gd::test_every_pair_of_effects_composes, frame combo | |
| U-12 | S1 Rules | Zapping again with the same gun undoes it; grow and shrink undo each other; nothing is one-way | built | test_physics_proto.gd::test_undo_restores_exactly, test_playtest1.gd::test_ten_objects_stack_every_effect_and_undo_cleanly | |
| U-13 | S1 Rules | Zapping the ground or fence: a sparkle (S1 Camera: "not a miss sound") | built | test_greybox.gd::test_zapping_nothing_sparkles | S1 Rules says "a dud sound" and S1 Camera says "not a miss sound"; the build plays a sparkle |
| U-14 | S1 Rules | Wide beam, generous auto-snap to the nearest object in the cone | built | test_physics_proto.gd::test_aim_cone_snaps_to_nearest | |
| U-15 | S1 Rules | Every gun has a distinct silhouette, colour **and sound** | partial | test_art.gd::test_every_gun_is_gear_with_a_muzzle_and_player_tape, ::test_gun_hues_stay_clear_of_the_players | Silhouettes and colours are done. The sounds are 7 synth beeps from one recipe (synth.gd `zap_`) |
| U-16 | S1 Rules | The belt wheel shows a picture of the effect, not a name | built | test_greybox.gd::test_belt_cycles_both_ways_with_a_click, scenes/ui/hud/hud.gd, frames (gun pictograms in the HUD corners) | |
| U-17 | S1 Combine | Every effect composes with every other, with no special cases | built | test_physics_proto.gd::test_every_pair_of_effects_composes | |
| U-18 | S3 | Grow is refused with a "nope" boing when there's no room | built | test_physics_proto.gd::test_grow_with_no_room_is_refused, ::test_grow_on_frozen_object_does_not_crush_through_floor | |
| U-19 | S3 | Physics body mass = volume_mass^0.5; logical mass still drives cards and juice | built | test_physics_proto.gd::test_giant_landing_on_a_crate_does_not_sink_it | Supersedes S1 Tech "scale mass by volume" for the physics body only |

## Yard and objects

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| Y-01 | S1 Yard | One wide yard, about six screens, a fence at each end | built | frame wide | |
| Y-02 | S1 Yard | Five zones: front gate, scrap heap, pond, barn, tower | built | frame wide, test_goal_deck.gd::test_every_gun_and_zone_has_a_card | |
| Y-03 | S1 Yard | Front gate: fence with the card stack, Reset Yard sign, tire pile | built | frame goal (card board, yellow sign, tires) | |
| Y-04 | S1 Yard | Scrap heap: crane with a hanging hook (grab-able) | built | test_polish.gd::test_the_crane_hook_can_be_grabbed_and_carries_what_it_catches, contraptions.gd `CraneHook`, frames handoff/frames/y04_hook_grabbed.png, y04_hook_carries.png | The gravity gun takes the hook; it catches the first thing it touches (a glue joint: the glue gun's blob lets go) and the winch lifts it to dangle under the jib. No face (a machine part). Not saved: it hangs empty after a reload |
| Y-05 | S1 Yard | Scrap heap: conveyor belt that runs when you zap its button | built | test_polish.gd::test_the_belt_button_runs_the_conveyor_and_carries_the_car, contraptions.gd `Conveyor`, `BeltButton`, frame handoff/frames/y05_belt_runs.png | The belt is let into the ground under the car and runs **toward the gate** (the heap's ramp blocks the other way); the button is on a post where the belt meets the heap. Carries objects and players |
| Y-06 | S1 Yard | Pond: water floats light things and splashes everything; a dock | built | test_greybox.gd::test_water_floats_light_things_and_sinks_heavy_ones, frame apart (dock, glass cut-away) | |
| Y-07 | S1 Yard | Barn: hayloft with a drop, see-saw | built | yard_level.gd:329-361, frame combo (loft, see-saw), test_goal_deck.gd::test_b2_tub_from_loft | |
| Y-08 | S1 Yard | Barn: trampoline landmark | built | test_polish.gd::test_the_trampoline_bounces_a_launched_object_and_a_player, contraptions.gd `Trampoline`, frame handoff/frames/y08_trampoline.png | On the play plane at the pond end of the barn (x 10.4, next to the cow). Objects bounce back at 86% (they settle); players pop to hayloft height. The scenery trampoline behind the plane is gone (yard_dressing.gd). Moving the cow instead broke test_goal_deck.gd::test_b2_egg_off_loft, so the cow stays put |
| Y-09 | S1 Yard | Tower: platforms and a pipe you can send things down | built | test_goal_deck.gd::test_b3_piano_pipe_pond, ::test_b2_duck_on_tower | |
| Y-10 | S1 Yard | Tower: a wind fan you can zap on | built | test_polish.gd::test_zapping_the_fan_blows_the_kite_off_the_tower, scripts/gameplay/contraptions.gd `YardFan`, frame handoff/frames/y10_fan_on.png | Any gun toggles it. Blows light things (volume mass < 4) left off the top deck; wind streaks and a yellow lamp while on. Off after Reset Yard |
| Y-11 | S1 Yard | Loose objects per zone (tires, crates, car, bathtub, fridge, pipes, duck, boat, logs, chickens, cow, hay, tractor, piano, kite, cannon, cannonball, balloons…) | partial | data/yard_layout.tres, test_art.gd::test_layout_uses_every_object_type | Pipe pile done: two pipes stacked by the plank (pipe, pipe_2). A third would break the 6-11 per zone cap (test_more_objects.gd). Still no loose **balloon** object (needs an ObjectData that floats and art: Content + Art, **S**). The cow lives in the barn, not the pond |
| Y-12 | S1 Yard | Objects react to every gun with a sound and a face | partial | test_art.gd::test_about_forty_object_types_all_with_art_and_faces, frames | Faces react on all 48. Only 8 have recorded voices (A-06) |
| Y-13 | S1 Yard | Survives any effect combination: capped scale and velocity, sleeps when still | built | test_more_objects.gd::test_stress_whole_yard_stays_clean, ::test_new_types_every_pair_composes_and_caps_hold, physics_object.gd:72 | |
| Y-14 | S1 Yard | About 40 object types as `ObjectData`; Content adds more without code | built | data/objects/ (48 types), test_art.gd::test_about_forty_object_types_all_with_art_and_faces | |
| Y-15 | S1 Yard | Persistence of transform, scale and effects; Reset Yard restores the default layout | built | test_greybox.gd::test_save_load_round_trip, ::test_reset_yard_puts_everything_back, data/yard_layout.tres | |
| Y-16 | S2 Kaden | "No personal info or real places, ever": generic, invented objects and landmarks | built | I read all 48 ids in data/objects/ and the landmarks in yard_dressing.gd: all generic | |

## Goal cards

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| G-01 | S1 Goal cards | Picture-card stack on the front fence; the top card is the current goal | built | frame goal (board by the gate) | |
| G-02 | S1 Goal cards | Walk up to the fence to see it big | built | scripts/levels/fence_card.gd (VIEW_DIST pop-up), frame goal | |
| G-03 | S1 Goal cards | Also small in a corner of the HUD | built | frames goal, combo, wide (top-right card) | |
| G-04 | S1 Goal cards | Done: fireworks, both cheer, card flips to the done pile with a stamp, next card shows | built | test_greybox.gd::test_deck_completes_skips_and_cheers, yard_level.gd:194-198 | |
| G-05 | S1 Goal cards | Optional: nothing nags, nothing times out | built | scripts/goals/goal_deck.gd header, test_goal_deck.gd::test_no_card_is_already_done_in_a_fresh_yard | |
| G-06 | S1 Goal cards | `GoalData`: id, description (never shown), picture, band, condition, hint_objects | built | scripts/goals/goal_data.gd, test_goal_deck.gd::test_every_card_hints_at_real_yard_objects_and_has_a_picture | |
| G-07 | S1 Goal cards | hint_objects glow softly when the card is viewed | built | fence_card.gd:64-67 | Code only; no frame or test of the glow itself |
| G-08 | S1 Goal cards | Condition vocabulary: in_zone, height_above, stack_height, has_effect, speed_over, glued_pair, scale, sequence, last touch | built | docs/contracts.md "Goal conditions", test_goal_deck.gd::test_sequence_steps_in_order_and_a_gun_touch_starts_over, ::test_touched_in_needs_the_last_touch_inside, ::test_stack_height_counts_a_resting_column, ::test_all_of_and_count_and_group | |
| G-09 | S1 Goal cards | The nine example cards (big cow … chain reaction) | built | data/goals/b1_big_cow, b1_float_chicken, b1_duck_in_tub, b2_tub_from_loft, b2_stack_three, b2_car_over_fence, b3_piano_pipe_pond, b3_raft, b3_chain_ball; test_greybox.gd::test_goal_checker_knows_all_five_band_one_cards, test_goal_deck.gd per-card tests | |
| G-10 | S1 Goal cards | Ordered easy to hard; skip a card by zapping it (to the back, with a raspberry) | built | test_goal_deck.gd::test_thirty_cards_in_three_bands_easy_first, ::test_all_thirty_skip_through_and_wrap | Raspberry is a placeholder (A-07) |
| G-11 | S1 Goal cards, S7 | 30 cards at launch as `.tres` (12 / 10 / 8; the first five are one zap or one carry) | built | data/goals/ (30), test_goal_deck.gd::test_thirty_cards_in_three_bands_easy_first | |
| G-12 | S1 Goal cards | New decks in updates (holiday deck, animals deck) | later | | Update decks |
| G-13 | S1 Goal cards | Done cards stay in a pile he can **flip through**: his trophy shelf | built | trophy_pile.gd (the done pile, a gold-star box by the easel: zap it), trophy_shelf.gd (finished cards in order with a star stamp, the rest as silhouettes; stick flips, stops at the ends; A up close; B back), test_trophy.gd | Trophy lane (jyz-trophy-1). Frames: handoff/frames/shelf_*.png |
| G-14 | S1 Goal cards | Kaden can author cards by hand in minutes | built | data/goals/*.tres, docs/contracts.md "Goal conditions" | |
| G-15 | S4 | Ten cards for first playable | superseded | S7 30-card deck (G-11) | |
| G-16 | S7 | Every card has a test that completes it in a real yard through the guns | built | test_goal_deck.gd (one test per new card), test_greybox.gd::test_the_five_playtest_cards_complete | |
| G-17 | S7 | New cards' pictures baked from code; the first ten use Pictos | built | scripts/goals/card_art.gd, assets/sprites/goals/ (20 PNGs), frame goal (Pictos card) | |
| G-18 | S7 | Rules: "taller than the barn" = 7 m walls; gun touch = zap or hold; piano may be shoved; deck checks every 0.1 s; chain ball counts below 2.5 m; every card hints | built | test_goal_deck.gd::test_b2_stack_three, ::test_b3_chain_ball, ::test_b3_chain_ball_does_not_count_a_zapped_ball, ::test_b3_piano_pipe_pond, ::test_b2_car_over_fence, ::test_every_card_hints_at_real_yard_objects_and_has_a_picture | |

## Systems, camera, controls, save

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| S-01 | S1 Camera | 2.5D side view; players and aiming locked to one plane | built | test_physics_proto.gd::test_plane_spring_keeps_z_small, frames | |
| S-02 | S1 Controls | Left stick moves and aims; right stick also aims, never required | built | zapper.gd:266 ("right stick wins, then the left stick") | |
| S-03 | S1 Controls | B: jump, low, floaty, forgiving; hop onto objects | built | test_playtest1.gd::test_both_players_walk_and_jump | |
| S-04 | S1 Controls | RB/LB next/previous gun; a big icon wheel pops for half a second | built | test_greybox.gd::test_belt_cycles_both_ways_with_a_click, hud.gd (WHEEL_TIME 0.6 s) | |
| S-05 | S1 Controls | Start pauses | built | test_lobby.gd::test_pause_shows_menu_and_resume | |
| S-06 | S1 Controls, S4 | Reset Yard: hold A on the in-world sign (S4: for 2.0 s) | built | test_greybox.gd::test_holding_a_on_the_sign_resets, test_playtest1.gd::test_a_long_grab_hold_by_the_sign_does_not_reset | |
| S-07 | S1 Camera | Shared camera frames both players, zooms out, soft-locked to the yard, never splits | built | frame apart, test_playtest1.gd::test_camera_never_looks_under_the_table | |
| S-08 | S1 Camera | Off-screen player: an arrow in their colour points the way | built | frame apart (green arrow left, red arrow right) | |
| S-09 | S1 Camera, Tech | Objects nudged back to the play plane by a gentle spring | built | test_physics_proto.gd::test_plane_spring_keeps_z_small | |
| S-10 | S1 Tech | EffectStack recomputes the body; undo pops; visuals driven from the same stack | built | scripts/physics/effect_stack.gd, test_physics_proto.gd::test_undo_restores_exactly | |
| S-11 | S1 Tech | Scale change re-creates the shape, 4-step cap, velocity clamp | built | test_physics_proto.gd::test_grow_in_a_stack_is_stable, ::test_glue_stable_across_mass_and_scale_and_grow | |
| S-12 | S1 Tech | Glue is a locked `Generic6DOFJoint3D` | built | scripts/physics/effects.gd:200-209, test_physics_proto.gd::test_glue_and_split | |
| S-13 | S1 Tech | Jolt physics | built | test_physics_proto.gd::test_jolt_is_the_3d_physics_engine | |
| S-14 | S1 Tech | Contracts: zapped, effect_changed, object_landed, goal_completed, goal_skipped, yard_reset, Goals.check, Yard.objects_in_zone | built | docs/contracts.md:267-327; yard_level.gd:8-11, physics_object.gd:20, effect_stack.gd:7, goals.gd:22, yard.gd:91 | |
| S-15 | S1 Tech | Save: every object's transform, scale and effects; deck position and done pile | built | yard_level.gd:225-244, test_greybox.gd::test_save_load_round_trip | |
| S-16 | S1 Tech | Save: **last gun per player** | built | test_polish.gd::test_each_player_keeps_their_last_gun_after_the_lobby_and_a_reload, scenes/main.gd:106-108, :121-125 | Was already built: main.gd keeps `guns` in the yard save (user://saves/<profile>.json, the game-save pattern, not settings) and restores it on spawn. This row misread it (it looked only at yard_level.gd and zapper.gd). Now under test: through the lobby, and through quit + boot with a change made just before quitting |
| S-17 | S1 Tech | Autosave every 30 s and on pause | built | yard_level.gd:23, :95-102, :206-207 | |
| S-18 | S1 Tech | 60 fps on a GTX 1060; sleep when still | partial | physics_object.gd:72 (`can_sleep`), test_more_objects.gd::test_stress_whole_yard_stays_clean | Never measured on the 1060. The queue log notes 6-8 ms headless frame time after 51 bodies: check with F3 on the TV box |
| S-19 | S2 | Template features: lobby + door, pause, solo (Select+Start 2 s, LB+RB+Select swaps), `--demo`, `--shots=`, smoke boot, `store/jar.glb` | built | test_lobby.gd::test_select_start_hold_toggles_solo, ::test_lobby_door_asks_then_quits, ::test_demo_skips_lobby; test_greybox.gd::test_solo_swap_moves_the_pad_to_the_other_player; test_store_jar.gd; .github/workflows/release.yml | |
| S-20 | S2 | Gravity as a function: `Yard.gravity_at(pos)` | built | test_physics_proto.gd::test_gravity_comes_from_yard_gravity_at | |
| S-21 | S2 | EffectStack and Fx generic enough to lift into openjar-addons | built | scripts/physics/ and scripts/fx/fx.gd have no game dependencies (fx.gd header) | The lift itself hasn't been done; it's for Worm |
| S-22 | S2 | Log what works in `~/openjar/WORM-READINESS.md` | missing | the ledger only has the pre-written rows that name "Physics game"; no Junk Yard Zap findings | Jolt scaling, mass^0.5, glue pull-in and plane spring are worth logging |
| S-23 | S4 | Mouse pointer always hidden in gameplay | built | test_playtest1.gd::test_mouse_pointer_hidden_in_play_shown_only_after_mouse_use_in_menus | |
| S-24 | S4 | Wide view: table apron with drawers; the camera never looks under the table | built | test_playtest1.gd::test_camera_never_looks_under_the_table, frame wide (three drawers) | |
| S-25 | S5 | Solo is never restored at boot | built | test_lobby.gd::test_saved_solo_stays_off_at_boot | |
| S-26 | S6 | The belt lives in `assets/gear/`, not `assets/characters/` | built | assets/gear/belt.glb | |

## Menus

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| M-01 | S5 | Showtime kit skinned by `data/menu_skin.tres` (accent #ffb21f, title "Junk Yard Zap") | built | test_jyz_menus.gd::test_skin_loads_with_the_game_look, frame lobby | |
| M-02 | S5 | Backdrop `SCREEN`: blurs the yard already drawn | built | test_showtime.gd::test_backdrop_modes, frame lobby | |
| M-03 | S5 | Podiums: the picked Jarlings hold the size gun in their tape, three-quarter view | built | test_polish.gd::test_the_podium_gun_points_up_not_over_the_legs, scenes/ui/lobby_jarling.gd `raise_gun()`, frames handoff/frames/m03_lobby_before.png, m03_lobby_after.png | The gun is held up and out by the shoulder ("guns up!"), so legs and hips show; it stays up after a chooser swap |
| M-04 | S5 | Round card "ZAP TIME!" with a "THE YARD IS OPEN" strip | built | test_jyz_menus.gd::test_round_card_says_the_yard_is_open | |
| M-05 | S6 | Lobby character chooser | built | test_chooser.gd, test_jyz_chooser.gd::test_lobby_swap_rebuilds_the_podium_rig_with_the_gun | |

## Visuals

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| V-01 | S1 Art | Low-poly **flat-shaded** 3D with **thick outlines** | superseded | Kaden's D44 a "Golden Afternoon **smooth**" (`~/openjar/HANDOFF-2026-11-10-morning.md`); art_kit.gd:3, :33 (smooth shading, thin ink outline on props) | GAME.md doesn't record D44 |
| V-02 | S1 Art | One warm key light, soft shadows, painted sky, parallax clouds, camera slightly above eye level | built | scripts/art/yard_light.gd, scripts/art/sky.gdshader, frames wide, apart | |
| V-03 | S1 Art | Palette constraints: rusty warm junk, cool sky and pond, gun colours never green or red | built | test_art.gd::test_gun_hues_stay_clear_of_the_players, frames | |
| V-04 | S1 Art | Every object has a simple face that reacts (wide, dizzy, smug, panicked) | built | scripts/physics/object_face.gd, physics_object.gd:552, test_art.gd::test_about_forty_object_types_all_with_art_and_faces, frames | |
| V-05 | S1 Art | Guns are junk-built, one signature silhouette each (dish, cone, bellows, funnel, snow globe, glue bottle, horseshoe), player tape | built | scripts/art/gun_art.gd:1-4, test_art.gd::test_every_gun_is_gear_with_a_muzzle_and_player_tape | |
| V-06 | S1 Art | Effect looks: boing ring, balloon tie, ice crust, glue blob, stripes + wobble, horseshoe + sparks, grab glow | built | scripts/physics/effect_look.gd, fx.gd:61 (zap ring), frame combo (stripes, balloon and tie) | |
| V-07 | S1 Art | Juice: screen shake scaled to impact mass, dust on landings | built | scripts/fx/fx.gd:12-18 | |
| V-08 | S1 Art | Juice: splash in the pond | built | physics_object.gd:21, :258 (`splashed`) | Sound is a placeholder (A-05) |
| V-09 | S1 Art | Juice: fireworks on a finished card | built | fx.gd:90, yard_level.gd:194, test_greybox.gd::test_deck_completes_skips_and_cheers | |
| V-10 | S1 Art | Store grid: Jeff zapping a cow to giant size while Chuck rides a ballooned bathtub | built | store/grid.png (looked at it) | |
| V-11 | S1 Art | Store hero: the whole yard **at golden hour** | partial | store/hero.png (looked at it) | Midday light, not golden hour. The tower is cut off at the right edge |

## Audio

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| A-01 | S1 Audio | `zap_<gun>`, 7 distinct cues (boing, hum, twang, squeak, crack, squelch, buzz) | partial | test_greybox.gd::test_toggle_guns_zap_and_undo_with_a_sound; synth.gd:32 | Every cue plays, but all are synth beeps from one recipe; no files in assets/audio/sfx |
| A-02 | S1 Audio | `grow`/`shrink` rising and falling boing; object voice pitch follows size | partial | synth.gd:18-19, physics_object.gd:586 | Pitch-follows-size works; the boing is a placeholder sine sweep |
| A-03 | S1 Audio | `grab` hum up, `throw` whoosh | partial | synth.gd:24-25 | Placeholder |
| A-04 | S1 Audio | `impact_<mass>`: 4 mass bands, thud to boom | partial | physics_object.gd:586, test_greybox.gd::test_a_dropped_object_lands_with_a_thud | The bands work; the sounds are noise bursts |
| A-05 | S1 Audio | `splash` | partial | synth.gd:26 | Placeholder |
| A-06 | S1 Audio | Object voices: cow moo, car honk, piano chord, fridge rattle, chicken bawk, duck squeak | partial | assets/audio/sfx/voice_*.ogg (8 files), test_more_objects.gd::test_new_types_have_art_a_face_and_their_own_voice | 8 of 48 types have a recorded voice (the 8 newest). The cow, car, piano, fridge, chicken and duck the plan names are all still beeps |
| A-07 | S1 Audio | `card_view` page flip, `card_done` fireworks + cheer, `card_skip` raspberry | partial | synth.gd:28-29, fence_card.gd:78 | Placeholder |
| A-08 | S1 Audio | `reset_yard`: big whoosh and a bell | partial | synth.gd:27 | Placeholder noise sweep, no bell |
| A-09 | S1 Audio | `wheel_move` click | partial | synth.gd:31 | Placeholder, though it already reads as a click |
| A-10 | S1 Audio | Music: a lazy junk-yard loop (washboard, banjo, kazoo), quiet under the chaos | missing | assets/audio/music/ is empty; nothing calls music | Gary is generating it with ElevenLabs (QUEUE 2026-11-10) |
| A-11 | S1 Audio | Music brightens for ten seconds after a finished card | missing | | Needs A-10 first |
| A-12 | S1 Audio | Barks: Jeff delights at big impacts; Chuck narrates his zaps and blames Jeff; at most one bark per zap | built | test_comedy.gd::test_one_bark_per_zap, ::test_bark_rate_cap_holds_back_a_burst_of_impacts, test_audio.gd::test_bark_gate_one_at_a_time | Every bark passes `Audio.can_bark` (1.6 s per speaker, 0.7 s for anyone), and a zap asks for at most one. Voices come through the existing fallback: own cue, then voice pack, then generic. No character has a voice pack yet (roster v0.4.0), so all barks are the generic `bark_*` files. A gated reaction does nothing, so there is no silent pose |
| A-13 | S1 Audio | Piano plays a chord when it lands | built | test_polish.gd::test_the_piano_plays_its_chord_when_it_lands_even_tiny, physics_object.gd `LANDING_GAGS` / `_landing_gag()`, frame handoff/frames/a13_piano_lands.png | The chord file (voice_piano_landed.ogg) existed but only played for medium+ landings and could be held back by the voice rate cap. Now it always plays on a real drop, any size, with a gold ring and black-and-white sparks |
| A-14 | S1 Audio, K | No scary sounds; even the biggest crash is a cartoon crash | partial | | Placeholder beeps aren't scary, but this can't be judged until real SFX land |

## Kid-design checks (S1 "Kid-design checks specific to this game")

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| K-01 | S1 Kid | Every gun does something visible and audible on the first zap, with no setup | built | test_greybox.gd::test_toggle_guns_zap_and_undo_with_a_sound, ::test_size_gun_tap_grows_stick_down_shrinks_hold_repeats, ::test_grab_carries_at_arms_length_and_drops_on_release | Audible = placeholder beeps |
| K-02 | S1 Kid | Every effect undoes with another zap | built | test_playtest1.gd::test_ten_objects_stack_every_effect_and_undo_cleanly, test_more_objects.gd::test_new_types_stack_every_effect_and_undo_cleanly | |
| K-03 | S1 Kid | Aim assist: pointing roughly at a thing hits it | built | test_physics_proto.gd::test_aim_cone_snaps_to_nearest | |
| K-04 | S1 Kid | Zapping your partner is funny and never hinders him for more than a second | built | test_greybox.gd::test_partner_zaps_are_funny_and_last_at_most_a_second | |
| K-05 | S1 Kid | Goal cards never nag, never time out, skip with one zap | built | test_goal_deck.gd::test_all_thirty_skip_through_and_wrap | |
| K-06 | S1 Kid | Reset Yard reachable in-world without a menu | built | test_greybox.gd::test_holding_a_on_the_sign_resets | |
| K-07 | S1 Kid | Camera never splits and never loses a player | built | frame apart (arrows), test_playtest1.gd::test_camera_never_looks_under_the_table | |
| K-08 | S1 Kid | Nothing launched off the map or stuck; recall to the gate **with a parachute** | built | test_polish.gd::test_a_recalled_object_floats_down_at_the_gate_under_a_parachute, test_playtest1.gd::test_objects_leaving_the_yard_come_back_at_the_gate, physics_object.gd `open_chute()`, frame handoff/frames/k08_parachute.png | A striped canopy on four cords; falls at 2.6 m/s, folds away on touchdown or after 1.9 s at most. One canopy per glued island |
| K-09 | S1 Kid | Giant and tiny extremes capped | built | test_playtest1.gd::test_giant_and_tiny_caps_hold | |
| K-10 | S1 Kid | Every object has a face **and a voice**; nothing is mute | partial | test_art.gd::test_about_forty_object_types_all_with_art_and_faces | Faces 48/48; recorded voices 8/48 (A-06) |

## Totals

152 rows: **built 117 · partial 20 · missing 4 · superseded 8 · later 3 · dropped 0**. Counted from the Status column.

## Next up

Missing and partial rows, ranked by how much Kaden (and his son) will notice them in play. C-12, C-14 and Y-12 roll up into the rows below. Size: S = under an hour, M = half a day, L = a day or more.

1. **A-01, A-06, A-02..A-05, A-07..A-09, K-10, U-15: real SFX and object voices**. Every zap, impact and animal is a beep today, and "sound on every action" is the whole toy. Start with the 7 zaps, grow/shrink, and the voices of the 6 card-star objects (cow, car, piano, fridge, chicken, duck). **L**
2. **A-10, A-11: music loop, brightening after a card**. The yard is silent between beeps. Gary is already generating the music. **M**
3. ~~P-05, P-06, A-12~~ built (scripts/players/reactions.gd).
4. ~~S-16~~ built (it already worked; now under test).
5. ~~Y-10, Y-05, Y-04~~ built (scripts/gameplay/contraptions.gd).
6. ~~A-13~~ built.
7. ~~K-08~~ built.
8. **G-13: trophy shelf you can flip through**. The done pile is only a growing stack. **M**
9. ~~P-07~~ built (reactions.gd idle bits, any Jarling).
10. ~~M-03~~ built.
11. ~~Y-08~~ built; **Y-11: loose balloon objects** still missing (an ObjectData that floats, plus art: Content + Art). **S**
12. **C-13: playtest #1 (Kaden and his son), then tag `v0.1.0`**. Add a "Playtest 2026-11-10 changes" section and new rows here from the notes. **S** (Gary)
13. **S-18: measure 60 fps on the GTX 1060** with 51 bodies (F3). **S**
14. **V-11: store hero at golden hour, tower in frame**. **S**
15. **S-22: log the physics findings in `~/openjar/WORM-READINESS.md`**. **S** (Gary)
16. **C-18: cow as a library character**: an answer from Kaden. **S**
17. **A-14: listen for anything scary** once real SFX land. **S**
