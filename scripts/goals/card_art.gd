## Card pictures for the goal deck, in the Pictos style (scenes/ui/hud/pictos.gd: flat shapes, ink
## faces, gun icons, fat arrows), for cards whose idea a plain condition pictogram can't show (the
## loft, the pipe, a stack taller than the barn). No words anywhere: every picture must read at the
## HUD corner size (220 px). Baked to assets/sprites/goals/<id>.png by scripts/goals/bake_card_art.gd;
## GoalData.picture points at the PNG and Pictos.card draws it inside the card frame.
class_name CardArt
extends RefCounted

const INK := Pictos.INK
const SKY := Color(0.62, 0.84, 0.95)
const WATER := Color(0.25, 0.55, 0.9)
const WOOD := Color(0.6, 0.38, 0.2)
const METAL := Color(0.55, 0.58, 0.62)
const BARN := Color(0.25, 0.6, 0.6)
const BAND := Color(0.9, 0.55, 0.1)
const COLORS := {
	&"car": Color(0.35, 0.5, 0.75), &"pig": Color(0.95, 0.66, 0.66), &"sheep": Color(0.99, 0.97, 0.92),
	&"tractor": Color(0.88, 0.65, 0.23), &"piano": Color(0.25, 0.17, 0.15), &"fridge": Color(0.93, 0.95, 0.97),
	&"egg": Color(0.99, 0.94, 0.8), &"crate": Color(0.8, 0.6, 0.35), &"cannonball": Color(0.25, 0.25, 0.3),
	&"tire": Color(0.2, 0.2, 0.22),
}

## Card ids that have a baked picture.
const CARDS: Array[StringName] = [
	&"b1_tiny_car", &"b1_magnet_fridge", &"b1_pig_in_pond", &"b1_sheep_to_gate", &"b1_tiny_tractor",
	&"b2_tub_from_loft", &"b2_three_in_tub", &"b2_chicken_stairs", &"b2_duck_on_tower", &"b2_egg_off_loft",
	&"b2_stack_three", &"b2_car_over_fence",
	&"b3_tractor_loft", &"b3_fast_duck", &"b3_cow_over_tower", &"b3_stack_five", &"b3_cannonball_pond",
	&"b3_piano_pipe_pond", &"b3_raft", &"b3_chain_ball",
]

static var _ci: CanvasItem
static var _m := Vector2.ZERO
static var _s := 1.0
static var _guns := {}


## Draw card `id`'s picture into r (transparent background; the card frame is Pictos.card's).
static func draw(ci: CanvasItem, id: StringName, band: int, r: Rect2, guns: Dictionary) -> void:
	_ci = ci
	_m = r.get_center()
	_s = r.size.x * 0.16
	_guns = guns
	match id:
		&"b1_tiny_car": _shrink(&"car")
		&"b1_tiny_tractor": _shrink(&"tractor")
		&"b1_magnet_fridge":
			thing(&"fridge", P(0, 0.9), 1.0)
			gun(&"magnet", P(0, -1.6), 0.8)
		&"b1_pig_in_pond":
			water(Rect2(P(-2.6, 0.9), V(5.2, 1.7)))
			thing(&"pig", P(0, -1.5), 0.7)
			arrow(P(0, -0.7), P(0, 0.6))
		&"b1_sheep_to_gate":
			fence(-2.6, -1.6, 1.4, 4)
			thing(&"sheep", P(1.4, 0.6), 0.8)
			arrow(P(0.4, 0.6), P(-0.6, 0.6))
		&"b2_tub_from_loft":
			loft(Rect2(P(-2.6, -1.1), V(2.6, 0.35)))
			thing(&"ball", P(-1.6, -1.7), 0.6)
			dotted_arc(P(-0.9, -1.7), P(1.4, 0.5), -1.6)
			thing(&"bathtub", P(1.4, 1.5), 1.0)
		&"b2_three_in_tub":
			arrow(P(0, -2.4), P(0, -1.1))
			for i in 3:
				thing([&"ball", &"duck", &"crate"][i], P(-0.8 + i * 0.8, 1.05), 0.45)
			thing(&"bathtub", P(0, 1.1), 1.3)
		&"b2_chicken_stairs":
			for i in 3:
				var c := P(-1.6 + i * 1.4, 1.3 - i * 1.0)
				thing(&"chicken", c, 0.5)
				_ci.draw_arc(c + V(0.1, -0.15), _s * 0.62, 0, TAU, 24, Effects.COLORS[&"freeze"], _s * 0.12, true)
			gun(&"freeze", P(-1.7, -1.6), 0.55)
		&"b2_duck_on_tower":
			tower(P(0.6, 2.3), 4.0)
			thing(&"duck", P(0.7, -2.15), 0.7)
			arrow(P(-1.9, 1.6), P(-1.9, -1.4))
		&"b2_egg_off_loft":
			loft(Rect2(P(-0.6, -0.9), V(3.2, 0.35)))
			thing(&"egg", P(1.6, 1.75), 0.6)
			arrow(P(1.6, -0.5), P(1.6, 1.1))
			thing(&"crate", P(-1.6, -1.5), 0.45)
			_speed_lines(P(-2.2, -1.5), 0.6)
			_star_hit(P(-0.8, -1.4))
		&"b2_stack_three":
			barn(Rect2(P(0.5, -0.8), V(2.1, 2.8)))
			for i in 3:
				thing(&"crate", P(-1.3, 1.45 - i * 1.25), 0.62)
			_line(P(-2.6, -1.95), P(2.6, -1.95), Color(BAND, 0.9), 0.08, true)
		&"b2_car_over_fence":
			fence(-0.5, 0.0, 1.0, 3)
			dotted_arc(P(-2.4, 1.6), P(2.2, 1.6), -3.0)
			thing(&"car", P(0.0, -1.7), 0.6)
		&"b3_tractor_loft":
			loft(Rect2(P(-1.0, -0.2), V(3.6, 0.35)))
			thing(&"tractor", P(0.8, -0.9), 0.6)
			arrow(P(-2.0, 2.0), P(-2.0, -0.6))
		&"b3_fast_duck":
			thing(&"duck", P(1.0, 0), 0.9)
			_speed_lines(P(-0.4, 0), 2.0)
		&"b3_cow_over_tower":
			tower(P(1.5, 2.3), 2.6)
			balloon(P(-0.6, -2.0), 0.8)
			thing(&"cow", P(-0.5, -0.9), 0.8)
			arrow(P(-2.2, 1.6), P(-2.2, -0.6))
		&"b3_stack_five":
			for i in 5:
				thing([&"crate", &"tire", &"crate", &"pig", &"chicken"][i], P(0, 2.1 - i * 1.0), 0.55)
		&"b3_cannonball_pond":
			tower(P(1.9, 2.3), 3.0)
			thing(&"cannonball", P(1.6, -1.25), 0.55)
			dotted_arc(P(1.1, -1.2), P(-1.5, 1.0), -1.4)
			water(Rect2(P(-2.6, 1.3), V(3.0, 1.2)))
		&"b3_piano_pipe_pond":
			tower(P(2.0, 2.3), 3.2)
			pipe(P(1.6, -1.2), P(-0.8, 0.6))
			thing(&"piano", P(1.75, -1.9), 0.6)
			arrow(P(0.2, -0.6), P(-0.6, 0.0), 0.08)
			arrow(P(-1.1, 0.9), P(-1.6, 1.3), 0.08)
			water(Rect2(P(-2.6, 1.6), V(2.6, 0.9)))
		&"b3_raft":
			water(Rect2(P(-2.6, 1.5), V(5.2, 1.0)))
			thing(&"cow", P(-0.9, 0.3), 0.6)
			thing(&"car", P(1.0, 0.45), 0.6)
			_ci.draw_circle(P(0.05, 0.4), _s * 0.25, Effects.COLORS[&"glue"])
			balloon(P(0, -1.3), 0.8)
		&"b3_chain_ball":
			loft(Rect2(P(-0.6, -0.8), V(3.2, 0.35)))
			thing(&"tire", P(-1.9, -1.6), 0.45)
			_speed_lines(P(-2.5, -1.6), 0.5)
			_star_hit(P(-1.1, -1.4))
			thing(&"ball", P(1.6, 1.9), 0.4)
			arrow(P(1.6, -0.4), P(1.6, 1.2))
			_no_gun(P(-1.4, 1.2))
	for i in band:
		_ci.draw_circle(r.position + Vector2(r.size.x * (0.06 + i * 0.1), r.size.y * 0.05), r.size.x * 0.035, BAND)


# ----------------------------------------------------------------------------- the card ideas

static func _shrink(id: StringName) -> void:
	thing(id, P(-1.0, 0.1), 1.0)
	arrow(P(0.3, 0.5), P(1.2, 0.5))
	thing(id, P(1.9, 0.7), 0.4)


static func _speed_lines(at: Vector2, length: float) -> void:
	for i in 3:
		var y := (i - 1) * 0.35
		_line(at + V(-length, y), at + V(0, y), INK, 0.09)


static func _star_hit(at: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		pts.append(at + Vector2.from_angle(i * TAU / 14) * _s * (0.45 if i % 2 == 0 else 0.22))
	_ci.draw_colored_polygon(pts, Color(1, 0.85, 0.2))


## A gun icon with a red "no" ring: the chain reaction rule (knock it with things, not with a zap).
static func _no_gun(at: Vector2) -> void:
	gun(&"size", at, 0.55)
	_ci.draw_arc(at, _s * 0.62, 0, TAU, 24, Color(0.85, 0.15, 0.1), _s * 0.13, true)
	_line(at + V(-0.42, -0.42), at + V(0.42, 0.42), Color(0.85, 0.15, 0.1), 0.13)


# ------------------------------------------------------------------------------- the pieces

## Where things go, in card units from the middle (one unit = r.size.x * 0.16, as in Pictos).
static func P(x: float, y: float) -> Vector2:
	return _m + Vector2(x, y) * _s


static func V(x: float, y: float) -> Vector2:
	return Vector2(x, y) * _s


static func _line(a: Vector2, b: Vector2, c: Color, w: float, dashed := false) -> void:
	if dashed:
		_ci.draw_dashed_line(a, b, c, _s * w, _s * 0.3, true, true)
	else:
		_ci.draw_line(a, b, c, _s * w, true)


static func arrow(from: Vector2, to: Vector2, w := 0.12) -> void:
	Pictos._arrow(_ci, from, to, INK, _s * w)


## A dotted throw arc with an arrow head (bulge: how far it rises, negative is up).
static func dotted_arc(from: Vector2, to: Vector2, bulge: float) -> void:
	var mid := (from + to) * 0.5 + Vector2(0, bulge * _s)
	var last := from
	for i in range(1, 11):
		var t := i / 10.0
		var p := from.lerp(mid, t).lerp(mid.lerp(to, t), t)
		if i < 10:
			_ci.draw_circle(p, _s * 0.09, INK)
		last = p
	var prev := from.lerp(mid, 0.9).lerp(mid.lerp(to, 0.9), 0.9)
	Pictos._arrow(_ci, prev, last, INK, _s * 0.1)


static func gun(effect: StringName, at: Vector2, size: float) -> void:
	var g: GunData = _guns.get(effect)
	if g:
		Pictos.gun_icon(_ci, g, Rect2(at - V(size, size), V(size, size) * 2.0))


static func water(r: Rect2) -> void:
	_ci.draw_rect(r, WATER)
	var pts := PackedVector2Array()
	for i in 13:
		pts.append(Vector2(r.position.x + r.size.x * i / 12.0, r.position.y + (0.0 if i % 2 == 0 else -_s * 0.18)))
	pts.append(r.position + Vector2(r.size.x, _s * 0.2))
	pts.append(r.position + Vector2(0, _s * 0.2))
	_ci.draw_colored_polygon(pts, WATER)
	_line(r.position + V(0.4, 0.5), r.position + V(1.0, 0.5), Color(1, 1, 1, 0.6), 0.08)


static func loft(r: Rect2) -> void:
	_ci.draw_rect(r, WOOD)
	_ci.draw_rect(r, INK, false, _s * 0.06)
	for x in [r.position.x + _s * 0.2, r.end.x - _s * 0.4]:
		_ci.draw_rect(Rect2(Vector2(x, r.end.y), Vector2(_s * 0.2, _s * 3.0)), WOOD.darkened(0.25))


## Fence posts from x (card units) for `n` posts, ground at y + h.
static func fence(x: float, y: float, h: float, n: int) -> void:
	for i in n:
		var px := x + i * 0.4
		_ci.draw_rect(Rect2(P(px, y), V(0.28, h * 2.0)), WOOD)
		_ci.draw_colored_polygon(PackedVector2Array([P(px, y), P(px + 0.14, y - 0.25), P(px + 0.28, y)]), WOOD)
	_ci.draw_rect(Rect2(P(x - 0.1, y + h * 0.5), V(n * 0.4, 0.2)), WOOD.darkened(0.2))
	_ci.draw_rect(Rect2(P(x - 0.1, y + h * 1.4), V(n * 0.4, 0.2)), WOOD.darkened(0.2))


static func barn(r: Rect2) -> void:
	_ci.draw_rect(r, BARN)
	var roof := PackedVector2Array([r.position + Vector2(-_s * 0.2, 0), r.position + Vector2(r.size.x * 0.5, -r.size.x * 0.45), r.position + Vector2(r.size.x + _s * 0.2, 0)])
	_ci.draw_colored_polygon(roof, Color(0.7, 0.35, 0.2))
	var door := Rect2(r.position + Vector2(r.size.x * 0.25, r.size.y * 0.45), Vector2(r.size.x * 0.5, r.size.y * 0.55))
	_ci.draw_rect(door, Color(0.98, 0.93, 0.8))
	_line(door.position, door.end, BARN, 0.1)
	_line(Vector2(door.end.x, door.position.y), Vector2(door.position.x, door.end.y), BARN, 0.1)


## A junk tower: a post and platforms going up from base (bottom middle), h card units tall.
static func tower(base: Vector2, h: float) -> void:
	_ci.draw_rect(Rect2(base + V(-0.15, -h), V(0.3, h)), METAL.darkened(0.2))
	var n := int(h / 1.1) + 1
	for i in n:
		var y := -h + i * 1.1
		var off := 0.3 if i % 2 == 0 else -0.3
		_ci.draw_rect(Rect2(base + V(-0.9 + off, y), V(1.8, 0.25)), METAL)
		_ci.draw_rect(Rect2(base + V(-0.9 + off, y), V(1.8, 0.25)), INK, false, _s * 0.04)


static func pipe(a: Vector2, b: Vector2) -> void:
	_ci.draw_line(a, b, INK, _s * 0.95, true)
	_ci.draw_line(a, b, METAL.lightened(0.2), _s * 0.75, true)
	for t in [0.25, 0.5, 0.75]:
		var p := a.lerp(b, t)
		var n := (b - a).normalized().orthogonal() * _s * 0.45
		_ci.draw_line(p - n, p + n, METAL.darkened(0.3), _s * 0.08, true)


static func balloon(at: Vector2, size: float) -> void:
	_ci.draw_line(at, at + V(0, size * 1.0), INK, _s * 0.05, true)
	_ci.draw_circle(at - V(0, size * 0.4), _s * size * 0.55, Effects.COLORS[&"balloon"])
	_ci.draw_circle(at - V(size * 0.18, size * 0.6), _s * size * 0.13, Color(1, 1, 1, 0.6))


## A yard object with a face. New silhouettes here; the rest come from Pictos.object.
static func thing(id: StringName, m: Vector2, size: float) -> void:
	var s := _s * size
	var c: Color = COLORS.get(id, Color.WHITE)
	var ow := maxf(2.0, s * 0.07)
	var face := m
	var fs := s * 0.55
	match id:
		&"car":
			var body := Rect2(m + Vector2(-s * 1.2, -s * 0.2), Vector2(s * 2.4, s * 0.7))
			var cab := Rect2(m + Vector2(-s * 0.6, -s * 0.75), Vector2(s * 1.2, s * 0.6))
			_ci.draw_rect(cab, c)
			_ci.draw_rect(Rect2(cab.position + Vector2(s * 0.12, s * 0.1), Vector2(s * 0.42, s * 0.4)), SKY)
			_ci.draw_rect(body, c)
			for x in [-0.7, 0.7]:
				_ci.draw_circle(m + Vector2(s * x, s * 0.55), s * 0.32, INK)
				_ci.draw_circle(m + Vector2(s * x, s * 0.55), s * 0.13, METAL)
			face = m + Vector2(s * 0.75, s * 0.1)
			fs = s * 0.5
		&"tractor":
			_ci.draw_rect(Rect2(m + Vector2(-s * 1.1, -s * 0.2), Vector2(s * 2.0, s * 0.6)), c)
			_ci.draw_rect(Rect2(m + Vector2(-s * 1.0, -s * 1.0), Vector2(s * 0.8, s * 0.8)), c.darkened(0.1))
			_ci.draw_rect(Rect2(m + Vector2(-s * 0.9, -s * 0.9), Vector2(s * 0.6, s * 0.45)), SKY)
			_ci.draw_rect(Rect2(m + Vector2(s * 0.5, -s * 0.75), Vector2(s * 0.14, s * 0.55)), INK)
			_ci.draw_circle(m + Vector2(-s * 0.6, s * 0.45), s * 0.55, INK)
			_ci.draw_circle(m + Vector2(-s * 0.6, s * 0.45), s * 0.22, c)
			_ci.draw_circle(m + Vector2(s * 0.65, s * 0.6), s * 0.35, INK)
			face = m + Vector2(s * 0.35, s * 0.05)
			fs = s * 0.45
		&"pig":
			_ci.draw_circle(m, s * 0.75, c)
			_ci.draw_circle(m + Vector2(s * 0.75, -s * 0.25), s * 0.5, c)
			for x in [-0.45, 0.35]:
				_ci.draw_rect(Rect2(m + Vector2(s * x, s * 0.5), Vector2(s * 0.2, s * 0.4)), c)
			_ci.draw_colored_polygon(PackedVector2Array([m + Vector2(s * 0.45, -s * 0.6), m + Vector2(s * 0.6, -s * 0.95), m + Vector2(s * 0.75, -s * 0.65)]), c.darkened(0.15))
			_ci.draw_circle(m + Vector2(s * 1.18, -s * 0.15), s * 0.2, c.darkened(0.15))
			_ci.draw_arc(m + Vector2(-s * 0.85, -s * 0.1), s * 0.15, 0, PI * 1.5, 8, c.darkened(0.3), ow, true)
			face = m + Vector2(s * 0.75, -s * 0.35)
			fs = s * 0.45
		&"sheep":
			for p in [Vector2(-0.5, 0), Vector2(0, -0.3), Vector2(0.4, 0), Vector2(0, 0.25), Vector2(-0.3, -0.25)]:
				_ci.draw_circle(m + p * s, s * 0.45, c)
			for p in [Vector2(-0.5, 0), Vector2(0, -0.3), Vector2(0.4, 0), Vector2(0, 0.25), Vector2(-0.3, -0.25)]:
				_ci.draw_arc(m + p * s, s * 0.45, 0, TAU, 16, Color(INK, 0.25), ow * 0.6, true)
			for x in [-0.45, 0.3]:
				_ci.draw_rect(Rect2(m + Vector2(s * x, s * 0.5), Vector2(s * 0.16, s * 0.4)), INK)
			_ci.draw_circle(m + Vector2(s * 0.9, -s * 0.2), s * 0.38, Color(0.3, 0.25, 0.25))
			face = m + Vector2(s * 0.95, -s * 0.2)
			fs = s * 0.4
			_eyes(face, fs, Color.WHITE)
			return
		&"piano":
			_ci.draw_rect(Rect2(m + Vector2(-s * 1.0, -s * 0.8), Vector2(s * 2.0, s * 1.4)), c)
			_ci.draw_rect(Rect2(m + Vector2(-s * 1.0, -s * 0.05), Vector2(s * 2.0, s * 0.3)), Color.WHITE)
			for i in 7:
				_ci.draw_rect(Rect2(m + Vector2(-s * 0.9 + i * s * 0.28, -s * 0.05), Vector2(s * 0.12, s * 0.18)), INK)
			for x in [-0.9, 0.75]:
				_ci.draw_rect(Rect2(m + Vector2(s * x, s * 0.6), Vector2(s * 0.15, s * 0.3)), c)
			face = m + Vector2(0, -s * 0.45)
			fs = s * 0.5
			_eyes(face, fs, Color.WHITE)
			return
		&"fridge":
			var r := Rect2(m + Vector2(-s * 0.6, -s * 1.1), Vector2(s * 1.2, s * 2.2))
			_ci.draw_rect(r, c)
			_ci.draw_rect(r, INK, false, ow)
			_ci.draw_line(m + Vector2(-s * 0.6, -s * 0.35), m + Vector2(s * 0.6, -s * 0.35), INK, ow, true)
			_ci.draw_rect(Rect2(m + Vector2(s * 0.35, -s * 0.85), Vector2(s * 0.1, s * 0.35)), METAL)
			face = m + Vector2(0, s * 0.3)
		&"egg":
			var pts := PackedVector2Array()
			for i in 24:
				var a := i * TAU / 24
				pts.append(m + Vector2(cos(a) * s * 0.6, sin(a) * s * (0.8 if sin(a) < 0 else 0.65)))
			_ci.draw_colored_polygon(pts, c)
			pts.append(pts[0])
			_ci.draw_polyline(pts, INK, ow, true)
			face = m + Vector2(0, s * 0.05)
			fs = s * 0.6
		&"crate":
			var r := Rect2(m - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5)
			_ci.draw_rect(r, c)
			_ci.draw_rect(r, c.darkened(0.35), false, s * 0.12)
			_ci.draw_line(r.position, r.end, c.darkened(0.25), s * 0.1, true)
			face = m + Vector2(0, s * 0.1)
		&"cannonball":
			_ci.draw_circle(m, s * 0.7, c)
			_ci.draw_circle(m + Vector2(-s * 0.25, -s * 0.3), s * 0.14, Color(1, 1, 1, 0.5))
			_eyes(m, s * 0.6, Color.WHITE)
			return
		&"tire":
			_ci.draw_circle(m, s * 0.75, c)
			_ci.draw_circle(m, s * 0.3, METAL)
			_eyes(m + Vector2(0, -s * 0.45), s * 0.5, Color.WHITE)
			return
		&"cow":   # Pictos' cow, with an ink edge and patches so white reads on the cream card
			var c2: Color = Pictos.OBJ_COLORS[&"cow"]
			_ci.draw_rect(Rect2(m + Vector2(-s, -s * 0.5), Vector2(s * 1.6, s)).grow(ow), INK)
			_ci.draw_rect(Rect2(m + Vector2(s * 0.5, -s * 0.85), Vector2(s * 0.6, s * 0.65)).grow(ow), INK)
			for x in [-0.85, -0.3, 0.2, 0.45]:
				_ci.draw_rect(Rect2(m + Vector2(s * x, s * 0.5), Vector2(s * 0.16, s * 0.4)).grow(ow), INK)
			Pictos.object(_ci, id, m, s)
			_ci.draw_circle(m + Vector2(s * 0.1, s * 0.15), s * 0.25, Color(0.55, 0.35, 0.2))
			_ci.draw_rect(Rect2(m + Vector2(s * 0.62, -s * 0.38), Vector2(s * 0.36, s * 0.16)), Color(0.95, 0.7, 0.75))
			return
		&"chicken":   # white too: an ink edge behind Pictos' chicken
			_ci.draw_circle(m, s * 0.7 + ow, INK)
			_ci.draw_circle(m + Vector2(s * 0.45, -s * 0.6), s * 0.38 + ow, INK)
			Pictos.object(_ci, id, m, s)
			return
		_:
			Pictos.object(_ci, id, m, s)
			return
	_eyes(face, fs, INK)
	_ci.draw_arc(face + Vector2(0, fs * 0.05), fs * 0.25, 0.3, PI - 0.3, 8, INK, maxf(2.0, fs * 0.07), true)


static func _eyes(face: Vector2, fs: float, c: Color) -> void:
	_ci.draw_circle(face + Vector2(-fs * 0.25, -fs * 0.15), fs * 0.11, c)
	_ci.draw_circle(face + Vector2(fs * 0.25, -fs * 0.15), fs * 0.11, c)
