## A line of hint text with controller glyphs: "[a] Select   [b] Back". See UiStyle.draw_rich.
class_name HintLine
extends Control

@export var text := "":
	set(v):
		text = v
		queue_redraw()
@export var role := UiStyle.Role.HINT
@export_enum("Left", "Center", "Right") var align := 1
@export var color := UiStyle.TEXT_DIM


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var x: float = [0.0, size.x * 0.5, size.x][align]
	UiStyle.draw_rich(self, Vector2(x, size.y * 0.5), text, role, color, align)
