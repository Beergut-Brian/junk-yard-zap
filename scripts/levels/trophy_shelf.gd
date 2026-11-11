## G-13 (GAME.md "Goal cards": "done cards stay in a pile he can flip through: his trophy shelf").
## A little wooden shelf under the fence card. Every finished card lands on it with a gold star.
## Zap the shelf with any gun and the newest trophy card flips up big above it, with a page-flip
## sound and gold sparkles; each zap after that flips back one card, round and round. It folds
## itself away after SHOW_FOR seconds of no zaps. Nothing to read, nothing to lose.
class_name TrophyShelf
extends Node3D

const SHOW_FOR := 5.0
const PX := 384
const CARD_SIZE := 1.4   # metres across when flipped up
const GOLD := Color("#ffc93a")
const MAX_PILE := 12     # cards drawn on the shelf; more still flip, the pile just stops growing

var deck: GoalDeck
var guns_by_effect := {}
var shown := -1          # index into deck.done of the flipped-up card, -1 when folded away
var _left := 0.0
var _vp: SubViewport
var _face: Control
var _sprite: Sprite3D
var _pile: Node3D
var _star: MeshInstance3D


func _ready() -> void:
	add_to_group(&"zap_targets")
	var plank := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.9, 0.08, 0.45)
	plank.mesh = pm
	plank.material_override = _mat(Color("#a8703f"))
	plank.position.y = -0.06
	add_child(plank)
	_pile = Node3D.new()
	add_child(_pile)
	_vp = SubViewport.new()
	_vp.size = Vector2i(PX, PX)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	_face = Control.new()
	_face.size = Vector2(PX, PX)
	_face.draw.connect(_draw_card)
	_vp.add_child(_face)
	_sprite = Sprite3D.new()
	_sprite.texture = _vp.get_texture()
	_sprite.pixel_size = CARD_SIZE / PX
	_sprite.shaded = false
	_sprite.position = Vector3(1.05, 1.35, 0.35)   # up and to the right: never over the goal card
	_sprite.scale = Vector3.ZERO
	_sprite.visible = false
	add_child(_sprite)
	if deck:
		deck.card_changed.connect(func(_g: GoalData) -> void: refresh())
	refresh()


func radius() -> float:
	return 0.55


func count() -> int:
	return deck.done.size() if deck else 0


## The id of the card flipped up right now (&"" when folded away).
func showing() -> StringName:
	return deck.done[shown] if shown >= 0 and shown < count() else &""


func zapped_by(_z: Node, _gun: GunData) -> void:
	var n := count()
	if n == 0:   # an empty shelf still answers: a sparkle and a little puff
		Audio.play("sparkle", global_position)
		Fx.burst(get_tree(), global_position + Vector3(0, 0.2, 0), GOLD, 8, 0.4, 0.4)
		return
	# First zap: the newest card. Each zap after: one older, wrapping back to the newest.
	shown = n - 1 if shown < 0 else (shown - 1 + n) % n
	_left = SHOW_FOR
	_face.queue_redraw()
	Audio.play("card_view", global_position)
	Fx.burst(get_tree(), global_position + _sprite.position, GOLD, 14, 0.7, 0.5)
	_sprite.visible = true
	var tw := create_tween().set_parallel()
	tw.tween_property(_sprite, "rotation:y", 0.0, 0.3).from(-PI * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "scale", Vector3.ONE, 0.25).from(Vector3.ONE * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if shown < 0:
		return
	_left -= delta
	if _left <= 0.0:
		fold()


## Fold the flipped-up card back down onto the shelf.
func fold() -> void:
	if shown < 0:
		return
	shown = -1
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _sprite.visible = shown >= 0)


func refresh() -> void:
	for c in _pile.get_children():
		c.queue_free()
	var n := count()
	if shown >= n:
		shown = -1
		_sprite.visible = false
		_sprite.scale = Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in mini(n, MAX_PILE):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.05, 0.36)
		mi.mesh = bm
		mi.material_override = _mat(Color(0.98, 0.95, 0.86))
		mi.position = Vector3(0, 0.03 + i * 0.055, 0)
		mi.rotation.y = rng.randf_range(-0.2, 0.2)
		_pile.add_child(mi)
	if n > 0:   # a gold star sticker on top: these are trophies
		var star := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.12
		sm.bottom_radius = 0.12
		sm.height = 0.02
		sm.radial_segments = 5
		star.mesh = sm
		star.material_override = _mat(GOLD, 0.4)
		star.position = Vector3(0, 0.03 + mini(n, MAX_PILE) * 0.055 + 0.01, 0)
		_pile.add_child(star)


func _draw_card() -> void:
	var g: GoalData = deck.cards.get(showing()) if deck and shown >= 0 else null
	if g == null:
		return
	# PT10-3: the same card art as the fence and the HUD, a gold rim and the done rosette in the
	# corner: a trophy, not the card to do next.
	var r := Rect2(Vector2.ZERO, Vector2(PX, PX)).grow(-18)
	Pictos._rrect(_face, r.grow(10), Pictos.GOLD, PX * 0.12)
	Pictos.card(_face, g, r, guns_by_effect)
	var badge := Rect2(r.end - Vector2(PX, PX) * 0.42, Vector2(PX, PX) * 0.5)
	_face.draw_set_transform(Vector2.ZERO)
	Pictos.card_stamp(_face, Rect2(badge.position - Vector2(0, badge.size.y * 0.25), badge.size), true, 1.0)


static func _mat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m
