## What each effect looks like on an object (GAME.md Art direction "Effects"), in the Golden Afternoon
## look: yellow bouncy stripes (the wobble is PhysicsObject._wobble), a magenta balloon on a string tied
## on top, an ice crust with frost shards, a blue-and-silver magnet horseshoe with orbiting sparks, a
## player-coloured grab glow, a pink glue splat. Driven from the same EffectStack the sim uses, so what
## you see is what the sim is doing. Lives under the object's Visual node, built at scale-1 size, so it
## grows and shrinks with the object. Looks only: no bodies, no shadows from the see-through bits.
class_name EffectLook
extends Node3D

var size := Vector3.ONE
var _on := {}   # effect id -> Node3D
var _t := 0.0


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


func _process(delta: float) -> void:
	_t += delta
	var balloon: Node3D = _on.get(&"balloon")
	if balloon:
		var b := balloon.get_node_or_null("Ball") as Node3D
		if b:
			b.rotation.z = sin(_t * 2.6) * 0.14
	var magnet: Node3D = _on.get(&"magnet")
	if magnet:
		var sp := magnet.get_node_or_null("Sparks") as Node3D
		if sp:
			sp.rotation.z = _t * 3.0
			sp.scale = Vector3.ONE * (1.0 + sin(_t * 9.0) * 0.08)
	var grab: Node3D = _on.get(&"grab")
	if grab:
		grab.scale = Vector3.ONE * (1.0 + sin(_t * 8.0) * 0.03)


func _build(kind: StringName, c: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "look_%s" % kind
	var top := size.y * 0.5
	match kind:
		&"bouncy":
			# Rubber bands of yellow wrapped round the object.
			var band := c.lightened(0.05)
			for i in 3:
				var y := (i - 1) * size.y * 0.3
				var mi := _mesh(ArtKit.rbox(Vector3(size.x * 1.05, maxf(size.y * 0.1, 0.06), size.z * 1.05), minf(size.y * 0.05, 0.05), 2), ArtKit.mat(band, ArtKit.EMIT))
				mi.position.y = y
				root.add_child(mi)
		&"balloon":
			var r := clampf(size.length() * 0.24, 0.28, 0.7)
			var hold := Node3D.new()
			hold.name = "Ball"
			hold.position.y = top
			root.add_child(hold)
			var ball := _mesh(ArtKit.sphere(r), ArtKit.mat(c, ArtKit.EMIT, 0.25))
			ball.position.y = r * 2.6
			ball.scale = Vector3(1, 1.18, 1)
			hold.add_child(ball)
			var shine := _mesh(ArtKit.sphere(r * 0.25, 10), ArtKit.glow(Color(1, 1, 1), 1.0))
			shine.position = Vector3(-r * 0.4, r * 3.05, r * 0.6)
			shine.scale = Vector3(0.7, 1.0, 0.4)
			hold.add_child(shine)
			var knot := _mesh(ArtKit.cyl(r * 0.16, r * 0.25, r * 0.03, 10), ArtKit.mat(c, ArtKit.EMIT))
			knot.position.y = r * 2.6 - r * 1.22
			knot.rotation_degrees.z = 180
			hold.add_child(knot)
			var string := _mesh(ArtKit.cyl(0.012, r * 1.3, -1.0, 6), ArtKit.mat(ArtKit.c("ink")))
			string.position.y = r * 0.65
			hold.add_child(string)
			var tie := _mesh(ArtKit.torus(r * 0.12, r * 0.22, 14), ArtKit.mat(c, ArtKit.EMIT))
			tie.position.y = 0.01
			hold.add_child(tie)
		&"freeze":
			var ice := _mesh(ArtKit.rbox(size * 1.08 + Vector3.ONE * 0.06, minf(size.length() * 0.08, 0.2), 3), ArtKit.glass(Color(c.lightened(0.35), 0.42), 0.15))
			root.add_child(ice)
			var frost := ArtKit.glass(Color(0.92, 0.98, 1.0, 0.85), 0.25)
			for k in 5:
				var u := (k / 4.0 - 0.5)
				var h := size.y * (0.3 + 0.15 * absf(sin(k * 2.1)))
				var shard := _mesh(ArtKit.cyl(maxf(size.x * 0.06, 0.04), h, 0.0, 6), frost)
				shard.position = Vector3(u * size.x * 0.9, top + h * 0.35, size.z * (0.2 - 0.1 * (k % 2)))
				shard.rotation_degrees.z = u * -40.0
				root.add_child(shard)
			for k in 3:
				var cap := _mesh(ArtKit.sphere(maxf(size.x, size.z) * 0.18, 10), frost)
				cap.position = Vector3((k - 1) * size.x * 0.35, top + 0.02, 0)
				cap.scale = Vector3(1.4, 0.35, 1.2)
				root.add_child(cap)
		&"magnet":
			var h := clampf(size.y * 0.4, 0.3, 0.7)
			var hold := Node3D.new()
			hold.position.y = top + h * 0.75
			root.add_child(hold)
			# The horseshoe: an arch of rounded blocks, two legs, silver tips.
			var blue := ArtKit.mat(c, ArtKit.EMIT, 0.35)
			var seg := ArtKit.rbox(Vector3(h * 0.27, h * 0.3, h * 0.28), h * 0.08, 2)
			for k in 7:
				var a := PI * k / 6.0
				var piece := _mesh(seg, blue)
				piece.position = Vector3(cos(a) * h * 0.38, sin(a) * h * 0.38, 0)
				piece.rotation.z = a - PI * 0.5
				hold.add_child(piece)
			for side in [-1.0, 1.0]:
				var leg := _mesh(ArtKit.rbox(Vector3(h * 0.27, h * 0.4, h * 0.28), h * 0.06, 2), blue)
				leg.position = Vector3(side * h * 0.38, -h * 0.18, 0)
				hold.add_child(leg)
				var tip := _mesh(ArtKit.rbox(Vector3(h * 0.29, h * 0.2, h * 0.3), h * 0.05, 2), ArtKit.mat(Color(0.88, 0.9, 0.94), 0.0, 0.2))
				tip.position = Vector3(side * h * 0.38, -h * 0.46, 0)
				hold.add_child(tip)
			var sparks := Node3D.new()
			sparks.name = "Sparks"
			root.add_child(sparks)
			var sr := maxf(size.x, size.y) * 0.62 + 0.15
			for k in 8:
				var a := TAU * k / 8.0
				var sp := _mesh(ArtKit.sphere(0.05, 6), ArtKit.glow(c.lightened(0.5), 1.6))
				sp.position = Vector3(cos(a) * sr, sin(a) * sr, size.z * 0.5)
				sp.scale = Vector3(1, 1, 1) * (1.4 if k % 2 else 0.8)
				sparks.add_child(sp)
		&"splat":   # glue on a player's head (partner zap)
			var blob := _mesh(ArtKit.sphere(size.x * 0.45), ArtKit.mat(c, ArtKit.EMIT, 0.15))
			blob.position.y = top + size.x * 0.1
			blob.scale = Vector3(1.3, 0.6, 1.3)
			root.add_child(blob)
			for k in 3:
				var drip := _mesh(ArtKit.sphere(size.x * 0.1, 8), ArtKit.mat(c, ArtKit.EMIT, 0.15))
				drip.position = Vector3((k - 1) * size.x * 0.35, top - size.x * 0.05 - (k % 2) * size.x * 0.1, size.z * 0.35)
				drip.scale = Vector3(0.8, 1.4, 0.8)
				root.add_child(drip)
		&"grab":
			# A soft shell of the player's colour, and a ring under it like a tractor beam.
			var shell := _mesh(ArtKit.rbox(size * 1.12 + Vector3.ONE * 0.12, minf(size.length() * 0.15, 0.35), 3), ArtKit.glow(Color(c, 0.22), 1.3))
			root.add_child(shell)
			var ring := _mesh(ArtKit.torus(maxf(size.x, size.z) * 0.55, maxf(size.x, size.z) * 0.55 + 0.07, 28), ArtKit.glow(c, 1.4))
			ring.position.y = -size.y * 0.5 - 0.1
			ring.scale = Vector3(1, 1, 0.45)
			root.add_child(ring)
		_:
			return null
	return root


func _mesh(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
