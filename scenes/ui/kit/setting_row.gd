## A settings row: a label on the left and its value on the right, as a 10-step slider or an
## on/off switch. Same focus look as MenuItem. The settings panel changes `value`.
class_name SettingRow
extends MenuItem

enum Kind { SLIDER, TOGGLE }

@export var kind := Kind.SLIDER
@export var detail := ""
## Slider: 0..1 in steps of 0.1. Toggle: 0 or 1.
var value := 1.0:
	set(v):
		value = v
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(0, 112 if detail != "" else 96)


func is_on() -> bool:
	return value >= 0.5


func _draw() -> void:
	_draw_frame()
	var k := clampf(_f, 0.0, 1.0)
	var ink := UiStyle.TEXT.lerp(UiStyle.INK, k)
	var dim := UiStyle.TEXT_DIM.lerp(Color(UiStyle.INK, 0.62), k)
	var x := 48.0
	if detail != "":
		UiStyle.draw_text(self, Vector2(x, size.y * 0.5 - 17), text, UiStyle.Role.BUTTON, ink, 0, 36)
		UiStyle.draw_text(self, Vector2(x, size.y * 0.5 + 25), detail, UiStyle.Role.HINT, dim, 0, 24)
	else:
		UiStyle.draw_text(self, Vector2(x, size.y * 0.5), text, UiStyle.Role.BUTTON, ink, 0, 36)
	var right := size.x - 40.0
	var cy := size.y * 0.5
	var on_col := UiStyle.accent
	var off_col := Color(UiStyle.LINE, 1.0).lerp(Color(UiStyle.INK, 0.18), k)
	if kind == Kind.SLIDER:
		var steps := 10
		var w := 20.0
		var gap := 7.0
		var total := steps * w + (steps - 1) * gap
		var pct := "%d%%" % roundi(value * 100.0)
		UiStyle.draw_text(self, Vector2(right, cy), pct, UiStyle.Role.BUTTON, ink, 2, 32)
		var x0 := right - 118.0 - total
		var lit := roundi(value * steps)
		for i in steps:
			var h := 18.0 + 22.0 * float(i + 1) / steps
			var seg := UiStyle.panel(on_col if i < lit else off_col, 5, 0)
			draw_style_box(seg, Rect2(Vector2(x0 + i * (w + gap), cy + 20.0 - h), Vector2(w, h)))
	else:
		var sw := Vector2(92, 50)
		var at := Vector2(right - sw.x, cy - sw.y * 0.5)
		var track := UiStyle.panel(on_col if is_on() else off_col, 25, 0)
		draw_style_box(track, Rect2(at, sw))
		var knob_x := at.x + (sw.x - 25.0 if is_on() else 25.0)
		draw_circle(Vector2(knob_x, cy), 19.0, UiStyle.FOCUS_FILL if not is_on() or k < 0.5 else Color.WHITE, true, -1.0, true)
		UiStyle.draw_text(self, Vector2(at.x - 22.0, cy), "On" if is_on() else "Off", UiStyle.Role.BUTTON, ink, 2, 32)
