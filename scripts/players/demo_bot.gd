## --demo: drives a Zapper through input_override so the yard plays itself (shots, smoke boots,
## the launcher's attract mode). It wanders to an object, aims at it, zaps it with the current gun,
## sometimes grabs and throws, and cycles guns. --demo-beat=<name> stages a scene for screenshots:
##   combo: a giant bouncy balloon cow.  goal: a goal card completing.  wide: the whole yard.
class_name DemoBot
extends Node

var zapper: Zapper
var rng := RandomNumberGenerator.new()
var _goal: Node3D
var _t := 0.0
var _phase := 0
var _hold := 0.0
var _next_cycle := 3.0
var _stuck := 0.0
var _last_x := 0.0


func _init(z: Zapper = null, seed_value := 0) -> void:
	zapper = z
	rng.seed = seed_value


func _physics_process(delta: float) -> void:
	if not is_instance_valid(zapper) or zapper.asleep:
		return
	_t += delta
	var inp := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}
	if not is_instance_valid(_goal) or _phase == 3:
		_pick_goal()
	var to := _goal.global_position - zapper.global_position
	match _phase:
		0:   # walk over
			inp.move = Vector2(signf(to.x), 0)
			if absf(to.x) < rng.randf_range(2.5, 5.0):
				_phase = 1
				_hold = 0.0
			if absf(zapper.global_position.x - _last_x) < 0.02:
				_stuck += delta
			else:
				_stuck = 0.0
			if _stuck > 0.4:
				inp.jump = true
				_stuck = 0.0
		1:   # aim and fire
			inp.aim = Vector2(to.x, -to.y).normalized() * Vector2(1, 1)
			inp.aim = Vector2(inp.aim.x, inp.aim.y)
			inp.action = true
			_hold += delta
			var g := zapper.gun()
			var hold_for := 1.4 if g and g.kind == GunData.Kind.GRAB else (0.6 if g and g.kind == GunData.Kind.SIZE else 0.05)
			if g and g.kind == GunData.Kind.GRAB and _hold > 1.0:
				inp.aim = Vector2(-signf(to.x), -1.0).normalized()   # swing back: a flick
				inp.move = inp.aim
			if _hold > hold_for:
				_phase = 2
				_hold = 0.0
		2:   # let go, maybe hop, then pick a new thing
			_hold += delta
			if _hold > 0.4:
				_phase = 3
	_last_x = zapper.global_position.x
	_next_cycle -= delta
	if _next_cycle <= 0.0 and _phase != 1:
		_next_cycle = rng.randf_range(2.0, 4.0)
		inp.next = true
	# Tap edges: next/action need a release in between, which the zapper sees frame to frame.
	if inp.next and zapper.input_override.get("next", false):
		inp.next = false
	zapper.input_override = inp


func _pick_goal() -> void:
	_phase = 0
	var objs := zapper.get_tree().get_nodes_in_group(PhysicsObject.GROUP)
	var near: Array = []
	for o in objs:
		if absf((o as Node3D).global_position.x - zapper.global_position.x) < 14.0:
			near.append(o)
	if rng.randf() < 0.15:
		for z in zapper.get_tree().get_nodes_in_group(Zapper.GROUP):
			if z != zapper:
				near = [z]
	if near.is_empty():
		near = objs
	_goal = near[rng.randi() % near.size()] if not near.is_empty() else zapper
