## The goal-card checker (GAME.md contract: Goals.check(goal) -> bool). Static and side-effect free:
## it reads the yard's objects (the PhysicsObject group) and the condition vocabulary in GoalData.
class_name Goals
extends RefCounted


static func check(goal: GoalData, objects: Array = []) -> bool:
	if goal == null:
		return false
	if objects.is_empty():
		var tree := Engine.get_main_loop() as SceneTree
		objects = tree.get_nodes_in_group(PhysicsObject.GROUP) if tree else []
	for o in objects:
		var obj := o as PhysicsObject
		if obj and matches(obj, goal.subject) and _holds(goal, obj, objects):
			return true
	return false


static func matches(o: PhysicsObject, what: StringName) -> bool:
	return what == &"any" or what == &"" or o.data.id == what or o.key == what


static func _holds(g: GoalData, o: PhysicsObject, objects: Array) -> bool:
	match g.condition:
		GoalData.Condition.OBJECT_SCALE_AT_LEAST:
			var s: Effect = o.stack.get_effect(&"size")
			return s != null and s.steps >= int(g.amount) and not o.is_scaling()
		GoalData.Condition.OBJECT_HAS_EFFECT:
			return o.stack.has(g.effect)
		GoalData.Condition.OBJECT_IN_ZONE:
			var zone := Yard.zone(g.other)
			if zone.size != Vector3.ZERO:
				return zone.has_point(o.global_position)
			for c in objects:
				var box := c as PhysicsObject
				if box and box != o and matches(box, g.other) and box.contains_point(o.global_position):
					return true
			return false
		GoalData.Condition.GLUED_PAIR:
			for e in o.stack.effects:
				if e is Effects.Glue and e.joined() and matches(e.other(o), g.other):
					return true
			return false
		GoalData.Condition.OBJECT_HEIGHT_ABOVE:
			return o.global_position.y > g.amount
		GoalData.Condition.OBJECT_SPEED_OVER:
			return o.linear_velocity.length() > g.amount
	return false
