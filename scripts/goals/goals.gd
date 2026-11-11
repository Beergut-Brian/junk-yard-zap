## The goal-card checker (GAME.md contract: Goals.check(goal) -> bool). Static; it never changes the
## yard. It reads the yard's objects (the PhysicsObject group), the condition vocabulary in GoalData
## (docs/contracts.md "Goal conditions") and, for touches and sequences, the deck's GoalMemory.
class_name Goals
extends RefCounted

## Card spots: small boxes around landmarks, copied from YardLevel._build (x from, y from, x to, y to;
## the full depth of the yard). tests/test_goal_deck.gd checks them against the real landmarks.
const SPOTS := {
	&"barn_loft": Rect2(23.0, 3.9, 6.5, 4.6),      # the hayloft floor (Loft, top at y 4.2) and above it
	&"pipe_top": Rect2(37.2, 6.0, 3.4, 3.2),       # the tower end of the pipe, by the middle deck
	&"pipe_bottom": Rect2(30.6, 2.2, 4.2, 3.0),    # the low half of the pipe, before it drops out
	&"over_pond": Rect2(-9.0, 1.5, 18.0, 12.5),    # in the air over the water, above the dock
	&"tower_top": Rect2(38.5, 9.2, 7.5, 10.0),     # on or above the top tower deck
}
const SPOT_DEPTH := 8.0
## A stack counts when each object sits within this of the one under it and nothing moves.
const STACK_GAP := 0.35
const REST_SPEED := 0.5
## `touched_in` forgives this much past the spot's edge: he stands on the loft and holds the ball out
## over the tub at arm's length, so the ball he lets go of is just outside the loft's box.
const TOUCH_REACH := 1.0
## Inside a container also counts what is piled on the things in it, this many deep (the third thing
## on a full tub is still "in the tub" to a five-year-old).
const HEAP_DEPTH := 4


static func check(goal: GoalData, objects: Array = [], memory: GoalMemory = null) -> bool:
	if goal == null:
		return false
	if objects.is_empty():
		var tree := Engine.get_main_loop() as SceneTree
		objects = tree.get_nodes_in_group(PhysicsObject.GROUP) if tree else []
	if goal.condition == GoalData.Condition.STACK_HEIGHT:
		return _stack(goal, objects)
	var need := maxi(goal.count, 1)
	var n := 0
	for o in objects:
		var obj := o as PhysicsObject
		if obj and matches(obj, goal.subject) and holds(goal, obj, objects, memory):
			n += 1
			if n >= need:
				return true
	return false


static func matches(o: PhysicsObject, what: StringName) -> bool:
	return what == &"any" or what == &"" or o.data.id == what or o.key == what


## A Yard zone, or a card spot, as a box. Empty when neither has that name.
static func spot(spot_name: StringName) -> AABB:
	var z := Yard.zone(spot_name)
	if z.size != Vector3.ZERO:
		return z
	var r: Rect2 = SPOTS.get(spot_name, Rect2())
	if r.size == Vector2.ZERO:
		return AABB()
	return AABB(Vector3(r.position.x, r.position.y, -SPOT_DEPTH), Vector3(r.size.x, r.size.y, SPOT_DEPTH * 2.0))


## One object against one card or step, guards included.
static func holds(g: GoalData, o: PhysicsObject, objects: Array, memory: GoalMemory = null) -> bool:
	if g.touched_in != &"":
		if memory == null or not memory.touched(o) or not spot(g.touched_in).grow(TOUCH_REACH).has_point(memory.last_touch_at(o)):
			return false
	if g.condition == GoalData.Condition.SEQUENCE:
		return _sequence(g, o, objects, memory)
	if g.group:
		for m in o.stack.glued_group():
			if _holds(g, m, objects, memory):
				return true
		return false
	return _holds(g, o, objects, memory)


static func _holds(g: GoalData, o: PhysicsObject, objects: Array, memory: GoalMemory) -> bool:
	match g.condition:
		GoalData.Condition.OBJECT_SCALE_AT_LEAST:
			var s: Effect = o.stack.get_effect(&"size")
			return s != null and s.steps >= int(g.amount) and not o.is_scaling()
		GoalData.Condition.OBJECT_SCALE_AT_MOST:
			var s: Effect = o.stack.get_effect(&"size")
			return s != null and s.steps <= int(g.amount) and not o.is_scaling()
		GoalData.Condition.OBJECT_HAS_EFFECT:
			return o.stack.has(g.effect)
		GoalData.Condition.OBJECT_IN_ZONE:
			var zone := spot(g.other)
			if zone.size != Vector3.ZERO:
				return zone.has_point(o.global_position)
			for c in objects:
				var box := c as PhysicsObject
				if box and box != o and matches(box, g.other) and _inside(o, box, objects):
					return true
			return false
		GoalData.Condition.GLUED_PAIR:
			for e in o.stack.effects:
				if e is Effects.Glue and e.joined() and matches(e.other(o), g.other):
					return true
			return false
		GoalData.Condition.OBJECT_HEIGHT_ABOVE:
			return o.global_position.y > g.amount
		GoalData.Condition.OBJECT_HEIGHT_BELOW:
			return o.global_position.y < g.amount
		GoalData.Condition.OBJECT_SPEED_OVER:   # flying, not being carried fast
			return not o.stack.has(&"grab") and o.linear_velocity.length() > g.amount
		GoalData.Condition.OBJECT_SPEED_UNDER:
			return o.linear_velocity.length() < g.amount
		GoalData.Condition.ALL_OF:
			for s in g.steps:
				if s == null or not holds(s, o, objects, memory):
					return false
			return not g.steps.is_empty()
	return false   # STACK_HEIGHT is card-level only; SEQUENCE is handled in holds()


## o is in the container: its middle is inside, or it is over the container's floor and rests on
## something that is in it (a heap that has grown past the rim). Held over it, or flying across the
## top of the heap, is not in it: the deck keeps the first true read, so a passing ball must not count.
static func _inside(o: PhysicsObject, box: PhysicsObject, objects: Array, depth := 0) -> bool:
	if box.contains_point(o.global_position):
		return true
	if depth >= HEAP_DEPTH or not _resting(o):
		return false
	var local := box.global_transform.affine_inverse() * o.global_position
	if absf(local.x) >= box.size_now().x * 0.5 or local.y < 0.0:
		return false
	for c in objects:
		var under := c as PhysicsObject
		if under and under != o and under != box and _sits_on(o, under) and _inside(under, box, objects, depth + 1):
			return true
	return false


## Steps in order, one per check at most. A gun touch on an `untouched` step sends it back to step 1.
static func _sequence(g: GoalData, o: PhysicsObject, objects: Array, memory: GoalMemory) -> bool:
	if memory == null or g.steps.is_empty():
		return false
	var s := memory.stage(o)
	if s >= g.steps.size():
		return true
	if s > 0 and g.steps[s].untouched and memory.touched_since(o, memory.stage_tick(o)):
		s = 0
		memory.set_stage(o, 0)
	if holds(g.steps[s], o, objects, memory):
		s += 1
		memory.set_stage(o, s)
	return s >= g.steps.size()


## Longest chain of resting objects standing on one another (sorted by their bottoms, so one pass).
static func _stack(g: GoalData, objects: Array) -> bool:
	var need := maxi(g.count, 2)
	var rest: Array[PhysicsObject] = []
	for o in objects:
		var obj := o as PhysicsObject
		if obj and _resting(obj):
			rest.append(obj)
	if rest.size() < need:
		return false
	rest.sort_custom(func(a: PhysicsObject, b: PhysicsObject) -> bool: return _bottom(a) < _bottom(b))
	var depth := PackedInt32Array()
	depth.resize(rest.size())
	for i in rest.size():
		depth[i] = 1
		for j in i:
			if depth[j] + 1 > depth[i] and _sits_on(rest[i], rest[j]):
				depth[i] = depth[j] + 1
		if depth[i] >= need and _top(rest[i]) > g.amount and matches(rest[i], g.subject):
			return true
	return false


static func _resting(o: PhysicsObject) -> bool:
	if o.stack.has(&"grab"):
		return false
	return o.stack.has(&"freeze") or o.linear_velocity.length() < REST_SPEED


static func _bottom(o: PhysicsObject) -> float:
	return o.global_position.y - o.half_extent_along(Vector3.UP)


static func _top(o: PhysicsObject) -> float:
	return o.global_position.y + o.half_extent_along(Vector3.UP)


static func _sits_on(a: PhysicsObject, b: PhysicsObject) -> bool:
	if absf(_bottom(a) - _top(b)) > STACK_GAP:
		return false
	var reach := a.half_extent_along(Vector3.RIGHT) + b.half_extent_along(Vector3.RIGHT) - 0.05
	return absf(a.global_position.x - b.global_position.x) < reach
