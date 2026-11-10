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
