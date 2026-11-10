## The menu background: a warm vertical gradient, a soft accent glow behind the title and a
## vignette. Games hide it (Backdrop.visible = false) to show their level behind the menu instead.
extends Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([UiStyle.BG_TOP, UiStyle.BG_TOP, UiStyle.BG_BOTTOM, UiStyle.BG_BOTTOM]))
	_radial(Vector2(w * 0.5, h * 0.2), Vector2(w * 0.42, h * 0.38), Color(UiStyle.accent, 0.13))
	_radial(Vector2(w * 0.5, h * 1.05), Vector2(w * 0.6, h * 0.35), Color(0, 0, 0, 0.35))


## A soft elliptical glow: full colour in the middle, fading to nothing at the edge.
func _radial(c: Vector2, radius: Vector2, col: Color) -> void:
	var n := 48
	var pts := PackedVector2Array([c])
	var cols := PackedColorArray([col])
	for i in n + 1:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * radius.x, sin(a) * radius.y))
		cols.append(Color(col, 0.0))
	for i in n:
		draw_polygon(PackedVector2Array([pts[0], pts[i + 1], pts[i + 2]]),
				PackedColorArray([cols[0], cols[i + 1], cols[i + 2]]))
