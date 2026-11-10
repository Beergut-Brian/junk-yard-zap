## The 30-card goal deck: order and coverage, the condition vocabulary (pure checks on a strip), and
## every card completed in a real yard through the gun effects (Effects.zap / glue / grab / release)
## with the real deck ticking. Gravity grab is held by a test hand (any Node3D with hold_point(), as
## Effects.grab allows) that floats where a player's hand would be, standing on whatever is there.
class_name TestGoalDeck
extends GdUnitTestSuite

const HAND_SPEED := 9.0   # m/s, about a carrying walk

var world: Node3D


class Hand extends Node3D:
	func hold_point(_t: Node3D) -> Vector3:
		return global_position


func before() -> void:
	Save.profile = "gdunit"


func before_test() -> void:
	Players.reset()
	Game.demo = false
	Audio.history.clear()
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func level() -> YardLevel:
	var l := YardLevel.new()
	l.use_save = false
	l.layout = load(YardLevel.LAYOUT)
	world.add_child(l)
	var players := Node3D.new()
	players.name = "Players"
	l.add_child(players)
	return l


func box(pos: Vector3, size := Vector3.ONE) -> PhysicsObject:
	var o := PhysicsObject.new(ObjectData.make(&"box", ObjectData.Shape.BOX, size, 1.0, Color.TAN))
	o.position = pos
	world.add_child(o)
	return o


## Make `id` the top card (as if he had skipped to it).
func top(l: YardLevel, id: StringName) -> void:
	assert_bool(l.deck.cards.has(id)).override_failure_message("%s missing" % id).is_true()
	l.deck.order.erase(id)
	l.deck.order.push_front(id)
	l.deck.card_changed.emit(l.deck.current())


func done(l: YardLevel, id: StringName, frames := 240) -> bool:
	for i in frames:
		if l.deck.done.has(id):
			return true
		await step(1)
	return l.deck.done.has(id)


## Gravity grab o and carry it through the waypoints; returns the hand (still holding).
func carry(o: PhysicsObject, path: Array) -> Hand:
	var h := Hand.new()
	world.add_child(h)
	h.global_position = o.global_position
	assert_object(Effects.grab(o, h, Color.WHITE)).is_not_null()
	for p in path:
		await move(h, p)
		assert_float(o.global_position.distance_to(p)).override_failure_message(
				"%s stuck at %s on the way to %s" % [o.key, o.global_position, p]).is_less(1.0)
	return h


func move(h: Hand, to: Vector3) -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	while h.global_position.distance_to(to) > 0.01:
		h.global_position = h.global_position.move_toward(to, HAND_SPEED * dt)
		await step(1)
	await step(20)


func drop(o: PhysicsObject, h: Hand, throw := Vector3.ZERO) -> void:
	Effects.release(o, throw)
	h.queue_free()


func expect_done(l: YardLevel, id: StringName, frames := 240) -> void:
	var ok: bool = await done(l, id, frames)
	var where := ""
	for h in l.deck.cards[id].hint_objects:
		var o := l.object(h)
		where += " %s at %s v %.1f" % [h, o.global_position, o.linear_velocity.length()]
	assert_bool(ok).override_failure_message("%s never completed:%s" % [id, where]).is_true()


# ------------------------------------------------------------------------------- the deck itself

func test_thirty_cards_in_three_bands_easy_first() -> void:
	var l := level()
	await step(3)
	var bands := {1: 0, 2: 0, 3: 0}
	for id in l.deck.cards:
		bands[l.deck.cards[id].band] += 1
	assert_int(l.deck.cards.size()).is_equal(30)
	assert_dict(bands).is_equal({1: 12, 2: 10, 3: 8})
	assert_str(String(l.deck.order[0])).is_equal("b1_big_cow")
	var last := 0
	for id in l.deck.order:
		var g: GoalData = l.deck.cards[id]
		assert_int(g.band).is_greater_equal(last)
		last = g.band
	for id in l.deck.order.slice(0, 5):
		assert_int(l.deck.cards[id].band).is_equal(1)


func test_every_card_hints_at_real_yard_objects_and_has_a_picture() -> void:
	var l := level()
	await step(3)
	for id in l.deck.cards:
		var g: GoalData = l.deck.cards[id]
		assert_array(g.hint_objects).override_failure_message("%s no hints" % id).is_not_empty()
		for h in g.hint_objects:
			var found := false
			for k in l.objects:
				found = found or Goals.matches(l.objects[k], h)
			assert_bool(found).override_failure_message("%s hints %s, not in the yard" % [id, h]).is_true()
		if g.subject != &"any":
			assert_bool(l.objects.values().any(func(o: PhysicsObject) -> bool: return Goals.matches(o, g.subject))) \
					.override_failure_message("%s subject %s not in the yard" % [id, g.subject]).is_true()
		if String(id) in CardArt.CARDS.map(func(x: StringName) -> String: return String(x)):
			assert_object(g.picture).override_failure_message("%s no picture" % id).is_not_null()
			assert_int(g.picture.get_width()).is_equal(512)


func test_every_gun_and_zone_has_a_card() -> void:
	var l := level()
	await step(3)
	var words := ""
	for id in l.deck.cards:
		var g: GoalData = l.deck.cards[id]
		words += " %s %s %s %s" % [g.effect, g.other, g.touched_in, g.condition]
		for s in g.steps:
			words += " %s %s" % [s.effect, s.other]
			for s2 in s.steps:
				words += " %s" % s2.other
	for w in ["magnet", "freeze", "balloon", "front_gate", "pond", "tower", "barn_loft", "bathtub"]:
		assert_str(words).contains(w)
	var conds := l.deck.cards.values().map(func(g: GoalData) -> int: return g.condition)
	for c in [GoalData.Condition.GLUED_PAIR, GoalData.Condition.OBJECT_SCALE_AT_LEAST, GoalData.Condition.OBJECT_SCALE_AT_MOST]:
		assert_array(conds).contains([c])


func test_no_card_is_already_done_in_a_fresh_yard() -> void:
	var l := level()
	await step(30)
	for id in l.deck.cards:
		var g: GoalData = l.deck.cards[id]
		l.deck.memory.reset_progress()
		var hit := false
		for i in 4:   # sequences need a few checks to show their hand
			hit = hit or Goals.check(g, [], l.deck.memory)
			l.deck.memory.tick += 1
		assert_bool(hit).override_failure_message("%s done at the start" % id).is_false()


func test_all_thirty_skip_through_and_wrap() -> void:
	var l := level()
	await step(3)
	var first := l.deck.order.duplicate()
	var seen := {}
	for i in 30:
		seen[l.deck.current().id] = true
		l.deck.skip()
	assert_int(seen.size()).is_equal(30)
	assert_array(l.deck.order).is_equal(first)   # wrapped: back to b1_big_cow on top
	assert_bool(Audio.played("card_skip")).is_true()


func test_card_spots_sit_on_the_real_landmarks() -> void:
	var l := level()
	await step(3)
	var loft := l.find_child("Loft", true, false) as Node3D
	assert_bool(Goals.spot(&"barn_loft").has_point(loft.global_position + Vector3(0, 0.5, 0))).is_true()
	var pipe := l.find_child("PipeFloor", true, false) as Node3D
	var down := Vector3(-cos(deg_to_rad(32.0)), -sin(deg_to_rad(32.0)), 0)
	var lift := Vector3(-sin(deg_to_rad(32.0)), cos(deg_to_rad(32.0)), 0) * 0.5
	assert_bool(Goals.spot(&"pipe_top").has_point(pipe.global_position - down * 3.6 + lift)).is_true()
	assert_bool(Goals.spot(&"pipe_bottom").has_point(pipe.global_position + down * 3.0 + lift)).is_true()
	var deck_top := l.find_child("TowerDeck2", true, false) as Node3D
	assert_bool(Goals.spot(&"tower_top").has_point(deck_top.global_position + Vector3(0, 0.6, 0))).is_true()
	assert_bool(Goals.spot(&"over_pond").has_point(Vector3(0, 4, 0))).is_true()
	assert_bool(Goals.spot(&"pond").has_point(Vector3(0, -1, 0))).is_true()   # zones still win


# ------------------------------------------------------------------- the vocabulary, on a strip

func test_sequence_steps_in_order_and_a_gun_touch_starts_over() -> void:
	world.add_child(YardStrip.new())
	var o := box(Vector3(0, 0.5, 0))
	await step(10)
	var up := GoalData.new()
	up.condition = GoalData.Condition.OBJECT_HEIGHT_ABOVE
	up.amount = 3.0
	var low := GoalData.new()
	low.condition = GoalData.Condition.OBJECT_HEIGHT_BELOW
	low.amount = 1.0
	low.untouched = true
	var g := GoalData.new()
	g.condition = GoalData.Condition.SEQUENCE
	g.steps = [up, low]
	var mem := GoalMemory.new()
	var objs := [o]
	assert_bool(Goals.check(g, objs)).is_false()          # no memory, no sequence
	assert_bool(Goals.check(g, objs, mem)).is_false()     # low but never high
	o.global_position = Vector3(0, 4, 0)
	mem.tick += 1
	assert_bool(Goals.check(g, objs, mem)).is_false()     # step 1 done
	assert_int(mem.stage(o)).is_equal(1)
	mem.touch(o)                                           # zapped on the way down
	o.global_position = Vector3(0, 0.5, 0)
	mem.tick += 1
	assert_bool(Goals.check(g, objs, mem)).is_false()
	assert_int(mem.stage(o)).is_equal(0)
	o.global_position = Vector3(0, 4, 0)
	mem.tick += 1
	Goals.check(g, objs, mem)
	o.global_position = Vector3(0, 0.5, 0)
	mem.tick += 1
	assert_bool(Goals.check(g, objs, mem)).is_true()      # knocked down, not zapped


func test_touched_in_needs_the_last_touch_inside() -> void:
	world.add_child(YardStrip.new())
	var o := box(Vector3(0, 0.5, 0))
	await step(5)
	var g := GoalData.new()
	g.condition = GoalData.Condition.OBJECT_HEIGHT_BELOW
	g.amount = 2.0
	g.touched_in = &"barn_loft"
	var mem := GoalMemory.new()
	assert_bool(Goals.check(g, [o], mem)).is_false()      # never touched
	o.global_position = Vector3(25, 5, 0)
	mem.touch(o)
	o.global_position = Vector3(0, 0.5, 0)
	assert_bool(Goals.check(g, [o], mem)).is_true()
	mem.touch(o)                                           # touched again down here
	assert_bool(Goals.check(g, [o], mem)).is_false()
	mem.clear()
	assert_bool(Goals.check(g, [o], mem)).is_false()


func test_stack_height_counts_a_resting_column() -> void:
	world.add_child(YardStrip.new())
	var objs := []
	for i in 3:
		objs.append(box(Vector3(0, 0.5 + i * 1.0, 0)))
	objs.append(box(Vector3(4, 0.5, 0)))
	await step(90)
	var g := GoalData.new()
	g.condition = GoalData.Condition.STACK_HEIGHT
	g.count = 3
	g.amount = 2.5
	assert_bool(Goals.check(g, objs)).is_true()
	g.amount = 3.5
	assert_bool(Goals.check(g, objs)).is_false()          # not that tall
	g.amount = 0.0
	g.count = 4
	assert_bool(Goals.check(g, objs)).is_false()          # the fourth is beside it, not on it


func test_all_of_and_count_and_group() -> void:
	world.add_child(YardStrip.new())
	var a := box(Vector3(-1, 0.5, 0))
	var b := box(Vector3(1, 0.5, 0))
	await step(10)
	var frozen := GoalData.new()
	frozen.condition = GoalData.Condition.OBJECT_HAS_EFFECT
	frozen.effect = &"freeze"
	var g := GoalData.new()
	g.condition = GoalData.Condition.ALL_OF
	g.steps = [frozen]
	g.count = 2
	Effects.zap(&"freeze", a)
	assert_bool(Goals.check(g, [a, b])).is_false()
	Effects.zap(&"freeze", b)
	assert_bool(Goals.check(g, [a, b])).is_true()
	Effects.zap(&"freeze", b)
	Effects.zap(&"freeze", a)
	Effects.zap(&"balloon", b)
	frozen.effect = &"balloon"
	frozen.group = true
	g.count = 1
	g.subject = &"any"
	assert_bool(Goals.holds(frozen, a, [a, b])).is_false()
	Effects.glue(a, b)
	await step(30)
	assert_bool(Goals.holds(frozen, a, [a, b])).is_true()   # its glued mate has the balloon


# -------------------------------------------------- every new card, completed through the guns
# Band 1

func test_b1_tiny_car() -> void:
	var l := level()
	await step(5)
	top(l, &"b1_tiny_car")
	await step(10)
	assert_bool(l.deck.done.has(&"b1_tiny_car")).is_false()
	Effects.zap(&"shrink", l.object(&"car"))
	await expect_done(l, &"b1_tiny_car")


func test_b1_tiny_tractor() -> void:
	var l := level()
	await step(5)
	top(l, &"b1_tiny_tractor")
	Effects.zap(&"shrink", l.object(&"tractor"))
	await expect_done(l, &"b1_tiny_tractor")


func test_b1_magnet_fridge() -> void:
	var l := level()
	await step(5)
	top(l, &"b1_magnet_fridge")
	Effects.zap(&"magnet", l.object(&"fridge"))
	await expect_done(l, &"b1_magnet_fridge")


func test_b1_pig_in_pond() -> void:
	var l := level()
	await step(5)
	top(l, &"b1_pig_in_pond")
	var pig := l.object(&"pig")
	var h := await carry(pig, [Vector3(29.3, 0.6, 0), Vector3(29.3, 6.5, 0), Vector3(2, 6.5, 0)])   # out from under the loft
	drop(pig, h)
	await expect_done(l, &"b1_pig_in_pond")


func test_b1_sheep_to_gate() -> void:
	var l := level()
	await step(5)
	top(l, &"b1_sheep_to_gate")
	var sheep := l.object(&"sheep")
	var h := await carry(sheep, [Vector3(29.3, 0.6, 0), Vector3(29.3, 6.5, 0), Vector3(-33, 6.5, 0)])   # out from under the loft
	drop(sheep, h)
	await expect_done(l, &"b1_sheep_to_gate")


# Band 2

func test_b2_three_in_tub() -> void:
	var l := level()
	await step(5)
	top(l, &"b2_three_in_tub")
	var tub := l.object(&"bathtub")
	for k in [&"ball", &"toaster", &"bucket"]:
		var o := l.object(k)
		var h := await carry(o, [o.global_position + Vector3(0, 3, 0), tub.global_position + Vector3(0, 3, 0), tub.global_position + Vector3(0, 1.2, 0)])
		drop(o, h)
		await step(30)
	await expect_done(l, &"b2_three_in_tub")


func test_b2_chicken_stairs() -> void:
	var l := level()
	await step(5)
	top(l, &"b2_chicken_stairs")
	Effects.zap(&"balloon", l.object(&"chicken"))   # the one on the ground floats up a bit...
	await step(40)
	Effects.zap(&"freeze", l.object(&"chicken"))    # ...and freezes there: the bottom stair
	Effects.zap(&"freeze", l.object(&"chicken_2"))
	Effects.zap(&"freeze", l.object(&"chicken_3"))
	await expect_done(l, &"b2_chicken_stairs")


func test_b2_duck_on_tower() -> void:
	var l := level()
	await step(5)
	top(l, &"b2_duck_on_tower")
	var duck := l.object(&"duck")
	var h := await carry(duck, [Vector3(duck.global_position.x, 12, 0), Vector3(41, 12, 0), Vector3(41, 10.2, 0)])
	drop(duck, h)
	await expect_done(l, &"b2_duck_on_tower")


func test_b2_tub_from_loft() -> void:
	var l := level()
	await step(5)
	top(l, &"b2_tub_from_loft")
	var tub := l.object(&"bathtub")
	# Make room under the loft's end (the tractor goes for a swim), put the tub there, and drop
	# the ball into it from up in the loft.
	var t := l.object(&"tractor")
	var h := await carry(t, [Vector3(29.85, 0.8, 0), Vector3(29.85, 8, 0), Vector3(3, 8, 0)])
	drop(t, h)
	h = await carry(tub, [tub.global_position + Vector3(0, 3, 0), Vector3(-10, 8, 0), Vector3(30.0, 8, 0), Vector3(30.0, 0.8, 0)])
	drop(tub, h)
	var ball := l.object(&"ball")
	h = await carry(ball, [ball.global_position + Vector3(0, 7, 0), Vector3(29.45, 7.45, 0), Vector3(29.45, 5.5, 0)])
	await step(10)
	assert_bool(l.deck.done.has(&"b2_tub_from_loft")).is_false()
	drop(ball, h, Vector3(1.0, 0, 0))
	await expect_done(l, &"b2_tub_from_loft")


func test_b2_tub_from_loft_needs_the_loft() -> void:
	var l := level()
	await step(5)
	top(l, &"b2_tub_from_loft")
	var tub := l.object(&"bathtub")
	var ball := l.object(&"ball")
	var h := await carry(ball, [ball.global_position + Vector3(0, 3, 0), tub.global_position + Vector3(0, 3, 0), tub.global_position + Vector3(0, 1.2, 0)])
	drop(ball, h)
	var ok: bool = await done(l, &"b2_tub_from_loft", 120)
	assert_bool(ok).is_false()
	assert_bool(Goals.check(l.deck.cards[&"b1_tub_ball"])).is_true()   # the band-1 card would take it


func test_b2_egg_off_loft() -> void:
	var l := level()
	await step(20)
	top(l, &"b2_egg_off_loft")
	await step(10)
	var hay := l.object(&"hay")   # bulldoze along the loft with a held hay bale: it sweeps the egg off
	var h := await carry(hay, [Vector3(15.2, 7, 0), Vector3(23.9, 7, 0), Vector3(23.9, 4.7, 0), Vector3(30.5, 4.7, 0)])
	drop(hay, h)
	await expect_done(l, &"b2_egg_off_loft", 300)


func test_b2_car_over_fence() -> void:
	var l := level()
	await step(5)
	top(l, &"b2_car_over_fence")
	var car := l.object(&"car")
	var h := await carry(car, [car.global_position + Vector3(0, 4.5, 0)])
	await step(10)
	assert_bool(l.deck.done.has(&"b2_car_over_fence")).is_false()   # high but not flying
	drop(car, h, Vector3(10, 6, 0))
	await expect_done(l, &"b2_car_over_fence", 120)


func test_b2_stack_three() -> void:
	var l := level()
	await step(5)
	top(l, &"b2_stack_three")
	var y := 4.2
	var x := 24.1
	for k in [&"crate", &"crate_2", &"fridge"]:   # up on the loft's free end: the loft is a head start
		var o := l.object(k)
		var hy := y + o.half_extent_along(Vector3.UP) + 0.1
		var h := await carry(o, [Vector3(o.global_position.x, 10, 0), Vector3(x, 10, 0), Vector3(x, hy, 0)])
		drop(o, h)
		await step(40)
		y = o.global_position.y + o.half_extent_along(Vector3.UP)
		x = o.global_position.x
	await expect_done(l, &"b2_stack_three", 240)


# Band 3

func test_b3_fast_duck() -> void:
	var l := level()
	await step(5)
	top(l, &"b3_fast_duck")
	Effects.zap(&"bouncy", l.object(&"duck"))
	var duck := l.object(&"duck")
	var h := await carry(duck, [Vector3(duck.global_position.x, 14, 0), Vector3(14, 14, 0)])
	drop(duck, h, Vector3(0, -14, 0))   # slam dunk
	await expect_done(l, &"b3_fast_duck", 120)


func test_b3_tractor_loft() -> void:
	var l := level()
	await step(5)
	top(l, &"b3_tractor_loft")
	var t := l.object(&"tractor")
	# Lift it in the gap between the loft and the pipe's foot, then over and down onto the loft.
	var h := await carry(t, [Vector3(29.85, 0.8, 0), Vector3(29.85, 11, 0), Vector3(26, 11, 0), Vector3(26, 5.6, 0)])
	drop(t, h)
	await expect_done(l, &"b3_tractor_loft")


func test_b3_cow_over_tower() -> void:
	var l := level()
	await step(5)
	top(l, &"b3_cow_over_tower")
	var cow := l.object(&"cow")
	var h := await carry(cow, [Vector3(cow.global_position.x, 12, 0), Vector3(41, 12, 0), Vector3(41, 10.0, 0)])
	drop(cow, h)
	await step(40)
	assert_bool(l.deck.done.has(&"b3_cow_over_tower")).is_false()   # on the tower, not over it
	Effects.zap(&"balloon", cow)
	await expect_done(l, &"b3_cow_over_tower", 600)


func test_b3_stack_five() -> void:
	var l := level()
	await step(5)
	top(l, &"b3_stack_five")
	var y := 0.0
	var x := -42.5
	for k in [&"washing_machine", &"crate", &"crate_2", &"tv", &"toolbox"]:
		var o := l.object(k)
		var hy := y + o.half_extent_along(Vector3.UP) + 0.1
		var h := await carry(o, [Vector3(o.global_position.x, 8, 0), Vector3(x, 8, 0), Vector3(x, hy, 0)])
		drop(o, h)
		await step(40)
		y = o.global_position.y + o.half_extent_along(Vector3.UP)
		x = o.global_position.x
	await expect_done(l, &"b3_stack_five", 240)


func test_b3_cannonball_pond() -> void:
	var l := level()
	await step(5)
	top(l, &"b3_cannonball_pond")
	var ball := l.object(&"cannonball")
	# Off the bottom deck, up round the right of the tower, over and down by the pipe's foot.
	var h := await carry(ball, [Vector3(47, 3.6, 0), Vector3(47, 13, 0), Vector3(30, 13, 0), Vector3(30, 6, 0)])
	drop(ball, h, Vector3(-12, 7, 0))   # a big throw from the tower
	await expect_done(l, &"b3_cannonball_pond", 300)


func test_b3_raft() -> void:
	var l := level()
	await step(5)
	top(l, &"b3_raft")
	var cow := l.object(&"cow")
	var car := l.object(&"car")
	var h := await carry(car, [car.global_position + Vector3(0, 3, 0), Vector3(-7.5, 3, 0), Vector3(-7.5, 1.2, 0)])
	drop(car, h)
	h = await carry(cow, [cow.global_position + Vector3(0, 3, 0), Vector3(-4.8, 4, 0), Vector3(-4.8, 1.3, 0)])
	drop(cow, h)
	await step(30)
	assert_object(Effects.glue(cow, car)).is_not_null()
	await step(120)
	Effects.zap(&"balloon", cow)
	Effects.zap(&"balloon", car)
	await expect_done(l, &"b3_raft", 600)


func test_b3_chain_ball() -> void:
	var l := level()
	await step(5)
	top(l, &"b3_chain_ball")
	var ball := l.object(&"ball")
	var h := await carry(ball, [ball.global_position + Vector3(0, 7, 0), Vector3(28.0, 7, 0), Vector3(28.0, 4.7, 0)])
	drop(ball, h)   # set down gently, so it rests up there
	for i in 120:
		if l.deck.memory.stage(ball) == 1:
			break
		await step(1)
	assert_int(l.deck.memory.stage(ball)).override_failure_message("ball never rested on the loft: %s" % ball.global_position).is_equal(1)
	assert_bool(l.deck.done.has(&"b3_chain_ball")).is_false()
	# Nobody touches the ball: a hen thrown along the loft knocks into the egg, the other hen, the ball.
	var hay := l.object(&"hay")   # a hay bale shoved along the loft: hens, egg and ball go over
	h = await carry(hay, [Vector3(15.2, 7, 0), Vector3(23.9, 7, 0), Vector3(23.9, 4.9, 0)])
	drop(hay, h, Vector3(14, 0.5, 0))
	await expect_done(l, &"b3_chain_ball", 300)


func test_b3_chain_ball_does_not_count_a_zapped_ball() -> void:
	var l := level()
	await step(5)
	top(l, &"b3_chain_ball")
	var ball := l.object(&"ball")
	var h := await carry(ball, [ball.global_position + Vector3(0, 7, 0), Vector3(28.0, 7, 0), Vector3(28.0, 5.0, 0)])
	drop(ball, h)
	await step(60)
	h = await carry(ball, [Vector3(28.0, 6.0, 0), Vector3(30.5, 6.0, 0)])   # just carry it off the edge
	drop(ball, h)
	var ok: bool = await done(l, &"b3_chain_ball", 120)
	assert_bool(ok).is_false()


func test_b3_piano_pipe_pond() -> void:
	var l := level()
	await step(5)
	top(l, &"b3_piano_pipe_pond")
	var piano := l.object(&"piano")
	for i in 4:   # the full-size piano doesn't fit the pipe: tiny it slides right down
		Effects.zap(&"shrink", piano)
	await step(60)
	# Round the right of the tower, up to the middle deck, into the pipe's mouth.
	var h := await carry(piano, [Vector3(33, 2.2, 0), Vector3(47, 2.2, 0), Vector3(47, 6.9, 0), Vector3(39.6, 6.9, 0), Vector3(38.6, 7.9, 0), Vector3(37.4, 7.2, 0)])
	drop(piano, h)
	await step(120)   # it slides part way; a wedged piano gets a shove down the pipe
	var mid := func(x: float) -> Vector3: return Vector3(x, 5.0 + (x - 35.0) * tan(deg_to_rad(32.0)) + 0.45, 0)
	h = await carry(piano, [mid.call(minf(piano.global_position.x, 36.0)), mid.call(32.2), Vector3(30.2, 2.6, 0)])
	assert_int(l.deck.memory.stage(piano)).override_failure_message("stage %d" % l.deck.memory.stage(piano)).is_equal(2)
	await move(h, Vector3(30.0, 6.5, 0))
	await move(h, Vector3(2, 6.5, 0))
	drop(piano, h)
	await expect_done(l, &"b3_piano_pipe_pond")
