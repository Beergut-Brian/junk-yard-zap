## S-18 steady frames (jyz-hitch-6). On the 2026-11-18 GTX 1060 bench of v0.1.7-dev.7 (high tier, 60 cap,
## vsync on) the average was 58.5-58.9 and the 1%-low 37.8-41.4. hitch-5 left two small steady costs:
## the fence card's 512x512 SubViewport rendered every frame (UPDATE_ALWAYS) for a face that only changes
## on a stamp or a flip, and the Reset sign wrote all 19 bulbs' material_override every frame, 2 of 3 the
## same value (each write marks the instance dirty for the renderer). Now the card renders once per change
## (UPDATE_ONCE armed by every redraw) and a bulb is written only when it turns on or off.
## These pin it: a still card asks for no render and draws nothing; a stamp and a flip each draw in a
## frame that also arms a render (and, with a renderer, the card's pixels change on the next frame);
## the bulbs are written exactly when they change and always show the right pattern.
## Events are counted through the face's draw signal and per-call counters, never by polling.
class_name TestHitch6
extends GdUnitTestSuite

var world: Node3D


func before_test() -> void:
	Game.demo = false
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	if is_instance_valid(world):
		world.free()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _deck() -> GoalDeck:
	var deck := GoalDeck.new()
	deck.load_dir(GoalDeck.DIR)
	world.add_child(deck)
	deck.checking = false
	return deck


## A fence card with a deck. Counts its face draws through the draw signal, and the draws that came with
## no render asked since the one before (a face drawn into a viewport that won't render it).
class Rig:
	var card: FenceCard
	var deck: GoalDeck
	var draws := 0
	var unarmed := 0
	var _asked_at_last_draw := 0

	func on_draw() -> void:
		draws += 1
		if card.renders_asked == _asked_at_last_draw:
			unarmed += 1
		_asked_at_last_draw = card.renders_asked


func _rig() -> Rig:
	var r := Rig.new()
	r.deck = _deck()
	r.card = FenceCard.new()
	r.card.deck = r.deck
	world.add_child(r.card)
	r.card._face.draw.connect(r.on_draw)
	return r


func run(_r: Rig, n: int) -> void:
	await frames(n)


func _every_draw_is_rendered(r: Rig, what: String) -> void:
	assert_int(r.unarmed).override_failure_message("%s: %d face draws with no render asked" % [what, r.unarmed]).is_equal(0)


# ------------------------------------------------------------------------------------- fence card

func test_the_card_viewport_does_not_render_every_frame() -> void:
	var r := _rig()
	assert_int(r.card._vp.render_target_update_mode).is_not_equal(SubViewport.UPDATE_ALWAYS)
	await run(r, 3)
	assert_int(r.card.renders_asked).is_greater_equal(1)   # the first face is rendered
	assert_int(r.draws).is_greater_equal(1)
	var asked := r.card.renders_asked
	var drawn := r.draws
	await run(r, 60)   # a still card: no stamp, no flip
	assert_int(r.card.renders_asked).is_equal(asked)
	assert_int(r.draws).is_equal(drawn)


func test_a_stamp_draws_and_renders_in_the_same_frame() -> void:
	var r := _rig()
	await run(r, 3)
	var drawn := r.draws
	var first := r.deck.current()
	r.deck.complete()
	assert_str(r.card.stamped()).is_equal("done")
	await run(r, 1)
	assert_int(r.draws).is_greater(drawn)
	assert_object(r.card._face_goal).is_same(first)
	# The stamp slams on over 0.3 s: every frame of it draws, and every draw is rendered.
	await run(r, 10)
	_every_draw_is_rendered(r, "stamp")


func test_a_skip_stamp_draws_and_renders_in_the_same_frame() -> void:
	var r := _rig()
	await run(r, 3)
	var drawn := r.draws
	r.card.zapped_by(null, null)
	assert_str(r.card.stamped()).is_equal("skip")
	await run(r, 2)
	assert_int(r.draws).is_greater(drawn)
	_every_draw_is_rendered(r, "skip")


func test_a_flip_to_the_next_card_draws_and_renders_in_the_same_frame() -> void:
	var r := _rig()
	await run(r, 3)
	r.deck.complete()
	await run(r, 30)   # past the slam
	var drawn := r.draws
	r.card._process(FenceCard.STAMP_FOR)   # stamp time's up: the flip starts
	var tries := 0
	while r.card.stamped() != "" and tries < 60:   # the flip swaps the face halfway (0.15 s)
		await run(r, 1)
		tries += 1
	assert_str(r.card.stamped()).is_equal("")
	assert_object(r.card._face_goal).is_same(r.deck.current())
	await run(r, 1)
	assert_int(r.draws).is_greater(drawn)
	_every_draw_is_rendered(r, "flip")
	# And then it's still again.
	await run(r, 20)
	var asked := r.card.renders_asked
	await run(r, 30)
	assert_int(r.card.renders_asked).is_equal(asked)


## Runs with a renderer only (`godot-render ... -a tests/test_hitch_6.gd`; headless has no pixels): the
## card's texture changes on the frame after a stamp, and again after the flip.
func test_with_a_renderer_a_stamp_and_a_flip_show_on_the_next_frame() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var r := _rig()
	await run(r, 3)
	await RenderingServer.frame_post_draw
	var before := r.card._vp.get_texture().get_image()
	r.deck.complete()
	await RenderingServer.frame_post_draw   # the frame the stamp was made in is drawn
	var stamped := r.card._vp.get_texture().get_image()
	assert_bool(stamped.get_data() != before.get_data()).override_failure_message("the stamp did not show").is_true()
	await run(r, 30)
	await RenderingServer.frame_post_draw
	var slammed := r.card._vp.get_texture().get_image()
	await run(r, 10)   # still: nothing renders, the texture keeps the last face
	await RenderingServer.frame_post_draw
	assert_bool(r.card._vp.get_texture().get_image().get_data() == slammed.get_data()).is_true()
	r.card._process(FenceCard.STAMP_FOR)
	var tries := 0
	while r.card.stamped() != "" and tries < 60:
		await run(r, 1)
		tries += 1
	await RenderingServer.frame_post_draw
	var flipped := r.card._vp.get_texture().get_image()
	assert_bool(flipped.get_data() != slammed.get_data()).override_failure_message("the flip did not show").is_true()


# ------------------------------------------------------------------------------------ reset sign

func _sign(n: int) -> ResetSignFx:
	var fx := ResetSignFx.new()
	fx.on_mat = StandardMaterial3D.new()
	fx.off_mat = StandardMaterial3D.new()
	for i in n:
		var mi := MeshInstance3D.new()
		fx.add_child(mi)
		fx.bulbs.append(mi)
	world.add_child(fx)
	fx.set_process(false)   # the test drives _process with its own deltas (after ready, which turns it on)
	return fx


func test_the_reset_sign_writes_a_bulb_only_when_it_changes() -> void:
	var fx := _sign(19)
	var shown: Array = []
	shown.resize(19)   # what each bulb shows, null at first
	var expected := 0
	var old_writes := 0   # what writing every bulb every frame cost
	for frame in 115:   # 1.92 s at 60 fps: the chase steps 11 times (one each 10 frames), the last frame mid-step
		fx._process(1.0 / 60.0)
		var lit := int(fx._t * 6.0)
		for i in 19:
			var want: Material = fx.on_mat if (i + lit) % 3 != 0 else fx.off_mat
			if shown[i] != want:
				expected += 1
				shown[i] = want
			assert_object(fx.bulbs[i].material_override).is_same(want)
		old_writes += 19
	assert_int(fx.bulb_writes).is_equal(expected)
	assert_int(fx.bulb_writes).is_less(old_writes / 5)
	# A frame inside one chase step writes nothing (1.92 s is mid-step: steps fall on multiples of 1/6 s).
	var w := fx.bulb_writes
	fx._process(0.0001)
	assert_int(fx.bulb_writes).is_equal(w)


func test_the_reset_sign_still_races_after_a_reset() -> void:
	var fx := _sign(19)
	fx._process(1.0 / 60.0)
	var w := fx.bulb_writes
	fx._kick = 1.6   # just reset: the chase runs at 36 steps a second
	for frame in 30:
		fx._process(1.0 / 60.0)
	assert_int(fx.bulb_writes - w).is_greater(19 * 3)   # many steps in half a second
	var lit := int(fx._t * (6.0 + 30.0 * minf(fx._kick, 1.0)))
	for i in 19:
		assert_object(fx.bulbs[i].material_override).is_same(fx.on_mat if (i + lit) % 3 != 0 else fx.off_mat)


func test_the_yard_sign_still_lights_its_bulbs() -> void:
	var l := YardLevel.new()
	l.use_save = false
	l.layout = load(YardLevel.LAYOUT)
	world.add_child(l)
	var players := Node3D.new()
	players.name = "Players"
	l.add_child(players)
	await frames(3)
	var fx := l.reset_sign.get_node("SignFx") as ResetSignFx
	var on := 0
	for b in fx.bulbs:
		assert_object(b.material_override).is_not_null()
		if b.material_override == fx.on_mat:
			on += 1
	assert_int(on).is_between(fx.bulbs.size() / 2, fx.bulbs.size() - 1)   # two of three lit
	world.free()
	Yard.reset_world()


# ------------------------------------------------------------------------------------ bench trace

func test_bench_trace_flag_and_path() -> void:
	assert_str(BenchTrace.path_from_args(PackedStringArray(["--bench"]))).is_equal("")
	assert_str(BenchTrace.path_from_args(PackedStringArray(["--bench", "--bench-trace"]))).is_equal("user://bench_trace.csv")
	assert_str(BenchTrace.path_from_args(PackedStringArray(["--bench-trace=/tmp/x.csv"]))).is_equal("/tmp/x.csv")


## rows: [t, seg, frame, physics, steps, process, draw, idle, gpu]
func _rows(n: int, slow_every: int, slow: Array) -> Array:
	var out := []
	for i in n:
		if i % slow_every == 0:
			out.append([i / 60.0, "follow"] + slow)
		else:
			out.append([i / 60.0, "follow", 16.7, 2.0, 1, 1.5, 3.0, 10.2, 4.0])
	return out


func test_bench_trace_names_the_part_that_grew_in_the_slow_frames() -> void:
	# Slow frames that slept: the work is the same, the limiter / present held them.
	var idle := BenchTrace.line(_rows(200, 50, [33.3, 2.0, 1, 1.5, 3.0, 26.8, 4.0]))
	assert_str(idle).starts_with("BENCH-TRACE slow=4/200").contains("cause=idle")
	# Slow frames with a heavy physics step.
	assert_str(BenchTrace.line(_rows(200, 50, [30.0, 18.0, 2, 1.5, 3.0, 7.5, 4.0]))).contains("cause=physics")
	# Slow frames that waited on the draw (render CPU or the GPU).
	assert_str(BenchTrace.line(_rows(200, 50, [28.0, 2.0, 1, 1.5, 21.0, 3.5, 14.0]))).contains("cause=draw")
	# Every frame slow (a software renderer): the biggest part, marked.
	assert_str(BenchTrace.line(_rows(10, 1, [1158.0, 21.5, 8, 9.8, 1127.7, 8.9, 1098.8]))).contains("slow=10/10").contains("cause=draw(all)")
	# No slow frame.
	assert_str(BenchTrace.line(_rows(200, 1000, [16.7, 2.0, 1, 1.5, 3.0, 10.2, 4.0]))).contains("slow=0/200").contains("cause=none")


func test_bench_trace_splits_every_counted_frame_and_writes_its_csv() -> void:
	var b := BenchProbe.new()
	b.quit_when_done = false
	b.duration = 0.5
	b.report_every = 0.5
	b.warmup = 0.1
	var tr := BenchTrace.new()
	tr.bench = b
	tr.path = "user://test_hitch_6_trace.csv"   # scratch: never the real settings or players file
	world.add_child(b)
	world.add_child(tr)
	await b.finished
	assert_int(tr.rows.size()).is_greater(5)
	for r: Array in tr.rows:
		var parts := float(r[3]) + float(r[5]) + float(r[6]) + float(r[7])
		assert_float(parts).is_equal_approx(float(r[2]), 0.01)   # physics + process + draw + idle = the frame
		assert_float(float(r[2])).is_greater(0.0)
	assert_str(tr.summary).starts_with("BENCH-TRACE slow=")
	var f := FileAccess.open(tr.path, FileAccess.READ)
	assert_object(f).is_not_null()
	assert_str(f.get_line()).is_equal(",".join(BenchTrace.COLS))
	var n := 0
	while not f.eof_reached():
		if f.get_line() != "":
			n += 1
	f.close()
	assert_int(n).is_equal(tr.rows.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tr.path))


func test_bench_trace_flag_runs_with_the_bench_and_prints_its_line() -> void:
	var scratch := ProjectSettings.globalize_path("user://bench_trace_child")
	DirAccess.make_dir_recursive_absolute(scratch)
	var csv := scratch.path_join("trace.csv")
	var out := []
	var cmd := "XDG_DATA_HOME='%s' timeout 150 '%s' --headless --path '%s' -- --bench --bench-seconds=2 --bench-trace='%s' 2>&1" % [
			scratch, OS.get_executable_path(), ProjectSettings.globalize_path("res://"), csv]
	var code := OS.execute("bash", ["-c", cmd], out)
	var text: String = "\n".join(out)
	var wrote := FileAccess.file_exists(csv)
	OS.execute("rm", ["-rf", "--", scratch])
	assert_int(code).override_failure_message("exit %d\n%s" % [code, text.right(2000)]).is_equal(0)
	assert_str(text).contains("BENCH avg=").contains("BENCH-TRACE slow=")
	assert_bool(wrote).is_true()
