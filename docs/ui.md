# Menu UI

**Menus are for the grown-up holding the pad.** Kaden, 2026-11-09: "Those should all be designed
for me. He's not using them, I am." The start screen (lobby), pause, settings and any other
front-end screen look like a well-made console game's menus: real type, text labels, clean
layout, a little motion, a sound on every move. Gameplay keeps the kid rules (`docs/kid-design.md`).

Everything lives in `scenes/ui/kit/` and is drawn in code, so it is crisp at 1080p and 4K
(`canvas_items` stretch re-rasterises fonts and shapes at the output size).

## The look

- Warm near-black backgrounds (`#2c2320` to `#110d0c`), warm off-white text (`#f8f0e5`).
- Fredoka (display) for titles and headings; Nunito for buttons, body and hints.
- Rounded cards (32 px radius) with a soft drop shadow and a hairline border.
- One accent colour per game for focus, sliders and progress. Default marigold `#ffb23e`.
- P1 green `#3cc24a` and P2 red `#e4393c` only ever mean "this player".

## Type scale (`UiStyle.Role`, sizes at 1080p)

| Role | Face | Size | Weight | Used for |
| --- | --- | --- | --- | --- |
| `TITLE` | Fredoka | 132 | 650 | game title when there is no logo |
| `HEADING` | Fredoka | 64 | 600 | "Paused", "Settings", "Leave the game?" |
| `BUTTON` | Nunito | 40 | 800 | menu items, setting labels |
| `BODY` | Nunito | 32 | 600 | sentences, player-panel prompts |
| `HINT` | Nunito | 27 | 700 | controller hints, status line |
| `CAPTION` | Nunito | 24 | 900, tracked | PLAYER 1, READY, version |

Nothing smaller than 24 px: it has to read from the sofa, 3 m from the TV.

## Focus, disabled, safe area

- **Focused** (`MenuItem`): the pill turns light (`#fff5e6`) with dark text, grows 5%, gets an
  accent bar on the left and an accent glow. Unfocused: dark pill, hairline border, light text.
  Readable at a glance from across the room, on any TV.
- **Disabled** (`MenuItem.disabled = true`): faded, skipped by focus movement.
- **Pressed**: a quick squash.
- **Safe area**: keep everything inside 5% of each edge, `UiStyle.SAFE` = (96, 54) at 1080p.

## Controller glyphs

Write `[a]`, `[b]`, `[x]`, `[y]`, `[start]`, `[select]`, `[lr]` (left/right), `[ud]` (up/down) in
any hint text; `HintLine` and `UiStyle.draw_rich()` draw them as neutral Xbox-layout glyphs (a
light disc with a dark letter, no logos, no brand colours). Example: `"Press [a] to join"`.

## Theme API

```gdscript
UiStyle.accent = Color("4fb3ff")                 # the one thing a game sets, in main.gd _ready()
UiStyle.font(UiStyle.Role.HEADING) -> Font
UiStyle.font_size(UiStyle.Role.HEADING) -> int
UiStyle.panel(color, radius, shadow) -> StyleBoxFlat   # rounded card with soft shadow
UiStyle.outline(color, width, radius) -> StyleBoxFlat
UiStyle.glow(color, radius, size) -> StyleBoxFlat      # focus glow
UiStyle.draw_text(canvas_item, at, text, role, color, align, size)
UiStyle.draw_rich(canvas_item, at, "Press [a] to join", role, color, align, size)
UiStyle.player_color(player) / UiStyle.player_name(player)   # "Player 1"
```

`assets/ui/theme.tres` is generated from `UiStyle` for `Label`s and `Panel`s. It has type
variations `TitleLabel`, `HeadingLabel`, `BodyLabel`, `HintLabel`, `CaptionLabel`. After
changing `ui_style.gd`, regenerate it:
`godot --headless --path . -s scripts/tools/build_theme.gd`.

Building blocks in `scenes/ui/kit/`: `MenuItem` (text button), `SettingRow` (slider / switch),
`HintLine` (hint text with glyphs), `menu_backdrop.gd` (gradient + glow), `MenuInput.read()`
(one shared cursor from every joined pad), `blur_dim.gdshader` (pause backdrop), `UiPreview`
(`--ui=` screenshot states).

## Screens

- **Lobby** (`scenes/ui/lobby.tscn`): title on top, Play / Settings / Back to Open Jar in the
  middle, a join panel per player either side ("Press [a] to join", their character, READY), a
  status line ("Hold [a] on Play to start solo", "Starting in 3"), hints bottom right.
- **Pause** (`scenes/ui/pause_menu.tscn`): blurred dimmed game, card with "Paused", who paused
  (in their colour), Resume / Restart / Settings / Back to Open Jar.
- **Settings** (`scenes/ui/settings_panel.tscn`): music volume, sound volume, screen shake,
  solo playtest mode. Per install (`user://settings.json`), saved the moment a value changes.
- **Leave the game?** (`scenes/ui/confirm_dialog.tscn`): Stay (focused first) / Leave.

Sounds: `ui_move` on every focus move (also bumping an end), `ui_confirm` on select and opening
a panel, `ui_back` on B / closing / Stay.

## How a game makes it its own

Do it in code in `_ready()` (exported builds lose overrides on instanced children):

```gdscript
UiStyle.accent = Color("4fb3ff")
var lobby := $UI/Lobby
lobby.title_texture = preload("res://assets/sprites/logo.png")   # or lobby.title_text = "Spaceballs"
lobby.get_node("Backdrop").visible = false      # show the level behind the lobby instead
lobby.get_node("Spots/P1").fill_alpha = 0.18    # see-through player panels over the level
# Replace Spots/P1/Character and Spots/P2/Character with the game's characters (Jeff left,
# Chuck right). The lobby calls set_joined(on) and wave() on them if they have them.
```

Screen shake: check `SettingsPanel.screen_shake()` before shaking the camera.

## Screenshots

`scripts/tools/shots.sh "" 1.5 /tmp/shots --ui=lobby-joined` (also `lobby`, `lobby-ready`,
`lobby-hold`, `lobby-settings`, `lobby-confirm`, `pause`, `pause-settings`, `pause-confirm`).
