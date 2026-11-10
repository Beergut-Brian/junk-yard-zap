## A loose yard balloon (Y-11): an ObjectData that floats, pops on a hard hit or a sharp poke, and
## comes back in its zone. YardLevel spawns a LooseBalloon body for any BalloonData row.
class_name BalloonData
extends ObjectData

## Metres above its layout spot that it bobs at (the layout row is where it pops back in).
@export var hover := 0.6
## Spring (1/s^2) and damping (1/s) pulling it back to the hover height: a gentle drift, never a rocket.
@export var hover_k := 3.0
@export var hover_damp := 2.2
## Air drag (1/s): a thrown balloon slows fast and drifts.
@export var air_drag := 1.4
## Sudden speed change (m/s) that pops it. A nudge or a soft bump stays well under this.
@export var pop_dv := 7.0
## Relative speed (m/s) at which a sharp thing (SHARP ids) touching it pops it.
@export var poke_speed := 1.5
## Seconds before it pops back in at its layout spot.
@export var respawn_time := 3.0
## Cue for the pop (the existing set: a puff and a pop).
@export var pop_cue: StringName = &"solo_swap"
