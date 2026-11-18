## Brings the Reset Yard sign to life (GAME.md "Playtest 2026-11-10 changes" item 4: "far more
## visible: big, lit, near the start"): a ring of marquee bulbs chases round the board, the swirl
## turns, and the warm lamp breathes. While someone holds A on the sign, or after a reset, the
## bulbs race and the swirl spins up. Built by YardDressing._build_front_gate().
class_name ResetSignFx
extends Node3D

var level: YardLevel
var swirl: Node3D
var lamp: OmniLight3D
var bulbs: Array[MeshInstance3D] = []
var on_mat: Material
var off_mat: Material
var _t := 0.0
var _kick := 0.0   # seconds of "just reset" excitement left
## S-18 (jyz-hitch-6): bulb material writes, counted per call (tests read it). A bulb is written only
## when it turns on or off, not every frame.
var bulb_writes := 0


func _ready() -> void:
	if level:
		level.yard_reset.connect(func() -> void: _kick = 1.6)


func _process(delta: float) -> void:
	_t += delta
	_kick = maxf(0.0, _kick - delta)
	var hold := level.reset_progress() if level else 0.0
	var speed := 6.0 + 22.0 * hold + 30.0 * minf(_kick, 1.0)
	var lit := int(_t * speed)
	for i in bulbs.size():
		var m := on_mat if (i + lit) % 3 != 0 else off_mat
		if bulbs[i].material_override != m:
			bulbs[i].material_override = m
			bulb_writes += 1
	if swirl:
		swirl.rotation.z -= delta * (0.8 + 9.0 * hold + 14.0 * minf(_kick, 1.0))
	if lamp:
		lamp.light_energy = 2.2 + 0.4 * sin(_t * 2.4) + 3.0 * hold + 3.0 * minf(_kick, 1.0)
