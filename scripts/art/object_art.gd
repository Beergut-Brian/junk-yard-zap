## The Art lane's yard objects: one small builder script per ObjectData id in scripts/art/objects/<id>.gd,
## each `static func build(root: Node3D, d: ObjectData) -> void`. A builder makes the object at scale 1,
## centred on the body's origin, filling d.size (a touch bigger is fine: chunky, slightly too big), with
## ArtKit meshes and the props-only outline. PhysicsObject adds the face and effect looks on top.
## No builder for an id: PhysicsObject falls back to the grey-box parts.
class_name ObjectArt
extends RefCounted

const DIR := "res://scripts/art/objects/"

static var _cache := {}


static func has_art(id: StringName) -> bool:
	return _script(id) != null


static func build(d: ObjectData, parent: Node3D) -> bool:
	var s := _script(d.id)
	if s == null:
		return false
	var root := Node3D.new()
	root.name = "Art"
	parent.add_child(root)
	s.call(&"build", root, d)
	return true


static func _script(id: StringName) -> Script:
	if _cache.has(id):
		return _cache[id]
	var path := DIR + String(id) + ".gd"
	var s: Script = load(path) if ResourceLoader.exists(path) else null
	_cache[id] = s
	return s


# --- shared bits for builders ------------------------------------------------------------------------

## A prop part: ArtKit.put with the outline on.
static func part(root: Node3D, mesh: Mesh, col: Color, pos := Vector3.ZERO, rot := Vector3.ZERO,
		scl := Vector3.ONE) -> MeshInstance3D:
	return ArtKit.put(root, mesh, col, pos, rot, scl, 0.0, true)


## A detail too small for an outline (spots, bolts, stitching).
static func detail(root: Node3D, mesh: Mesh, col: Color, pos := Vector3.ZERO, rot := Vector3.ZERO,
		scl := Vector3.ONE) -> MeshInstance3D:
	var mi := ArtKit.put(root, mesh, col, pos, rot, scl)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A wheel facing the camera: tyre, hub, hub cap.
static func wheel(root: Node3D, r: float, w: float, pos: Vector3) -> void:
	part(root, ArtKit.cyl(r, w), ArtKit.c("rubber"), pos, Vector3(90, 0, 0))
	detail(root, ArtKit.cyl(r * 0.5, w + 0.02), ArtKit.c("metal"), pos, Vector3(90, 0, 0))
	detail(root, ArtKit.sphere(r * 0.18, 10), ArtKit.c("metal").darkened(0.25), pos + Vector3(0, 0, w * 0.5 + 0.01))


# --- machine gags (Y-19) ------------------------------------------------------------------------------

## Vehicles and machines have no face (producer rule), so each one gets a moving part that shows it
## felt the zap: the fridge door swings open and shuts, the toast pops up, the antennae wobble.
## Builders call gag() and put the moving parts in the Node3D it returns, with their usual
## coordinates; PhysicsObject plays every gag for GAG_SECONDS when the machine reacts.
## kind: &"swing" (opens by amount radians about axis, then shuts), &"wiggle" (wobbles about axis,
## dying away), &"pop" (jumps amount metres along axis and drops back).
static func gag(root: Node3D, kind: StringName, pivot: Vector3, axis: Vector3, amount: float) -> Node3D:
	var p := Node3D.new()
	p.name = "Gag_" + String(kind)
	p.position = pivot
	p.set_meta(&"gag", {"kind": kind, "axis": axis.normalized(), "amount": amount, "rest": pivot})
	root.add_child(p)
	var holder := Node3D.new()
	holder.position = -pivot
	p.add_child(holder)
	return holder


## A puff of smoke that comes out at this point when the machine's gags start (tractor exhaust).
static func puff(root: Node3D, at: Vector3) -> void:
	var m := Node3D.new()
	m.name = "GagPuff"
	m.position = at
	m.set_meta(&"gag_puff", true)
	root.add_child(m)


## Every gag pivot under node.
static func gags_in(node: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in node.find_children("Gag_*", "Node3D", true, false):
		if n.has_meta(&"gag"):
			out.append(n)
	return out


## Pose a gag pivot at progress t (0 = start, 1 = done, back at rest).
static func pose_gag(p: Node3D, t: float) -> void:
	var g: Dictionary = p.get_meta(&"gag")
	var axis: Vector3 = g["axis"]
	var amount: float = g["amount"]
	p.position = g["rest"]
	p.basis = Basis.IDENTITY
	if t <= 0.0 or t >= 1.0:
		return
	match g["kind"]:
		&"swing":
			# Flies open in the first fifth, hangs there with a little flutter, swings shut.
			var e := smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.7, 1.0, t))
			var flutter := sin(t * 40.0) * 0.06 * e
			p.basis = Basis(axis, amount * (e + flutter))
		&"wiggle":
			p.basis = Basis(axis, amount * sin(t * TAU * 3.0) * (1.0 - t))
		&"pop":
			p.position += axis * amount * sin(PI * minf(1.0, t * 1.4))
