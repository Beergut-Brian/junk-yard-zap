## The in-game HUD, pictures only (no reading in gameplay): the current goal card small in the top
## corner, the gun wheel that pops for half a second around a player who cycles guns, each player's
## current gun in their colour in the bottom corners, arrows to off-screen players, the Reset Yard
## hold ring, and who the pad drives in solo mode. Systems owns the structure, Art the look.
class_name Hud
extends Control

const WHEEL_TIME := 0.6
const CARD_SIZE := 220.0

var level: YardLevel
var camera: CameraRig
var _wheel := {}        # player -> seconds left
var _card_pop := 0.0
var _done_flash := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func attach(p_level: YardLevel, p_camera: CameraRig) -> void:
	level = p_level
	camera = p_camera
	level.deck.card_changed.connect(func(_g: GoalData) -> void: _card_pop = 0.35)
	level.goal_completed.connect(func(_id: StringName) -> void: _done_flash = 1.2)


func show_wheel(player: int) -> void:
	_wheel[player] = WHEEL_TIME


func _process(delta: float) -> void:
	visible = Game.state == Game.State.PLAYING or Game.state == Game.State.PAUSED
	for p in _wheel.keys():
		_wheel[p] -= delta
		if _wheel[p] <= 0.0:
			_wheel.erase(p)
	_card_pop = maxf(0.0, _card_pop - delta)
	_done_flash = maxf(0.0, _done_flash - delta)
	queue_redraw()


func zappers() -> Array:
	return get_tree().get_nodes_in_group(Zapper.GROUP)


func _draw() -> void:
	if level == null or camera == null or not camera.is_inside_tree():
		return
	var vs := get_viewport_rect().size
	# Goal card, top right.
	var s := CARD_SIZE * (1.0 + _card_pop * 0.6)
	var r := Rect2(Vector2(vs.x - UiStyle.SAFE.x - s, UiStyle.SAFE.y), Vector2(s, s))
	if _done_flash > 0.0:
		draw_rect(r.grow(14.0), Color(1, 0.85, 0.2, _done_flash / 1.2))
	Pictos.card(self, level.deck.current(), r, level.guns_by_effect)
	for i in level.deck.done.size():   # the done pile: a stamp per card
		draw_circle(Vector2(r.position.x - 30 - (i % 5) * 34, r.position.y + 24 + (i / 5) * 34), 13, Color(1, 0.8, 0.2))
	for zn in zappers():
		var z := zn as Zapper
		if z.asleep or z.gun() == null:
			continue
		var col: Color = Players.COLOR[z.player]
		# Current gun, bottom corner in the player's colour.
		var corner := Vector2(UiStyle.SAFE.x + 60, vs.y - UiStyle.SAFE.y - 60) if z.player == Players.P1 \
				else Vector2(vs.x - UiStyle.SAFE.x - 60, vs.y - UiStyle.SAFE.y - 60)
		draw_circle(corner, 58, col)
		draw_circle(corner, 50, Color(0.12, 0.1, 0.1, 0.85))
		Pictos.gun_icon(self, z.gun(), Rect2(corner - Vector2(36, 36), Vector2(72, 72)))
		var head := z.global_position + Vector3(0, Zapper.HEIGHT + 0.6, 0)
		if not camera.sees(z.global_position + Vector3(0, 0.8, 0)):
			_arrow_to(z.global_position + Vector3(0, 0.8, 0), col)
			continue
		var at := camera.unproject_position(head)
		if Players.solo and Players.solo_focus == z.player:
			draw_colored_polygon(PackedVector2Array([at + Vector2(-16, -30), at + Vector2(16, -30), at + Vector2(0, -6)]), col)
		if _wheel.has(z.player):
			_draw_wheel(z, at + Vector2(0, -120), col)
	# Reset Yard hold ring.
	var prog := level.reset_progress()
	if prog > 0.0:
		var c := camera.unproject_position(level.reset_sign.global_position + Vector3(0, 1.75, 0))
		draw_arc(c, 70, -PI / 2, -PI / 2 + TAU * prog, 48, Color(1, 0.95, 0.6), 14, true)


func _draw_wheel(z: Zapper, at: Vector2, col: Color) -> void:
	var n := z.guns.size()
	var t := clampf(_wheel[z.player] / WHEEL_TIME, 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - minf(1.0, (1.0 - t) * 6.0), 3.0)
	var rad := 110.0 * grow
	draw_circle(at, rad + 52, Color(0.1, 0.08, 0.08, 0.55 * grow))
	for i in n:
		var k := posmod(i - z.gun_index, n)
		var ang := -PI / 2 + TAU * k / n
		var p := at + Vector2.from_angle(ang) * rad
		var big := k == 0
		var sz := 74.0 if big else 46.0
		if big:
			draw_circle(p, sz * 0.62, col)
		draw_circle(p, sz * 0.52, Color(0.15, 0.12, 0.12, 0.9))
		Pictos.gun_icon(self, z.guns[i], Rect2(p - Vector2(sz, sz) * 0.36, Vector2(sz, sz) * 0.72), 1.0 if big else 0.7)


## An arrow at the screen edge in the player's colour, pointing at them.
func _arrow_to(p: Vector3, col: Color) -> void:
	var vs := get_viewport_rect().size
	var centre := vs * 0.5
	var s := camera.unproject_position(p)
	if camera.is_position_behind(p):
		s = centre + (centre - s)
	var d := (s - centre)
	if d.length() < 1.0:
		return
	d = d.normalized()
	var m := Vector2(vs.x * 0.5 - 90, vs.y * 0.5 - 90)
	var k := minf(m.x / maxf(absf(d.x), 0.001), m.y / maxf(absf(d.y), 0.001))
	var tip := centre + d * k
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([tip + d * 30, tip - d * 26 + n * 30, tip - d * 26 - n * 30]), col)
	draw_circle(tip - d * 40, 22, col)
