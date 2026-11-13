## The yard (GAME.md "The yard"): about six screens wide, fence to fence, five zones with their
## landmarks (collision here, visuals in YardDressing), the objects from data/yard_layout.tres, the goal deck on
## the front fence, the Reset Yard sign and the tire pile. Owns the yard's save (transforms, sizes,
## effects, glue pairs, deck) and Reset Yard. Built in code so tests can drop a yard into any tree.
class_name YardLevel
extends Node3D

signal zapped(player: int, gun: StringName, target: Node3D)
signal goal_completed(goal_id: StringName)
signal goal_skipped(goal_id: StringName)
signal yard_reset()

const GROUP := &"yard_level"
const LEFT := -48.0
const RIGHT := 48.0
const DEPTH := 8.0
const LID_Y := 22.0
const POND := Vector2(-9.0, 9.0)       # x range of the pond basin
const POND_FLOOR := -2.4
const WATER_Y := -0.35
const RESET_HOLD := 2.0       # seconds; long enough that holding A to grab near the sign never wipes the yard
const RESET_REACH := 1.6
const SIGN_Y := 2.9            # the Reset Yard sign board's centre height (YardDressing, hud ring)
const AUTOSAVE := 30.0
## PF-2: a zap saves the yard this soon after (not up to AUTOSAVE later), so a hard stop (the TV box
## switched off, a killed process) loses at most a few seconds of play.
const SAVE_SOON := 3.0
const SAVE_KEY := "yard"
const LAYOUT := "res://data/yard_layout.tres"

## Zones, left to right: name, x from, x to.
const ZONES := [
	[&"front_gate", -48.0, -29.0],
	[&"scrap_heap", -29.0, -9.0],
	[&"pond", -9.0, 9.0],
	[&"barn", 9.0, 29.0],
	[&"tower", 29.0, 48.0],
]

@export var layout: YardLayout
## Tests: build without the save and autosave.
@export var use_save := true

var deck: GoalDeck
var card: FenceCard
var reset_sign: Node3D
var tire_pile: Node3D
var contraptions: Contraptions
var spawns := {}
var objects := {}     # key -> PhysicsObject
var guns_by_effect := {}
var resets := 0
var _reset_hold := {}   # player -> seconds held
var _autosave := AUTOSAVE
var _restore_on_exit := true


static func find(n: Node) -> YardLevel:
	return n.get_tree().get_first_node_in_group(GROUP) as YardLevel if n.is_inside_tree() else null


func _ready() -> void:
	add_to_group(GROUP)
	if Game.demo:
		use_save = false   # the bots never overwrite the family's yard
	Yard.BOUNDS = AABB(Vector3(LEFT - 4, -8, -8), Vector3(RIGHT - LEFT + 8, LID_Y + 12, 16))
	Yard.GATE = Vector3(-37, 4, 0)
	Yard.water = [AABB(Vector3(POND.x, POND_FLOOR, -DEPTH * 0.5), Vector3(POND.y - POND.x, WATER_Y - POND_FLOOR, DEPTH))]
	Yard.zones.clear()
	for z in ZONES:
		Yard.zones[z[0]] = AABB(Vector3(z[1], -4, -DEPTH), Vector3(z[2] - z[1], LID_Y + 4, DEPTH * 2))
	Yard.zones[&"pond_air"] = AABB(Vector3(POND.x, WATER_Y, -DEPTH), Vector3(POND.y - POND.x, 12, DEPTH * 2))
	if layout == null and ResourceLoader.exists(LAYOUT):
		layout = load(LAYOUT)
	for g in Zapper.load_guns():
		guns_by_effect[g.effect_id()] = g
	_build_world()
	deck = GoalDeck.new()
	deck.name = "GoalDeck"
	add_child(deck)
	deck.goal_completed.connect(_on_goal_completed)
	deck.goal_skipped.connect(func(id: StringName) -> void: goal_skipped.emit(id))
	card = FenceCard.new()
	card.name = "FenceCard"
	card.deck = deck
	card.guns_by_effect = guns_by_effect
	card.position = Vector3(-45.5, 2.6, -0.9)
	add_child(card)
	spawn_layout()
	Audio.music("music_yard")
	if use_save:
		load_yard()
		Game.state_changed.connect(_on_state_changed)
		Game.quit_requested.connect(save_yard)


func _exit_tree() -> void:
	if _restore_on_exit:
		Yard.reset_world()


func _process(delta: float) -> void:
	if not use_save or Game.state != Game.State.PLAYING:
		return
	_autosave -= delta
	if _autosave <= 0.0:
		_autosave = AUTOSAVE
		save_yard()


# ------------------------------------------------------------------------------------- objects

func spawn_layout() -> void:
	if layout == null:
		return
	for e in layout.entries:
		spawn(e)


func spawn(e: YardLayoutEntry) -> PhysicsObject:
	var o: PhysicsObject = LooseBalloon.new(e.object) if e.object is BalloonData else PhysicsObject.new(e.object)
	o.key = e.key
	o.name = String(e.key)
	o.position = e.position
	o.rotation.z = deg_to_rad(e.rotation_deg)
	$Objects.add_child(o)
	objects[e.key] = o
	return o


func object(key: StringName) -> PhysicsObject:
	var o: PhysicsObject = objects.get(key)
	return o if is_instance_valid(o) else null


func clear_objects() -> void:
	for j in get_tree().get_nodes_in_group(&"glue_joints"):
		if is_ancestor_of(j):
			j.free()
	for o in objects.values():
		if is_instance_valid(o):
			o.free()
	objects.clear()


## Everything back to data/yard_layout.tres with the whoosh and bell. The deck stays.
## Three ways in: hold Select 1.5 s (Zapper), hold A on the sign 2 s, or Reset Yard in the pause menu.
## by: the player who did it (a ring in their colour), or null.
func reset_yard(by: Node3D = null) -> void:
	deck.checking = false
	for o in objects.values():
		if is_instance_valid(o):
			Fx.burst(get_tree(), o.global_position, Color(1, 1, 1, 0.7), 10, 1.0, 0.5)
	clear_objects()
	spawn_layout()
	for o in objects.values():
		Fx.burst(get_tree(), o.global_position, Color(0.95, 0.9, 0.6, 0.8), 10, 0.8, 0.5)
	resets += 1
	if by is Zapper:
		Fx.ring(get_tree(), (by as Zapper).center(), Players.COLOR[(by as Zapper).player], 2.2)
	Audio.play("reset_yard")
	Fx.shake(0.6)
	yard_reset.emit()
	get_tree().create_timer(0.5).timeout.connect(func() -> void: deck.checking = true)
	if use_save:
		save_yard()


## Start fresh (FreshStart.start_fresh): the layout's yard and the deck from its first card, as on
## the first day (trophy shelf empty). The whoosh and bell, like Reset Yard. Saves nothing itself.
func fresh_yard() -> void:
	deck.checking = false
	clear_objects()
	spawn_layout()
	var all: Array[GoalData] = []
	for g: GoalData in deck.cards.values():
		all.append(g)
	deck.set_cards(all)
	deck.memory.clear()
	Audio.play("reset_yard")
	Fx.shake(0.4)
	get_tree().create_timer(0.5).timeout.connect(func() -> void: deck.checking = true)


## Restore old yard (FreshStart.restore): the yard rebuilt from what Save holds now.
func reload_from_save() -> void:
	deck.checking = false
	clear_objects()
	spawn_layout()
	deck.memory.clear()
	if not load_yard():
		get_tree().create_timer(0.5).timeout.connect(func() -> void: deck.checking = true)
	Audio.play("reset_yard")
	Fx.shake(0.4)


func near_reset_sign(z: Node3D) -> bool:
	return absf(z.global_position.x - reset_sign.global_position.x) < RESET_REACH and z.global_position.y < 2.5


func reset_hold_begin(player: int) -> void:
	_reset_hold[player] = 0.0
	Audio.play("reset_hold", reset_sign.global_position)


func reset_holding(player: int) -> bool:
	return _reset_hold.has(player)


func reset_hold_step(player: int, delta: float) -> void:
	if not _reset_hold.has(player):
		return
	_reset_hold[player] += delta
	if _reset_hold[player] >= RESET_HOLD:
		_reset_hold.erase(player)
		reset_yard()


func reset_hold_end(player: int) -> void:
	_reset_hold.erase(player)


## 0..1 of the longest current hold, for the ring on the sign.
func reset_progress() -> float:
	var best := 0.0
	for p in _reset_hold:
		best = maxf(best, _reset_hold[p] / RESET_HOLD)
	return best


func _on_goal_completed(id: StringName) -> void:
	Fx.fireworks(get_tree(), card.global_position)
	for z in get_tree().get_nodes_in_group(Zapper.GROUP):
		if not (z as Zapper).asleep:
			Fx.fireworks(get_tree(), (z as Node3D).global_position)
			(z as Zapper).cheer()
	Fx.shake(0.3)
	goal_completed.emit(id)
	if use_save:
		save_yard()


func _on_state_changed(_from: int, to: int) -> void:
	if to == Game.State.PAUSED or to == Game.State.LOBBY:
		save_yard()


func register_zapper(z: Zapper) -> void:
	if not z.zapped.is_connected(_on_zapped):
		z.zapped.connect(_on_zapped)


func _on_zapped(player: int, gun: StringName, target: Node3D) -> void:
	if use_save:
		_autosave = minf(_autosave, SAVE_SOON)
	zapped.emit(player, gun, target)


# ---------------------------------------------------------------------------------------- save

func to_save() -> Dictionary:
	var objs := {}
	var glue := []
	for key in objects:
		var o: PhysicsObject = objects[key]
		if not is_instance_valid(o):
			continue
		var q := o.global_basis.get_rotation_quaternion()
		var p := o.global_position
		var fx := []
		var size := 0
		var parked := false
		for e in o.stack.effects:
			if e is Effects.Balloon:
				parked = e.parked
			if e is Effects.Size:
				size = e.steps
			elif e is Effects.Glue:
				if e.a == o and is_instance_valid(e.b):
					glue.append([String(o.key), String(e.b.key)])
			elif e.id != &"grab":
				fx.append(String(e.id))
		objs[String(key)] = {"p": [p.x, p.y, p.z], "r": [q.x, q.y, q.z, q.w], "size": size, "fx": fx, "parked": parked}
	return {"version": 1, "objects": objs, "glue": glue, "deck": deck.to_save()}


func from_save(d: Dictionary) -> void:
	deck.checking = false
	var objs: Dictionary = d.get("objects", {})
	for key in objs:
		var o := object(StringName(key))
		if o == null:
			continue
		var s: Dictionary = objs[key]
		var p: Array = s.get("p", [0, 0, 0])
		var r: Array = s.get("r", [0, 0, 0, 1])
		o.global_transform = Transform3D(Basis(Quaternion(r[0], r[1], r[2], r[3])), Vector3(p[0], p[1], p[2]))
		o.linear_velocity = Vector3.ZERO
		o.angular_velocity = Vector3.ZERO
		o.restore_size(int(s.get("size", 0)))
		for id in s.get("fx", []):
			if not o.stack.has(StringName(id)):
				Effects.zap(StringName(id), o)
		var balloon: Effects.Balloon = o.stack.get_effect(&"balloon")
		if balloon and s.get("parked", false):   # stays where it floated to, no second climb
			balloon.parked = true
			o.stack.recompute()
	for pair in d.get("glue", []):
		var a := object(StringName(pair[0]))
		var b := object(StringName(pair[1]))
		if a and b:
			Effects.glue(a, b)
	if d.has("deck"):
		deck.from_save(d["deck"])
	get_tree().create_timer(0.5).timeout.connect(func() -> void: deck.checking = true)


func save_yard() -> void:
	Save.set_value(SAVE_KEY, to_save())
	Save.flush()


func load_yard() -> bool:
	var d = Save.get_value(SAVE_KEY)
	if d is Dictionary and int(d.get("version", 0)) == 1:
		from_save(d)
		return true
	return false


# --------------------------------------------------------------------------------------- world

func _build_world() -> void:
	var objs := Node3D.new()
	objs.name = "Objects"
	add_child(objs)
	var st := Node3D.new()
	st.name = "Static"
	add_child(st)
	# Collision only: every visual is YardDressing (the Golden Afternoon diorama, scripts/art/).
	# Ground either side of the pond, the basin, and ramps in and out.
	_box(st, "GroundL", Vector3((LEFT - 4 + POND.x) * 0.5, -2.0, 0), Vector3(POND.x - LEFT + 4, 4, DEPTH))
	_box(st, "GroundR", Vector3((RIGHT + 4 + POND.y) * 0.5, -2.0, 0), Vector3(RIGHT + 4 - POND.y, 4, DEPTH))
	_box(st, "PondFloor", Vector3(0, POND_FLOOR - 1.0, 0), Vector3(POND.y - POND.x, 2, DEPTH))
	_box(st, "RampL", Vector3(POND.x + 1.3, POND_FLOOR * 0.5 - 0.3, 0), Vector3(3.6, 0.5, DEPTH), -38.0)
	_box(st, "RampR", Vector3(POND.y - 1.3, POND_FLOOR * 0.5 - 0.3, 0), Vector3(3.6, 0.5, DEPTH), 38.0)
	# Fences and the invisible walls and lid that keep everything in the yard.
	for side in [-1.0, 1.0]:
		var x: float = LEFT if side < 0 else RIGHT
		_box(st, "Fence", Vector3(x + side * 0.25, 2.0, 0), Vector3(0.5, 4.0, DEPTH))
		_box(st, "Wall", Vector3(x + side * 0.25, (4.0 + LID_Y) * 0.5, 0), Vector3(0.5, LID_Y - 4.0, DEPTH))
	_box(st, "Lid", Vector3(0, LID_Y + 0.25, 0), Vector3(RIGHT - LEFT + 4, 0.5, DEPTH))
	# Front gate: the Reset Yard sign and the tire pile (the card board is dressing).
	reset_sign = Node3D.new()
	reset_sign.name = "ResetSign"
	reset_sign.position = Vector3(-42.0, 0, -1.0)
	st.add_child(reset_sign)
	tire_pile = Node3D.new()
	tire_pile.name = "TirePile"
	tire_pile.position = Vector3(-34.0, 0, -1.5)
	st.add_child(tire_pile)
	_add_spawn(Players.P1, Vector3(-39.0, 0.1, 0))
	_add_spawn(Players.P2, Vector3(-34.0, 0.1, 0))
	# Scrap heap: a junk mound to climb (the crane and conveyor are dressing).
	_box(st, "Mound", Vector3(-21.0, 0.0, 0), Vector3(5.0, 1.6, DEPTH * 0.6))
	_box(st, "MoundL", Vector3(-24.0, 0.3, 0), Vector3(2.4, 0.5, DEPTH * 0.6), 22.0)
	# Pond: a dock over the water.
	_box(st, "Dock", Vector3(-6.5, 0.15, 0), Vector3(5.0, 0.3, 2.0))
	# Barn: a loft with steps up, a see-saw.
	_box(st, "Loft", Vector3(26.0, 4.0, 0), Vector3(5.0, 0.4, DEPTH * 0.6))
	for i in 3:
		_box(st, "LoftStep%d" % i, Vector3(21.2 + i * 0.8, 1.0 + i * 1.0, 0), Vector3(0.9, 0.3, 2.0))
	_build_seesaw(st, Vector3(18.0, 0, 0))
	# Tower: platforms going up and the pipe from the top back to the ground.
	for i in 3:
		var y := 3.0 + i * 3.0
		_box(st, "TowerDeck%d" % i, Vector3(41.0 + (i % 2) * 1.5, y, 0), Vector3(4.0, 0.4, DEPTH * 0.6))
		_box(st, "TowerStep%d" % i, Vector3(45.5 - (i % 2) * 8.0, y - 1.5, 0), Vector3(1.4, 0.3, 2.0))
	_box(st, "PipeFloor", Vector3(35.0, 5.0, 0), Vector3(9.0, 0.25, 1.6), 32.0)
	_box(st, "PipeRoof", Vector3(35.4, 6.6, 0), Vector3(9.0, 0.25, 1.6), 32.0)
	YardDressing.build(self)
	contraptions = Contraptions.build(self)   # fan, conveyor and button, crane hook, trampoline


func _add_spawn(player: int, at: Vector3) -> void:
	var m := Marker3D.new()
	m.name = "P%d" % (player + 1)
	m.position = at
	if not has_node("Spawns"):
		var s := Node3D.new()
		s.name = "Spawns"
		add_child(s)
	$Spawns.add_child(m)
	spawns[player] = m


## A see-saw: a plank on a hinge over a wedge. A landmark (guns don't change it), but anything
## dropped on one end flips the other end up.
func _build_seesaw(parent: Node3D, at: Vector3) -> void:
	var pivot := _box(parent, "SeesawPivot", at + Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 1.2))
	var plank := SeesawPlank.new()
	plank.name = "SeesawPlank"
	plank.mass = 3.0
	plank.position = at + Vector3(0, 1.05, 0)
	plank.collision_layer = 1
	plank.collision_mask = 1
	plank.axis_lock_linear_z = true
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(5.0, 0.2, 1.2)
	cs.shape = sh
	plank.add_child(cs)
	parent.add_child(plank)
	var hinge := HingeJoint3D.new()
	hinge.name = "SeesawHinge"
	parent.add_child(hinge)
	hinge.global_position = at + Vector3(0, 1.0, 0)
	hinge.node_a = hinge.get_path_to(pivot)
	hinge.node_b = hinge.get_path_to(plank)
	hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, deg_to_rad(-22))
	hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(22))


## S-18: the see-saw plank is the yard's one plain rigid body (engine gravity, a hinge). Left alone it
## could never sleep while it rested on a yard object: that object falls asleep on an even frame, the
## awake plank wakes it by contact, and the waking keeps the plank's own sleep timer from running out.
## So it follows the yard objects' rule: still for PhysicsObject.REST_STEPS steps, it sleeps on an even
## physics frame, the same step as whatever it rests on.
class SeesawPlank extends RigidBody3D:
	var _still := 0

	func _physics_process(_delta: float) -> void:
		if sleeping:
			_still = 0
			return
		if linear_velocity.length() < PhysicsObject.REST_SPEED and angular_velocity.length() < PhysicsObject.REST_SPIN:
			_still += 1
		else:
			_still = 0
		if _still >= PhysicsObject.REST_STEPS and Engine.get_physics_frames() % 2 == 0:
			sleeping = true


func _box(parent: Node3D, n: String, pos: Vector3, size: Vector3, roll_deg := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = n
	b.position = pos
	b.rotation_degrees.z = roll_deg
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	parent.add_child(b)
	return b
