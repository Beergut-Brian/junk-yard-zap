## The active effects on one object (GAME.md "Effects as a stack"). Any change rebuilds BodyProps
## from ObjectData and folds every effect over it, in order, then hands the result to the body.
## So undo is exact by construction: remove the effect and recompute.
class_name EffectStack
extends Node

signal effect_changed(target: Node3D, effect: StringName, on: bool)
signal recomputed(props: BodyProps)

var effects: Array[Effect] = []
var props: BodyProps


func body() -> PhysicsObject:
	return get_parent() as PhysicsObject


func has(kind: StringName) -> bool:
	return get_effect(kind) != null


func get_effect(kind: StringName) -> Effect:
	for e in effects:
		if e.id == kind:
			return e
	return null


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for e in effects:
		out.append(e.id)
	return out


func push(e: Effect) -> bool:
	if e == null or effects.has(e):
		return false
	effects.append(e)
	e.added(body())
	recompute()
	effect_changed.emit(body(), e.id, true)
	return true


func remove(e: Effect) -> void:
	if not effects.has(e):
		return
	effects.erase(e)
	e.removed(body())
	recompute()
	effect_changed.emit(body(), e.id, false)


func clear() -> void:
	for e in effects.duplicate():
		e.undo(body())


func compute() -> BodyProps:
	var p := BodyProps.from_data(body().data)
	for e in effects:
		e.modify(p)
	return p


func recompute() -> void:
	props = compute()
	body().apply_props(props)
	recomputed.emit(props)


func tick(delta: float) -> void:
	for e in effects.duplicate():
		if effects.has(e):
			e.tick(body(), delta)


## The glued island this object belongs to (itself included).
func glued_group() -> Array[PhysicsObject]:
	var seen: Array[PhysicsObject] = [body()]
	var i := 0
	while i < seen.size():
		for e in seen[i].stack.effects:
			if e is Effects.Glue:
				var o: PhysicsObject = e.other(seen[i])
				if is_instance_valid(o) and not seen.has(o):
					seen.append(o)
		i += 1
	return seen
