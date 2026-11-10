## The trophy shelf (G-13): every goal card on one wooden shelf. Finished cards show their picture with
## a gold star stamp, in the order he finished them; the rest of the deck follows as dark silhouettes
## (cards still to win). Opened by zapping the done pile on the front fence (TrophyPile). No text:
## the stick flips left and right (it stops at the ends with a boing), A looks at a card up close,
## A or B puts it back, B closes the shelf. The yard holds still while it is open.
class_name TrophyShelf
extends CanvasLayer

signal opened()
signal closed()
signal flipped(index: int)

const CARD := 360.0           # px, a card on the shelf at scale 1
const FOCUS_SCALE := 1.0
const SIDE_SCALE := 0.6
const CLOSE_SCALE := 2.2      # up close: about 800 px tall on a 1080 screen
const GAP := 250.0            # px between card centres beside the focused one
const SHOW_SIDE := 2          # cards drawn each side of the focused one
const REPEAT_FIRST := 0.4     # s before a held stick starts repeating
const REPEAT_EVERY := 0.22
const DEMO_CLOSE := 4.0       # --demo: a bot's zap opens it for this long, then it closes itself
const PAPER := Color(0.98, 0.95, 0.86)
const WOOD := Color(0.62, 0.38, 0.2)
const WOOD_DARK := Color(0.42, 0.24, 0.12)
const GOLD := Color(1.0, 0.8, 0.2)

const SILHOUETTE_CODE := """
shader_type canvas_item;
uniform vec3 paper = vec3(0.98, 0.95, 0.86);
void fragment() {
	vec4 c = COLOR;
	float bg = step(distance(c.rgb, paper), 0.12);
	COLOR = vec4(mix(vec3(0.16, 0.13, 0.2), vec3(0.5, 0.46, 0.44), bg), c.a);
}
"""

var deck: GoalDeck
var guns_by_effect := {}
var is_open := false
var up_close := false
var focus := 0
## Who opened it (their colour rings the focused card); -1 = nobody.
var opener := -1
## Tests drive it by calling flip/look/back; the pads are read only when this is on.
var read_pads := true
var _entries: Array = []      # [{id, done}]
var _cards: Array[TrophyCard] = []
var _root: Control
var _back: Control
var _row: Control
var _front: Control           # the focus ring and the arrows, over the cards and their shader
var _closing := false
var _hold := 0.0
var _hold_dir := 0
var _bump := 0.0              # wobble left on the end card after a stop
var _demo_left := 0.0
var _t := 0.0
static var _silhouette: Shader


## One card on the shelf. Draws the goal card (Pictos.card) and, when finished, a gold star stamp.
class TrophyCard extends Control:
	var goal: GoalData
	var done := false
	var guns := {}

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(size.x * 0.03, size.y * 0.04), r.size), Color(0, 0, 0, 0.3))
		Pictos.card(self, goal, r, guns)
		if done:
			TrophyShelf.star(self, r.position + Vector2(size.x * 0.86, size.y * 0.14), size.x * 0.13, GOLD)


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _silhouette == null:
		_silhouette = Shader.new()
		_silhouette.code = SILHOUETTE_CODE
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 0.0
	add_child(_root)
	_back = Control.new()
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.draw.connect(_draw_back)
	_root.add_child(_back)
	_row = Control.new()
	_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_row)
	_front = Control.new()
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	_root.add_child(_front)
	visible = false
	Game.state_changed.connect(func(_from: int, to: int) -> void:
		if is_open and to != Game.State.PLAYING:
			_shut(false))


# ------------------------------------------------------------------------------------------ data

## The shelf, left to right: finished cards in the order he finished them, then the cards still in
## the stack (top first) as silhouettes. Each entry is {"id": StringName, "done": bool}.
static func entries_for(d: GoalDeck) -> Array:
	var out := []
	if d == null:
		return out
	for id in d.done:
		out.append({"id": id, "done": true})
	for id in d.order:
		if not d.done.has(id):
			out.append({"id": id, "done": false})
	return out


func entries() -> Array:
	return _entries


func finished_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for e in _entries:
		if e.done:
			out.append(e.id)
	return out


func focused() -> Dictionary:
	return _entries[focus] if focus >= 0 and focus < _entries.size() else {}


func card_node(i: int) -> TrophyCard:
	return _cards[i] if i >= 0 and i < _cards.size() else null


# ---------------------------------------------------------------------------------------- open/close

func open(player := -1) -> void:
	if is_open:
		return
	is_open = true
	_closing = false
	up_close = false
	opener = player
	_rebuild()
	var n_done := finished_ids().size()
	focus = maxi(0, n_done - 1)   # his newest trophy
	visible = true
	if is_inside_tree():
		get_tree().paused = true
	_demo_left = DEMO_CLOSE if Game.demo and not _pinned() else 0.0
	_hold_dir = 0
	_layout(true)
	Audio.play("card_view")
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(_row, "position:y", 0.0, 0.3).from(220.0) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	opened.emit()


## B: put a close-up card back, else close the shelf.
func back() -> void:
	if not is_open:
		return
	if up_close:
		look()
	else:
		close()


func close() -> void:
	if is_open:
		Audio.play("drop")
		_shut(true)


## Hides the shelf. The yard restarts once every button is let go, so the B that closed the
## shelf doesn't also make someone jump.
func _shut(resume: bool) -> void:
	is_open = false
	up_close = false
	_closing = resume
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func() -> void:
		if not is_open:
			visible = false)
	if not resume:
		_closing = false
	closed.emit()


# ------------------------------------------------------------------------------------------- flip

## Move the focus one card; stops at the ends (a boing and a wobble). Returns true if it moved.
func flip(dir: int) -> bool:
	if not is_open or up_close or dir == 0 or _entries.is_empty():
		return false
	var to := focus + signi(dir)
	if to < 0 or to >= _entries.size():
		Audio.play("boing")
		_bump = 0.35 * signi(dir)
		return false
	focus = to
	Audio.play("wheel_move")
	_layout(false)
	flipped.emit(focus)
	return true


## A: the focused card comes up close (and A again puts it back).
func look() -> void:
	if not is_open or _entries.is_empty():
		return
	up_close = not up_close
	if up_close:
		Audio.play("card_view")
		if _entries[focus].done:
			Audio.play("sparkle")
	else:
		Audio.play("gun_cycle")
	_layout(false)


# ------------------------------------------------------------------------------------------ layout

func _rebuild() -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	_entries = entries_for(deck)
	for e in _entries:
		var c := TrophyCard.new()
		c.goal = deck.cards.get(e.id)
		c.done = e.done
		c.guns = guns_by_effect
		c.size = Vector2(CARD, CARD)
		c.pivot_offset = c.size * 0.5
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not e.done:
			var m := ShaderMaterial.new()
			m.shader = _silhouette
			c.material = m
		_row.add_child(c)
		_cards.append(c)


func _screen() -> Vector2:
	return _root.get_viewport_rect().size if _root.is_inside_tree() else Vector2(1920, 1080)


func _shelf_y() -> float:
	return _screen().y * 0.56


## Where card i sits for the current focus: [centre, scale, alpha].
func slot(i: int) -> Array:
	var s := _screen()
	var d := i - focus
	var centre := Vector2(s.x * 0.5 + d * GAP + signf(d) * (CARD * (FOCUS_SCALE - SIDE_SCALE) * 0.5), _shelf_y() - CARD * 0.5)
	var sc := FOCUS_SCALE if d == 0 else SIDE_SCALE
	centre.y = _shelf_y() - CARD * sc * 0.5
	var a := 1.0 if absi(d) <= SHOW_SIDE else 0.0
	if up_close:
		if d == 0:
			return [Vector2(s.x * 0.5, s.y * 0.5), CLOSE_SCALE, 1.0]
		a *= 0.25
	return [centre, sc, a]


func _layout(snap: bool) -> void:
	for i in _cards.size():
		var c := _cards[i]
		var t := slot(i)
		var pos: Vector2 = t[0] - c.size * 0.5
		var sc := Vector2.ONE * float(t[1])
		c.z_index = 10 if i == focus else 0
		if snap:
			c.position = pos
			c.scale = sc
			c.modulate.a = t[2]
		else:
			var tw := c.create_tween().set_parallel()
			tw.tween_property(c, "position", pos, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "scale", sc, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "modulate:a", t[2], 0.15)
	_back.queue_redraw()


# ------------------------------------------------------------------------------------------- input

func _process(delta: float) -> void:
	_t += delta
	if _closing:
		if not _any_button():
			_closing = false
			if Game.state != Game.State.PAUSED and is_inside_tree():   # the pause menu keeps it held
				get_tree().paused = false
		return
	if not is_open:
		return
	if is_inside_tree() and not get_tree().paused:   # something else (restart) let the yard go
		_shut(false)
		return
	if _bump != 0.0:
		var c := card_node(focus)
		_bump = move_toward(_bump, 0.0, delta)
		if c:
			c.rotation = sin(_t * 40.0) * _bump * 0.4
	elif card_node(focus):
		card_node(focus).rotation = 0.0
	_back.queue_redraw()
	_front.queue_redraw()
	if _demo_left > 0.0:
		_demo_left -= delta
		if _demo_left <= 0.0:
			close()
			return
	if read_pads:
		_read_pads(delta)


func _read_pads(delta: float) -> void:
	var dir := 0
	for p in [Players.P1, Players.P2]:
		var x := Players.move_vector(p).x
		if absf(x) > 0.5:
			dir = signi(int(signf(x)))
		if Input.is_action_just_pressed(Players.action(p, "action")):
			look()
		elif Input.is_action_just_pressed(Players.action(p, "jump")):
			back()
			return
	if dir == 0:
		_hold_dir = 0
	elif dir != _hold_dir:
		_hold_dir = dir
		_hold = REPEAT_FIRST
		flip(dir)
	else:
		_hold -= delta
		if _hold <= 0.0:
			_hold = REPEAT_EVERY
			flip(dir)


func _any_button() -> bool:
	for p in [Players.P1, Players.P2]:
		if Input.is_action_pressed(Players.action(p, "action")) or Input.is_action_pressed(Players.action(p, "jump")):
			return true
	return false


func _pinned() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shelf="):
			return true
	return false


# -------------------------------------------------------------------------------------------- draw

func _draw_back() -> void:
	var s := _screen()
	_back.draw_rect(Rect2(Vector2.ZERO, s), Color(0.08, 0.06, 0.1, 0.78))
	var y := _shelf_y()
	var lift := _row.position.y
	# The shelf: a thick plank with brackets, cards stand on it.
	var plank := Rect2(Vector2(s.x * 0.04, y + lift), Vector2(s.x * 0.92, 44))
	_back.draw_rect(plank, WOOD)
	_back.draw_rect(Rect2(plank.position, Vector2(plank.size.x, 10)), WOOD.lightened(0.25))
	_back.draw_rect(Rect2(plank.position + Vector2(0, plank.size.y), Vector2(plank.size.x, 12)), WOOD_DARK)
	for bx in [0.14, 0.86]:
		var b := Vector2(s.x * bx, y + lift + plank.size.y + 12)
		_back.draw_colored_polygon(PackedVector2Array([b + Vector2(-22, 0), b + Vector2(22, 0), b + Vector2(-22, 90)]), WOOD_DARK)
	# Trophy count, as pictures: one pip per card in the deck, gold when finished, the focused one big.
	var n := _entries.size()
	if n > 0:
		var pip := minf(34.0, (s.x * 0.8) / n)
		var x0 := s.x * 0.5 - pip * n * 0.5 + pip * 0.5
		var py := y + lift + 150
		for i in n:
			var c := Vector2(x0 + i * pip, py)
			var rr := pip * (0.42 if i == focus else 0.26)
			if _entries[i].done:
				star(_back, c, rr * 1.3, GOLD)
			else:
				_back.draw_circle(c, rr, Color(0.45, 0.42, 0.45))
			if i == focus:
				_back.draw_arc(c, rr * 1.6, 0, TAU, 24, Color.WHITE, 3.0)
	if up_close:
		_back.draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.04, 0.08, 0.6))
		if not _entries.is_empty() and _entries[focus].done:   # sunburst behind a trophy
			var m := s * 0.5
			for k in 16:
				var a := _t * 0.3 + k * TAU / 16.0
				var w := 0.09
				_back.draw_colored_polygon(PackedVector2Array([m, m + Vector2.from_angle(a - w) * s.x, m + Vector2.from_angle(a + w) * s.x]),
						Color(1.0, 0.85, 0.3, 0.16))
		return


func _draw_front() -> void:
	if up_close or _entries.is_empty():
		return
	var s := _screen()
	var n := _entries.size()
	var c := card_node(focus)
	if c:   # the opener's colour around the focused card
		var r := Rect2(c.position + c.size * 0.5 - c.size * c.scale * 0.5, c.size * c.scale).grow(16.0)
		_front.draw_set_transform(r.get_center(), c.rotation)
		_front.draw_rect(Rect2(-r.size * 0.5, r.size), Players.COLOR.get(opener, Color.WHITE), false, 12.0)
		_front.draw_set_transform(Vector2.ZERO)
	# Big bobbing arrows: there are more cards that way.
	var y := _shelf_y()
	var lift := _row.position.y
	var bob := sin(_t * 5.0) * 10.0
	var ay := y - CARD * 0.5 + lift
	if focus > 0:
		_arrow(Vector2(s.x * 0.035 - bob, ay), -1)
	if focus < n - 1:
		_arrow(Vector2(s.x * 0.965 + bob, ay), 1)


func _arrow(at: Vector2, dir: int) -> void:
	var d := float(dir)
	var pts := PackedVector2Array([at + Vector2(d * 34, 0), at + Vector2(-d * 22, -46), at + Vector2(-d * 22, 46)])
	_front.draw_colored_polygon(pts, Color(1, 1, 1, 0.9))


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var rad := r if k % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI * 0.5 + k * PI / 5.0) * rad)
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, col.darkened(0.4), maxf(1.5, r * 0.08))
