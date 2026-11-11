## Menu input from every joined pad (and the keyboard fallback): one shared cursor, either player
## drives it. read() once a frame; `a` / `b` hold the player who pressed, or -1.
## The D-pad moves the cursor too (launch-ready: a kid reaches for it before the stick). Its edges
## are worked out once per frame, so a second read() in the same frame sees the same move.
class_name MenuInput
extends RefCounted

const DPAD := {
	JOY_BUTTON_DPAD_UP: Vector2i(0, -1), JOY_BUTTON_DPAD_DOWN: Vector2i(0, 1),
	JOY_BUTTON_DPAD_LEFT: Vector2i(-1, 0), JOY_BUTTON_DPAD_RIGHT: Vector2i(1, 0),
}

static var _held := {}          # device -> Vector2i the D-pad held last frame it was read
static var _frame := -1
static var _edge := {}          # player -> this frame's D-pad move (new presses only)


static func read() -> Dictionary:
	var move := Vector2i.ZERO
	var a := -1
	var b := -1
	_dpad_edges()
	for p in Players.active_players():
		if Input.is_action_just_pressed(Players.action(p, "move_up")):
			move.y = -1
		elif Input.is_action_just_pressed(Players.action(p, "move_down")):
			move.y = 1
		if Input.is_action_just_pressed(Players.action(p, "move_left")):
			move.x = -1
		elif Input.is_action_just_pressed(Players.action(p, "move_right")):
			move.x = 1
		var d: Vector2i = _edge.get(p, Vector2i.ZERO)
		if d.y != 0:
			move.y = d.y
		if d.x != 0:
			move.x = d.x
		if a == -1 and Input.is_action_just_pressed(Players.action(p, "action")):
			a = p
		elif b == -1 and Input.is_action_just_pressed(Players.action(p, "jump")):
			b = p
	return { "move": move, "a": a, "b": b }


static func _dpad_edges() -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	_frame = f
	_edge.clear()
	for p in Players.active_players():
		var dev := Players.device_of(p)
		if dev < 0 or (Players.solo and p != Players.solo_focus):
			continue
		var now := Vector2i.ZERO
		for button in DPAD:
			if Input.is_joy_button_pressed(dev, button):
				now += DPAD[button]
		var was: Vector2i = _held.get(dev, Vector2i.ZERO)
		_held[dev] = now
		_edge[p] = Vector2i(now.x if now.x != was.x else 0, now.y if now.y != was.y else 0)
