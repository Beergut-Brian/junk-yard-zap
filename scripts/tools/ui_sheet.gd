## A contact sheet of the in-game UI pieces (jyz-ui-1), so a lane can look at them with real pixels:
## the seven gun icons at wheel and corner size, the belt wheel open, the switch-preview frames, and
## the goal cards at fence size, incl. the done and skip states. Needs a renderer:
##   godot-render --path . --resolution 1920x1080 res://scripts/tools/ui_sheet.tscn -- --sheet=<png> [--part=icons|cards]
extends Control

var _guns: Array[GunData] = []
var _by_effect := {}
var _deck: GoalDeck
var _part := "icons"
var _t := 0.0

const CARDS: Array[StringName] = [&"b1_big_cow", &"b1_freeze_cow", &"b1_tub_ball", &"b1_float_chicken",
		&"b1_glue_two", &"b2_cow_car", &"b2_float_car", &"b2_giant_chicken", &"b1_tiny_car", &"b2_car_over_fence"]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_guns = Zapper.load_guns()
	for g in _guns:
		_by_effect[g.id] = g
		_by_effect[g.effect_id()] = g
	_deck = GoalDeck.new()
	_deck.checking = false
	add_child(_deck)
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sheet="):
			path = a.trim_prefix("--sheet=")
		elif a.begins_with("--part="):
			_part = a.trim_prefix("--part=")
	_shoot.call_deferred(path)


func _shoot(path: String) -> void:
	get_tree().create_timer(20.0).timeout.connect(get_tree().quit)
	for i in 4:
		await get_tree().process_frame
	queue_redraw()
	await RenderingServer.frame_post_draw
	if path != "":
		get_viewport().get_texture().get_image().save_png(path)
		print("sheet ", path)
	get_tree().quit()


func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.42, 0.62, 0.45))   # a grassy yard-ish backdrop
	draw_rect(Rect2(Vector2(0, vs.y * 0.5), Vector2(vs.x, vs.y * 0.5)), Color(0.55, 0.45, 0.32))
	if _part == "cards":
		_draw_cards(vs)
	else:
		_draw_icons(vs)


func _draw_icons(vs: Vector2) -> void:
	# Row 1: each icon at 150 px (wheel size). Row 2: the same at 72 px (HUD corner).
	for i in _guns.size():
		var c := Vector2(150 + i * 250, 150)
		Pictos.gun_icon(self, _guns[i], Rect2(c - Vector2(75, 75), Vector2(150, 150)))
		Pictos.gun_icon(self, _guns[i], Rect2(c + Vector2(-36, 140), Vector2(72, 72)))
	# The wheel, open, around a stand-in head, for gun 0 and gun 3.
	var hud := Hud.new()
	for k in 2:
		var at := Vector2(420 + k * 700, 720)
		draw_circle(at + Vector2(0, 150), 50, Color(0.3, 0.75, 0.35))
		if hud.has_method(&"draw_wheel_at"):
			hud.call(&"draw_wheel_at", self, _guns, k * 3, at, Players.COLOR[k], 1.0)
	hud.free()
	# Switch preview frames, one row per gun (if the preview exists).
	var px := Pictos.new()
	if px.has_method(&"gun_preview"):
		for i in _guns.size():
			for f in 5:
				var r := Rect2(Vector2(1440 + f * 92, 430 + i * 92), Vector2(84, 84))
				px.call(&"gun_preview", self, _guns[i], r, f / 4.0)


func _draw_cards(vs: Vector2) -> void:
	var s := 330.0
	for i in CARDS.size():
		var g: GoalData = _deck.cards.get(CARDS[i])
		var r := Rect2(Vector2(40 + (i % 5) * (s + 40), 60 + (i / 5) * (s + 140)), Vector2(s, s))
		Pictos.card(self, g, r, _by_effect)
	# The corner size (HUD): the first five at 220.
	for i in 5:
		var g: GoalData = _deck.cards.get(CARDS[i])
		Pictos.card(self, g, Rect2(Vector2(40 + i * 260, vs.y - 250), Vector2(220, 220)), _by_effect)
	var px := Pictos.new()
	if px.has_method(&"card_stamp"):
		var g: GoalData = _deck.cards.get(CARDS[0])
		var r := Rect2(Vector2(1380, vs.y - 250), Vector2(220, 220))
		Pictos.card(self, g, r, _by_effect)
		px.call(&"card_stamp", self, r, true, 1.0)
		r.position.x += 260
		Pictos.card(self, g, r, _by_effect)
		px.call(&"card_stamp", self, r, false, 1.0)
