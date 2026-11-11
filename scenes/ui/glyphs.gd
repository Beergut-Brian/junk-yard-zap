## Chunky picture glyphs drawn in code, shared by the HUD (the Select-hold reset ring) and the pause
## menu (an icon on every bar). One look: thick rounded strokes with a dark outline, so they read
## from the sofa on any background. `draw(ci, kind, centre, radius, colour)`.
class_name UiGlyphs
extends RefCounted

enum Kind { RESUME, RESET, LOBBY, SETTINGS, DOOR }

const OUTLINE := Color(0.13, 0.08, 0.06, 0.9)


static func draw(ci: CanvasItem, kind: Kind, c: Vector2, r: float, col: Color, spin := 0.0) -> void:
	match kind:
		Kind.RESUME:
			var pts := PackedVector2Array([c + Vector2(-0.42, -0.6) * r, c + Vector2(0.62, 0) * r, c + Vector2(-0.42, 0.6) * r])
			_poly(ci, pts, col, r)
		Kind.RESET:
			reset_swirl(ci, c, r, col, spin)
		Kind.LOBBY:
			# Two podiums (the lobby), the tall one in the middle.
			for k in [[-0.55, 0.45], [0.0, 0.85], [0.55, 0.6]]:
				var w := r * 0.42
				var h: float = r * k[1]
				var x: float = c.x + r * k[0]
				var rr := Rect2(x - w * 0.5, c.y + r * 0.62 - h, w, h)
				ci.draw_rect(rr.grow(r * 0.09), OUTLINE)
				ci.draw_rect(rr, col)
		Kind.SETTINGS:
			var pts := PackedVector2Array()
			for i in 32:
				var a := TAU * i / 32.0 + spin
				var tooth := 1.0 if (i / 2) % 2 == 0 else 0.74
				pts.append(c + Vector2.from_angle(a) * r * 0.78 * tooth)
			_poly(ci, pts, col, r)
			ci.draw_circle(c, r * 0.3, OUTLINE)
		Kind.DOOR:
			var d := Rect2(c + Vector2(-0.42, -0.72) * r, Vector2(0.84, 1.44) * r)
			ci.draw_rect(d.grow(r * 0.1), OUTLINE)
			ci.draw_rect(d, col)
			ci.draw_circle(c + Vector2(0.2, 0.05) * r, r * 0.1, OUTLINE)


## The "start again" swirl: a fat ring three-quarters round with an arrow head chasing its tail.
## spin turns it (radians), so a filling ring can wind it up.
static func reset_swirl(ci: CanvasItem, c: Vector2, r: float, col: Color, spin := 0.0) -> void:
	var rad := r * 0.58
	var w := r * 0.3
	var a0 := -PI * 0.35 + spin
	var a1 := a0 + PI * 1.45
	ci.draw_arc(c, rad, a0, a1, 32, OUTLINE, w + r * 0.16, true)
	ci.draw_arc(c, rad, a0, a1, 32, col, w, true)
	var tip := c + Vector2.from_angle(a1) * rad
	var fwd := Vector2.from_angle(a1 + PI * 0.5)
	var side := Vector2.from_angle(a1)
	var head := PackedVector2Array([tip + side * r * 0.36, tip + fwd * r * 0.42, tip - side * r * 0.36])
	_poly(ci, head, col, r)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, r: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, OUTLINE, r * 0.16, true)
	ci.draw_colored_polygon(pts, col)
