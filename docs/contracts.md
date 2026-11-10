# Contracts

Shared signals and APIs that lanes code against. Systems lane owns this file. Change it in its
own PR before changing code; every other lane reads the merged version.

## Autoloads (always available)

### `Game` (`scripts/autoload/Game.gd`)

State machine for the whole session. Boots into `LOBBY` (the start screen / main menu,
`scenes/ui/lobby.tscn`) unless `--demo` is passed, which skips straight to a round.

```gdscript
enum State { LOBBY, PLAYING, PAUSED, ROUND_END, TITLE = 0 }   # TITLE: old name of LOBBY, deprecated
var state: State
var round_index: int
var demo: bool                  # --demo: skip the lobby, both players join as virtual players
signal state_changed(from: State, to: State)
signal round_started(round_index: int)
signal round_ended(round_index: int, result: Dictionary)   # result is game-defined
signal lobby_ready(players: Array)   # the lobby countdown finished; players = who readied up
signal back_to_lobby()               # pause menu Restart: clear the level, show the lobby
signal quit_requested()              # emitted just before a clean quit; last chance to save

func start_round() -> void
func end_round(result: Dictionary = {}) -> void
func pause() -> void
func resume() -> void
func restart() -> void          # Select: back to a fresh round, no questions asked
func to_lobby() -> void         # back to the start screen; round_index resets to 0
func finish_lobby(players: Array) -> void   # the lobby calls this: emits lobby_ready, starts round 1
func quit(code: int = 0) -> void            # Save.flush(), then exit; the launcher resumes
```

Start (`pause`) toggles `PLAYING` <-> `PAUSED`. The pause menu (`scenes/ui/pause_menu.tscn`) is a
text menu over the blurred game: Resume, Restart (`to_lobby()`), Settings, Back to Open Jar
("Leave the game?" Stay / Leave, then `quit()`). It shows who paused (`paused_by`). Either pad
moves the cursor; A selects; B backs out of Settings / the question, else resumes; Start resumes.
Window close also goes through `quit()`. Menus are for the grown-up: see `docs/ui.md`.

### Lobby (`scenes/ui/lobby.tscn`, `scenes/ui/lobby.gd`)

Start screen and main menu in one, a text menu for the grown-up (`docs/ui.md`). Title on top,
Play / Settings / Back to Open Jar in the middle, a join panel per player (P1 green left, P2 red
right) with "Press A to join", the player's character and READY.

- A on a new pad: that pad joins and is ready; its panel lights up and its character waves.
- B: un-ready (or back out of Settings / the question). Both ready: "Starting in 3, 2, 1", then
  `Game.finish_lobby(ready_players)`. Un-readying cancels.
- A held on Play for 1.5 s by a ready player starts without the other (Play fills up).
- Back to Open Jar asks "Leave the game?" (Stay focused first), Leave calls `Game.quit()`.
- Solo mode readies both. A pad that joins mid-game plays from the next round.

Hooks a game uses (keep the node names):

```gdscript
@export var title_texture: Texture2D        # the logo / key art; empty: title_text in the display face
@export var title_text: String              # empty: the project name
signal player_readied(player: int, ready: bool)
signal countdown_started()
signal countdown_cancelled()
# Spots/P1/Character, Spots/P2/Character: swap in your character. The lobby calls
# set_joined(on: bool) and wave() on it if it has them.
# Backdrop (hide it to show the level), TitleArt, Spots/P*/fill_alpha (0..1, see-through panels),
# Buttons/Play, Buttons/Settings, Buttons/Door, Settings, Confirm. Customise in _ready(), in code.
```

Theme: `UiStyle.accent = Color(...)` sets the game's accent (focus, sliders, progress). The rest
of the look is shared; see `docs/ui.md`.

### Settings (`scenes/ui/settings_panel.gd`, class `SettingsPanel`)

Music volume, sound volume, screen shake, solo playtest mode; in the lobby and the pause menu.
Per install, through `Save.set_setting()`, written the moment a value changes.

```gdscript
const MUSIC := "music_volume"     # 0..1, default 0.8 -> Audio "Music" bus
const SOUND := "sound_volume"     # 0..1, default 1.0 -> Audio "SFX" bus
const SHAKE := "screen_shake"     # bool, default true
const SOLO := "solo_playtest"     # bool, default false; on at boot turns Players solo on
static func screen_shake() -> bool  # games check this before shaking the camera
```

### `Players` (`scripts/autoload/Players.gd`)

Who is holding which controller. Never read device ids directly.

```gdscript
const P1 := 0
const P2 := 1
const COLOR := { P1: Color("3cc24a"), P2: Color("e4393c") }   # green, red
const VIRTUAL := -2             # device of a keyboard or --demo player

signal player_joined(player: int, device: int)
signal player_left(player: int)
signal solo_changed(on: bool)

var solo: bool                  # playtest only: one pad plays both players
var solo_focus: int             # the player the solo pad drives right now; the game sets it

func is_active(player: int) -> bool
func device_of(player: int) -> int
func active_players() -> Array[int]
func action(player: int, action: String) -> String   # "p1_move_left" etc. for Input.*
func move_vector(player: int) -> Vector2
func join_virtual(player: int) -> void
func set_solo(on: bool, device: int = VIRTUAL) -> void
func set_solo_focus(player: int) -> void   # the game calls this when the other player's turn comes
func reset() -> void                       # tests: nobody joined, solo off, InputMap restored
```

Solo mode: `--solo` on the command line, or hold Select + Start together for 2 s on a pad (again
to turn it off). Both players join on that pad; only `solo_focus`'s actions get its events. A
two-heads icon shows top-left while it is on. A keyboard key from a player's action joins that player.

Input map actions (defined in `project.godot`, per player, prefix `p1_` / `p2_`):
`move_left`, `move_right`, `move_up`, `move_down`, `action`, `jump`, and for Junk Yard Zap
`gun_next` (RB, E / .), `gun_prev` (LB, Q / ,), `aim_left/right/up/down` (right stick, IJKL / numpad).
`restart` is keyboard-only (R): Select is not used in play (GAME.md).
Global: `pause`, `restart`, `debug_overlay`, `debug_screenshot`.

### `Save` (`scripts/autoload/Save.gd`)

JSON under `user://saves/<profile>.json`. Autosave at every natural stopping point.

```gdscript
var profile: String                 # set by the launcher via --profile=<id>, default "p1"
signal saved()
signal loaded()

func get_value(key: String, default = null)
func set_value(key: String, value) -> void   # marks dirty
func flush() -> void                         # writes if dirty; Game.end_round() calls this
func wipe() -> void

# Per install, not per profile: user://settings.json, written on every set_setting().
var settings_path: String                    # tests point this elsewhere
func get_setting(key: String, default = null)
func set_setting(key: String, value) -> void
func reload_settings() -> void
func wipe_settings() -> void
```

### `Audio` (`scripts/autoload/Audio.gd`)

```gdscript
func play(cue: String, position = null, pitch := 1.0) -> void   # cue = file stem in assets/audio/sfx/
var history: PackedStringArray     # every cue played, newest last (tests, demo logs)
func played(cue: String) -> bool
func music(track: String, fade: float = 0.5) -> void
func stop_music(fade: float = 0.5) -> void
func bark(character: String, bark: String) -> void   # from openjar-characters voice packs
func set_volume(bus: String, linear: float) -> void  # "Music" / "SFX", 0..1; Settings calls it
func get_volume(bus: String) -> float
```

Audio creates the `Music` and `SFX` buses at start if the project has no bus layout, and applies
the saved volumes.

Every action must call `Audio.play`. Missing cue files log a line once, never crash, and play a
placeholder synth beep (`Synth.beep(cue)`, `scripts/autoload/synth.gd`) so the grey-box is never silent.

Menu cues (Audio lane supplies the files): `ui_move`, `ui_confirm`, `ui_back`, `player_join`,
`player_ready`, `player_unready`, `count_tick`, `round_start`, `pause`, `solo_on`, `solo_off`.

### `Debug` (`scripts/autoload/Debug.gd`)

F3 toggles the overlay (fps, state, player count). F12 saves `user://screenshots/<timestamp>.png`
and prints the path. `--screenshot-after=<seconds>` CLI flag does it headlessly for the Reviewer.

## Launcher handshake

The launcher starts a game with `--profile=<id>` and expects the game to:

- read `store/openjar.json` at export time (name, version, card art, clip) — produced by CI;
- exit with code 0 on a clean quit (`Game.quit()`: the door button in the lobby or the pause menu);
- not change display mode (the launcher owns fullscreen).

## Game-specific contracts

Add this game's own signals and APIs below. Keep the same format.

### Junk Yard Zap (Systems, grey-box)

```gdscript
# The yard: scripts/levels/yard_level.gd (scenes/levels/yard.tscn), group "yard_level"
class_name YardLevel
signal zapped(player: int, gun: StringName, target: Node3D)   # target null = sparkle at nothing
signal goal_completed(goal_id: StringName)
signal goal_skipped(goal_id: StringName)
signal yard_reset()
var deck: GoalDeck
var objects: Dictionary          # layout key ("cow", "chicken_2") -> PhysicsObject
func object(key: StringName) -> PhysicsObject
func reset_yard() -> void        # Reset Yard: back to data/yard_layout.tres; the deck stays
func to_save() -> Dictionary     # {"version": 1, "objects": {key: {p, r, size, fx}}, "glue": [[a, b]], "deck": {...}}
func from_save(d: Dictionary) -> void
static func find(n: Node) -> YardLevel

# Physics rules (scripts/physics/yard.gd), static
func Yard.gravity_at(pos: Vector3) -> Vector3
func Yard.up_at(pos: Vector3) -> Vector3
func Yard.water_level_at(pos: Vector3) -> float          # -INF when not over water
func Yard.objects_in_zone(zone: StringName) -> Array[Node3D]   # front_gate, scrap_heap, pond, barn, tower, pond_air
func Yard.zone(zone: StringName) -> AABB

# Objects: PhysicsObject (RigidBody3D) configured by ObjectData (data/objects/*.tres)
signal object_landed(target: Node3D, impulse: float)     # impulse = logical mass x speed change
signal recalled(obj: PhysicsObject)                      # left the yard, sent back to the gate
signal scale_refused(obj: PhysicsObject)                 # no room to grow: play "nope"
signal splashed(obj: PhysicsObject)
var key: StringName                                      # layout key
func speak() -> void                                     # its voice, pitched by size
EffectStack.effect_changed(target: Node3D, effect: StringName, on: bool)

# Effects: every gun goes through these; nothing checks which other effects are on
func Effects.zap(gun: StringName, target: PhysicsObject) -> bool   # grow, shrink, bouncy, balloon, freeze, magnet
func Effects.glue(a: PhysicsObject, b: PhysicsObject) -> Effects.Glue
func Effects.grab(target: PhysicsObject, holder: Node3D, color: Color) -> Effects.Grab   # holder.hold_point(t)
func Effects.release(target: PhysicsObject, throw_velocity := Vector3.ZERO) -> void

# Guns: data/guns/<n>_<id>.tres (GunData), belt order = file order
class_name GunData   # id, kind (SIZE, GRAB, BOUNCY, BALLOON, FREEZE, GLUE, MAGNET), params, icon, beam_color, cue

# Players: scenes/players/zapper.tscn (Zapper, CharacterBody3D, group "zappers")
signal zapped(player: int, gun: StringName, target: Node3D)
signal gun_changed(player: int, gun: GunData)
signal woke(player: int)
signal partner_zapped(player: int, gun: StringName)
var asleep: bool                 # in the tire pile until his pad presses something
func wake() -> void
func partner_zap(gun: GunData, from: Zapper) -> void     # harmless, at most PARTNER_TIME (1 s)
var input_override: Dictionary   # tests and the demo bot: {move, aim, action, jump, next, prev}

# Goal cards: data/goals/*.tres (GoalData); the checker is static and side-effect free
func Goals.check(goal: GoalData, objects: Array = []) -> bool
class_name GoalDeck   # current(), complete(), skip(), order, done; signals goal_completed, goal_skipped, card_changed

# Juice: scripts/fx/fx.gd, static (lift to openjar-addons later)
func Fx.shake(amount: float) -> void    # respects SettingsPanel.screen_shake()
func Fx.impact(tree, at, mass, speed) / burst(...) / ring(...) / sparkle(...) / fireworks(...)
```

Cues the grey-box plays (Audio lane: real files replace the synth beeps by name): `zap_<gun>` (size,
grab, bouncy, balloon, freeze, glue, magnet), `grow`, `shrink`, `nope`, `sparkle`, `grab`, `throw`,
`drop`, `glue_pick`, `unglue`, `jump`, `land`, `wheel_move`, `impact_light|medium|heavy|huge`,
`splash`, `recall`, `voice_<object id>` (pitched by size), `card_view`, `card_done`, `card_skip`,
`reset_hold`, `reset_yard`, `snore`, `snort`, `bark_jeff`, `bark_chuck`, `bark_<who>_cheer`, `boing`,
`squelch`, `crack`, `solo_swap`.

Save keys (`Save`, per profile): `yard` (YardLevel.to_save()), `guns` ({"0": belt index, "1": ...}).
