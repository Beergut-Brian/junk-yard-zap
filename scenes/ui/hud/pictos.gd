## Pictures instead of words (no reading in gameplay): the gun tokens (drawn by GunIcons) and the goal
## cards (the frame here, the pictures in CardArt). A GunData.icon texture still wins over the token,
## and a GoalData.picture only shows for a card CardArt can't draw.
class_name Pictos
extends RefCounted

const INK := Color(0.12, 0.1, 0.1)
const CARD := Color("#fff5e6")
const DEEP := Color("#33201a")      # the menu skin's deep brown
const GOLD := Color("#ffc93a")
const SKY := Color("#bfe6f5")
const SAND := Color("#ecc98d")
const OBJ_COLORS := {
	&"cow": Color(0.96, 0.96, 0.93), &"chicken": Color(1, 1, 0.97), &"duck": Color(1.0, 0.85, 0.2),
	&"bathtub": Color(0.9, 0.93, 1.0), &"ball": Color(0.95, 0.5, 0.3), &"car": Color(0.35, 0.5, 0.75),
	&"any": Color(0.8, 0.6, 0.38),
}


## The gun's token (GunIcons): its effect on a little crate, on a disc in its beam colour.
static func gun_icon(ci: CanvasItem, gun: GunData, r: Rect2, alpha := 1.0) -> void:
	if gun.icon:
		ci.draw_texture_rect(gun.icon, r, false, Color(1, 1, 1, alpha))
		return
	GunIcons.token(ci, gun.kind, gun.beam_color, r.get_center(), r.size.x * 0.5, 1.0, alpha)


## The switch preview (PT10-2): the same token with its little story at stage t (0..1; 1 = the icon).
static func gun_preview(ci: CanvasItem, gun: GunData, r: Rect2, t: float, alpha := 1.0) -> void:
	GunIcons.token(ci, gun.kind, gun.beam_color, r.get_center(), r.size.x * 0.5, t, alpha)


## No faces on vehicles or machines (Kaden, 2026-11-10): the drawing follows the object's own data
## (ObjectData.has_face, the same flag the 3D object uses), so the car, tractor, fridge, cannon and
## friends read as friendly through shape and colour, and their headlights stay lights.
static var _face_cache := {}


static func draws_face(id: StringName) -> bool:
	if not _face_cache.has(id):
		var path := "res://data/objects/%s.tres" % id
		var d := load(path) as ObjectData if ResourceLoader.exists(path) else null
		_face_cache[id] = d.has_face if d else true
	return _face_cache[id]


## A yard object as a little drawing; a face only when draws_face(id). id picks the silhouette.
static func object(ci: CanvasItem, id: StringName, m: Vector2, s: float, alpha := 1.0) -> void:
	var c: Color = OBJ_COLORS.get(id, OBJ_COLORS[&"any"])
	c.a = alpha
	var ink := Color(INK, alpha)
	var face := m
	match id:
		&"car":   # a little car: body, cab with a window, a cream headlight, two wheels
			var cab := Rect2(m + Vector2(-s * 0.6, -s * 0.75), Vector2(s * 1.2, s * 0.6))
			ci.draw_rect(cab, c)
			ci.draw_rect(Rect2(cab.position + Vector2(s * 0.12, s * 0.1), Vector2(s * 0.42, s * 0.4)), Color(0.75, 0.9, 1.0, alpha))
			ci.draw_rect(Rect2(cab.position + Vector2(s * 0.66, s * 0.1), Vector2(s * 0.42, s * 0.4)), Color(0.75, 0.9, 1.0, alpha))
			ci.draw_rect(Rect2(m + Vector2(-s * 1.2, -s * 0.2), Vector2(s * 2.4, s * 0.7)), c)
			ci.draw_circle(m + Vector2(s * 1.08, s * 0.0), s * 0.13, Color(1.0, 0.95, 0.7, alpha))
			for x in [-0.7, 0.7]:
				ci.draw_circle(m + Vector2(s * x, s * 0.55), s * 0.32, ink)
				ci.draw_circle(m + Vector2(s * x, s * 0.55), s * 0.13, Color(0.75, 0.75, 0.78, alpha))
		&"cow":
			ci.draw_rect(Rect2(m + Vector2(-s, -s * 0.5), Vector2(s * 1.6, s)), c)
			ci.draw_rect(Rect2(m + Vector2(s * 0.5, -s * 0.85), Vector2(s * 0.6, s * 0.65)), c)
			ci.draw_circle(m + Vector2(-s * 0.4, -s * 0.1), s * 0.2, ink)
			for x in [-0.85, -0.3, 0.2, 0.45]:
				ci.draw_rect(Rect2(m + Vector2(s * x, s * 0.5), Vector2(s * 0.16, s * 0.4)), c)
			face = m + Vector2(s * 0.8, -s * 0.5)
			s *= 0.55
		&"chicken", &"duck":
			ci.draw_circle(m, s * 0.7, c)
			ci.draw_circle(m + Vector2(s * 0.45, -s * 0.6), s * 0.38, c)
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(s * 0.8, -s * 0.65), m + Vector2(s * 1.15, -s * 0.55), m + Vector2(s * 0.8, -s * 0.45)]), Color(1, 0.55, 0.1, alpha))
			if id == &"chicken":
				ci.draw_circle(m + Vector2(s * 0.45, -s * 1.0), s * 0.13, Color(0.95, 0.25, 0.2, alpha))
			face = m + Vector2(s * 0.45, -s * 0.6)
			s *= 0.45
		&"bathtub":
			ci.draw_rect(Rect2(m + Vector2(-s * 1.1, s * 0.3), Vector2(s * 2.2, s * 0.3)), c)
			ci.draw_rect(Rect2(m + Vector2(-s * 1.1, -s * 0.4), Vector2(s * 0.3, s * 0.8)), c)
			ci.draw_rect(Rect2(m + Vector2(s * 0.8, -s * 0.4), Vector2(s * 0.3, s * 0.8)), c)
			for x in [-0.9, 0.7]:
				ci.draw_rect(Rect2(m + Vector2(s * x, s * 0.6), Vector2(s * 0.2, s * 0.25)), ink)
			return
		&"ball":
			ci.draw_circle(m, s * 0.75, c)
		_:
			ci.draw_rect(Rect2(m - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5), c)
			ci.draw_rect(Rect2(m - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5), Color(INK, alpha * 0.4), false, s * 0.08)
	if not draws_face(id):
		return
	ci.draw_circle(face + Vector2(-s * 0.25, -s * 0.15), s * 0.11, ink)
	ci.draw_circle(face + Vector2(s * 0.25, -s * 0.15), s * 0.11, ink)
	ci.draw_arc(face + Vector2(0, s * 0.05), s * 0.25, 0.3, PI - 0.3, 8, ink, maxf(2.0, s * 0.07), true)


static func _arrow(ci: CanvasItem, from: Vector2, to: Vector2, c: Color, w: float) -> void:
	ci.draw_line(from, to, c, w, true)
	var d := (to - from).normalized()
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([to + d * w * 1.5, to - d * w + n * w * 1.6, to - d * w - n * w * 1.6]), c)


## PT10-3: the goal card. A thick cream card with an ink edge and rounded corners; a dark header
## with the band as 1-3 gold stars and, on the right, the token of the gun that does it; under it a
## window onto the yard (sky over sand) with the goal as a picture: the objects involved and the
## result (CardArt.draw_goal). Same layout on every card, the HUD corner, the fence and the trophy
## shelf. guns: GunData by id and by effect id.
static func card(ci: CanvasItem, g: GoalData, r: Rect2, guns: Dictionary, alpha := 1.0) -> void:
	var u := r.size.x
	var ink := Color(INK, alpha)
	_rrect(ci, Rect2(r.position + Vector2(0, u * 0.035), r.size), Color(INK, 0.35 * alpha), u * 0.09)
	_rrect(ci, r, Color(CARD, alpha), u * 0.09, ink, u * 0.03)
	var head := Rect2(r.position + Vector2(u * 0.07, u * 0.07), Vector2(u * 0.86, u * 0.15))
	_rrect(ci, head, Color(DEEP, alpha), u * 0.05)
	var win := window(r)
	_rrect(ci, win, Color(SKY, alpha), u * 0.05, ink, u * 0.014)
	var sand := Rect2(Vector2(win.position.x, win.end.y - win.size.y * 0.2), Vector2(win.size.x, win.size.y * 0.2))
	_rrect(ci, sand.grow(-u * 0.007), Color(SAND, alpha), u * 0.04)
	if g == null:   # the deck is empty: one big gold star
		_star(ci, win.get_center(), u * 0.25, Color(GOLD, alpha))
		return
	for i in g.band:
		var c := head.position + Vector2(head.size.y * (0.6 + i * 0.95), head.size.y * 0.5)
		_star(ci, c, head.size.y * 0.5, ink)
		_star(ci, c, head.size.y * 0.4, Color(GOLD, alpha))
	var side := win.size.y * 1.18   # the pictures keep to the middle; this fills the window
	var pic := Rect2(win.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
	if g.picture and not CardArt.CARDS.has(g.id) and not CardArt.handles(g):
		ci.draw_texture_rect(g.picture, pic, false, Color(1, 1, 1, alpha))
	else:
		CardArt.draw_goal(ci, g, pic, guns)
	var gun: GunData = guns.get(CardArt.gun_for(g))
	if gun:
		var c := Vector2(head.end.x - head.size.y * 0.55, head.get_center().y + u * 0.01)
		GunIcons.token(ci, gun.kind, gun.beam_color, c, u * 0.105, 1.0, alpha)


## Where a card's picture goes (under the header).
static func window(r: Rect2) -> Rect2:
	var u := r.size.x
	return Rect2(r.position + Vector2(u * 0.07, u * 0.26), Vector2(u * 0.86, u * 0.67))


## PT10-3: the done and skip states, stamped over a card. done: a gold rosette with a tick, a little
## tilted, as if slapped on. skip: a curly "round the back" arrow on a dark disc. k: 0..1 slam (scale).
static func card_stamp(ci: CanvasItem, r: Rect2, done: bool, k: float, alpha := 1.0) -> void:
	var u := r.size.x
	var c := window(r).get_center()
	var big := lerpf(2.2, 1.0, clampf(k, 0.0, 1.0))
	var a := alpha * clampf(k * 3.0, 0.0, 1.0)
	if done:
		_rrect(ci, r, Color(GOLD, 0.25 * a), u * 0.09)
		var s := u * 0.26 * big
		var pts := PackedVector2Array()
		for i in 24:
			pts.append(c + Vector2.from_angle(-0.2 + i * TAU / 24.0) * (s if i % 2 == 0 else s * 0.84))
		ci.draw_colored_polygon(pts, Color(INK, a))
		pts.clear()
		for i in 24:
			pts.append(c + Vector2.from_angle(-0.2 + i * TAU / 24.0) * (s * 0.92 if i % 2 == 0 else s * 0.77))
		ci.draw_colored_polygon(pts, Color(GOLD, a))
		ci.draw_circle(c, s * 0.62, Color(GOLD.lightened(0.25), a))
		var tick := PackedVector2Array([c + Vector2(-0.32, 0.0) * s, c + Vector2(-0.08, 0.26) * s, c + Vector2(0.36, -0.26) * s])
		ci.draw_polyline(tick, Color(INK, a), s * 0.2, true)
		ci.draw_circle(tick[1], s * 0.1, Color(INK, a))
	else:
		var s := u * 0.22 * big
		ci.draw_circle(c, s + u * 0.015, Color(INK, a))
		ci.draw_circle(c, s, Color(DEEP, a))
		ci.draw_arc(c, s * 0.55, PI * 0.15, PI * 1.75, 24, Color(CARD, a), s * 0.22, true)
		var tip := c + Vector2.from_angle(PI * 0.15) * s * 0.55
		var d := Vector2.from_angle(PI * 0.15 + PI * 0.5)
		var n := Vector2(-d.y, d.x)
		ci.draw_colored_polygon(PackedVector2Array([tip + d * s * 0.3, tip - n * s * 0.28, tip + n * s * 0.28]), Color(CARD, a))


static var _sb: StyleBoxFlat


## A rounded rectangle (fill, optional ink border), drawn through a shared StyleBoxFlat.
static func _rrect(ci: CanvasItem, r: Rect2, fill: Color, radius: float, border := Color(0, 0, 0, 0), width := 0.0) -> void:
	if _sb == null:
		_sb = StyleBoxFlat.new()
		_sb.anti_aliasing = true
		_sb.corner_detail = 6
	_sb.bg_color = fill
	_sb.set_corner_radius_all(int(radius))
	_sb.border_color = border
	_sb.set_border_width_all(int(ceilf(width)))
	_sb.draw(ci.get_canvas_item(), r)


static func _star(ci: CanvasItem, m: Vector2, s: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(m + Vector2.from_angle(-PI / 2 + i * PI / 5) * (s if i % 2 == 0 else s * 0.48))
	ci.draw_colored_polygon(pts, c)
