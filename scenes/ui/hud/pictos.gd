## Pictures instead of words (no reading in gameplay): gun icons for the belt wheel and the goal-card
## pictograms. Placeholder drawings in code; the Art lane replaces them with GunData.icon and
## GoalData.picture textures, which win when set.
class_name Pictos
extends RefCounted

const INK := Color(0.12, 0.1, 0.1)
const OBJ_COLORS := {
	&"cow": Color(0.96, 0.96, 0.93), &"chicken": Color(1, 1, 0.97), &"duck": Color(1.0, 0.85, 0.2),
	&"bathtub": Color(0.9, 0.93, 1.0), &"ball": Color(0.95, 0.5, 0.3), &"car": Color(0.35, 0.5, 0.75),
	&"any": Color(0.8, 0.6, 0.38),
}


static func gun_icon(ci: CanvasItem, gun: GunData, r: Rect2, alpha := 1.0) -> void:
	if gun.icon:
		ci.draw_texture_rect(gun.icon, r, false, Color(1, 1, 1, alpha))
		return
	var c := Color(gun.beam_color, alpha)
	var ink := Color(INK, alpha)
	var m := r.get_center()
	var s := r.size.x * 0.5
	match gun.kind:
		GunData.Kind.SIZE:
			ci.draw_rect(Rect2(m + Vector2(-s * 0.85, s * 0.15), Vector2(s * 0.5, s * 0.5)), c)
			ci.draw_rect(Rect2(m + Vector2(-s * 0.15, -s * 0.75), Vector2(s * 0.95, s * 1.4)), c)
			_arrow(ci, m + Vector2(-s * 0.6, -s * 0.1), m + Vector2(-s * 0.2, -s * 0.6), ink, s * 0.12)
		GunData.Kind.GRAB:
			ci.draw_rect(Rect2(m + Vector2(-s * 0.35, -s * 0.85), Vector2(s * 0.7, s * 0.6)), Color(0.8, 0.6, 0.38, alpha))
			for i in 3:
				var x := (i - 1) * s * 0.4
				ci.draw_line(m + Vector2(x, s * 0.8), m + Vector2(x * 1.3, -s * 0.15), c, s * 0.2, true)
			ci.draw_line(m + Vector2(-s * 0.55, s * 0.85), m + Vector2(s * 0.55, s * 0.85), c, s * 0.3, true)
		GunData.Kind.BOUNCY:
			var pts := PackedVector2Array()
			for i in 7:
				pts.append(m + Vector2(((i % 2) * 2 - 1) * s * 0.45, s * 0.8 - i * s * 0.27))
			ci.draw_polyline(pts, c, s * 0.18, true)
			ci.draw_circle(m + Vector2(0, -s * 0.85), s * 0.22, c)
		GunData.Kind.BALLOON:
			ci.draw_circle(m + Vector2(0, -s * 0.2), s * 0.6, c)
			ci.draw_line(m + Vector2(0, s * 0.4), m + Vector2(s * 0.15, s * 0.95), ink, s * 0.08, true)
		GunData.Kind.FREEZE:
			for i in 3:
				var d := Vector2.from_angle(i * PI / 3.0) * s * 0.85
				ci.draw_line(m - d, m + d, c, s * 0.16, true)
			ci.draw_circle(m, s * 0.2, c)
		GunData.Kind.GLUE:
			ci.draw_circle(m + Vector2(0, s * 0.25), s * 0.55, c)
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.48, s * 0.0), m + Vector2(0, -s * 0.9), m + Vector2(s * 0.48, 0)]), c)
		GunData.Kind.MAGNET:
			ci.draw_arc(m + Vector2(0, -s * 0.1), s * 0.6, PI, TAU, 16, Color(0.9, 0.2, 0.15, alpha), s * 0.35, true)
			for side in [-1, 1]:
				ci.draw_rect(Rect2(m + Vector2(side * s * 0.6 - s * 0.18, -s * 0.1), Vector2(s * 0.36, s * 0.5)), Color(0.9, 0.2, 0.15, alpha))
				ci.draw_rect(Rect2(m + Vector2(side * s * 0.6 - s * 0.18, s * 0.4), Vector2(s * 0.36, s * 0.3)), Color(0.85, 0.85, 0.9, alpha))


## A yard object as a little drawing with a face. id picks the silhouette.
static func object(ci: CanvasItem, id: StringName, m: Vector2, s: float, alpha := 1.0) -> void:
	var c: Color = OBJ_COLORS.get(id, OBJ_COLORS[&"any"])
	c.a = alpha
	var ink := Color(INK, alpha)
	var face := m
	match id:
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
	ci.draw_circle(face + Vector2(-s * 0.25, -s * 0.15), s * 0.11, ink)
	ci.draw_circle(face + Vector2(s * 0.25, -s * 0.15), s * 0.11, ink)
	ci.draw_arc(face + Vector2(0, s * 0.05), s * 0.25, 0.3, PI - 0.3, 8, ink, maxf(2.0, s * 0.07), true)


static func _arrow(ci: CanvasItem, from: Vector2, to: Vector2, c: Color, w: float) -> void:
	ci.draw_line(from, to, c, w, true)
	var d := (to - from).normalized()
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([to + d * w * 1.5, to - d * w + n * w * 1.6, to - d * w - n * w * 1.6]), c)


## The goal card face: a pictogram of the condition. guns: GunData by effect id, for the icons.
static func card(ci: CanvasItem, g: GoalData, r: Rect2, guns: Dictionary, alpha := 1.0) -> void:
	ci.draw_rect(r, Color(0.98, 0.95, 0.86, alpha))
	ci.draw_rect(r, Color(INK, alpha), false, maxf(2.0, r.size.x * 0.02))
	if g == null:
		_star(ci, r.get_center(), r.size.x * 0.3, Color(1, 0.8, 0.2, alpha))
		return
	if g.picture:
		ci.draw_texture_rect(g.picture, r.grow(-r.size.x * 0.06), false, Color(1, 1, 1, alpha))
		return
	var m := r.get_center()
	var s := r.size.x * 0.16
	var ink := Color(INK, alpha)
	match g.condition:
		GoalData.Condition.OBJECT_SCALE_AT_LEAST:
			object(ci, g.subject, m + Vector2(-s * 1.9, s * 0.9), s * 0.45, alpha)
			_arrow(ci, m + Vector2(-s * 1.2, s * 0.5), m + Vector2(-s * 0.3, s * 0.5), ink, s * 0.12)
			object(ci, g.subject, m + Vector2(s * 1.1, s * 0.2), s * 1.1, alpha)
		GoalData.Condition.OBJECT_HAS_EFFECT:
			object(ci, g.subject, m + Vector2(0, s * 0.9), s * 0.9, alpha)
			var gun: GunData = guns.get(g.effect)
			if gun:
				gun_icon(ci, gun, Rect2(m + Vector2(-s * 0.8, -s * 2.3), Vector2(s * 1.6, s * 1.6)), alpha)
			if g.effect == &"balloon":
				_arrow(ci, m + Vector2(s * 1.6, s * 0.8), m + Vector2(s * 1.6, -s * 1.2), ink, s * 0.12)
		GoalData.Condition.OBJECT_IN_ZONE:
			object(ci, g.other, m + Vector2(0, s * 1.4), s * 1.0, alpha)
			object(ci, g.subject, m + Vector2(0, -s * 1.5), s * 0.6, alpha)
			_arrow(ci, m + Vector2(0, -s * 0.7), m + Vector2(0, s * 0.6), ink, s * 0.12)
		GoalData.Condition.GLUED_PAIR:
			object(ci, g.subject, m + Vector2(-s * 1.0, s * 0.3), s * 0.75, alpha)
			object(ci, g.other if g.other != &"" else &"any", m + Vector2(s * 1.0, s * 0.3), s * 0.75, alpha)
			var gun: GunData = guns.get(&"glue")
			ci.draw_circle(m + Vector2(0, s * 0.3), s * 0.35, gun.beam_color if gun else Color.WHITE)
		_:
			object(ci, g.subject, m, s, alpha)
	# Band: one to three dots in the corner.
	for i in g.band:
		ci.draw_circle(r.position + Vector2(r.size.x * (0.12 + i * 0.1), r.size.y * 0.1), r.size.x * 0.035, Color(0.9, 0.55, 0.1, alpha))


static func _star(ci: CanvasItem, m: Vector2, s: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(m + Vector2.from_angle(-PI / 2 + i * PI / 5) * (s if i % 2 == 0 else s * 0.45))
	ci.draw_colored_polygon(pts, c)
