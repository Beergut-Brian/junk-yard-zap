## The question before New yard or Restore old yard (FreshStart): a card over the menu where A must be
## HELD while a ring fills (HOLD s); letting go early empties it again, and B keeps the yard as it is.
## The A that opened the card never counts: A has to come up first. A menu, so text and glyphs are
## fine (docs/kid-design.md, "Menus are for grown-ups"); every press still has a sound.
## The lobby owns one, over its Settings; it reads MenuInput like the other cards.
## Every press answers (docs/press-answers.md): the stick or D-pad (nothing to move between here) and
## every other button (X, Y, shoulders, triggers, stick clicks, Select, Start) refuse: the soft
## refusal sound and the card shakes. Nothing else changes: the ring keeps its fill, the question stays.
class_name FreshCard
extends Control

signal confirmed(kind: Ask)
signal cancelled(kind: Ask)

enum Ask { NONE, NEW, RESTORE }

const HOLD := 1.5
const TICK := 0.25            # a rising tick this often while A is held
const CARD := Vector2(1080, 520)
const TEXT := {
	Ask.NEW: ["START A NEW YARD?", "Your yard now is kept as a backup.",
			"Settings > Restore old yard brings it back.", "[a] Hold: new yard    [b] Keep my yard"],
	Ask.RESTORE: ["RESTORE YOUR OLD YARD?", "The yard from before New yard comes back.",
			"The yard you have now is kept as a backup too.", "[a] Hold: restore    [b] Keep this yard"],
}

var active := false
var ask := Ask.NONE
var hold := 0.0
var _armed := false
var _tick := 0.0
var _pop := 0.0
var _wob := 0.0      # refusal shake, 1 (just refused) .. 0 (still)
var _tw_wob: Tween
## How many times the card shook (tests read it).
var wobbles := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open(kind: Ask) -> void:
	ask = kind
	active = true
	visible = true
	hold = 0.0
	_tick = 0.0
	_armed = false
	_pop = 1.0
	UiSound.play("ui_confirm")
	queue_redraw()


func dismiss() -> void:
	active = false
	visible = false
	ask = Ask.NONE


func cancel() -> void:
	if not active:
		return
	var k := ask
	dismiss()
	UiSound.play("ui_back")
	cancelled.emit(k)


## One frame. a_down: is any joined player's A held (the lobby passes it; tests too).
func step(delta: float, input: Dictionary, a_down: bool) -> void:
	if not active:
		return
	_pop = maxf(0.0, _pop - delta * 4.0)
	queue_redraw()
	if input.b != -1:
		cancel()
		return
	if input.move != Vector2i.ZERO:
		MenuInput.refuse(self, "left" if input.move.x < 0 else "right" if input.move.x > 0 \
				else "up" if input.move.y < 0 else "down")
	elif input.get("other", -1) != -1 and not MenuInput.owned_elsewhere(input):
		MenuInput.refuse(self, input.button)
	if not _armed:
		_armed = not a_down   # the press that opened the card does not count
		return
	if not a_down:
		if hold > 0.0:
			hold = 0.0
			UiSound.play("ui_back")   # let go early: the ring empties, nothing happens
		return
	if hold == 0.0:
		_tick = TICK
		UiSound.play("ui_tick", 0.8)
	hold += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		UiSound.play("ui_tick", 0.8 + 0.6 * progress())
	if hold >= HOLD:
		var k := ask
		dismiss()
		UiSound.play("ui_confirm")
		confirmed.emit(k)


## The refusal (MenuInput.refuse()): the card shakes side to side three times, fading out.
func wobble() -> void:
	wobbles += 1
	if not is_inside_tree():
		return
	if _tw_wob:
		_tw_wob.kill()
	_tw_wob = create_tween()
	_tw_wob.tween_method(_set_wob, 1.0, 0.0, MenuItem.WOBBLE_TIME)


## Screenshots: hold the shake at `v` (1 just refused .. 0 still).
func pose_wobble(v: float) -> void:
	if _tw_wob:
		_tw_wob.kill()
	_set_wob(v)


func is_wobbling() -> bool:
	return _wob > 0.0


func _set_wob(v: float) -> void:
	_wob = v
	queue_redraw()


func progress() -> float:
	return clampf(hold / HOLD, 0.0, 1.0)


func _draw() -> void:
	if not active:
		return
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var sc := 1.0 + 0.04 * _pop
	var sz := CARD * sc
	var shake := sin((1.0 - _wob) * TAU * 3.0) * MenuItem.WOBBLE_PX * _wob
	var r := Rect2((vs - sz) * 0.5 + Vector2(shake, 0.0), sz)
	UiStyle.para(self, r.grow(10.0), UiStyle.skin().accent)
	UiStyle.para(self, r, UiStyle.INK_SHOW)
	var lines: Array = TEXT.get(ask, TEXT[Ask.NEW])
	var cx := r.get_center().x
	UiStyle.draw_show(self, Vector2(cx, r.position.y + 80.0), lines[0], 68, UiStyle.CREAM, 1)
	UiStyle.draw_rich(self, Vector2(cx, r.position.y + 160.0), lines[1], UiStyle.Role.BODY, Color(UiStyle.CREAM, 0.85), 1, 34)
	UiStyle.draw_rich(self, Vector2(cx, r.position.y + 206.0), lines[2], UiStyle.Role.BODY, Color(UiStyle.CREAM, 0.7), 1, 30)
	# The hold ring, the A glyph in the middle.
	var c := Vector2(cx, r.position.y + 330.0)
	draw_arc(c, 62.0, 0.0, TAU, 48, Color(UiStyle.CREAM, 0.18), 14.0, true)
	if hold > 0.0:
		draw_arc(c, 62.0, -PI * 0.5, -PI * 0.5 + TAU * progress(), 48, UiStyle.skin().accent, 14.0, true)
	UiStyle.draw_glyph(self, c, 64.0, "a")
	UiStyle.draw_rich(self, Vector2(cx, r.end.y - 50.0), lines[3], UiStyle.Role.HINT, Color(UiStyle.CREAM, 0.8), 1, 30)
