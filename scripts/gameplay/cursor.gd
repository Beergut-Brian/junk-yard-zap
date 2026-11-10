## The mouse pointer. Nothing in Junk Yard Zap needs a mouse (the menus are pad/keyboard, solo is
## pad/keyboard), so the pointer is hidden. It comes back only when someone moves the mouse while a
## menu is up (lobby, pause), and hides again on the next pad or key press or when play resumes.
## Never hidden in gameplay by accident: in PLAYING it is always hidden.
class_name Cursor
extends Node

var mouse_recent := false


static func should_show(state: int, p_mouse_recent: bool) -> bool:
	return p_mouse_recent and state != Game.State.PLAYING


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.state_changed.connect(func(_f: int, _t: int) -> void: apply())
	apply()


func _input(event: InputEvent) -> void:
	var was := mouse_recent
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		mouse_recent = true
	elif event is InputEventKey or event is InputEventJoypadButton \
			or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		mouse_recent = false
	if was != mouse_recent:
		apply()


func apply() -> void:
	var want := Input.MOUSE_MODE_VISIBLE if should_show(Game.state, mouse_recent) else Input.MOUSE_MODE_HIDDEN
	if Input.mouse_mode != want:
		Input.mouse_mode = want
