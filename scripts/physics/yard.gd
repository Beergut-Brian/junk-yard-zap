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
const GLUE_MASS_RATIO := 10.0   # glued bodies stay within 10:1 of the heaviest in the island
## Anything outside this box is recalled to the gate.
const BOUNDS := AABB(Vector3(-34, -6, -8), Vector3(68, 30, 16))
const GATE := Vector3(-24, 3, 0)

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


static func in_bounds(pos: Vector3) -> bool:
	return BOUNDS.has_point(pos)


static func reset_stats() -> void:
	gravity_queries = 0
	recalls = 0
