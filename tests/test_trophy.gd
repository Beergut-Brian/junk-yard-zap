## Trophy lane (jyz-trophy-1, G-13): the done pile on the front fence opens a trophy shelf. Finished
## cards in the order he finished them, then the rest of the deck as silhouettes; the stick flips and
## stops at the ends, A looks up close, B puts it back and closes. Uses its own save profile and
## settings file, never the family's.
class_name TestTrophy
extends GdUnitTestSuite

const REAL_SETTINGS := "user://settings.json"

var world: Node3D
var _real_profile := ""
var _real_settings := ""
var _real_settings_mtime := 0
var _state: Game.State


func before() -> void:
	_real_profile = Save.profile
	Save.profile = "gdunit_trophy"
	_real_settings = Save.settings_path
	_real_settings_mtime = FileAccess.get_modified_time(REAL_SETTINGS) if FileAccess.file_exists(REAL_SETTINGS) else 0
	Save.settings_path = "user://test_settings_trophy.json"
	Save.wipe_settings()


func after() -> void:
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Save.profile = _real_profile


func before_test() -> void:
	Players.reset()
	Game.demo = false
	_state = Game.state
	Audio.history.clear()
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	get_tree().paused = false
	Game.state = _state
	Game.demo = false
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()


func level() -> YardLevel:
	var l := YardLevel.new()
	l.use_save = false
	l.layout = load(YardLevel.LAYOUT)
	world.add_child(l)
	var players := Node3D.new()
	players.name = "Players"
	l.add_child(players)
	return l


func shelf_of(l: YardLevel) -> TrophyShelf:
	var s := l.card.pile.shelf
	s.read_pads = false   # the test drives it, not whatever pad is plugged in
	return s


func test_the_pile_sits_by_the_card_and_is_a_zap_target() -> void:
	var l := level()
	var pile := l.card.pile
	assert_object(pile).is_not_null()
	assert_bool(pile.is_in_group(&"zap_targets")).is_true()
	assert_float(absf(pile.global_position.x - l.card.global_position.x)).is_less(2.5)
	assert_float(pile.global_position.x).is_greater(YardLevel.LEFT)   # inside the fence
	assert_float(pile.global_position.y).is_between(0.0, 1.0)   # on the ground, where a player aims
	assert_int(pile.count()).is_equal(0)


func test_the_shelf_lists_the_finished_cards_in_order() -> void:
	var l := level()
	var d := l.deck
	var first := d.current().id
	d.skip()                       # the top card goes to the back
	var a := d.current().id
	d.complete()
	var b := d.current().id
	d.complete()
	d.skip()
	var c := d.order[d.order.size() - 1]   # just skipped, still to win
	assert_int(l.card.pile.count()).is_equal(2)   # one card on the box per trophy
	var s := shelf_of(l)
	s.open(Players.P1)
	assert_array(s.finished_ids()).is_equal([a, b] as Array[StringName])
	assert_int(s.entries().size()).is_equal(d.cards.size())   # the whole deck, one slot each
	assert_bool(s.entries()[0].done).is_true()
	assert_bool(s.entries()[1].done).is_true()
	for i in range(2, s.entries().size()):
		assert_bool(s.entries()[i].done).is_false()
	# The rest follow in stack order: the card on top next, the skipped ones at the end.
	assert_str(String(s.entries()[2].id)).is_equal(String(d.order[0]))
	assert_str(String(s.entries()[s.entries().size() - 1].id)).is_equal(String(c))
	assert_bool(s.entries().any(func(e: Dictionary) -> bool: return e.id == first)).is_true()
	# Finished cards show their picture; the rest are silhouettes.
	assert_object(s.card_node(0).material).is_null()
	assert_object(s.card_node(1).material).is_null()
	assert_object(s.card_node(2).material).is_instanceof(ShaderMaterial)
	assert_int(s.focus).is_equal(1)   # opens on his newest trophy
	s.close()


func test_flipping_stops_at_the_ends() -> void:
	var l := level()
	var s := shelf_of(l)
	s.open(Players.P1)
	var n := s.entries().size()
	assert_int(s.focus).is_equal(0)   # nothing finished: the first card in the stack
	assert_bool(s.flip(-1)).is_false()
	assert_int(s.focus).is_equal(0)
	assert_bool(Audio.played("boing")).is_true()
	Audio.history.clear()
	assert_bool(s.flip(1)).is_true()
	assert_int(s.focus).is_equal(1)
	assert_bool(Audio.played("wheel_move")).is_true()
	for i in n + 5:
		s.flip(1)
	assert_int(s.focus).is_equal(n - 1)   # no wrap: it stops on the last card
	assert_bool(s.flip(1)).is_false()
	assert_int(s.focus).is_equal(n - 1)
	s.flip(-1)
	assert_int(s.focus).is_equal(n - 2)
	s.close()


func test_a_looks_up_close_and_b_backs_out() -> void:
	var l := level()
	l.deck.complete()
	var s := shelf_of(l)
	s.open(Players.P2)
	assert_bool(s.is_open).is_true()
	assert_bool(Audio.played("card_view")).is_true()
	s.look()
	assert_bool(s.up_close).is_true()
	assert_float(float(s.slot(s.focus)[1])).is_equal(TrophyShelf.CLOSE_SCALE)
	assert_bool(s.flip(1)).is_false()     # up close holds still
	s.back()                              # B: the card goes back on the shelf
	assert_bool(s.up_close).is_false()
	assert_bool(s.is_open).is_true()
	s.back()                              # B again: the shelf closes
	assert_bool(s.is_open).is_false()
	assert_bool(Audio.played("drop")).is_true()


func test_zapping_the_pile_opens_the_shelf_and_holds_the_yard() -> void:
	var l := level()
	var s := shelf_of(l)
	var gun: GunData = l.guns_by_effect.values()[0]
	var zapper := Node3D.new()
	world.add_child(zapper)
	l.card.pile.zapped_by(zapper, gun)
	assert_bool(s.is_open).is_true()
	assert_bool(s.visible).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(l.deck.done.size()).is_equal(0)          # the pile never changes the game
	assert_int(l.deck.order.size()).is_equal(l.deck.cards.size())
	s.close()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(get_tree().paused).is_false()           # no button held: the yard runs again


func test_pause_closes_the_shelf() -> void:
	var l := level()
	var s := shelf_of(l)
	Game.state = Game.State.PLAYING
	s.open(Players.P1)
	Game.pause()
	assert_bool(s.is_open).is_false()
	assert_bool(get_tree().paused).is_true()            # the pause menu keeps the yard held
	Game.resume()
	assert_bool(get_tree().paused).is_false()


func test_demo_bots_dont_get_stuck_in_the_shelf() -> void:
	var l := level()
	var s := shelf_of(l)
	Game.demo = true
	s.open(Players.P1)
	assert_bool(s.is_open).is_true()
	s._process(TrophyShelf.DEMO_CLOSE + 0.1)
	assert_bool(s.is_open).is_false()


func test_the_settings_file_is_not_the_real_one() -> void:
	assert_str(Save.settings_path).is_not_equal(REAL_SETTINGS)
	assert_str(Save.settings_path).is_not_equal(_real_settings)
	assert_str(Save.profile).is_not_equal(_real_profile)
	var l := level()
	var s := shelf_of(l)
	s.open(Players.P1)
	s.flip(1)
	s.close()
	var now := FileAccess.get_modified_time(REAL_SETTINGS) if FileAccess.file_exists(REAL_SETTINGS) else 0
	assert_int(now).is_equal(_real_settings_mtime)   # the family's settings were never written


func test_a_player_can_aim_at_the_pile_and_still_at_the_card() -> void:
	var l := level()
	var targets := get_tree().get_nodes_in_group(&"zap_targets")
	var pile := l.card.pile
	var card := l.card
	assert_float(pile.global_position.x).is_less(card.global_position.x)   # the fence corner side
	# Walked up under the card, aiming down-left at the box: the pile.
	var under := Vector3(card.global_position.x, 1.0, 0.0)
	assert_object(Aim.pick(under, _dir(under, pile), targets)).is_same(pile)
	# From the yard side, flat left or straight at the card: still the card (skipping is unchanged).
	for dx in [2.0, 3.5, 5.0]:
		var o := Vector3(card.global_position.x + dx, 1.0, 0.0)
		assert_object(Aim.pick(o, Vector2.LEFT, targets)).is_same(card)
		assert_object(Aim.pick(o, _dir(o, card), targets)).is_same(card)


func _dir(from: Vector3, to: Node3D) -> Vector2:
	return Vector2(to.global_position.x - from.x, to.global_position.y - from.y)
