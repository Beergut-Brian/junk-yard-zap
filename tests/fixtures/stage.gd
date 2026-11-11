## Staging for physics tests in the full yard. The layout packs about fifty bodies into the yard, so
## a test that drops, launches or places something next to them is really testing how that pile
## settles, and a pile settles differently on a slower or different CPU, or after another suite has
## changed the order bodies were made in. Bench the bodies a test is not about, so the hit, landing
## or carry it checks is the only contact that can happen.
##
##     const Stage := preload("res://tests/fixtures/stage.gd")
##     Stage.clear_around(l, 30.0, 2.5, [hen])   # open ground at x = 30 for the hen to grow on
##
## Tests only. Gameplay never reads this.
extends RefCounted


## Takes one body out of play: out of the physics space (process mode disabled removes a body from
## the space), out of the object group (aim, magnets, goals and zone counts skip it), and hidden.
## It stays in the level's table, so saving and freeing the level work as before.
static func bench(o: Node3D) -> void:
	if not is_instance_valid(o):
		return
	o.process_mode = Node.PROCESS_MODE_DISABLED
	if o is RigidBody3D:
		(o as RigidBody3D).linear_velocity = Vector3.ZERO
		(o as RigidBody3D).angular_velocity = Vector3.ZERO
	o.remove_from_group(PhysicsObject.GROUP)
	o.visible = false


## Benches every yard object whose body comes within `reach` metres (along x) of `x`, except those
## in `keep`. Returns what it benched.
static func clear_around(level: YardLevel, x: float, reach: float, keep: Array = []) -> Array:
	var out := []
	for o in level.objects.values():
		if not is_instance_valid(o) or o in keep:
			continue
		if absf(o.global_position.x - x) < reach + o.radius():
			bench(o)
			out.append(o)
	return out


## Benches every yard object except those in `keep`.
static func clear_all(level: YardLevel, keep: Array = []) -> Array:
	var out := []
	for o in level.objects.values():
		if is_instance_valid(o) and not o in keep:
			bench(o)
			out.append(o)
	return out
