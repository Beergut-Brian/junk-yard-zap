## A stand-in holder for gravity grab in tests: holds the object a metre in front of itself.
extends Node3D


func hold_point(_t: Node3D) -> Vector3:
	return global_position + Vector3(1.0, 0.5, 0.0)
