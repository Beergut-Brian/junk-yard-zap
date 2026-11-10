## The yard's physical rules, in one place: gravity, the play plane, speed caps, bounds and recall.
## Everything is static so any body (objects, players, effects) can ask without a node lookup.
## Life of a Worm: swap the one line in gravity_at() for radial_gravity() and set CENTER.
class_name Yard
extends RefCounted

const G := 9.8
const DOWN := Vector3(0, -1, 0)
## Radial gravity centre (only used by radial_gravity()).
static var center := Vector3(0, -50, 0)

## Plane rule: a soft spring pulls every object back to Z = 0 (players lock Z outright).
const PLANE_K := 30.0          # 1/s^2: spring stiffness per unit mass
const PLANE_DAMP := 8.0        # 1/s: damping of Z velocity
const PLANE_CREEP := 3.0       # 1/s: direct position creep toward Z = 0 (beats friction at rest)
## Caps that keep the sim sane whatever effects stack up.
const MAX_SPEED := 30.0        # m/s, linear
const MAX_SPIN := 20.0         # rad/s
const SCALE_CHANGE_MAX_SPEED := 4.0   # m/s while a body is changing size
const MASS_MIN := 0.05
const MASS_MAX := 400.0
## Body mass handed to Jolt: (volume mass / 1 kg) ^ MASS_EXPONENT kg. Keeps the order (bigger is
## heavier) but squeezes the range so stacks of very different sizes don't sink into each other.
static var mass_exponent := 0.5
const GLUE_MASS_RATIO := 10.0   # glued bodies stay within 10:1 of the heaviest in the island
## Anything outside this box is recalled to the gate. The yard level sets both (and restores them).
const DEFAULT_BOUNDS := AABB(Vector3(-34, -6, -8), Vector3(68, 30, 16))
const DEFAULT_GATE := Vector3(-24, 3, 0)
static var BOUNDS := DEFAULT_BOUNDS
static var GATE := DEFAULT_GATE
## Water: anything lighter per cubic metre than this floats (ObjectData.density()).
const WATER_DENSITY := 1.5
const WATER_DRAG := 2.5        # 1/s at full submersion
## Water volumes (the pond). The surface is the top of each box.
static var water: Array[AABB] = []
## Named zones (front_gate, scrap_heap, pond, barn, tower, ...) the level registers.
static var zones := {}

## Counters the tests and the stress run read. Reset with reset_stats().
static var gravity_queries := 0
static var recalls := 0


static func gravity_at(pos: Vector3) -> Vector3:
	gravity_queries += 1
	return flat_gravity(pos)   # Life of a Worm: return radial_gravity(pos)


static func flat_gravity(_pos: Vector3) -> Vector3:
	return DOWN * G


static func radial_gravity(pos: Vector3) -> Vector3:
	var to_c := center - pos
	return to_c.normalized() * G if to_c.length_squared() > 0.0001 else Vector3.ZERO


## "Up" for a body at pos: always against gravity, so balloons and jumps work on a planet too.
static func up_at(pos: Vector3) -> Vector3:
	var g := gravity_at(pos)
	return -g.normalized() if g.length_squared() > 0.0001 else Vector3.UP


## Z acceleration that pulls a body back to the play plane.
static func plane_accel(z: float, vz: float) -> float:
	return -PLANE_K * z - PLANE_DAMP * vz


static func body_mass(volume_mass: float) -> float:
	return pow(volume_mass, mass_exponent)


static func in_bounds(pos: Vector3) -> bool:
	return BOUNDS.has_point(pos)


## The water surface height above pos, or -INF when pos isn't over water.
static func water_level_at(pos: Vector3) -> float:
	for w in water:
		if pos.x > w.position.x and pos.x < w.end.x and pos.y > w.position.y - 1.0 and pos.y < w.end.y + 3.0:
			return w.end.y
	return -INF


## A named zone's box, or an empty AABB.
static func zone(zone_name: StringName) -> AABB:
	return zones.get(zone_name, AABB())


## GAME.md contract: every yard object inside a named zone.
static func objects_in_zone(zone_name: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var box := zone(zone_name)
	var tree := Engine.get_main_loop() as SceneTree
	if box.size == Vector3.ZERO or tree == null:
		return out
	for o in tree.get_nodes_in_group(PhysicsObject.GROUP):
		if box.has_point((o as Node3D).global_position):
			out.append(o)
	return out


static func reset_world() -> void:
	BOUNDS = DEFAULT_BOUNDS
	GATE = DEFAULT_GATE
	water.clear()
	zones.clear()


static func reset_stats() -> void:
	gravity_queries = 0
	recalls = 0
