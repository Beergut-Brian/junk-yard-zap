## The stack of goal cards on the front fence. Top card = current goal. Checked a few times a second;
## done cards go to the done pile (his trophy shelf), skipped cards go to the back. Nothing nags,
## nothing times out. Cards are data/goals/*.tres, ordered by band, then rank, then id.
## Keeps a GoalMemory for cards that care where an object was last touched, or that happen in steps:
## every zap on an object and every check it spends held by gravity grab count as a gun touch.
class_name GoalDeck
extends Node

signal goal_completed(goal_id: StringName)
signal goal_skipped(goal_id: StringName)
signal card_changed(goal: GoalData)

const CHECK_EVERY := 0.1   # fast enough to see a flying car mid-arc
const DIR := "res://data/goals/"

var cards := {}                       # id -> GoalData
var order: Array[StringName] = []     # the stack, top first
var done: Array[StringName] = []
## Off while the yard resets or loads, so nothing completes mid-teleport.
var checking := true
var memory := GoalMemory.new()
var _t := 0.0


func _ready() -> void:
	if cards.is_empty():
		load_dir(DIR)
		_dev_top()
	var level := get_parent() as YardLevel
	if level:
		level.zapped.connect(_on_zapped)
		level.yard_reset.connect(memory.clear)
	card_changed.connect(func(_g: GoalData) -> void: memory.reset_progress())


func load_dir(dir: String) -> void:
	var list: Array[GoalData] = []
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with(".tres") or f.ends_with(".res"):
			var g := load(dir.path_join(f)) as GoalData
			if g:
				list.append(g)
	set_cards(list)


func set_cards(list: Array[GoalData]) -> void:
	list.sort_custom(func(a: GoalData, b: GoalData) -> bool:
		if a.band != b.band:
			return a.band < b.band
		if a.rank != b.rank:
			return a.rank < b.rank
		return String(a.id) < String(b.id))
	cards.clear()
	order.clear()
	done.clear()
	for g in list:
		cards[g.id] = g
		order.append(g.id)
	card_changed.emit(current())


func current() -> GoalData:
	return cards.get(order[0]) if not order.is_empty() else null


## Counted in physics time, not frames: a slow frame (or a slow CI box) can't stretch the gap between
## two checks and miss a duck that was only fast, or a car that was only over the fence, for a moment.
func _physics_process(delta: float) -> void:
	_t += delta
	if _t < CHECK_EVERY - 0.001 or not checking:
		return
	_t = 0.0
	check_now()


## One check of the top card (the deck does this every CHECK_EVERY; tests call it directly).
func check_now() -> bool:
	var g := current()
	if g == null:
		return false
	var objects := get_tree().get_nodes_in_group(PhysicsObject.GROUP)
	for o in objects:
		if (o as PhysicsObject).stack.has(&"grab"):
			memory.touch(o)
	memory.tick += 1
	if Goals.check(g, objects, memory):
		complete()
		return true
	return false


func _on_zapped(_player: int, _gun: StringName, target: Node3D) -> void:
	if target is PhysicsObject:
		memory.touch(target)


func complete() -> void:
	var g := current()
	if g == null:
		return
	order.pop_front()
	done.append(g.id)
	Audio.play("card_done")
	goal_completed.emit(g.id)
	card_changed.emit(current())


## Zap the card: it goes to the back with a raspberry.
func skip() -> void:
	var g := current()
	if g == null:
		return
	order.pop_front()
	order.append(g.id)
	Audio.play("card_skip")
	goal_skipped.emit(g.id)
	card_changed.emit(current())


func to_save() -> Dictionary:
	return {"order": order.map(func(x): return String(x)), "done": done.map(func(x): return String(x))}


func from_save(d: Dictionary) -> void:
	var o: Array = d.get("order", [])
	var dn: Array = d.get("done", [])
	var new_order: Array[StringName] = []
	var new_done: Array[StringName] = []
	for x in o:
		if cards.has(StringName(x)):
			new_order.append(StringName(x))
	for x in dn:
		if cards.has(StringName(x)) and not new_order.has(StringName(x)):
			new_done.append(StringName(x))
	for id in cards:   # cards added since the save go on the bottom
		if not new_order.has(id) and not new_done.has(id):
			new_order.append(id)
	order = new_order
	done = new_done
	card_changed.emit(current())


## Screenshots and playtests: `-- --goal-top=b3_raft,b1_tiny_car` puts those cards on top, in order.
func _dev_top() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--goal-top="):
			var ids := a.trim_prefix("--goal-top=").split(",", false)
			ids.reverse()
			for id in ids:
				if order.has(StringName(id)):
					order.erase(StringName(id))
					order.push_front(StringName(id))
			card_changed.emit(current())
