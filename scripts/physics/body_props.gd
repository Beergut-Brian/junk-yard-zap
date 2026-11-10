## The body an EffectStack asks for. Built fresh from ObjectData, then every active effect modifies it
## in turn. Effects only ever read and write these fields, which is what makes them compose.
class_name BodyProps
extends RefCounted

var scale_step := 0
var gravity_scale := 1.0
var bounce := 0.1
var friction := 0.8
var freeze := false
var linear_damp := 0.0
var angular_damp := 0.0
var tints: Array[Color] = []


static func from_data(d: ObjectData) -> BodyProps:
	var p := BodyProps.new()
	p.bounce = d.bounce
	p.friction = d.friction
	return p


func to_dict() -> Dictionary:
	return {
		"scale_step": scale_step, "gravity_scale": gravity_scale, "bounce": bounce,
		"friction": friction, "freeze": freeze, "linear_damp": linear_damp,
		"angular_damp": angular_damp,
	}
