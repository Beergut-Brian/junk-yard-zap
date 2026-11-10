## The done pile beside the goal card (G-13): a little wooden trophy box with a gold star on it, and
## the finished cards stacked on top, one per trophy. Zap it with any gun and the trophy shelf opens
## (TrophyShelf). It never changes the yard or the deck.
## Screenshots: `-- --shelf=open|close [--shelf-done=N]` finishes the first N cards (dev only, for
## frames) and opens the shelf a second in, `close` then looks at the focused card up close.
class_name TrophyPile
extends Node3D

const BOX := Vector3(1.1, 0.55, 0.6)

var deck: GoalDeck
var guns_by_effect := {}
var shelf: TrophyShelf
var _stack: Node3D
var _box: Node3D
var _spin: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group(&"zap_targets")
	_box = Node3D.new()
	_box.position.y = -BOX.y * 0.5 - 0.02   # this node is the box's middle; the box stands on the ground
	add_child(_box)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.62, 0.38, 0.2)
	_mesh(_box, BoxMesh.new(), Vector3(0, BOX.y * 0.5, 0), BOX, wood)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.8, 0.2)
	gold.metallic = 0.4
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.75, 0.2)
	gold.emission_energy_multiplier = 0.25
	var star := MeshInstance3D.new()
	star.mesh = _star_mesh(0.22, 0.05)
	star.material_override = gold
	star.position = Vector3(0, BOX.y * 0.5, BOX.z * 0.5 + 0.03)
	_box.add_child(star)
	# A big gold star on a post: above whatever junk is parked in front of the box.
	_mesh(_box, BoxMesh.new(), Vector3(-BOX.x * 0.38, BOX.y + 0.5, 0), Vector3(0.07, 1.0, 0.07), wood)
	var top := MeshInstance3D.new()
	top.mesh = _star_mesh(0.34, 0.06)
	top.material_override = gold
	top.position = Vector3(-BOX.x * 0.38, BOX.y + 1.05, 0.0)
	_box.add_child(top)
	_spin = top
	_stack = Node3D.new()
	_stack.position = Vector3(0, BOX.y, 0)
	_box.add_child(_stack)
	shelf = TrophyShelf.new()
	shelf.name = "TrophyShelf"
	shelf.deck = deck
	shelf.guns_by_effect = guns_by_effect
	add_child(shelf)
	if deck:
		deck.card_changed.connect(func(_g: GoalData) -> void: refresh())
	refresh()
	_dev_shots.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _spin:   # a slow wobble so the star catches the eye
		_spin.rotation.z = sin(_t * 1.6) * 0.18


func radius() -> float:
	return 0.8


func zapped_by(z: Node, _gun: GunData) -> void:
	Fx.burst(get_tree(), global_position + Vector3(0, 0.6, 0), Color(1, 0.85, 0.3), 14, 0.7, 0.45)
	var tw := create_tween()
	tw.tween_property(_box, "scale", Vector3(1.15, 0.85, 1.15), 0.08)
	tw.tween_property(_box, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	shelf.open(int(z.get(&"player")) if z and z.get(&"player") != null else -1)


func count() -> int:
	return _stack.get_child_count() if _stack else 0


## One card on the box per finished goal.
func refresh() -> void:
	if _stack == null:
		return
	for c in _stack.get_children():
		_stack.remove_child(c)
		c.queue_free()
	var n := deck.done.size() if deck else 0
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.98, 0.95, 0.86)
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		(mi.mesh as BoxMesh).size = Vector3(0.7, 0.05, 0.45)
		mi.material_override = paper
		mi.position = Vector3(0, 0.03 + i * 0.06, 0)
		mi.rotation.y = sin(i * 2.3) * 0.25
		_stack.add_child(mi)


func _mesh(parent: Node3D, m: BoxMesh, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## A flat five-point star facing +z.
static func _star_mesh(r: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for k in 10:
		var rad := r if k % 2 == 0 else r * 0.45
		var a := PI * 0.5 + k * PI / 5.0
		pts.append(Vector3(cos(a) * rad, sin(a) * rad, depth))
	for k in 10:
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3(0, 0, depth))
		st.add_vertex(pts[(k + 1) % 10])
		st.add_vertex(pts[k])
	return st.commit()


func _dev_shots() -> void:
	var mode := ""
	var n := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shelf="):
			mode = a.trim_prefix("--shelf=")
		elif a.begins_with("--shelf-done="):
			n = int(a.trim_prefix("--shelf-done="))
	if mode == "" or deck == null:
		return
	for i in mini(n, deck.order.size()):
		deck.done.append(deck.order.pop_front())
	deck.card_changed.emit(deck.current())
	await get_tree().create_timer(1.0).timeout
	shelf.open(Players.P1)
	if mode == "close":
		await get_tree().create_timer(0.6).timeout
		shelf.look()
