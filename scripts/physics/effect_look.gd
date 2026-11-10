## What each effect looks like on an object (GAME.md Art direction "Effects"): bouncy stripes, a
## balloon tie, an ice crust, a magnet horseshoe, a player-coloured grab glow. Driven from the same
## EffectStack the sim uses, so what you see is what the sim is doing. Lives under the object's
## Visual node, built at scale-1 size, so it grows and shrinks with the object.
## Grey-box placeholders: the Art lane swaps these for scenes/fx/*.tscn.
class_name EffectLook
extends Node3D

var size := Vector3.ONE
var _on := {}   # effect id -> Node3D


func sync(effects: Array[Effect]) -> void:
	var want := {}
	for e in effects:
		if e.id != &"size" and e.id != &"glue":
			want[e.id] = e
	for k in _on.keys():
		if not want.has(k):
			_on[k].queue_free()
			_on.erase(k)
	for k in want:
		if not _on.has(k):
			var n := _build(k, want[k].color)
			if n:
				add_child(n)
				_on[k] = n
				n.scale = Vector3.ONE * 0.01
				n.create_tween().tween_property(n, "scale", Vector3.ONE, 0.3) \
						.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func has_look(kind: StringName) -> bool:
	return _on.has(kind)


func _process(_delta: float) -> void:
	var balloon: Node3D = _on.get(&"balloon")
	if balloon:
		balloon.rotation.z = sin(Time.get_ticks_msec() * 0.003) * 0.15


func _build(kind: StringName, c: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "look_%s" % kind
	match kind:
		&"bouncy":
			for i in 3:
				var band := _box(Vector3(size.x * 1.04, size.y * 0.09, size.z * 1.04), c)
				band.position.y = (i - 1) * size.y * 0.3
				root.add_child(band)
		&"balloon":
			var r := clampf(size.length() * 0.22, 0.25, 0.6)
			var ball := _sphere(r, c)
			ball.position.y = size.y * 0.5 + r * 2.2
			ball.scale = Vector3(1, 1.15, 1)
			root.add_child(ball)
			var tie := _box(Vector3(0.03, r * 1.6, 0.03), Color(0.95, 0.95, 0.95))
			tie.position.y = size.y * 0.5 + r * 0.8
			root.add_child(tie)
		&"freeze":
			var ice := _box(size * 1.1 + Vector3.ONE * 0.06, Color(c, 0.45))
			root.add_child(ice)
		&"magnet":
			var h := clampf(size.y * 0.35, 0.25, 0.6)
			for side in [-1, 1]:
				var arm := _box(Vector3(h * 0.3, h, h * 0.3), Color(0.9, 0.15, 0.12))
				arm.position = Vector3(side * h * 0.4, size.y * 0.5 + h * 0.6, 0)
				root.add_child(arm)
				var tip := _box(Vector3(h * 0.32, h * 0.25, h * 0.32), Color(0.85, 0.85, 0.9))
				tip.position = Vector3(side * h * 0.4, size.y * 0.5 + h * 0.15, 0)
				root.add_child(tip)
			var top := _box(Vector3(h * 1.1, h * 0.3, h * 0.3), Color(0.9, 0.15, 0.12))
			top.position.y = size.y * 0.5 + h * 1.1
			root.add_child(top)
		&"splat":   # glue on a player's head (partner zap)
			var blob := _sphere(size.x * 0.45, c)
			blob.position.y = size.y * 0.5 + size.x * 0.1
			blob.scale = Vector3(1.3, 0.6, 1.3)
			root.add_child(blob)
		&"grab":
			var glow := _box(size * 1.15 + Vector3.ONE * 0.1, Color(c, 0.3))
			(glow.material_override as StandardMaterial3D).emission_enabled = true
			(glow.material_override as StandardMaterial3D).emission = c
			root.add_child(glow)
		_:
			return null
	return root


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _box(s: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = s
	mi.mesh = m
	mi.material_override = _mat(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _sphere(r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	mi.mesh = m
	mi.material_override = _mat(c)
	return mi
