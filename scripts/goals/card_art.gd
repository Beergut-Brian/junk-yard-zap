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

## PT10-3: the gun that does each pictured card (its token sits in the card's header).
## &"" = no gun (the chain reaction: knock it with things, never a zap).
const GUN_FOR := {
	&"b1_tiny_car": &"size", &"b1_tiny_tractor": &"size", &"b1_magnet_fridge": &"magnet",
	&"b1_pig_in_pond": &"grab", &"b1_sheep_to_gate": &"grab", &"b2_tub_from_loft": &"grab",
	&"b2_three_in_tub": &"grab", &"b2_chicken_stairs": &"freeze", &"b2_duck_on_tower": &"grab",
	&"b2_egg_off_loft": &"grab", &"b2_stack_three": &"grab", &"b2_car_over_fence": &"grab",
	&"b3_tractor_loft": &"grab", &"b3_fast_duck": &"bouncy", &"b3_cow_over_tower": &"balloon",
	&"b3_stack_five": &"grab", &"b3_cannonball_pond": &"grab", &"b3_piano_pipe_pond": &"size",
	&"b3_raft": &"glue", &"b3_chain_ball": &"",
}

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


## The gun id (or effect id) whose token goes in g's header.
static func gun_for(g: GoalData) -> StringName:
	if g == null:
		return &""
	if GUN_FOR.has(g.id):
		return GUN_FOR[g.id]
	match g.condition:
		GoalData.Condition.OBJECT_SCALE_AT_LEAST, GoalData.Condition.OBJECT_SCALE_AT_MOST:
			return &"size"
		GoalData.Condition.OBJECT_HAS_EFFECT:
			return &"size" if g.effect == &"grow" or g.effect == &"shrink" else g.effect
		GoalData.Condition.GLUED_PAIR:
			return &"glue"
		GoalData.Condition.OBJECT_IN_ZONE, GoalData.Condition.STACK_HEIGHT, GoalData.Condition.OBJECT_HEIGHT_ABOVE:
			return &"grab"
	return &""


## True when draw_goal can draw g from its condition alone (no baked picture needed).
static func handles(g: GoalData) -> bool:
	return g.condition in [GoalData.Condition.OBJECT_SCALE_AT_LEAST, GoalData.Condition.OBJECT_SCALE_AT_MOST,
			GoalData.Condition.OBJECT_HAS_EFFECT, GoalData.Condition.OBJECT_IN_ZONE, GoalData.Condition.GLUED_PAIR]


## PT10-3: any card's picture, live and crisp at any size: the hand-drawn idea for the pictured
## cards, else the objects and the result from its condition (cow + car = joined, small -> big, ...).
static func draw_goal(ci: CanvasItem, g: GoalData, r: Rect2, guns: Dictionary) -> void:
	if CARDS.has(g.id):
		draw(ci, g.id, g.band, r, guns)
		return
	_ci = ci
	_m = r.get_center()
	_s = r.size.x * 0.16
	_guns = guns
	var subj := _who(g.subject, g, 0)
	match g.condition:
		GoalData.Condition.OBJECT_SCALE_AT_LEAST:
			thing(subj, P(-1.75, 1.0), 0.45)
			arrow(P(-1.05, 0.75), P(-0.2, 0.75), 0.14)
			thing(subj, P(1.15, 0.35), 1.15 if g.amount < 3.0 else 1.3)
			_grow_marks(P(1.15, 0.35), 2.0)
		GoalData.Condition.OBJECT_SCALE_AT_MOST:
			_shrink(subj)
		GoalData.Condition.OBJECT_HAS_EFFECT:
			_effect(subj, g.effect)
		GoalData.Condition.OBJECT_IN_ZONE:
			_into(subj, g.other)
		GoalData.Condition.GLUED_PAIR:
			var b := _who(g.other, g, 1)
			thing(subj, P(-1.45, -1.25), 0.5)
			_plus(P(0, -1.25))
			thing(b, P(1.45, -1.25), 0.5)
			arrow(P(0, -0.65), P(0, -0.05), 0.12)
			thing(subj, P(-0.95, 1.15), 0.68)
			thing(b, P(0.95, 1.15), 0.68)
			GunIcons.blob(_ci, P(0, 0.75), _s * 0.22, _s * 0.07)
		_:
			thing(subj, _m, 1.0)


## "any" on a card means: the first hinted object, else a crate.
static func _who(id: StringName, g: GoalData, i: int) -> StringName:
	if id != &"any" and id != &"":
		return id
	if g.hint_objects.size() > i:
		return StringName(String(g.hint_objects[i]).trim_suffix("_2"))
	return &"crate"


static func _effect(subj: StringName, effect: StringName) -> void:
	match effect:
		&"freeze":
			thing(subj, P(0, 0.5), 1.0)
			var box := Rect2(P(-2.0, -1.1), V(4.0, 3.0))
			_ci.draw_rect(box, Color(0.86, 0.97, 1.0, 0.55))
			_ci.draw_rect(box, INK, false, _s * 0.07)
			_line(box.position + V(0.4, 1.0), box.position + V(1.0, 0.4), Color.WHITE, 0.12)
			_line(box.position + V(0.4, 1.8), box.position + V(1.8, 0.4), Color(1, 1, 1, 0.7), 0.08)
			GunIcons.flake(_ci, P(1.9, -1.2), _s * 0.55, _s * 0.08)
		&"balloon":
			var at := P(0, 1.1)
			balloon(P(0, -1.5), 1.3)
			_line(P(0, -0.5), at - V(0, 0.5), INK, 0.05)
			thing(subj, at, 1.0)
			arrow(P(-2.1, 1.0), P(-2.1, -0.6), 0.14)
			arrow(P(2.1, 1.0), P(2.1, -0.6), 0.14)
		&"bouncy":
			_line(P(-2.6, 1.95), P(2.6, 1.95), INK, 0.1)
			for i in 12:
				var t := (i + 0.5) / 13.0
				var x := lerpf(-2.4, 1.0, t)
				var y := 1.6 - absf(sin(t * PI * 2.0)) * (1.6 + t * 1.3)
				_ci.draw_circle(P(x, y), _s * 0.11, INK)
			thing(subj, P(1.3, -1.3), 0.7)
			_ci.draw_line(P(-1.6, 1.98), P(-0.9, 1.98), Color(1, 0.85, 0.2), _s * 0.14, true)
		&"magnet":
			thing(subj, P(1.0, 0.4), 0.8)
			GunIcons.horseshoe(_ci, P(-1.6, 0.4), _s * 0.75, _s * 0.08)
			for i in 2:
				_ci.draw_arc(P(-0.7 + i * 0.55, 0.4), _s * 0.8, -0.7, 0.7, 10, INK, _s * 0.1, true)
		_:
			thing(subj, P(0, 0.6), 1.0)
			gun(effect, P(0, -1.6), 0.8)


static func _into(subj: StringName, other: StringName) -> void:
	match other:
		&"pond":
			water(Rect2(P(-2.6, 1.0), V(5.2, 1.5)))
		&"barn":
			barn(Rect2(P(-1.2, -0.2), V(2.4, 2.4)))
		_:
			if COLORS.has(other) or Pictos.OBJ_COLORS.has(other):
				thing(other, P(0, 1.35), 1.4)
			else:   # a spot in the yard: a dashed target box
				var box := Rect2(P(-1.4, 0.5), V(2.8, 1.8))
				_ci.draw_rect(box, Color(1, 1, 1, 0.35))
				for e in [[box.position, Vector2(box.end.x, box.position.y)], [Vector2(box.end.x, box.position.y), box.end],
						[box.end, Vector2(box.position.x, box.end.y)], [Vector2(box.position.x, box.end.y), box.position]]:
					_ci.draw_dashed_line(e[0], e[1], INK, _s * 0.1, _s * 0.3, true)
	thing(subj, P(0, -1.55), 0.75)
	arrow(P(0, -0.7), P(0, 0.3), 0.14)


static func _plus(at: Vector2) -> void:
	_line(at - V(0.38, 0), at + V(0.38, 0), INK, 0.17)
	_line(at - V(0, 0.38), at + V(0, 0.38), INK, 0.17)


## Little corner brackets bursting out round a grown thing.
static func _grow_marks(at: Vector2, size: float) -> void:
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector2 = at + c * _s * size * 0.85
		_ci.draw_line(p, p - Vector2(c.x, 0) * _s * 0.4, INK, _s * 0.1, true)
		_ci.draw_line(p, p - Vector2(0, c.y) * _s * 0.4, INK, _s * 0.1, true)


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


## A yard object with a face (vehicles and machines without one). New silhouettes here; the rest come from Pictos.object.
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
			return   # vehicles and machines never wear a face
		&"tractor":
			_ci.draw_rect(Rect2(m + Vector2(-s * 1.1, -s * 0.2), Vector2(s * 2.0, s * 0.6)), c)
			_ci.draw_rect(Rect2(m + Vector2(-s * 1.0, -s * 1.0), Vector2(s * 0.8, s * 0.8)), c.darkened(0.1))
			_ci.draw_rect(Rect2(m + Vector2(-s * 0.9, -s * 0.9), Vector2(s * 0.6, s * 0.45)), SKY)
			_ci.draw_rect(Rect2(m + Vector2(s * 0.5, -s * 0.75), Vector2(s * 0.14, s * 0.55)), INK)
			_ci.draw_circle(m + Vector2(-s * 0.6, s * 0.45), s * 0.55, INK)
			_ci.draw_circle(m + Vector2(-s * 0.6, s * 0.45), s * 0.22, c)
			_ci.draw_circle(m + Vector2(s * 0.65, s * 0.6), s * 0.35, INK)
			return
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
			return
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
