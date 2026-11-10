## What the goal checker can't read off the yard right now: where each object was last touched by a
## gun, and how far each object got through the top card's SEQUENCE. Owned by the GoalDeck; plain
## data, keyed by instance id, nothing allocated per check.
class_name GoalMemory
extends RefCounted

## Advances once per deck check; touches and sequence steps are stamped with it.
var tick := 0
var _touch_at := {}      # instance id -> Vector3 where the last gun touch happened
var _touch_tick := {}    # instance id -> tick of the last gun touch
var _stage := {}         # instance id -> next sequence step
var _stage_tick := {}    # instance id -> tick that step was reached


## A gun touched o (zapped it, or it is being held). Stamped with the next check's tick, so a zap
## between two checks always counts as after the step the last check reached.
func touch(o: PhysicsObject) -> void:
	var k := o.get_instance_id()
	_touch_at[k] = o.global_position
	_touch_tick[k] = tick + 1


func touched(o: PhysicsObject) -> bool:
	return _touch_tick.has(o.get_instance_id())


func last_touch_at(o: PhysicsObject) -> Vector3:
	return _touch_at.get(o.get_instance_id(), Vector3.INF)


## Touched by a gun after tick t.
func touched_since(o: PhysicsObject, t: int) -> bool:
	return _touch_tick.get(o.get_instance_id(), -1) > t


func stage(o: PhysicsObject) -> int:
	return _stage.get(o.get_instance_id(), 0)


func stage_tick(o: PhysicsObject) -> int:
	return _stage_tick.get(o.get_instance_id(), 0)


func set_stage(o: PhysicsObject, s: int) -> void:
	_stage[o.get_instance_id()] = s
	_stage_tick[o.get_instance_id()] = tick


## A new top card: nobody is part-way through it.
func reset_progress() -> void:
	_stage.clear()
	_stage_tick.clear()


## Reset Yard: everything is back where it started, untouched.
func clear() -> void:
	reset_progress()
	_touch_at.clear()
	_touch_tick.clear()
