## The menu look, in one place: type scale, colours, panels, focus, controller glyphs.
## Menus are for the grown-up holding the pad (docs/ui.md); gameplay keeps the kid rules.
## Games set the accent and nothing else: `UiStyle.accent = Color("4fb3ff")` in main.gd _ready().
## assets/ui/theme.tres is generated from this file by scripts/tools/build_theme.gd.
class_name UiStyle
extends RefCounted

enum Role { TITLE, HEADING, BUTTON, BODY, HINT, CAPTION }

const DISPLAY_FONT := "res://assets/fonts/fredoka/Fredoka-Variable.ttf"
const BODY_FONT := "res://assets/fonts/nunito/Nunito-Variable.ttf"
## Type scale at 1080p (canvas_items stretch scales it up crisply for 4K).
const SIZE := {
	Role.TITLE: 132, Role.HEADING: 64, Role.BUTTON: 40, Role.BODY: 32, Role.HINT: 27, Role.CAPTION: 24,
}
const WEIGHT := {
	Role.TITLE: 650, Role.HEADING: 600, Role.BUTTON: 800, Role.BODY: 600, Role.HINT: 700, Role.CAPTION: 900,
}
## TV safe area: 5% each side.
const SAFE := Vector2(96, 54)

# Warm neutrals. Player colours are only for player identity.
const BG_TOP := Color("2c2320")
const BG_BOTTOM := Color("110d0c")
const PANEL := Color("221b18")
const PANEL_RAISED := Color("2f2622")
const LINE := Color("4a3e37")
const TEXT := Color("f8f0e5")
const TEXT_DIM := Color("c4b6a6")
const TEXT_FAINT := Color("85776c")
const INK := Color("1c1714")
const FOCUS_FILL := Color("fff5e6")
const SHADOW := Color(0, 0, 0, 0.45)
const RADIUS := 22
const RADIUS_PANEL := 32

## The one colour a game sets: focus bar, glow, sliders, progress.
static var accent := Color("ffb23e")

static var _fonts := {}


static func font(role: Role) -> Font:
	if _fonts.has(role):
		return _fonts[role]
	var fv := FontVariation.new()
	var display := role == Role.TITLE or role == Role.HEADING
	fv.base_font = load(DISPLAY_FONT if display else BODY_FONT)
	var ts := TextServerManager.get_primary_interface()
	fv.variation_opentype = { ts.name_to_tag("wght"): WEIGHT[role] }
	if role == Role.CAPTION:
		fv.spacing_glyph = 3
	_fonts[role] = fv
	return fv


static func font_size(role: Role) -> int:
	return SIZE[role]


## Same as Players.COLOR (a test keeps them equal); copied so the theme builds without autoloads.
const PLAYER_COLORS := [Color("3cc24a"), Color("e4393c")]


static func player_color(player: int) -> Color:
	return PLAYER_COLORS[player]


static func player_name(player: int) -> String:
	return "Player %d" % (player + 1)


## A rounded panel with a soft drop shadow.
static func panel(color: Color = PANEL, radius: int = RADIUS_PANEL, shadow := 28) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 12
	sb.anti_aliasing = true
	sb.shadow_color = SHADOW
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, shadow * 0.35)
	return sb


static func outline(color: Color, width: int, radius: int = RADIUS_PANEL) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = color
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 12
	sb.anti_aliasing = true
	return sb


## The focus glow behind a focused element: accent shadow, no fill.
static func glow(color: Color, radius: int = RADIUS, size := 26) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.0)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 12
	sb.shadow_color = Color(color, 0.5)
	sb.shadow_size = size
	return sb


# --- text with controller glyphs -------------------------------------------------
# "Press [a] to join": [a] [b] [x] [y] [start] [select] [lr] [ud] become drawn Xbox-layout glyphs.

const GLYPHS := ["a", "b", "x", "y", "start", "select", "lr", "ud"]


static func _parts(text: String) -> Array:
	var out := []
	var rest := text
	while rest != "":
		var i := rest.find("[")
		var j := rest.find("]", i)
		if i == -1 or j == -1:
			out.append(rest)
			break
		var tok := rest.substr(i + 1, j - i - 1)
		if tok in GLYPHS:
			if i > 0:
				out.append(rest.substr(0, i))
			out.append([tok])
		else:
			out.append(rest.substr(0, j + 1))
		rest = rest.substr(j + 1)
	return out


static func glyph_width(tok: String, size: int) -> float:
	var h := size * 1.25
	return h * (1.5 if tok == "lr" or tok == "ud" else 1.0)


static func rich_width(text: String, role: Role, size := 0) -> float:
	var fs := size if size > 0 else font_size(role)
	var f := font(role)
	var w := 0.0
	for p in _parts(text):
		if p is Array:
			w += glyph_width(p[0], fs) + fs * 0.3
		else:
			w += f.get_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w


## Draws text (with glyph tokens) vertically centred on `at.y`. align: 0 left, 1 centre, 2 right of `at.x`.
static func draw_rich(ci: CanvasItem, at: Vector2, text: String, role: Role, color: Color,
		align := 0, size := 0) -> float:
	var fs := size if size > 0 else font_size(role)
	var f := font(role)
	var w := rich_width(text, role, fs)
	var x := at.x - (w * 0.5 if align == 1 else (w if align == 2 else 0.0))
	var base := at.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	var parts := _parts(text)
	for i in parts.size():
		var p = parts[i]
		if p is Array:
			var gw := glyph_width(p[0], fs)
			var pad := fs * 0.15
			draw_glyph(ci, Vector2(x + pad + gw * 0.5, at.y), fs * 1.25, p[0], color.a)
			x += gw + fs * 0.3
		else:
			ci.draw_string(f, Vector2(x, base), p, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
			x += f.get_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w


## Plain text, vertically centred on `at.y`.
static func draw_text(ci: CanvasItem, at: Vector2, text: String, role: Role, color: Color,
		align := 0, size := 0) -> void:
	var fs := size if size > 0 else font_size(role)
	var f := font(role)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := at.x - (w * 0.5 if align == 1 else (w if align == 2 else 0.0))
	ci.draw_string(f, Vector2(x, at.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


## A neutral controller glyph (Xbox layout, no logos): a light disc with a dark letter,
## a pill for the d-pad directions. `h` is the glyph height.
static func draw_glyph(ci: CanvasItem, c: Vector2, h: float, tok: String, alpha := 1.0) -> void:
	var r := h * 0.5
	var fill := Color(FOCUS_FILL, alpha)
	var ink := Color(INK, alpha)
	match tok:
		"lr", "ud":
			var sb := StyleBoxFlat.new()
			sb.bg_color = fill
			sb.set_corner_radius_all(int(r))
			sb.anti_aliasing = true
			ci.draw_style_box(sb, Rect2(c - Vector2(r * 1.5, r), Vector2(r * 3.0, r * 2.0)))
			var k := r * 0.42
			for s in [-1.0, 1.0]:
				var tip := c + (Vector2(s * r * 1.0, 0) if tok == "lr" else Vector2(0, s * r * 0.62))
				var back := Vector2(-s * k, 0) if tok == "lr" else Vector2(0, -s * k)
				var side := Vector2(0, k) if tok == "lr" else Vector2(k, 0)
				ci.draw_colored_polygon(PackedVector2Array([tip, tip + back + side, tip + back - side]), ink)
		"start":
			ci.draw_circle(c, r, fill, true, -1.0, true)
			for i in 3:
				var y := (i - 1) * r * 0.32
				ci.draw_line(c + Vector2(-r * 0.42, y), c + Vector2(r * 0.42, y), ink, r * 0.14, true)
		"select":
			ci.draw_circle(c, r, fill, true, -1.0, true)
			var s := r * 0.62
			ci.draw_rect(Rect2(c + Vector2(-s * 0.75, -s * 0.75), Vector2(s, s)), ink, false, r * 0.12)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.25, -s * 0.25), Vector2(s, s)), fill)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.25, -s * 0.25), Vector2(s, s)), ink, false, r * 0.12)
		_:
			ci.draw_circle(c, r, fill, true, -1.0, true)
			var f := font(Role.CAPTION)
			var fs := int(h * 0.68)
			var letter := tok.to_upper()
			var sz := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			ci.draw_string(f, Vector2(c.x - sz.x * 0.5 + fs * 0.06, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5),
					letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


## Theme for Label-based text in menus (titles, headings, body). Saved to assets/ui/theme.tres.
static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(Role.BODY)
	t.default_font_size = SIZE[Role.BODY]
	t.set_color("font_color", "Label", TEXT)
	var variations := {
		"TitleLabel": [Role.TITLE, TEXT], "HeadingLabel": [Role.HEADING, TEXT],
		"BodyLabel": [Role.BODY, TEXT_DIM], "HintLabel": [Role.HINT, TEXT_DIM],
		"CaptionLabel": [Role.CAPTION, TEXT_FAINT],
	}
	for v in variations:
		t.set_type_variation(v, "Label")
		t.set_font("font", v, font(variations[v][0]))
		t.set_font_size("font_size", v, SIZE[variations[v][0]])
		t.set_color("font_color", v, variations[v][1])
	t.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.35))
	t.set_constant("shadow_offset_y", "TitleLabel", 6)
	t.set_constant("shadow_offset_x", "TitleLabel", 0)
	var card := panel(PANEL, RADIUS_PANEL, 40)
	card.border_color = Color(LINE, 0.8)
	card.set_border_width_all(2)
	t.set_stylebox("panel", "PanelContainer", card)
	t.set_stylebox("panel", "Panel", card)
	return t
