## One thing a gun does to an object. Lives on an EffectStack; see scripts/physics/effects.gd.
## The contract that makes effects compose without special cases:
##   - modify(props) only reads/writes BodyProps fields (never the body directly),
##   - side effects that need nodes (joints, forces on others) live in added/removed/tick,
##   - apply(target) and undo(target) are each other's exact inverse.
class_name Effect
extends RefCounted

var id: StringName = &"effect"
var color := Color.WHITE


## Push this effect onto target's stack. Returns false if the stack refused it.
func apply(target: PhysicsObject) -> bool:
	return target.stack.push(self)


func undo(target: PhysicsObject) -> void:
	target.stack.remove(self)


func modify(_p: BodyProps) -> void:
	pass


func added(_target: PhysicsObject) -> void:
	pass


func removed(_target: PhysicsObject) -> void:
	pass


## Called every physics frame while active (and not frozen-skipped: effects decide themselves).
func tick(_target: PhysicsObject, _delta: float) -> void:
	pass


func label() -> String:
	return String(id).left(2).to_upper()
