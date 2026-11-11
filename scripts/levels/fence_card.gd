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
		Pictos.card(_face, deck.current() if deck else null, Rect2(Vector2.ZERO, Vector2(PX, PX)), guns_by_effect))
	_vp.add_child(_face)
	_sprite = Sprite3D.new()
	_sprite.texture = _vp.get_texture()
	_sprite.pixel_size = 1.8 / PX
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
		deck.card_changed.connect(func(_g: GoalData) -> void:
			_face.queue_redraw())


func radius() -> float:
	return 1.0


func zapped_by(_z: Node, _gun: GunData) -> void:
	if deck and deck.current():
		Fx.burst(get_tree(), global_position, Color(1, 0.9, 0.6), 16, 0.8, 0.5)
		var tw := create_tween()
		tw.tween_property(_sprite, "rotation:y", TAU, 0.35).from(0.0)
		deck.skip()
	else:
		Audio.play("sparkle", global_position)


func _process(delta: float) -> void:
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
		if near:
			Audio.play("card_view", global_position)
		create_tween().tween_property(_sprite, "scale", Vector3.ONE * (1.5 if near else 1.0), 0.25) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func viewed() -> bool:
	return _viewed
