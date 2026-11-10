## One menu entry with a text label. The menu that owns it moves the focus and presses it; this
## draws: a quiet dark pill normally; focused, a light pill that grows 5% with an accent bar and an
## accent glow (readable from the sofa). `progress` (0..1) fills it with the accent (hold to start).
class_name MenuItem
extends Control

@export var text := "Item":
	set(v):
		text = v
		queue_redraw()
@export var disabled := false:
	set(v):
		disabled = v
		queue_redraw()

var focused := false:
	set(v):
		if v == focused:
			return
		focused = v
		_animate_focus()
var progress := 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()

var _f := 0.0        # focus amount, animated 0..1
var _press := 0.0    # press squash, animated 0..1
var _tw: Tween


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	return Vector2(0, 92)


## Next focusable index from `from` in direction dir (skips disabled; stays put at the ends).
static func step(items: Array, from: int, dir: int) -> int:
	var i := from + dir
	while i >= 0 and i < items.size():
		if not items[i].disabled:
			return i
		i += dir
	return from


func press() -> void:
	var tw := create_tween()
	tw.tween_method(_set_press, 0.0, 1.0, 0.06)
	tw.tween_method(_set_press, 1.0, 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate_focus() -> void:
	if _tw:
		_tw.kill()
	if not is_inside_tree():
		_f = 1.0 if focused else 0.0
		queue_redraw()
		return
	_tw = create_tween()
	_tw.tween_method(_set_f, _f, 1.0 if focused else 0.0, 0.16 if focused else 0.12) \
			.set_trans(Tween.TRANS_BACK if focused else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_f(v: float) -> void:
	_f = v
	queue_redraw()


func _set_press(v: float) -> void:
	_press = v
	queue_redraw()


func _draw() -> void:
	_draw_frame()
	var col := UiStyle.TEXT.lerp(UiStyle.INK, clampf(_f, 0.0, 1.0))
	if disabled:
		col = Color(UiStyle.TEXT, 0.32)
	UiStyle.draw_text(self, size * 0.5, text, UiStyle.Role.BUTTON, col, 1)


## Background, glow, progress and accent bar, in a transform that scales round the centre.
func _draw_frame() -> void:
	var s := 1.0 + 0.05 * _f - 0.04 * _press
	draw_set_transform(size * 0.5 * (1.0 - s), 0.0, Vector2(s, s))
	var r := Rect2(Vector2.ZERO, size)
	var k := clampf(_f, 0.0, 1.0)
	if k > 0.0:
		var g := UiStyle.glow(UiStyle.accent)
		g.shadow_color.a *= k
		draw_style_box(g, r)
	var bg := Color(UiStyle.PANEL_RAISED, 0.92).lerp(UiStyle.FOCUS_FILL, k)
	if disabled:
		bg = Color(UiStyle.PANEL_RAISED, 0.5)
	var sb := UiStyle.panel(bg, UiStyle.RADIUS, 0)
	if k < 1.0:
		sb.border_color = Color(UiStyle.LINE, 1.0 - k)
		sb.set_border_width_all(2)
	draw_style_box(sb, r)
	if progress > 0.0:
		var p := UiStyle.panel(Color(UiStyle.accent, 0.85), UiStyle.RADIUS, 0)
		draw_style_box(p, Rect2(r.position, Vector2(maxf(r.size.x * progress, UiStyle.RADIUS * 2), r.size.y)))
	if k > 0.0:
		var bar := UiStyle.panel(UiStyle.accent, 5, 0)
		var bh := (size.y - 36.0) * k
		draw_style_box(bar, Rect2(Vector2(16, (size.y - bh) * 0.5), Vector2(9, bh)))
