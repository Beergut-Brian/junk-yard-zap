## Standing rule: every curse or penalty shows its cause. A zap that can't do its thing never just
## goes "nope": it shows the kid *why*, in pictures (no reading in gameplay).
##   size_ladder   every size zap shows a ladder of nine squares, small to big, lit up to the object's
##                 size now. At a cap the end square blinks, a stop bar bumps up past it and the
##                 ladder shakes "no": it can't get bigger (or smaller) than this.
##   blocked       a grow that something stopped (a static wall or roof, a frozen thing): a bonk star
##                 pops where the bigger shape hit, the blocker flashes, the object goes wide-eyed and
##                 the ladder shows the step coming back down (Y-20).
##   held          a grab on a thing your partner is carrying: a ring in the holder's colour.
##   already_glued glue on a pair that's already stuck: their glue blob pulses.
## The glue string while two glued things pull together, and its snap when they can't meet, live
## on Effects.Glue (string_mesh, snap) and call snapped() here.
## Static, so any node can call it. Tests read `shown` (kind, object, cause) instead of pixels.
class_name Refusal
extends RefCounted

const SIZE_COLOR := Color("#ff9a14")   # the size gun's beam (Effects.COLORS.size)
const CREAM := Color("#f4efe0")
const DEEP := Color("#33201a")
const STAR := Color("#fff4b8")

## Every refusal shown since the last clear(): {kind, obj, cause, at}. Tests only; capped.
static var shown: Array[Dictionary] = []
## Glue-snap strands spawned since the last clear(). Tests only.
static var recoils := 0


static func clear() -> void:
	shown.clear()
	recoils = 0


static func _log(kind: StringName, obj: Node3D, cause: Variant = null, at := Vector3.ZERO) -> void:
	shown.append({"kind": kind, "obj": obj, "cause": cause, "at": at})
	if shown.size() > 64:
		shown.pop_front()


static func last(kind: StringName) -> Dictionary:
	for i in range(shown.size() - 1, -1, -1):
		if shown[i].kind == kind:
			return shown[i]
	return {}


## Show (or refresh) the size ladder over obj. cap: +1 refused at the top, -1 at the bottom, 0 none.
static func size_ladder(obj: PhysicsObject, cap := 0) -> SizeLadder:
	if not is_instance_valid(obj) or not obj.is_inside_tree():
		return null
	var l := obj.get_node_or_null("SizeLadder") as SizeLadder
	if l == null:
		l = SizeLadder.new()
		l.name = "SizeLadder"
		obj.add_child(l)
	l.show_for(obj, cap)
	if cap != 0:
		_log(&"size_cap", obj, cap, obj.global_position)
	return l


## A grow that bumped into something static or frozen and is boinging back.
static func blocked(obj: PhysicsObject, blocker: Object, at: Vector3) -> void:
	_log(&"blocked", obj, blocker, at)
	if not is_instance_valid(obj) or not obj.is_inside_tree():
		return
	var tree := obj.get_tree()
	Audio.play("nope", at)
	bonk_star(tree, at)
	Fx.burst(tree, at, STAR, 10, 0.6, 0.35)
	obj.react_look(ObjectFace.Mood.WIDE, 0.8)
	var b := blocker as PhysicsObject
	if b:   # a frozen thing: it flashes in the freeze colour and pulls a face too
		b.react_look(ObjectFace.Mood.WIDE, 0.6)
		Fx.ring(tree, b.global_position, Effects.COLORS[&"freeze"], b.radius())
	size_ladder(obj)


## Grab refused: someone else already carries it. The ring is the holder's colour.
static func held(obj: PhysicsObject, holder_color: Color) -> void:
	_log(&"held", obj, holder_color, obj.global_position if is_instance_valid(obj) else Vector3.ZERO)
	if not is_instance_valid(obj) or not obj.is_inside_tree():
		return
	Fx.ring(obj.get_tree(), obj.global_position, holder_color, obj.radius() * 1.2)
	obj.react_look(ObjectFace.Mood.WIDE, 0.5)


## Glue refused: the two are already stuck. Their blob swells and settles.
static func already_glued(g: Effects.Glue) -> void:
	var at: Vector3 = g.anchor() if is_instance_valid(g.a) and is_instance_valid(g.b) else Vector3.ZERO
	_log(&"already_glued", g.a, g, at)
	if is_instance_valid(g.blob) and g.blob.is_inside_tree():
		var tw := g.blob.create_tween()
		tw.tween_property(g.blob, "scale", Vector3.ONE * 2.2, 0.12).set_ease(Tween.EASE_OUT)
		tw.tween_property(g.blob, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		Fx.ring(g.blob.get_tree(), g.blob.global_position, g.color, 0.8)


## The glue string snapped: the pair pulled for PULL_TIME and never met. The two halves of the
## string whip back into each object (drawn over everything, like the string, so a wall between
## them can't hide it) and each object rings in the glue colour. ends: the string's two ends.
static func snapped(g: Effects.Glue, at: Vector3, ends: Array[Vector3] = []) -> void:
	_log(&"glue_snap", g.a, g.b, at)
	var any: Node3D = g.a if is_instance_valid(g.a) and g.a.is_inside_tree() else (g.b if is_instance_valid(g.b) and g.b.is_inside_tree() else null)
	if any == null:
		return
	var tree := any.get_tree()
	Audio.play("unglue", at)
	Fx.burst(tree, at, g.color, 14, 0.9, 0.5)
	for o in [g.a, g.b]:
		if is_instance_valid(o) and o.is_inside_tree():
			(o as PhysicsObject).react_look(ObjectFace.Mood.WIDE, 0.7)
			Fx.burst(tree, (o as PhysicsObject).global_position, g.color, 6, 0.5, 0.35)
			Fx.ring(tree, (o as PhysicsObject).global_position, g.color, (o as PhysicsObject).radius())
	if ends.size() == 2:
		recoil(any.get_parent(), at, ends[0], g.color)
		recoil(any.get_parent(), at, ends[1], g.color)


## Half a snapped glue string: a strand from the break back to its end that shrinks into the end
## with a wiggle. Unshaded, no depth test. Lives beside the objects (parent: their parent).
static func recoil(parent: Node, from: Vector3, to: Vector3, c: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var d := to - from
	if d.length() < 0.05:
		return
	var strand := MeshInstance3D.new()
	strand.name = "GlueRecoil"
	var m := CylinderMesh.new()
	m.top_radius = Effects.Glue.STRING_R * 0.8
	m.bottom_radius = Effects.Glue.STRING_R * 0.8
	m.height = 1.0
	m.radial_segments = 6
	m.rings = 1
	strand.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.albedo_color = c
	strand.material_override = mat
	strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(strand)
	recoils += 1
	var y := d.normalized()
	var x := y.cross(Vector3.BACK)
	x = x.normalized() if x.length() > 0.01 else Vector3.RIGHT
	var z := x.cross(y)
	var pose := func(t: float) -> void:   # t 0..1: the strand's free end runs from the break to `to`
		if not is_instance_valid(strand):
			return
		var k := 1.0 - t
		var free_end := to - d * k
		var wig := x * sin(t * 18.0) * 0.12 * k
		strand.global_transform = Transform3D(Basis(x, y * maxf(d.length() * k, 0.01), z),
				(free_end + to) * 0.5 + wig + Vector3(0, 0, 0.3))
		mat.albedo_color.a = 1.0 if t < 0.7 else (1.0 - t) / 0.3
	pose.call(0.0)
	var tw := strand.create_tween()
	tw.tween_method(pose, 0.0, 1.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(strand.queue_free)


## A cartoon bonk: a fat five-point star that pops and fades, drawn over everything.
static func bonk_star(tree: SceneTree, at: Vector3) -> void:
	Fx.bursts += 1
	if tree == null or tree.current_scene == null:
		return
	var root := Node3D.new()
	root.name = "BonkStar"
	var outline := _flat(_star_mesh(0.62, 0.3), DEEP, 1)
	var fill := _flat(_star_mesh(0.5, 0.22), STAR, 2)
	fill.position.z = 0.01
	root.add_child(outline)
	root.add_child(fill)
	tree.current_scene.add_child(root)
	root.global_position = at + Vector3(0, 0, 1.2)
	root.scale = Vector3.ONE * 0.2
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.25, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "rotation:z", 0.5, 0.5)
	tw.tween_property(root, "scale", Vector3.ONE, 0.12)
	tw.tween_interval(0.45)
	tw.tween_property(root, "scale", Vector3.ONE * 0.01, 0.18).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)


static func _star_mesh(outer: float, inner: float) -> ArrayMesh:
	var pts := PackedVector3Array()
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		var a := PI * 0.5 + i * PI / 5.0
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0))
	var verts := PackedVector3Array()
	for i in 10:
		verts.append(Vector3.ZERO)
		verts.append(pts[(i + 1) % 10])
		verts.append(pts[i])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## An unshaded, always-on-top, camera-facing shape.
static func _flat(mesh: Mesh, c: Color, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = flat_mat(c, priority)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func flat_mat(c: Color, priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.render_priority = priority
	mat.albedo_color = c
	return mat


## Nine squares over the object, smallest (step -4) on the left, biggest (+4) on the right. The
## middle one (normal size) is always cream; the steps between normal and now light in the size
## colour; the square for now wears a white rim. top_level, so it neither tumbles nor scales with
## the object; it follows it from above and fades after LIFE seconds.
class SizeLadder extends Node3D:
	const LIFE := 1.4
	const FADE := 0.3
	const BASE := 0.15      # m: the smallest square
	const GROWTH := 1.17    # each square this much bigger than the last
	const GAP := 0.07
	const SHAKE := 0.5      # s of "no" shake at a cap
	var obj: PhysicsObject
	var left := 0.0
	var cap := 0
	var steps := 0
	var _shake := 0.0
	var _cells: Array[Node3D] = []
	var _fills: Array[StandardMaterial3D] = []
	var _rims: Array[MeshInstance3D] = []
	var _all_mats: Array[StandardMaterial3D] = []
	var _bar: Node3D
	var _sides: Array[float] = []
	var _lo := -4
	var _hi := 4

	func _ready() -> void:
		top_level = true

	## Squares that are lit, as steps (for tests): every step between 0 and now, plus 0.
	func lit_steps() -> Array[int]:
		var out: Array[int] = []
		for s in range(_lo, _hi + 1):
			if s == 0 or (steps > 0 and s > 0 and s <= steps) or (steps < 0 and s < 0 and s >= steps):
				out.append(s)
		return out

	func show_for(o: PhysicsObject, p_cap: int) -> void:
		obj = o
		var sz: Effects.Size = o.stack.get_effect(&"size")
		steps = sz.steps if sz else 0
		cap = p_cap
		if _cells.is_empty() or _lo != o.data.min_step or _hi != o.data.max_step:
			_build(o.data.min_step, o.data.max_step)
		left = LIFE
		_shake = SHAKE if cap != 0 else 0.0
		_reset_alpha()
		_follow()
		visible = true

	func _build(lo: int, hi: int) -> void:
		for c in get_children():
			c.free()
		_cells.clear()
		_fills.clear()
		_rims.clear()
		_all_mats.clear()
		_lo = lo
		_hi = hi
		var sides: Array[float] = []
		_sides = sides
		var width := 0.0
		for s in range(lo, hi + 1):
			var side := BASE * pow(GROWTH, s - lo)
			sides.append(side)
			width += side + GAP
		width -= GAP
		var x := -width * 0.5
		for i in sides.size():
			var side := sides[i]
			var cell := Node3D.new()
			cell.position = Vector3(x + side * 0.5, side * 0.5, 0)   # bottoms line up
			add_child(cell)
			var rim := _quad(side + 0.1, Color.WHITE, 1)
			cell.add_child(rim)
			var edge := _quad(side + 0.05, DEEP, 2)
			cell.add_child(edge)
			var fill := _quad(side, CREAM, 3)
			cell.add_child(fill)
			_cells.append(cell)
			_fills.append(fill.material_override as StandardMaterial3D)
			_rims.append(rim)
			x += side + GAP
		_bar = Node3D.new()
		_bar.add_child(_quad_wh(0.13, sides[-1] * 1.6, DEEP, 2))
		var inner := _quad_wh(0.07, sides[-1] * 1.6 - 0.06, Color.WHITE, 3)
		_bar.add_child(inner)
		add_child(_bar)

	func _quad(side: float, c: Color, prio: int) -> MeshInstance3D:
		return _quad_wh(side, side, c, prio)

	func _quad_wh(w: float, h: float, c: Color, prio: int) -> MeshInstance3D:
		var q := QuadMesh.new()
		q.size = Vector2(w, h)
		var mi := Refusal._flat(q, c, prio)
		_all_mats.append(mi.material_override as StandardMaterial3D)
		return mi

	func _paint() -> void:
		var lit := lit_steps()
		for i in _cells.size():
			var s := _lo + i
			var c := CREAM if s == 0 else (SIZE_COLOR if lit.has(s) else Color(CREAM, 0.35))
			_fills[i].albedo_color = c
			_rims[i].visible = s == steps
			_cells[i].scale = Vector3.ONE * (1.25 if s == steps else 1.0)
		_bar.visible = cap != 0
		if cap != 0:
			var end := _cells[-1] if cap > 0 else _cells[0]
			var half := (_sides[-1] if cap > 0 else _sides[0]) * 0.5
			_bar.position = Vector3(end.position.x + (half + 0.14) * signf(cap), _cells[-1].position.y, 0)

	func _follow() -> void:
		if not is_instance_valid(obj):
			return
		var up := Yard.up_at(obj.global_position)
		var top := obj.half_extent_along(up)
		var sx := sin(_shake * 40.0) * 0.12 * (_shake / SHAKE) if _shake > 0.0 else 0.0
		global_position = obj.global_position + up * (top + 0.45) + Vector3(sx, 0, 0.8)

	func _process(delta: float) -> void:
		if not visible:
			return
		left -= delta
		_shake = maxf(0.0, _shake - delta)
		_follow()
		if cap != 0:   # the end square blinks while it says no
			var end := _cells[-1] if cap > 0 else _cells[0]
			var on := fmod(LIFE - left, 0.24) < 0.12
			_fills[_cells.find(end)].albedo_color = Color.WHITE if on else SIZE_COLOR
		if left < FADE:
			var a := clampf(left / FADE, 0.0, 1.0)
			for m in _all_mats:
				m.albedo_color.a = minf(m.albedo_color.a, a)
		if left <= 0.0:
			visible = false

	func _reset_alpha() -> void:
		for m in _all_mats:
			m.albedo_color.a = 1.0
		_paint()
