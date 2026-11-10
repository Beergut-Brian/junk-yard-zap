## The stack of goal cards on the front fence. Top card = current goal. Checked a few times a second;
## done cards go to the done pile (his trophy shelf), skipped cards go to the back. Nothing nags,
## nothing times out. Cards are data/goals/*.tres, ordered by band then file name.
class_name GoalDeck
extends Node

signal goal_completed(goal_id: StringName)
signal goal_skipped(goal_id: StringName)
signal card_changed(goal: GoalData)

const CHECK_EVERY := 0.25
const DIR := "res://data/goals/"

var cards := {}                       # id -> GoalData
var order: Array[StringName] = []     # the stack, top first
var done: Array[StringName] = []
## Off while the yard resets or loads, so nothing completes mid-teleport.
var checking := true
var _t := 0.0


func _ready() -> void:
	if cards.is_empty():
		load_dir(DIR)


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
		return a.band < b.band or (a.band == b.band and String(a.id) < String(b.id)))
	cards.clear()
	order.clear()
	done.clear()
	for g in list:
		cards[g.id] = g
		order.append(g.id)
	card_changed.emit(current())


func current() -> GoalData:
	return cards.get(order[0]) if not order.is_empty() else null


func _process(delta: float) -> void:
	_t += delta
	if _t < CHECK_EVERY or not checking:
		return
	_t = 0.0
	var g := current()
	if g and Goals.check(g):
		complete()


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
