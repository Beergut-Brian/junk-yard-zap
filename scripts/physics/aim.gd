## Aim assist (GAME.md: "a wide cone that snaps to the nearest object in it").
## Works on the play plane: only X and Y matter, so the stick aims exactly where it points.
class_name Aim
extends RefCounted

const HALF_ANGLE := deg_to_rad(40.0)
const RANGE := 12.0


## Best target for a stick direction from origin, or null. Candidates are Node3Ds; a PhysicsObject's
## surface (not its centre) counts for distance, so big things are easy to hit.
## Score is distance, nudged toward the beam's centre line so two neighbours split sensibly.
static func pick(origin: Vector3, dir: Vector2, candidates: Array, half_angle := HALF_ANGLE, reach := RANGE) -> Node3D:
	if dir.length_squared() < 0.0001:
		return null
	var d := dir.normalized()
	var best: Node3D = null
	var best_score := INF
	for c in candidates:
		var n := c as Node3D
		if n == null or not is_instance_valid(n):
			continue
		var to := Vector2(n.global_position.x - origin.x, n.global_position.y - origin.y)
		var r := (n as PhysicsObject).radius() * 0.7 if n is PhysicsObject else 0.0
		var dist := maxf(0.0, to.length() - r)
		if dist > reach:
			continue
		# Inside the object: always a hit. Otherwise the angle to the nearest edge must be in the cone.
		var ang := 0.0
		if to.length() > r and to.length() > 0.0001:
			ang = maxf(0.0, absf(d.angle_to(to)) - asin(clampf(r / to.length(), 0.0, 1.0)))
		if ang > half_angle:
			continue
		var score := dist * (1.0 + ang / half_angle)
		if score < best_score:
			best_score = score
			best = n
	return best
