## The goal-card stack on the front fence: the top card big enough to read from the sofa, drawn by
## Pictos.card into a SubViewport. Zap it with any gun to skip (it goes to the back of the stack).
## Pops up bigger when a player walks up to it.
class_name FenceCard
extends Node3D

const VIEW_DIST := 5.0
const PX := 512

var deck: GoalDeck
var guns_by_effect := {}
var _vp: SubViewport
var _face: Control
var _sprite: Sprite3D
var _viewed := false
## G-13: the done pile, a shelf you can flip through (scripts/levels/trophy_shelf.gd).
var shelf: TrophyShelf
var _hint_t := 0.0
## PT10-3: what the face shows, and a stamp on it ("done" / "skip") for a beat before the next card.
var _face_goal: GoalData
var _stamp := ""
var _stamp_t := 0.0
const STAMP_FOR := 1.2


func _ready() -> void:
	add_to_group(&"zap_targets")
	_vp = SubViewport.new()
	_vp.size = Vector2i(PX, PX)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_face = Control.new()
	_face.size = Vector2(PX, PX)
	_face.draw.connect(func() -> void:
		var r := Rect2(Vector2(PX, PX) * 0.04, Vector2(PX, PX) * 0.92)
		Pictos.card(_face, _face_goal, r, guns_by_effect)
		if _stamp != "":
			Pictos.card_stamp(_face, r, _stamp == "done", _stamp_t / 0.22))
	_vp.add_child(_face)
	_sprite = Sprite3D.new()
	_sprite.texture = _vp.get_texture()
	_sprite.pixel_size = 2.0 / PX   # PT10-3: the framed card reads as big as the old bare picture
	_sprite.shaded = false
	_sprite.position.z = 0.05
	add_child(_sprite)
	# The done pile: the trophy shelf under the card's right corner. Zap it to flip through.
	shelf = TrophyShelf.new()
	shelf.name = "TrophyShelf"
	shelf.deck = deck
	shelf.guns_by_effect = guns_by_effect
	shelf.position = Vector3(1.55, -1.0, 0.15)
	add_child(shelf)
	if deck:
		_face_goal = deck.current()
		deck.goal_completed.connect(func(id: StringName) -> void: _stamp_on("done", id))
		deck.goal_skipped.connect(func(id: StringName) -> void: _stamp_on("skip", id))
		deck.card_changed.connect(func(g: GoalData) -> void:
			if _stamp == "":
				_face_goal = g
				_face.queue_redraw())


## The finished (or skipped) card keeps its face under the stamp for a beat, then flips to the next.
func _stamp_on(kind: String, id: StringName) -> void:
	_face_goal = deck.cards.get(id, _face_goal)
	_stamp = kind
	_stamp_t = 0.0
	_face.queue_redraw()
	if kind == "done":
		var tw := create_tween()
		tw.tween_property(_sprite, "scale", _sprite.scale * 1.25, 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sprite, "scale", _sprite.scale, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Flip on the vertical axis, swapping the face to the deck's top card halfway.
func _flip_to_current() -> void:
	var tw := create_tween()
	tw.tween_property(_sprite, "rotation:y", PI * 0.5, 0.15).from(0.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_stamp = ""
		_face_goal = deck.current() if deck else null
		_face.queue_redraw())
	tw.tween_property(_sprite, "rotation:y", 0.0, 0.2).from(-PI * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## True while a done / skip stamp is on the face.
func stamped() -> String:
	return _stamp


func radius() -> float:
	return 1.0


func zapped_by(_z: Node, _gun: GunData) -> void:
	if deck and deck.current():
		Fx.burst(get_tree(), global_position, Color(1, 0.9, 0.6), 16, 0.8, 0.5)
		deck.skip()
	else:
		Audio.play("sparkle", global_position)


func _process(delta: float) -> void:
	if _stamp != "":
		_stamp_t += delta
		if _stamp_t < 0.3:
			_face.queue_redraw()   # the stamp slams on
		if _stamp_t >= (STAMP_FOR if _stamp == "done" else 0.45) and _stamp_t - delta < (STAMP_FOR if _stamp == "done" else 0.45):
			_flip_to_current()
	_hint_t -= delta
	if _viewed and _hint_t <= 0.0 and deck and deck.current():
		_hint_t = 1.2
		for o in get_tree().get_nodes_in_group(PhysicsObject.GROUP):   # hint_objects glow softly
			for h in deck.current().hint_objects:
				if Goals.matches(o, h):
					Fx.sparkle(get_tree(), (o as Node3D).global_position + Vector3(0, 0.6, 0))
	var near := false
	for z in get_tree().get_nodes_in_group(Zapper.GROUP):
		if not (z as Zapper).asleep and absf((z as Node3D).global_position.x - global_position.x) < VIEW_DIST:
			near = true
	if near != _viewed:
		_viewed = near
		if near:   # PT10-3: looking at the card is an event: it flips round to face you
			Audio.play("card_view", global_position)
			create_tween().tween_property(_sprite, "rotation:y", 0.0, 0.45).from(-TAU).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		create_tween().tween_property(_sprite, "scale", Vector3.ONE * (1.5 if near else 1.0), 0.25) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func viewed() -> bool:
	return _viewed
