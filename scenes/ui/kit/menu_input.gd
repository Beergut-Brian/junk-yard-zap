## Menu input from every joined pad (and the keyboard fallback): one shared cursor, either player
## drives it. read() once a frame; `a` / `b` hold the player who pressed, or -1.
## The D-pad moves the cursor too (launch-ready: a kid reaches for it before the stick). Its edges
## are worked out once per frame, so a second read() in the same frame sees the same move.
## Every press answers (docs/press-answers.md): `other` holds the player who pressed a button the
## menus have no use for (X, Y, LB, RB, LT, RT, the stick clicks, Select, Start), or -1, and
## `button` names it ("x", "lt", "select", ...). The screen decides: refuse() it, or leave it to
## its owner (Start in pause is Game's resume, Select in the solo lobby switches podium).
class_name MenuInput
extends RefCounted

const DPAD := {
	JOY_BUTTON_DPAD_UP: Vector2i(0, -1), JOY_BUTTON_DPAD_DOWN: Vector2i(0, 1),
	JOY_BUTTON_DPAD_LEFT: Vector2i(-1, 0), JOY_BUTTON_DPAD_RIGHT: Vector2i(1, 0),
}

## Buttons the menus never use, by name. Guide is the system's, never read.
const OTHER := {
	JOY_BUTTON_X: "x", JOY_BUTTON_Y: "y",
	JOY_BUTTON_LEFT_SHOULDER: "lb", JOY_BUTTON_RIGHT_SHOULDER: "rb",
	JOY_BUTTON_LEFT_STICK: "l3", JOY_BUTTON_RIGHT_STICK: "r3",
	JOY_BUTTON_BACK: "select", JOY_BUTTON_START: "start",
}
const TRIGGERS := { JOY_AXIS_TRIGGER_LEFT: "lt", JOY_AXIS_TRIGGER_RIGHT: "rt" }
## A trigger counts once per pull: past PULL, and again only after it falls back under RELEASE.
const PULL := 0.6
const RELEASE := 0.3
## The soft refusal. The template plays `honk` (a game's honk.ogg, else a synth stand-in); Junk Yard
## Zap has no honk.ogg and keeps every menu cue a designed file, so its menus say the yard's own
## refusal, "nope" (nope_1/2.ogg, the zapper's refused press, R-05): one "no" sound for the game.
const REFUSE_CUE := "nope"

static var _held := {}          # device -> Vector2i the D-pad held last frame it was read
static var _frame := -1
static var _edge := {}          # player -> this frame's D-pad move (new presses only)
static var _other_last := [-1, ""]   # this frame's unused-button press (a second read() sees it too)
static var _other_down := {}   # [device, button or axis name] -> held at the last read
static var _other_frame := -1
static var _joined_before := []   # devices joined at the last read (a join press is not a refusal)
## Refusals so far, and the last one's button (tests read these).
static var refusals := 0
static var last_refused := ""


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
	var other := _other()
	return { "move": move, "a": a, "b": b, "other": other[0], "button": other[1] }


## The soft refusal for a press that does nothing here: the honk and a wobble on `item` (the
## focused bar or icon; anything with wobble()). Every screen in the kit calls this, and a game's
## own menu can too.
static func refuse(item: Object = null, button := "") -> void:
	UiSound.play(REFUSE_CUE)
	if item != null and is_instance_valid(item) and item.has_method("wobble"):
		item.wobble()
	refusals += 1
	last_refused = button


## Is this press someone else's to answer? Start while the game is paused is Game's resume.
static func owned_elsewhere(input: Dictionary) -> bool:
	return input.get("button", "") == "start" and Game.state == Game.State.PAUSED


## [player, name] of the first unused button pressed since the last read, or [-1, ""].
## After a gap (the menu was not reading), it only takes stock: a button already held when a menu
## opens (a trigger held through Start) is not a press.
static func _other() -> Array:
	var frame := Engine.get_process_frames()
	if frame == _other_frame:
		return _other_last.duplicate()
	var fresh := frame - _other_frame <= 1
	_other_frame = frame
	var owner := {}   # device -> player
	for p in Players.active_players():
		var d := Players.device_of(p)
		if d >= 0:
			owner[d] = p
	for p in Players.active_players():
		if Players.device_of(p) == Players.VIRTUAL:
			for d in Input.get_connected_joypads():
				if not owner.has(d):
					owner[d] = p
	var found := [-1, ""]
	var devices: Array = owner.keys()
	for d in Input.get_connected_joypads():
		if not d in devices:
			devices.append(d)
	for d in devices:
		for button in OTHER:
			var key := [d, button]
			var held := Input.is_joy_button_pressed(d, button)
			if held and not _other_down.get(key, false) and fresh and found[0] == -1 \
					and owner.has(d) and d in _joined_before and not _solo_hold(d, button):
				found = [owner[d], OTHER[button]]
			_other_down[key] = held
		for axis in TRIGGERS:
			var key := [d, TRIGGERS[axis]]
			var v := Input.get_joy_axis(d, axis)
			var was: bool = _other_down.get(key, false)
			var held := v > PULL or (was and v > RELEASE)
			if held and not was and fresh and found[0] == -1 and owner.has(d) and d in _joined_before:
				found = [owner[d], TRIGGERS[axis]]
			_other_down[key] = held
	_joined_before = owner.keys()
	_other_last = found
	return found.duplicate()


## Select with Start held (or Start with Select held) is the solo toggle's hold (Players).
static func _solo_hold(device: int, button: int) -> bool:
	if button == JOY_BUTTON_BACK:
		return Input.is_joy_button_pressed(device, JOY_BUTTON_START)
	if button == JOY_BUTTON_START:
		return Input.is_joy_button_pressed(device, JOY_BUTTON_BACK)
	return false


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
