# Player flow: Junk Yard Zap

Lane jyz-player-flow-1, branch `fix/jyz-player-flow-1` (from `origin/dev` @ `8646fd0`), 2026-11-12.
Played as the person on the couch: a new player, then a returning player with a save.

## How it was played

- **The exported build.** `godot --headless --path . --export-release Linux .scratch/b/game.x86_64`
  (a second copy, `.scratch/b2/`, carried PF-1 and PF-2 while the first was still running the session flow).
- **Driven by synthetic pads**, the same events a real pad sends, through two flags the boot scene
  now takes on an export (a release export refuses a scene path on the command line):
  - `-- --session-flow --flow-out=<dir>`: the whole-session script (scripts/tools/session_flow.gd, 30 steps
    and 8 window closes).
  - `-- --player-flow=<phase> --flow-out=<dir>`: scripts/tools/player_flow.gd. One process per phase, so a
    save, a setting or a pick has to survive a real quit and relaunch: `first` (new player), `return`
    (returning player), `return2` (then killed with SIGTERM), `killed` (what survived), `solo` (`--solo`).
  - `-- --ui=<state> --shots=3`: the menu screens frozen for a frame.
- **Nothing of the family's was touched.** Every run set `XDG_DATA_HOME` to a folder under `.scratch/`, so
  `user://` (the save, settings.json) and the shared `players.json` (`OS.get_data_dir()/openjar/`) all lived
  there. Tests use their own profile, settings and picks paths.
- **Real frames** from the export on the software Vulkan renderer (`run-export`), all looked at.
  Frames are in `handoff/shots/` (untracked, like earlier lanes' frames: `handoff/` is in this clone's
  `.git/info/exclude`).

Results: **pass** works the way a player expects. **fail** a player gets stuck, lost or loses
something (six found: five fixed here, PF-6 left for the TV box). **rough** works, but could be clearer; left with the reason.

## Every path

| # | Path | Result | Frame | Notes / what a player expects |
| --- | --- | --- | --- | --- |
| 1 | First launch: the title screen (lobby) | pass | flow_01_boot_lobby.png | Title, two podiums, "Who's playing? Press A on a controller to join", Play / Settings / Back to Open Jar, footer hints |
| 2 | Join, pick a character, hear its catchphrase | pass | flow_02_chooser_pick_and_catchphrase.png | D-pad or stick left / right, the podium swaps with a poof and the character says its line |
| 3 | The whole roster once round | pass | flow_03_chooser_full_lap.png | 21 / 21 free Jarlings, 21 catchphrases, none in the wrong voice |
| 4 | Lobby Settings, and back with B | pass | flow_04_lobby_settings_open.png, flow_05_lobby_settings_back.png | |
| 5 | Lobby Back to Open Jar: asks first; Stay; Leave | pass | flow_06_lobby_door_asks.png, flow_07_lobby_door_stay.png, pf_lobby_quit_01_lobby_door_asks.png | Stay is focused first, so a double press never quits. Leave from the title screen: exit 0 (export, `lobby_quit`) |
| 6 | Two players ready: countdown, wipe, round card, the yard | pass | flow_08_two_ready_countdown.png, flow_09_playing_two.png | "ZAP TIME! The yard is open" |
| 7 | **Start on the title screen** | **fail → fixed (PF-5)** | before_lobby_one_ready.png → pf5_lobby_one_ready.png | Start joined and readied, then did nothing; a lone player had to find "hold A". Expected: Start starts. Now the second Start starts the countdown (B cancels); it waits for a partner who has joined but isn't ready |
| 8 | Alone: hold A on Play to start | pass | before_lobby_one_ready.png, pf_first_03_ready_alone_hint.png, pf_first_04_playing_alone.png | P2's character sleeps in the tire pile |
| 9 | Change gun (RB / LB): the wheel pops | pass | flow_10_gun_wheel.png | The current gun stays in each player's corner badge |
| 10 | Zap and jump | pass | flow_11_zap_and_jump.png | |
| 11 | Select tap does nothing; held 1.5 s the ring fills and the yard resets | pass | flow_12_select_tap_no_reset.png, flow_13_select_hold_ring.png, flow_14_select_hold_resets.png | Whoosh and bell |
| 12 | Second player leaves mid-game (pad unplugged) and comes back | pass | flow_15_p2_drops_out_to_tire_pile.png, flow_16_p2_drops_back_in.png | Back to sleep in the tire pile; any press wakes them with a snort |
| 13 | Second player joins mid-game after starting alone | pass | (test_lobby.gd::test_late_joiner_wakes_up_in_the_tire_pile) | |
| 14 | **Second controller joins while one pad plays solo** | **fail → fixed (PF-1)** | pf_solo_*.png | The new pad was ignored: both characters stayed on the solo pad, and only Select + Start (never shown) let P2 in. Expected: pick up a pad and you're in. Now solo ends, P1 keeps their pad, the new pad is P2 |
| 15 | Pause (Start) | pass | flow_17_pause.png | "PLAYER 1 PAUSED" in the pauser's colour |
| 16 | Pause Settings and back; B resumes | pass | flow_18_pause_settings.png, flow_19_pause_settings_back.png, flow_20_resume_with_b.png | |
| 17 | **"Restart" in the pause menu** | **fail → fixed (PF-3)** | before_pause_restart_label.png → pf3_pf4_pause.png | It sat right under "Reset Yard" and went to character select, not a fresh yard. Expected: "Restart" restarts. The bar now says **Main Menu**; same place, same one press |
| 18 | Back to the main menu, pads still joined | pass | flow_22_restart_to_lobby.png | Both podiums back to choosing |
| 19 | **Which buttons do what, once playing** | **fail → fixed (PF-4)** | pf3_pf4_pause.png | Play is pictures only (kid rule) and nothing anywhere showed LB / RB or the Select hold. Expected: a place to look. The pause card now shows "A Zap, B Jump, LB RB Gun, Hold Select Reset" with drawn glyphs |
| 20 | Start a **new** game when a save exists | pass (after PF-3, PF-4) | flow_21_pause_reset_yard.png, pf_return_04_fresh_yard_from_pause.png | The yard is the game: Pause → Reset Yard (one press), or hold Select 1.5 s, or hold A on the lit sign. Returning run: the grown cow was back to normal size |
| 21 | Continue a save | pass | pf_return_03_yard_as_left.png | The cow grown last session was still big (the frame caught the round card on the slow renderer; the size check passed) |
| 22 | Quit from the pause menu: Back to Open Jar, Leave | pass | pause_leave_question.png, pf_first_08_door_asks.png | "Progress is saved. You'll go back to Open Jar." Process exit 0 |
| 23 | Window closed mid-play (the launcher or Alt+F4) | pass | pf_return_05_tire_grown_then_close.png, pf_return2_01_close_kept_the_yard.png | Exit 0; next launch the tire was still big and the cow still reset |
| 23b | **Window closed on the title screen seconds after launch, a save present** | **fail, open (PF-6)** | pf_close_early_01_title_then_close.png | The save is written, then the exported game never exits (main thread blocked on a futex; 4 min until the run's timeout; twice, also in the `killed` phase). A player would expect to be back in Open Jar; the launcher would wait on a process that never ends. Only seen on the software Vulkan renderer here (headless exits 0; later quits exit 0). Needs the TV box to see if it happens on the GTX 1060 before a fix (fallback: a quit watchdog in Game.quit after the save) |
| 24 | **Hard stop mid-play (TV box off, process killed)** | **fail → fixed (PF-2)** | (no frame: the process is killed) | The yard saved only every 30 s and on pause, menu and quit, so a kill lost up to 30 s of play. A zap now saves the yard 3 s later. Export run: SIGTERM 30 s after a zap (the software renderer draws a few frames a second, and the timer counts frames), the next launch had the grown cow (pf_killed_01_cow_kept_after_sigterm.png). Headless: SIGTERM 4 s after, kept |
| 25 | Settings: Music and Sound volume do what they say and stick | pass | pause_settings.png, pf_first_07_music_down.png, pf_return_01_settings_stuck.png | Music 0.8 → 0.3 in one session; next launch the setting and the Music bus were both 0.3 |
| 26 | Settings: Screen shake | pass | pause_settings.png | Fx.shake reads it before every shake |
| 27 | Settings: Solo playtest | rough | pause_settings.png | Works (one pad drives both, LB + RB + Select swaps), but it is the one setting that does not stick across launches, under a "Saved on this TV" caption. That is on purpose (scenes/ui/lobby.gd: solo is playtest-only, never restored at boot). Leave for Kaden: keep it, rename it, or make it stick |
| 28 | Solo with `--solo` | pass | pf_solo_01_solo_flag_plays.png | Readies both and plays |
| 29 | Solo with Select + Start held 2 s, swap with LB + RB + Select, off again | pass | (session flow steps 23-26, headless: test_launch_ready.gd) | The export run hit its 25-minute cap on the shared software renderer at step 22 |
| 30 | Character pick remembered | pass | pf_return_02_pick_kept.png | Astro Ana picked in the first session was still P1's next launch |
| 31 | Any screen with no way back | pass | every frame above | B backs out of Settings and the leave question, resumes from pause, un-readies in the lobby, cancels the countdown |
| 32 | Placeholder text or art | pass | every frame above | None found (frames and a grep of scenes and data). The lobby footer says v0.1.0 in a local build; release.yml stamps the tag |
| 33 | A sound on every action | pass | | Menu moves, picks, toggles, ticks, ready / unready, count ticks, back; PF-5's Start reuses the ready and count cues |
| 34 | Lobby, one player ready: the "STARTING SOLO" podium tag | rough | before_lobby_one_ready.png | The READY! stamp covers most of the tag. Layout and look: Art lane |
| 35 | The word "solo" means two things | rough | pf5_lobby_one_ready.png, pause_settings.png | "start solo" in the lobby means one player with P2 asleep; "Solo playtest" in Settings means one pad drives both. Wording: Kaden's pick |
| 36 | Real pads on the TV: hot-plug, non-Xbox layouts, 60 fps on the GTX 1060 | not checked here | | Needs the TV box (L-11, S-18) |

## Fails fixed (most noticed first)

| ID | Fail | Fix | Test | Frame |
| --- | --- | --- | --- | --- |
| PF-5 | Start on the title screen did nothing after joining | Lobby `press_start()`: a joined player's Start readies them; a ready player's Start starts the countdown if nobody else is still choosing. Status line: "Press Start or hold A to start solo" | test_player_flow.gd::test_start_on_the_title_screen_starts_a_lone_player, ::test_start_waits_for_a_joined_partner_and_select_start_is_not_a_start | pf5_lobby_one_ready.png |
| PF-3 | "Restart" (to the lobby) next to "Reset Yard" | The bar says Main Menu | ::test_pause_main_menu_bar_says_main_menu_and_goes_to_the_lobby | pf3_pf4_pause.png |
| PF-4 | Controls never shown | Controls line on the pause card; `[lb]` / `[rb]` glyphs in the UI kit | ::test_pause_card_shows_the_controls | pf3_pf4_pause.png |
| PF-1 | Second pad ignored during solo | `Players.hand_p2_to()`: solo ends, the new pad is P2 | ::test_a_second_pad_takes_p2_out_of_solo, ::test_a_second_pad_takes_p2_after_cli_solo, ::test_the_solo_pad_pressing_a_stays_solo, ::test_a_second_pad_wakes_p2_during_solo_play | pf_solo_02_second_pad_joins_solo.png |
| PF-2 | A hard stop lost up to 30 s | A zap saves the yard 3 s later (`YardLevel.SAVE_SOON`) | ::test_a_zap_saves_the_yard_within_seconds | pf_return2_02_cow_grown_waiting_for_kill.png, pf_killed_01_cow_kept_after_sigterm.png |

## Left open, with the reason

- **PF-6, the exported game hangs at exit after an early close on the title screen (row 23b):** found
  at the end of the lane; seen only on the software renderer, and the cause is inside the engine's
  shutdown (no game thread). Needs the TV box first: launch, close within a few seconds, does it
  return to Open Jar? Repro: `XDG_DATA_HOME=<scratch> run-export game.x86_64 -- --player-flow=close_early
  --flow-out=<dir>` after any run that left a save.

- **Solo playtest doesn't stick, and "solo" means two things (rows 27, 35):** a deliberate template rule
  and a wording choice. Kaden's pick.
- **The podium's "STARTING SOLO" tag under the READY! stamp (row 34):** layout and look, Art lane.
- **Real pads and the 1060 (row 36):** the TV box.
