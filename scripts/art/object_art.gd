## The Art lane's yard objects: one small builder script per ObjectData id in scripts/art/objects/<id>.gd,
## each `static func build(root: Node3D, d: ObjectData) -> void`. A builder makes the object at scale 1,
## centred on the body's origin, filling d.size (a touch bigger is fine: chunky, slightly too big), with
## ArtKit meshes and the props-only outline. PhysicsObject adds the face and effect looks on top.
## No builder for an id: PhysicsObject falls back to the grey-box parts.
class_name ObjectArt
extends RefCounted

const DIR := "res://scripts/art/objects/"

static var _cache := {}
## S-18 (jyz-hitch-3): merge each object's still parts into one mesh per material (merge_static). Tests
## turn it off to compare against the parts as built.
static var merge_parts := true
static var _merged := {}   # parts signature -> ArrayMesh (crate and crate_2 share one)


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
	if merge_parts:
		merge_static(root)
	return true


# --- S-18: one draw per material, not one per part -------------------------------------------------

## A yard object is 10-50 ArtKit parts, each its own MeshInstance3D: in the "yard wide" shot that is
## ~1000 draw calls in the colour pass and ~600 in the shadow pass (jyz-hitch-3 findings). Parts that never
## move on their own and share a material are baked into one mesh, in place, vertex for vertex: same
## triangles, same material (outline pass included), same shadow setting, same bounds. Left as they are:
## named parts (code finds them: a balloon's Body), parts under a gag pivot (they swing), inside an
## instanced model (the cow's glb), with a script, children, an overlay, see-through or textured
## materials, and outlined parts with a scale (the outline grows in the mesh's own space, so baking a
## scale would change the ink line's width). Returns how many MeshInstance3Ds it removed.
static func merge_static(root: Node3D) -> int:
	var groups := {}
	var order: Array = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var rel = _merge_rel(mi, root)
		if rel == null:
			continue
		var key := "%d|%d|%d" % [mi.material_override.get_instance_id(), mi.cast_shadow, mi.layers]
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append([mi, rel])
	var removed := 0
	for key in order:
		var g: Array = groups[key]
		if g.size() < 2:
			continue
		var first: MeshInstance3D = g[0][0]
		var merged := MeshInstance3D.new()
		merged.name = "Merged"
		merged.mesh = _merged_mesh(g)
		merged.material_override = first.material_override
		merged.cast_shadow = first.cast_shadow
		merged.layers = first.layers
		merged.set_meta(&"parts_aabb", merged.mesh.custom_aabb)
		root.add_child(merged)
		for e in g:
			var mi: MeshInstance3D = e[0]
			mi.get_parent().remove_child(mi)
			mi.free()
			removed += 1
		removed -= 1
	return removed


## The part's transform relative to root when it can be baked, else null.
static func _merge_rel(mi: MeshInstance3D, root: Node3D) -> Variant:
	if mi.get_script() != null or mi.get_child_count() > 0 or not String(mi.name).begins_with("@"):
		return null
	if not mi.visible or mi.material_overlay != null or mi.skin != null or mi.transparency > 0.0:
		return null
	if mi.mesh == null or mi.mesh.get_surface_count() != 1 or mi.visibility_range_end > 0.0:
		return null
	var m := mi.material_override as BaseMaterial3D
	if m == null or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.albedo_texture != null \
			or m.vertex_color_use_as_albedo or m.normal_enabled or m.uv1_triplanar:
		return null
	if m.next_pass != null and m.next_pass != ArtKit.outline_mat():
		return null
	var t := mi.transform
	var p := mi.get_parent()
	while p != root:
		if p == null or not p is Node3D or p.get_script() != null or p.scene_file_path != "" \
				or String(p.name).begins_with("Gag_") or p.has_meta(&"gag") or not (p as Node3D).visible \
				or (p as Node3D).top_level:
			return null
		t = (p as Node3D).transform * t
		p = p.get_parent()
	if m.next_pass != null:
		var b := t.basis
		if absf(b.x.length() - 1.0) > 0.001 or absf(b.y.length() - 1.0) > 0.001 or absf(b.z.length() - 1.0) > 0.001:
			return null
	return t


## One ArrayMesh with every part's triangles moved by its transform (positions, normals; parts have no
## textures, so UVs and tangents are not needed). The parts' own boxes are kept as its custom AABB (culling) and
## as the node's "parts_aabb" meta (PhysicsObject._art_bounds), so the effect look wraps the same box as before.
static func _merged_mesh(g: Array) -> ArrayMesh:
	var sig := PackedStringArray()
	for e in g:
		sig.append("%d:%s" % [(e[0] as MeshInstance3D).mesh.get_instance_id(), str(e[1])])
	var key := ",".join(sig)
	if _merged.has(key):
		return _merged[key]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var box := AABB()
	var first := true
	for e in g:
		var mesh: Mesh = (e[0] as MeshInstance3D).mesh
		var t: Transform3D = e[1]
		var a := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nn = a[Mesh.ARRAY_NORMAL]
		var ii = a[Mesh.ARRAY_INDEX]
		var nb := t.basis.inverse().transposed()
		var base := verts.size()
		for k in v.size():
			verts.append(t * v[k])
			norms.append((nb * (nn[k] as Vector3)).normalized() if nn != null and nn.size() == v.size() else Vector3.UP)
		var flip := t.basis.determinant() < 0.0
		if ii == null or (ii as PackedInt32Array).is_empty():
			ii = PackedInt32Array(range(v.size()))
		var tri: PackedInt32Array = ii
		for k in range(0, tri.size() - 2, 3):
			if flip:
				idx.append_array([base + tri[k], base + tri[k + 2], base + tri[k + 1]])
			else:
				idx.append_array([base + tri[k], base + tri[k + 1], base + tri[k + 2]])
		var b: AABB = t * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	out.custom_aabb = box
	_merged[key] = out
	return out


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
