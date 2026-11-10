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
var _pile: Node3D


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
	# The done pile: a little stack that grows beside the card.
	_pile = Node3D.new()
	_pile.position = Vector3(1.4, -0.7, 0.05)
	add_child(_pile)
	if deck:
		deck.card_changed.connect(func(_g: GoalData) -> void:
			_face.queue_redraw()
			_refresh_pile())
	_refresh_pile()


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


func _process(_delta: float) -> void:
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


func _refresh_pile() -> void:
	for c in _pile.get_children():
		c.queue_free()
	var n := deck.done.size() if deck else 0
	for i in n:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.06, 0.4)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.98, 0.95, 0.86)
		mi.material_override = mat
		mi.position = Vector3(0, i * 0.07, 0)
		mi.rotation.y = randf_range(-0.2, 0.2)
		_pile.add_child(mi)
