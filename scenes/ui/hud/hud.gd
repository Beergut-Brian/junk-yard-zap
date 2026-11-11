## The in-game HUD, pictures only (no reading in gameplay): the current goal card small in the top
## corner, the gun wheel that pops for half a second around a player who cycles guns, each player's
## current gun in their colour in the bottom corners, arrows to off-screen players, the Reset Yard
## hold rings (by a player holding Select, and on the sign), and who the pad drives in solo mode. Systems owns the structure, Art the look.
class_name Hud
extends Control

const WHEEL_TIME := GunWheel.PREVIEW_TIME
const CARD_SIZE := 220.0
const BEAT_TIME := 1.1   # PT10-2: the first-fire beat

var level: YardLevel
var camera: CameraRig
var _wheel := {}        # player -> seconds since the last flick (while the wheel/preview shows)
var _wheel_from := {}   # player -> the gun index before the last flick (the ring spins from it)
var _last_gun := {}     # player -> the gun index we last saw
var _badge_age := {}    # player -> seconds since their corner badge changed
## PT10-2: the first time each player fires each gun this session gets a beat.
var fired := {}         # "player:gun" -> true
var _beats := []        # [{player, gun: GunData, age}]
## PT10-3: the corner card's events. "done": the gold stamp slams on, confetti, then it flips to
## the next card. "skip": it spins off with the skip stamp and the next one drops in. "flip": a new
## card turns over (any other change).
const CARD_DONE := 1.4
const CARD_SKIP := 0.65
const CARD_FLIP := 0.3
var card_mode := ""
var _card: GoalData        # the card on show
var _card_next: GoalData
var _card_t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func attach(p_level: YardLevel, p_camera: CameraRig) -> void:
	level = p_level
	camera = p_camera
	_card = level.deck.current()
	_card_next = _card
	level.deck.goal_completed.connect(func(id: StringName) -> void: _card_event("done", id))
	level.deck.goal_skipped.connect(func(id: StringName) -> void: _card_event("skip", id))
	level.deck.card_changed.connect(func(g: GoalData) -> void:
		_card_next = g
		if card_mode == "" and g != _card:
			card_mode = "flip"
			_card_t = 0.0)


func _card_event(mode: String, id: StringName) -> void:
	_card = level.deck.cards.get(id, _card)
	card_mode = mode
	_card_t = 0.0


func show_wheel(player: int) -> void:
	var z := _zapper(player)
	var idx := z.gun_index if z else 0
	var was: int = _last_gun.get(player, idx)
	# A second flick while the ring is still turning spins on from where it shows now.
	_wheel_from[player] = was
	_last_gun[player] = idx
	_wheel[player] = 0.0
	_badge_age[player] = 0.0


func wheel_showing(player: int) -> bool:
	return _wheel.has(player)


## PT10-2: the first time `player` fires `gun` this session: a beat (the token stamps over them,
## a colour flash at the screen edge, a camera punch and its own sound). Later zaps of that gun: none.
func on_zapped(player: int, gun_id: StringName, _target: Node3D) -> bool:
	var key := "%d:%s" % [player, gun_id]
	if fired.has(key) or _target == null:   # a zap at nothing doesn't use up the beat
		return false
	fired[key] = true
	var z := _zapper(player)
	var g: GunData = z.gun() if z and z.gun() and z.gun().id == gun_id else null
	if g == null:
		return false
	_beats.append({"player": player, "gun": g, "age": 0.0})
	_wheel.erase(player)   # the beat takes the wheel's place over the player
	Audio.play("card_view")       # a bright page-flip tick under the gun's own zap: "new thing!"
	Audio.play("sparkle")
	Fx.shake(0.18)
	if camera:
		var tw := camera.create_tween()
		tw.tween_property(camera, "fov", 31.5, 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(camera, "fov", 34.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true


func _zapper(player: int) -> Zapper:
	for zn in zappers():
		if (zn as Zapper).player == player:
			return zn
	return null


## For the UI sheet (scripts/tools/ui_sheet.gd): a wheel, fully open, mid-preview.
func draw_wheel_at(ci: CanvasItem, guns: Array, index: int, at: Vector2, col: Color, age: float) -> void:
	GunWheel.draw(ci, guns, index, index, at, col, age * 0.6)


func _process(delta: float) -> void:
	visible = Game.state == Game.State.PLAYING or Game.state == Game.State.PAUSED
	for p in _wheel.keys():
		_wheel[p] += delta
		if _wheel[p] >= WHEEL_TIME:
			_wheel.erase(p)
	for p in _badge_age.keys():
		_badge_age[p] += delta
	for b in _beats:
		b["age"] += delta
	_beats = _beats.filter(func(b: Dictionary) -> bool: return b["age"] < BEAT_TIME)
	if card_mode != "":
		_card_t += delta
		var length: float = {"done": CARD_DONE, "skip": CARD_SKIP, "flip": CARD_FLIP}[card_mode]
		if _card_t >= length:
			card_mode = ""
			_card = _card_next
	queue_redraw()


func zappers() -> Array:
	return get_tree().get_nodes_in_group(Zapper.GROUP)


func _draw() -> void:
	if level == null or camera == null or not camera.is_inside_tree():
		return
	var vs := get_viewport_rect().size
	# Goal card, top right.
	var s := CARD_SIZE
	var r := Rect2(Vector2(vs.x - UiStyle.SAFE.x - s, UiStyle.SAFE.y), Vector2(s, s))
	_draw_card_event(r)
	for i in level.deck.done.size():   # the done pile: a gold star per card
		var at := Vector2(r.position.x - 34 - (i % 5) * 38, r.position.y + 26 + (i / 5) * 38)
		Pictos._star(self, at, 18.0, GunIcons.INK)
		Pictos._star(self, at, 14.0, Pictos.GOLD)
	for zn in zappers():
		var z := zn as Zapper
		if z.asleep or z.gun() == null:
			continue
		var col: Color = Players.COLOR[z.player]
		# Current gun, bottom corner in the player's colour.
		var corner := Vector2(UiStyle.SAFE.x + 60, vs.y - UiStyle.SAFE.y - 60) if z.player == Players.P1 \
				else Vector2(vs.x - UiStyle.SAFE.x - 60, vs.y - UiStyle.SAFE.y - 60)
		GunWheel.badge(self, z.gun(), corner, col, _badge_age.get(z.player, 9.0))
		var head := z.global_position + Vector3(0, Zapper.HEIGHT + 0.6, 0)
		if not camera.sees(z.global_position + Vector3(0, 0.8, 0)):
			_arrow_to(z.global_position + Vector3(0, 0.8, 0), col)
			continue
		var at := camera.unproject_position(head)
		if Players.solo and Players.solo_focus == z.player:
			draw_colored_polygon(PackedVector2Array([at + Vector2(-16, -30), at + Vector2(16, -30), at + Vector2(0, -6)]), col)
		if _wheel.has(z.player):
			GunWheel.draw(self, z.guns, z.gun_index, _wheel_from.get(z.player, z.gun_index), at + Vector2(0, -150), col, _wheel[z.player])
		elif z.reset_progress() > 0.0:
			draw_reset_ring(at + Vector2(0, -78), z.reset_progress(), col)
		for b in _beats:
			if b["player"] == z.player:
				_draw_beat(b, at + Vector2(0, -110), vs)
	# Reset Yard hold ring on the sign (hold A on it).
	var prog := level.reset_progress()
	if prog > 0.0:
		var c := camera.unproject_position(level.reset_sign.global_position + Vector3(0, YardLevel.SIGN_Y, 0))
		draw_reset_ring(c, prog, Color(1, 0.86, 0.3), 1.5)


## The Select-hold ring by a player: a dark badge with the "start again" swirl that winds up as a
## ring in the player's colour fills; it swells as it nears full so the last moment feels big.
func draw_reset_ring(c: Vector2, prog: float, col: Color, size := 1.0) -> void:
	var k := size * (1.0 + 0.22 * prog * prog)
	var r := 54.0 * k
	draw_circle(c, r + 12.0 * k, Color(0.13, 0.08, 0.06, 0.82))
	draw_arc(c, r, 0, TAU, 48, Color(UiStyle.CREAM, 0.35), 13.0 * k, true)
	draw_arc(c, r, -PI / 2, -PI / 2 + TAU * prog, 48, col, 15.0 * k, true)
	draw_circle(c + Vector2.from_angle(-PI / 2 + TAU * prog) * r, 10.0 * k, Color.WHITE)
	UiGlyphs.reset_swirl(self, c, r * 0.72, UiStyle.CREAM.lerp(col, prog * 0.5), prog * TAU * 0.5)


## The corner card and its events (see CARD_DONE / CARD_SKIP / CARD_FLIP).
func _draw_card_event(r: Rect2) -> void:
	var guns := level.guns_by_effect
	var c := r.get_center()
	var t := _card_t
	match card_mode:
		"done":
			if t < CARD_DONE - CARD_FLIP:
				var glow := 0.5 + 0.5 * sin(t * 14.0)
				Pictos._rrect(self, r.grow(10.0 + glow * 8.0), Color(Pictos.GOLD, 0.75), r.size.x * 0.12)
				var pop := 1.0 + 0.12 * exp(-t * 6.0) * sin(t * 30.0)
				_card_at(_card, c, pop, 0.0, 1.0, guns)
				Pictos.card_stamp(self, r, true, t / 0.22)
				_confetti(r, t)
			else:
				_flip(r, (t - (CARD_DONE - CARD_FLIP)) / CARD_FLIP, _card, _card_next, true)
		"skip":
			if t < 0.35:
				var k := t / 0.35
				var at := c + Vector2(k * k * 260.0, -sin(k * PI) * 60.0)
				_card_at(_card, at, 1.0 - k * 0.3, k * k * 2.5, 1.0 - k * 0.6, guns)
				draw_set_transform(at, k * k * 2.5, Vector2.ONE * (1.0 - k * 0.3))
				Pictos.card_stamp(self, Rect2(-r.size * 0.5, r.size), false, k / 0.4)
				draw_set_transform(Vector2.ZERO)
				for i in 5:   # the raspberry: little puffs blown out of the card
					var d := Vector2.from_angle(PI * (0.7 + i * 0.15))
					draw_circle(c + d * (r.size.x * 0.5 + k * 90.0), 10.0 * (1.0 - k) + 3.0, Color(1, 1, 1, 1.0 - k))
			else:
				var k := (t - 0.35) / (CARD_SKIP - 0.35)
				var drop := 1.0 - GunIcons._back(k)
				_card_at(_card_next, c + Vector2(0, -drop * 180.0), 1.0, 0.0, minf(1.0, k * 3.0), guns)
		"flip":
			_flip(r, t / CARD_FLIP, _card, _card_next, false)
		_:
			Pictos.card(self, _card, r, guns)


func _card_at(g: GoalData, c: Vector2, scale: float, rot: float, alpha: float, guns: Dictionary, sx := 1.0) -> void:
	draw_set_transform(c, rot, Vector2(scale * sx, scale))
	Pictos.card(self, g, Rect2(Vector2(-CARD_SIZE, -CARD_SIZE) * 0.5, Vector2(CARD_SIZE, CARD_SIZE)), guns, alpha)
	draw_set_transform(Vector2.ZERO)


## Turn the card over from a to b (k 0..1), squashing it on its vertical axis.
func _flip(r: Rect2, k: float, a: GoalData, b: GoalData, stamped: bool) -> void:
	k = clampf(k, 0.0, 1.0)
	var sx := absf(cos(k * PI))
	var g := a if k < 0.5 else b
	_card_at(g, r.get_center(), 1.0 + 0.08 * sin(k * PI), 0.0, 1.0, level.guns_by_effect, maxf(sx, 0.02))
	if stamped and k < 0.5:
		draw_set_transform(r.get_center(), 0.0, Vector2(maxf(sx, 0.02), 1.0))
		Pictos.card_stamp(self, Rect2(-r.size * 0.5, r.size), true, 1.0)
		draw_set_transform(Vector2.ZERO)


## Paper confetti falling from the card (never green or red: those are the players').
func _confetti(r: Rect2, t: float) -> void:
	var cols := [Pictos.GOLD, Color("#4fd8ff"), Color("#ec3cf0"), Color("#ff9a14"), Color("#7e52ff"), Color.WHITE]
	for i in 26:
		var seed_x := fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var seed_v := fposmod(sin(i * 78.233) * 12345.678, 1.0)
		var p := Vector2(r.position.x + seed_x * r.size.x, r.get_center().y)
		p += Vector2((seed_x - 0.5) * 300.0 * t, -260.0 * (0.6 + seed_v) * t + 520.0 * t * t)
		var rot := t * (6.0 + seed_v * 8.0) + i
		draw_set_transform(p, rot, Vector2(1.0, absf(cos(t * 8.0 + i))))
		draw_rect(Rect2(-7, -4, 14, 8), cols[i % cols.size()])
	draw_set_transform(Vector2.ZERO)


## The first-fire beat: the gun's token stamps down big over the player with rays in its colour,
## and the screen edge flashes that colour.
func _draw_beat(b: Dictionary, at: Vector2, vs: Vector2) -> void:
	var g: GunData = b["gun"]
	var age: float = b["age"]
	var k := age / BEAT_TIME
	var col := g.beam_color
	var edge := (1.0 - k) * 0.55
	for i in 6:   # edge flash, thick to thin
		var w := 28.0 - i * 4.0
		draw_rect(Rect2(Vector2(w, w) * 0.5 + Vector2(i, i) * 6.0, vs - Vector2(w, w) - Vector2(i, i) * 12.0), Color(col, edge * (1.0 - i / 6.0)), false, w)
	var stamp := GunIcons._back(age / 0.22) * lerpf(1.0, 0.85, k)
	var r := 78.0 * stamp
	var fade := 1.0 - clampf((age - BEAT_TIME + 0.25) / 0.25, 0.0, 1.0)
	for i in 12:   # rays
		var d := Vector2.from_angle(TAU * i / 12.0 + age * 1.5)
		draw_line(at + d * (r + 10.0), at + d * (r + 30.0 + 50.0 * minf(1.0, age * 4.0)), Color(col.lightened(0.3), fade), 10.0, true)
	draw_circle(at, r + 12.0, Color(GunIcons.INK, fade))
	draw_circle(at, r + 8.0, Color(1, 1, 1, fade))
	Pictos.gun_preview(self, g, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), clampf(age / (BEAT_TIME * 0.8), 0.0, 1.0), fade)


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
