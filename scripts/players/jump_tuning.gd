## Variable jump (GAME.md "Playtest 2026-11-10 changes" item 5): a tap of B is a short hop, holding
## B goes higher, up to the cap (a full hold). Letting go early cuts the rise. Floaty and forgiving.
## The numbers live in data/players/jump.tres; both characters use the same file.
class_name JumpTuning
extends Resource

## Take-off speed (m/s). A full hold rises to takeoff^2 / (2 g rise_gravity): the cap.
@export var takeoff_speed := 6.5
## Let go while still rising and the rise speed is cut to this (m/s): the tap hop.
@export var cut_speed := 4.0
## Gravity multipliers: rising with B held, rising after B came up, and falling.
@export var rise_gravity := 0.6
@export var released_rise_gravity := 0.85
@export var fall_gravity := 0.9
## Kid-design: forgiving timing. Jump just after walking off an edge, or just before landing.
@export var coyote := 0.15
@export var buffer := 0.15


## Apex height (m) of a full hold, for gravity g.
func cap_height(g := Yard.G) -> float:
	return takeoff_speed * takeoff_speed / (2.0 * g * rise_gravity)


## Apex height (m) of a tap (B up at once), for gravity g.
func hop_height(g := Yard.G) -> float:
	var v := minf(cut_speed, takeoff_speed)
	return v * v / (2.0 * g * released_rise_gravity)
