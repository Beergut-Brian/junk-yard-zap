# Audio cues

Every SFX file and both placeholder music loops are synthesised by `scripts/audio/make_cues.py`
(Python stdlib + ffmpeg, seeded per stem `openjar-jyz:<stem>`, reproducible). Regenerate with
`python3 scripts/audio/make_cues.py` (about 4 minutes on 6 cores; `--list` shows every stem).

Loudness: -16 LUFS integrated for cues of 0.6 s or more; shorter cues are measured looped (so
they are "as loud as the rest while they sound"); the Trim column lowers frequent cues (object
voices -3 dB, clicks -4 dB). True peak <= -1 dBTP on every file; nothing above 9.5 kHz. Master
has a hard limiter at -1 dB so stacked cues never clip.

`Audio.play("cue")` plays `sfx/cue.ogg`, or rotates through `sfx/cue_1.ogg .. cue_N.ogg` (never
the same variant twice in a row, plus a ±5 % pitch wobble). Never leave a `cue.ogg` next to
`cue_N.ogg` variants: it wins. A missing cue warns once and plays a synth beep.

Buses: **Music** (duck stage, Settings "music"), **SFX** (Settings "sound"), **Voice** (barks;
follows the sound slider). Music ducks under `impact_heavy` (-5 dB), `impact_huge` (-8 dB),
`card_done`, `reset_yard` and every bark (-5 dB), holds 0.35 s, recovers at 14 dB/s.

Loudest cue: `card_done` (momentary max -12.5 LUFS). Nothing in play goes above it: the heavy and
huge landings are trimmed (-2.5 / -3.5 dB) so a giant's crash with its +1.5 dB size boost still
peaks at about -12.7 (`Audio.IMPACT_BOOST_DB`); the music ducks under it instead.

Mass bands (`Audio.IMPACT_BANDS`, volume mass = `ObjectData.mass * scale^3`): light < 1, medium
1..8, heavy 8..60, huge 60+. Growing a thing moves it up the bands (an egg grown 4x is 64x the mass).

## SFX

| Cue (`Audio.play`) | Files | Plays when | Sounds like | Trim dB |
| --- | --- | --- | --- | --- |
| `zap_size` | sfx/zap_size_1..3.ogg | size gun fires (`GunData.zap_cue`) | size gun: pew + springy rising boing | 0 |
| `zap_grab` | sfx/zap_grab_1..3.ogg | gravity gun fires | gravity gun: tractor-beam hum, rising | 0 |
| `zap_bouncy` | sfx/zap_bouncy_1..3.ogg | bouncy gun fires | bouncy gun: rubber-band twang (bwoing) | 0 |
| `zap_balloon` | sfx/zap_balloon_1..3.ogg | balloon gun fires | balloon gun: twisty balloon squeaks | 0 |
| `zap_freeze` | sfx/zap_freeze_1..3.ogg | freeze gun fires | freeze gun: ice crack, fizz, tinkle | 0 |
| `zap_glue` | sfx/zap_glue_1..3.ogg | glue gun fires (second pick) | glue gun: wet squelch + blop | 0 |
| `zap_magnet` | sfx/zap_magnet_1..3.ogg | magnet gun fires | magnet gun: short electric buzz + crackles, a zip at the end | 0 |
| `grow` | sfx/grow_1..3.ogg | size step up (`Zapper._size_step`, pitched `Audio.size_pitch(target_scale)`: a tiny thing boings high; partner grow) | rising boing + xylophone up | 0 |
| `shrink` | sfx/shrink_1..3.ogg | size step down (pitched by the new size, like `grow`) | falling boing + xylophone down | 0 |
| `grab` | sfx/grab_1..2.ogg | gravity grab catches | gravity grab: hum up, little bell 'lock' | 0 |
| `throw` | sfx/throw_1..3.ogg | flick throw | throw: whoosh with a faint rising whistle | 0 |
| `drop` | sfx/drop_1..2.ogg | let go without a flick | let go: falling blip + plup | -2 |
| `impact_light` | sfx/impact_light_1..3.ogg | object lands, volume mass < 1 (`PhysicsObject._on_landed` → `Audio.impact_band(mass)`, pitch `Audio.size_pitch(scale)`, up to +1.5 dB when big, down to -9 dB when tiny) | light landing: wood bonk | -2 |
| `impact_medium` | sfx/impact_medium_1..3.ogg | lands, mass 1..8 | medium landing: thud + knock | -1 |
| `impact_heavy` | sfx/impact_heavy_1..3.ogg | lands, mass 8..60 (ducks music, Jeff delights) | heavy landing: boom + junk bouncing | -2.5 |
| `impact_huge` | sfx/impact_huge_1..2.ogg | lands, mass 60+ (ducks music, Jeff delights) | huge landing: cartoon crash, clattering cans, a boing, stars | -3.5 |
| `splash` | sfx/splash_1..3.ogg | object hits the pond | pond: sploosh + bubbles + droplets | 0 |
| `card_view` | sfx/card_view_1..2.ogg | a player looks at the fence card | goal card: page flip + soft marimba tick | 0 |
| `card_done` | sfx/card_done_1..2.ogg | card completed (`GoalDeck.complete`; also brightens the music 10 s) | card done: two fireworks, bell run, crowd 'yaaay' + claps | 0 |
| `card_skip` | sfx/card_skip_1..2.ogg | card skipped | skip: friendly raspberry (pbbbt) | 0 |
| `reset_yard` | sfx/reset_yard.ogg | Reset Yard | reset: big whoosh, two bells, sparkles | 0 |
| `reset_hold` | sfx/reset_hold.ogg | holding at the Reset sign | holding at the Reset sign: ratchet ticks rising | -2 |
| `wheel_move` | sfx/wheel_move_1..2.ogg | gun wheel step | gun wheel: click | -4 |
| `gun_cycle` | sfx/gun_cycle.ogg | proto gun cycle | proto gun cycle: click | -4 |
| `sparkle` | sfx/sparkle_1..3.ogg | zap at nothing; fence-card sparkle | zap at nothing: glockenspiel sparkle | -3 |
| `nope` | sfx/nope_1..2.ogg | zap that can't apply | can't: friendly 'uh-uh' | -2 |
| `boing` | sfx/boing_1..2.ogg | partner zapped with bouncy | partner bounced: spring boing | 0 |
| `squelch` | sfx/squelch_1..2.ogg | partner zapped with glue | partner glued: squelch | 0 |
| `crack` | sfx/crack_1..2.ogg | partner thaws from freeze | partner thaws: ice crack | 0 |
| `jump` | sfx/jump_1..2.ogg | player jumps | player jump: tiny whoop | -3 |
| `land` | sfx/land_1..2.ogg | player lands | player lands: soft thud | -4 |
| `action` | sfx/action.ogg | proto action | proto action: pop | -2 |
| `recall` | sfx/recall.ogg | object recalled to the gate | object recalled to the gate: whistle in + pop + ding | 0 |
| `snort` | sfx/snort.ogg | partner snort | a partner snorts | 0 |
| `snore` | sfx/snore_1..2.ogg | sleeping partner | a sleeping partner snores (cartoon wheeze-whistle) | 0 |
| `unglue` | sfx/unglue.ogg | glue split | unglue: stretchy goo + cork pop | 0 |
| `glue_pick` | sfx/glue_pick.ogg | glue first pick | first glue pick: ding + little squelch | -1 |
| `glue` | sfx/glue.ogg | proto glue | proto glue: squelch | 0 |
| `solo_swap` | sfx/solo_swap.ogg | solo mode swaps the player | solo mode swaps player: puff + pop | 0 |
| `solo_on` | sfx/solo_on.ogg | solo playtest on | solo playtest on: two notes up | 0 |
| `solo_off` | sfx/solo_off.ogg | solo playtest off | solo playtest off: two notes down | 0 |
| `player_join` | sfx/player_join.ogg | a pad joins | a pad joins: pop + arpeggio up | 0 |
| `round_start` | sfx/round_start.ogg | `Game.start_round` | round start: soft pea-whistle toot-tooot | 0 |
| `round_end` | sfx/round_end.ogg | `Game.end_round` | round end: marimba ta-da | 0 |
| `pause` | sfx/pause.ogg | pause / resume | pause / resume: two soft xylophone notes down | 0 |
| `ui_confirm` | sfx/ui_confirm.ogg | menu select (`Game`, `UiSound`) | menu select: two-note marimba up | 0 |
| `ui_move` | sfx/ui_move.ogg | menu cursor moves (`UiSound`) | small wood tak | -4 |
| `ui_back` | sfx/ui_back.ogg | menu back / bump (`UiSound`) | wood tak + falling chirp | -3 |
| `ui_tick` | sfx/ui_tick.ogg | settings slider step (`UiSound`) | ratchet tick | -5 |
| `ui_toggle` | sfx/ui_toggle.ogg | settings toggle (`UiSound`) | tin clack + wood click | -3 |
| `player_ready` | sfx/player_ready.ogg | lobby: a player readies (`UiSound`) | marimba run up + stamp | -1 |
| `player_unready` | sfx/player_unready.ogg | lobby: unready (`UiSound`) | two marimba notes down | -2 |
| `count_tick` | sfx/count_tick.ogg | lobby countdown dot (`UiSound`) | wood block + small bell | -2 |
| `ui_go` | sfx/ui_go.ogg | lobby countdown done (`UiSound`) | marimba chord hit + thump + sparkle | 0 |
| `ui_wipe` | sfx/ui_wipe.ogg | lobby to yard wipe (`UiSound`) | three fast whooshes | -2 |
| `ui_card` | sfx/ui_card.ogg | round card "ZAP TIME!" (`UiSound`) | airy swell + sparkle + bell | 0 |
| `ui_pause` | sfx/ui_pause.ogg | pause menu opens (`UiSound`) | scratch dip + soft marimba pad | -2 |
| `char_swap` | sfx/char_swap.ogg | chooser: next character (`UiSound`) | puff + pop + rising chirp | -2 |
| `bark` | sfx/bark_1..4.ogg | plain bark, character has no own cue / pack (partner zap) | generic bark (no voice pack): wordless 'hey!' / 'woo!' / 'hup!' / 'ooh!' | -1 |
| `bark_cheer` | sfx/bark_cheer_1..3.ogg | card done, every awake player (`Zapper.cheer`) | generic cheer: 'yi-yaaay!' + claps | -1 |
| `bark_zap` | sfx/bark_zap_1..3.ogg | Chuck narrates his own zap | generic zap narration (Chuck): 'bzz-HA!', 'pew-pew!', 'zip!' | -1 |
| `bark_delight` | sfx/bark_delight_1..3.ogg | Jeff at a big impact near him | generic big-impact delight (Jeff): 'whoa-ho!', 'woooow!', 'hee-hee-hee' | -1 |

## Object voices

`PhysicsObject.speak(kind)` calls `Audio.voice(ObjectData.voice_cue(), kind, self, Audio.size_pitch(scale))`
(1 / sqrt(scale), clamped 0.5..2):
it plays `voice_<id>_<kind>.ogg`, else `voice_<id>_react.ogg`, else `voice_<id>` (synth beep).
Pitch follows size (a giant cow moos low, a tiny one squeaks). Caps: one voice per object per
0.5 s (`Audio.VOICE_GAP`), at most 4 object voices at once (`MAX_OBJECT_VOICES`).

| Kind | When |
| --- | --- |
| react | a gun changes it (`Zapper._press`), a size step |
| grabbed | gravity grab catches it |
| thrown | flick throw |
| landed | it lands, medium mass band or heavier |

A new object needs nothing in code: add `"<id>": (archetype, base Hz)` to `OBJECTS` in
`make_cues.py`, run `python3 scripts/audio/make_cues.py voice_<id>_react voice_<id>_grabbed
voice_<id>_thrown voice_<id>_landed`, add a line here. The test checks every `data/objects/*.tres`.

| Voice (`voice_<id>_<kind>`) | Files | Sounds like |
| --- | --- | --- |
| `voice_cow_*` | sfx/voice_cow_{react,grabbed,thrown,landed}.ogg | moo (u-o formant voice); low when giant, high when tiny |
| `voice_pig_*` | sfx/voice_pig_{react,grabbed,thrown,landed}.ogg | double oink, snorty |
| `voice_sheep_*` | sfx/voice_sheep_{react,grabbed,thrown,landed}.ogg | bleating baa with vibrato |
| `voice_chicken_*` | sfx/voice_chicken_{react,grabbed,thrown,landed}.ogg | b-b-BAWK |
| `voice_duck_*` | sfx/voice_duck_{react,grabbed,thrown,landed}.ogg | rubber-duck squeak (two on grab/throw) |
| `voice_fish_*` | sfx/voice_fish_{react,grabbed,thrown,landed}.ogg | bubble blubs; floppy flap on landing |
| `voice_egg_*` | sfx/voice_egg_{react,grabbed,thrown,landed}.ogg | tiny tik + wobble (never breaks) |
| `voice_car_*` | sfx/voice_car_{react,grabbed,thrown,landed}.ogg | two-tone horn honk (beep-beep when grabbed, long honk thrown) |
| `voice_tractor_*` | sfx/voice_tractor_{react,grabbed,thrown,landed}.ogg | putt-putt engine (+ toot on react), faster when grabbed/thrown |
| `voice_boat_*` | sfx/voice_boat_{react,grabbed,thrown,landed}.ogg | soft foghorn toot |
| `voice_cannon_*` | sfx/voice_cannon_{react,grabbed,thrown,landed}.ogg | cork pop + low poomf; metal clank otherwise |
| `voice_piano_*` | sfx/voice_piano_{react,grabbed,thrown,landed}.ogg | react: major chord; grabbed: two notes up; thrown: glissando; landed: big friendly chord |
| `voice_fridge_*` | sfx/voice_fridge_{react,grabbed,thrown,landed}.ogg | rattle (bottles + fridge hum / tools) |
| `voice_toolbox_*` | sfx/voice_toolbox_{react,grabbed,thrown,landed}.ogg | rattle (bottles + fridge hum / tools) |
| `voice_washing_machine_*` | sfx/voice_washing_machine_{react,grabbed,thrown,landed}.ogg | water slosh (+ a ding) |
| `voice_kiddie_pool_*` | sfx/voice_kiddie_pool_{react,grabbed,thrown,landed}.ogg | water slosh (+ a ding) |
| `voice_toaster_*` | sfx/voice_toaster_{react,grabbed,thrown,landed}.ogg | spring pop + ding |
| `voice_kettle_*` | sfx/voice_kettle_{react,grabbed,thrown,landed}.ogg | kettle whistle |
| `voice_tv_*` | sfx/voice_tv_{react,grabbed,thrown,landed}.ogg | channel blips + a puff of static |
| `voice_anvil_*` | sfx/voice_anvil_{react,grabbed,thrown,landed}.ogg | friendly metal clank / ring |
| `voice_cannonball_*` | sfx/voice_cannonball_{react,grabbed,thrown,landed}.ogg | friendly metal clank / ring |
| `voice_milk_can_*` | sfx/voice_milk_can_{react,grabbed,thrown,landed}.ogg | friendly metal clank / ring |
| `voice_bucket_*` | sfx/voice_bucket_{react,grabbed,thrown,landed}.ogg | friendly metal clank / ring |
| `voice_watering_can_*` | sfx/voice_watering_can_{react,grabbed,thrown,landed}.ogg | friendly metal clank / ring |
| `voice_oil_drum_*` | sfx/voice_oil_drum_{react,grabbed,thrown,landed}.ogg | hollow metal bong |
| `voice_pipe_*` | sfx/voice_pipe_{react,grabbed,thrown,landed}.ogg | hollow metal bong |
| `voice_crate_*` | sfx/voice_crate_{react,grabbed,thrown,landed}.ogg | wood knocks (hollow thunk for pumpkin / cone) |
| `voice_log_*` | sfx/voice_log_{react,grabbed,thrown,landed}.ogg | wood knocks (hollow thunk for pumpkin / cone) |
| `voice_plank_*` | sfx/voice_plank_{react,grabbed,thrown,landed}.ogg | wood knocks (hollow thunk for pumpkin / cone) |
| `voice_bowling_pin_*` | sfx/voice_bowling_pin_{react,grabbed,thrown,landed}.ogg | wood knocks (hollow thunk for pumpkin / cone) |
| `voice_pumpkin_*` | sfx/voice_pumpkin_{react,grabbed,thrown,landed}.ogg | wood knocks (hollow thunk for pumpkin / cone) |
| `voice_traffic_cone_*` | sfx/voice_traffic_cone_{react,grabbed,thrown,landed}.ogg | wood knocks (hollow thunk for pumpkin / cone) |
| `voice_ball_*` | sfx/voice_ball_{react,grabbed,thrown,landed}.ogg | rubbery bwomp (+ squeak when grabbed/thrown) |
| `voice_beach_ball_*` | sfx/voice_beach_ball_{react,grabbed,thrown,landed}.ogg | rubbery bwomp (+ squeak when grabbed/thrown) |
| `voice_tire_*` | sfx/voice_tire_{react,grabbed,thrown,landed}.ogg | rubbery bwomp (+ squeak when grabbed/thrown) |
| `voice_swim_ring_*` | sfx/voice_swim_ring_{react,grabbed,thrown,landed}.ogg | rubbery bwomp (+ squeak when grabbed/thrown) |
| `voice_trampoline_*` | sfx/voice_trampoline_{react,grabbed,thrown,landed}.ogg | rubbery bwomp (+ squeak when grabbed/thrown) |
| `voice_armchair_*` | sfx/voice_armchair_{react,grabbed,thrown,landed}.ogg | creak (+ springs) |
| `voice_mattress_*` | sfx/voice_mattress_{react,grabbed,thrown,landed}.ogg | creak (+ springs) |
| `voice_wheelbarrow_*` | sfx/voice_wheelbarrow_{react,grabbed,thrown,landed}.ogg | creak (+ springs) |
| `voice_tire_swing_*` | sfx/voice_tire_swing_{react,grabbed,thrown,landed}.ogg | creak (+ springs) |
| `voice_hay_*` | sfx/voice_hay_{react,grabbed,thrown,landed}.ogg | dry rustle / flutter |
| `voice_kite_*` | sfx/voice_kite_{react,grabbed,thrown,landed}.ogg | dry rustle / flutter |
| `voice_bathtub_*` | sfx/voice_bathtub_{react,grabbed,thrown,landed}.ogg | porcelain ring + glug / squeak |
| `voice_garden_gnome_*` | sfx/voice_garden_gnome_{react,grabbed,thrown,landed}.ogg | tiny gruff 'hm!', giggle when thrown |
| `voice_lawn_flamingo_*` | sfx/voice_lawn_flamingo_{react,grabbed,thrown,landed}.ogg | honky plastic-bird squawk |
| `voice_rubber_chicken_*` | sfx/voice_rubber_chicken_{react,grabbed,thrown,landed}.ogg | wheezy rubber-chicken squawk |
| `voice_surfboard_*` | sfx/voice_surfboard_{react,grabbed,thrown,landed}.ogg | whoosh + slap |

## Barks

`Zapper.bark(kind)` → `Audio.bark(character, kind, speaker)`, on the Voice bus. Order:
1. the game's own cue `bark_<id>[_<kind>]` (`sfx/`), if it exists;
2. the character's voice pack from the roster (`Roster.info(id).voice`): `<voice>/<kind>.ogg`, or
   for a plain bark any of `Roster.info(id).barks` (history records `roster:<id>`);
3. the generic `bark[_<kind>]` above (wordless synth Jarling voice, never a character's voice).

Gates (`Audio.can_bark(speaker)`): one bark per zap, the same speaker at most every 1.6 s, anyone at
most every 0.7 s. Styles (`Audio.BARK_STYLE`): Jeff `delight`s at heavy / huge impacts within
30 m (`Audio.big_impact`); Chuck `narrate`s his own successful zaps (`bark("zap")`); any other
roster character does both. The partner who gets zapped still barks (one bark for that zap).
Kinds the code asks for: `""` (plain), `zap`, `delight`, `cheer`. A voice pack drop-in needs
`voice/zap.ogg`, `voice/delight.ogg`, `voice/cheer.ogg` plus its plain barks.

## Music (drop-in spec)

The music files are the ElevenLabs tracks (2026-11-10, 96 BPM; both 32.6 s, so the beat stays in place through the crossfade).
`YardLevel._ready` calls `Audio.music("music_yard")`; `card_done` calls `Audio.brighten()`.

| File | Plays | Length | Loop |
| --- | --- | --- | --- |
| `music_yard` | music/music_yard.ogg | under all play, quietly (`MUSIC_GAIN_DB` -2 dB on top of the file) | 16 bars of a lazy junk-yard loop (washboard, banjo, oom-pah bass, kazoo), 100 BPM, 38.4 s |
| `music_yard_bright` | music/music_yard_bright.ogg | crossfades in over 1 s after a completed card, holds 10 s, crossfades back over 1 s | same loop brightened: tune up an octave, glockenspiel, busier washboard |

Requirements for the real files (ElevenLabs or anything else):
- **Names:** `assets/audio/music/music_yard.ogg` and `assets/audio/music/music_yard_bright.ogg`
  (Ogg Vorbis, 44.1 kHz, mono or stereo). Credit both in `assets/CREDITS.md` with the prompt.
- **Loudness:** -20 LUFS integrated (music sits 4 LU under the -16 LUFS SFX), true peak <= -1 dBTP.
  `ffmpeg -i in.wav -af loudnorm=I=-20:TP=-1.5:LRA=11 -ar 44100 -c:a libvorbis -q:a 5 out.ogg`
  (two-pass loudnorm if it lands more than 0.5 LU off).
- **Loop:** whole bars, seamless: no fade in or out, no silence at either end, the reverb tail of
  the last bar mixed back into the start (export a 3-loop take and cut the middle loop on the bar
  lines if the generator can't loop). Godot loops the whole file (`loop = true`, offset 0).
- **Bright layer:** the *same piece* (same tempo, key, chords and sample length to within 50 ms),
  a full mix, just livelier. `brighten()` starts it at the base loop's playback position, so equal
  lengths keep the beat in place through the crossfade. If the lengths differ it still works, the
  beat just jumps a little.
- Nothing scary: no minor-key stingers, no sudden loud hits; it must sit under the chaos.
