## jyz-ui-1 (playtest 2026-11-10 items 1-3): gun icons that show the effect, the belt wheel with
## weight, the switch preview and the first-fire beat, distinct beams and hits, and the goal cards.
class_name TestUiClarity
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
var _clock := Clock.new()   # 60 Hz, time scale 1: frame counts below mean the same seconds everywhere

const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")

var _main: Node
var _real_profile := ""
var _real_settings := ""
var _real_picks := ""


func before() -> void:
	_clock.pin()
	_real_profile = Save.profile
	Save.profile = "gdunit_ui_clarity"   # main.tscn saves the yard: never the family's profile
	Save.wipe()
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_ui_clarity.json"
	Save.wipe_settings()
	_real_picks = Roster.picks_path   # the defaults (Jeff P1, Chuck P2), never the family's picks
	Roster.picks_path = "user://test_ui_clarity_players.json"
	Roster.args_override = PackedStringArray(["--no-picks"])
	Roster.reload()
	Game.quit_exits = false


func after() -> void:
	_clock.restore()
	Game.quit_exits = true
	Save.wipe()
	Save.profile = _real_profile
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Roster.picks_path = _real_picks
	Roster.args_override = PackedStringArray()
	Roster.reload()


func before_test() -> void:
	Save.wipe()
	Audio.history.clear()
	Players.reset()
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Yard.reset_world()
	Players.reset()
	Game.demo = false
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func _boot_two() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	(_main.get_node("UI/Lobby") as Lobby).count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	await step(2)


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _hud() -> Hud:
	return _main.get_node("UI/Hud")


# --- PT10-1: icons ------------------------------------------------------------------------------

func test_every_gun_kind_has_its_own_effect_story() -> void:
	# One picture per kind, and the token wears the gun's beam colour (no texture overrides it).
	for k in GunData.Kind.values():
		assert_bool(GunIcons.STORY.has(k)).override_failure_message("no icon story for kind %d" % k).is_true()
	var stories := {}
	for g in Zapper.load_guns():
		assert_object(g.icon).override_failure_message("%s: a texture would hide the drawn token" % g.id).is_null()
		stories[GunIcons.STORY[g.kind]] = true
	assert_int(stories.size()).is_equal(7)


func test_beam_colours_are_seven_different_hues_never_player_colours() -> void:
	var guns := Zapper.load_guns()
	for i in guns.size():
		for j in range(i + 1, guns.size()):
			var a: Color = guns[i].beam_color
			var b: Color = guns[j].beam_color
			var d := absf(a.h - b.h) + absf(a.s - b.s) + absf(a.v - b.v)
			assert_float(d).override_failure_message("%s and %s look alike" % [guns[i].id, guns[j].id]).is_greater(0.05)   # size and bouncy are closest: their stories differ most
		for p in [P1, P2]:
			var pc: Color = Players.COLOR[p]
			assert_float(absf(guns[i].beam_color.h - pc.h)).is_greater(0.03)


func test_icons_and_previews_draw_at_every_stage() -> void:
	# Drawing every token at every stage must not error (a canvas outside the tree records nothing).
	var c := Control.new()
	add_child(c)
	var drawn := [0]
	c.draw.connect(func() -> void:
		for g in Zapper.load_guns():
			for i in 11:
				Pictos.gun_preview(c, g, Rect2(0, 0, 80, 80), i / 10.0)
				drawn[0] += 1
			Pictos.gun_icon(c, g, Rect2(0, 0, 40, 40), 0.5))
	c.queue_redraw()
	await await_idle_frame()
	await await_idle_frame()
	assert_int(drawn[0]).is_equal(77)
	c.free()


# --- PT10-1 / PT10-2: the wheel and the switch preview -------------------------------------------

func test_flicking_the_belt_pops_the_wheel_spins_from_the_old_gun_and_plays_the_preview() -> void:
	await _boot_two()
	var z: Zapper = _main.zapper(P1)
	var hud := _hud()
	assert_bool(hud.wheel_showing(P1)).is_false()
	z.set_gun(0, false)
	await step(1)
	z.set_gun(2)
	assert_bool(Audio.played("wheel_move")).is_true()
	assert_bool(hud.wheel_showing(P1)).is_true()
	assert_bool(hud.wheel_showing(P2)).is_false()
	assert_int(hud._wheel_from[P1]).is_equal(0)   # the ring turns from where it was
	assert_float(hud._badge_age[P1]).is_less(0.05)   # and the corner badge punches
	# The preview plays 1-2 s (picture only, by the player), then the wheel is gone.
	assert_float(GunWheel.PREVIEW_TIME).is_between(1.0, 2.0)
	hud._process(GunWheel.PREVIEW_TIME * 0.5)
	assert_bool(hud.wheel_showing(P1)).is_true()
	hud._process(GunWheel.PREVIEW_TIME * 0.6)
	assert_bool(hud.wheel_showing(P1)).is_false()


# --- PT10-2: the first-fire beat ----------------------------------------------------------------

func test_the_first_zap_of_each_gun_gets_a_beat_once_per_player() -> void:
	await _boot_two()
	var hud := _hud()
	var z: Zapper = _main.zapper(P1)
	var cow: Node3D = _main.level.object(&"cow")
	z.set_gun(0, false)
	assert_bool(hud.on_zapped(P1, z.gun().id, null)).is_false()   # a zap at nothing keeps the beat
	assert_bool(hud.on_zapped(P1, z.gun().id, cow)).is_true()
	assert_int(hud._beats.size()).is_equal(1)
	assert_bool(Audio.played("card_view")).is_true()
	assert_bool(hud.on_zapped(P1, z.gun().id, cow)).is_false()   # once
	z.set_gun(4, false)
	assert_bool(hud.on_zapped(P1, z.gun().id, cow)).is_true()     # each gun has its own
	var z2: Zapper = _main.zapper(P2)
	z2.set_gun(0, false)
	assert_bool(hud.on_zapped(P2, z2.gun().id, cow)).is_true()    # and each player
	hud._process(Hud.BEAT_TIME + 0.1)
	assert_int(hud._beats.size()).is_equal(0)


func test_a_real_zap_from_the_zapper_reaches_the_beat() -> void:
	await _boot_two()
	var hud := _hud()
	var z: Zapper = _main.zapper(P1)
	var crate: PhysicsObject = _main.level.object(&"crate")
	z.global_position = Vector3(0, 0.1, 0)
	crate.global_position = Vector3(2.5, 0.6, 0)
	z.set_gun(2, false)   # bouncy
	z.target = crate
	z._press()
	assert_bool(hud.fired.has("%d:%s" % [P1, z.gun().id])).is_true()


# --- PT10-2: beams and hits ------------------------------------------------------------------

func test_each_gun_has_its_own_beam_pattern_and_hit() -> void:
	await _boot_two()
	var z: Zapper = _main.zapper(P1)
	var crate: PhysicsObject = _main.level.object(&"crate")
	var patterns := {}
	for i in z.guns.size():
		z.set_gun(i, false)
		var mat := z._beam_mat
		assert_object(mat.shader).is_equal(Zapper.BEAM_SHADER)
		assert_int(mat.get_shader_parameter(&"pattern")).is_equal(int(z.gun().kind))
		assert_object(mat.get_shader_parameter(&"color")).is_equal(z.gun().beam_color)
		patterns[mat.get_shader_parameter(&"pattern")] = true
	assert_int(patterns.size()).is_equal(7)
	# A landed zap plays that gun's own hit.
	for i in [2, 4, 6]:   # bouncy, freeze, magnet: single-target toggles
		z.set_gun(i, false)
		GunHits.last_kind = -1
		z.target = crate
		z._press()
		assert_int(GunHits.last_kind).is_equal(int(z.gun().kind))
		z._press()   # undo it again


func test_gun_hits_play_for_every_kind_without_a_scene() -> void:
	for k in GunData.Kind.values():
		GunHits.play(null, k, Vector3.ZERO, Color.WHITE)
		assert_int(GunHits.last_kind).is_equal(k)


# --- PT10-3: goal cards ---------------------------------------------------------------------

func test_every_card_names_a_real_gun_and_draws_as_a_picture() -> void:
	var guns := {}
	for g in Zapper.load_guns():
		guns[g.id] = g
		guns[g.effect_id()] = g
	var deck := GoalDeck.new()
	add_child(deck)
	assert_int(deck.cards.size()).is_greater_equal(30)
	var c := Control.new()
	add_child(c)
	var drawn := [0]
	c.draw.connect(func() -> void:
		for id in deck.cards:
			Pictos.card(c, deck.cards[id], Rect2(0, 0, 220, 220), guns)
			Pictos.card_stamp(c, Rect2(0, 0, 220, 220), drawn[0] % 2 == 0, 0.5)
			drawn[0] += 1)
	c.queue_redraw()
	await await_idle_frame()
	await await_idle_frame()
	assert_int(drawn[0]).is_equal(deck.cards.size())
	for id in deck.cards:
		var g: GoalData = deck.cards[id]
		var gun := CardArt.gun_for(g)
		# Every card shows which gun does it, except the chain reaction (no zap allowed).
		if id == &"b3_chain_ball":
			assert_str(String(gun)).is_empty()
		else:
			assert_bool(guns.has(gun)).override_failure_message("%s: no gun token (%s)" % [id, gun]).is_true()
		# Drawn live: a pictured card, or one CardArt draws from its condition.
		assert_bool(CardArt.CARDS.has(id) or CardArt.handles(g)).override_failure_message("%s has no picture" % id).is_true()
	c.free()
	deck.free()


func test_done_stamps_the_card_then_flips_to_the_next_on_the_fence_and_hud() -> void:
	await _boot_two()
	var hud := _hud()
	var deck: GoalDeck = _main.level.deck
	var fence: FenceCard = _main.level.card
	var first := deck.current()
	deck.complete()
	assert_bool(Audio.played("card_done")).is_true()
	assert_str(hud.card_mode).is_equal("done")
	assert_object(hud._card).is_same(first)          # the finished card stays up under its stamp
	assert_str(fence.stamped()).is_equal("done")
	assert_object(fence._face_goal).is_same(first)
	hud._process(Hud.CARD_DONE + 0.05)
	assert_str(hud.card_mode).is_equal("")
	assert_object(hud._card).is_same(deck.current())
	fence._process(FenceCard.STAMP_FOR + 0.01)
	await get_tree().create_timer(0.5).timeout     # the flip tween swaps the face halfway
	assert_str(fence.stamped()).is_equal("")
	assert_object(fence._face_goal).is_same(deck.current())


func test_zapping_the_fence_card_skips_it_with_a_raspberry_and_a_drop_in() -> void:
	await _boot_two()
	var hud := _hud()
	var deck: GoalDeck = _main.level.deck
	var fence: FenceCard = _main.level.card
	var first := deck.current()
	fence.zapped_by(_main.zapper(P1), _main.zapper(P1).gun())
	assert_bool(Audio.played("card_skip")).is_true()
	assert_object(deck.current()).is_not_same(first)
	assert_str(hud.card_mode).is_equal("skip")
	assert_str(fence.stamped()).is_equal("skip")
	hud._process(Hud.CARD_SKIP + 0.05)
	assert_str(hud.card_mode).is_equal("")
	assert_object(hud._card).is_same(deck.current())


func test_the_trophy_shelf_shows_a_done_card_in_the_same_art() -> void:
	await _boot_two()
	var deck: GoalDeck = _main.level.deck
	var shelf: TrophyShelf = _main.level.card.shelf
	var first := deck.current()
	deck.complete()
	shelf.zapped_by(_main.zapper(P1), null)
	assert_str(String(shelf.showing())).is_equal(String(first.id))
	await await_idle_frame()   # _draw_card runs Pictos.card + the done rosette without error
