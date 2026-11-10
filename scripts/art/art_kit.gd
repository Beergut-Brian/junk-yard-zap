## The Golden Afternoon look (Kaden's pick, D44: palette A in the smooth Jarling look), as code:
## the palette, shared materials and the rounded meshes every yard visual is built from. A toy diorama
## on a table: one warm key light, smooth shading with a soft rim, a thin ink outline on props only.
## Materials and meshes are cached, so forty cows share one white and one rounded box.
## Colours mirror art/direction/palettes.json "a" (that folder is not in builds); edit both together.
class_name ArtKit
extends RefCounted

const PAL := {
	"sky_top": Color("#2f8fd0"), "sky_horizon": Color("#9fe2dc"), "cloud": Color("#fff4e2"), "sun": Color("#ffe7a0"),
	"pond": Color("#22a9bd"), "ground": Color("#c9965c"), "ground_dark": Color("#94653c"), "table": Color("#6b3f25"),
	"room": Color("#2d2a33"), "fence": Color("#b88a58"), "fence_dark": Color("#7f5a39"),
	"rust": Color("#c45a28"), "rust_dark": Color("#86391b"), "metal": Color("#97a3ab"), "enamel": Color("#f4ecda"),
	"crate": Color("#d9a75e"), "rubber": Color("#38302e"), "car": Color("#d97a34"),
	"cow": Color("#fbf5ea"), "cow_spot": Color("#4d3b33"), "chicken": Color("#fffaf0"), "beak": Color("#ffa22e"),
	"ink": Color("#24181a"), "card": Color("#fff8e8"), "key": Color("#ffe6bd"), "ambient": Color("#b8d8e6"),
	# Extras for the full yard, chosen to sit inside A: warm junk, cool sky and water.
	"hay": Color("#e8c25a"), "wood": Color("#a8703f"), "wood_light": Color("#d9b07a"), "barn": Color("#b5532f"),
	"barn_trim": Color("#f4ecda"), "leaf": Color("#7fa84a"), "teal": Color("#3f9e9a"), "mustard": Color("#e0a73a"),
	"cream": Color("#fff1d6"), "pink": Color("#f3b3b0"), "denim": Color("#4d78a8"), "plum": Color("#7a4c6e"),
}
const KEY_ENERGY := 1.4
const KEY_PITCH := -42.0
const KEY_YAW := 38.0
const AMBIENT_ENERGY := 0.55
const GLOW := 0.25
const EMIT := 0.25
## Gun hues are fixed in every palette (GAME.md "Guns"): never P1 green or P2 red.
const GUN := {
	&"size": Color("#ff9a14"), &"grow": Color("#ff9a14"), &"bouncy": Color("#ffd21a"), &"freeze": Color("#4fd8ff"),
	&"magnet": Color("#2f68ff"), &"grab": Color("#7e52ff"), &"balloon": Color("#ec3cf0"), &"glue": Color("#ff9fdf"),
}
const OUTLINE := 0.022   # metres at scale 1: thin enough to read as a pen line, not a cartoon border

static var _mats := {}
static var _meshes := {}
static var _outline_mat: StandardMaterial3D


static func c(k: String) -> Color:
	return PAL[k]


static func gun(k: StringName) -> Color:
	return GUN.get(k, Color.WHITE)


# --- materials -------------------------------------------------------------------------------------

## Smooth, slightly rimmed. emit lights it from inside (effects); outline adds the props-only ink line.
static func mat(col: Color, emit := 0.0, rough := 0.62, outline := false) -> Material:
	var key := "%s|%.2f|%.2f|%s" % [col.to_html(), emit, rough, outline]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.5
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	if outline:
		m.next_pass = outline_mat()
	_mats[key] = m
	return m


## Glassy see-through (ice, water, windows).
static func glass(col: Color, emit := 0.0) -> Material:
	var key := "glass|%s|%.2f" % [col.to_html(), emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.2
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


## Flat, self-lit (beams, glows, sparkles): reads the same in any light.
static func glow(col: Color, energy := 1.0) -> Material:
	var key := "glow|%s|%.2f" % [col.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r * energy, col.g * energy, col.b * energy, col.a)
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
	_mats[key] = m
	return m


static func outline_mat() -> StandardMaterial3D:
	if _outline_mat == null:
		_outline_mat = StandardMaterial3D.new()
		_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline_mat.grow = true
		_outline_mat.grow_amount = OUTLINE
		_outline_mat.albedo_color = c("ink")
	return _outline_mat


# --- meshes ----------------------------------------------------------------------------------------

## A box with rounded edges and smooth normals: the toy look. Cached by size and radius.
static func rbox(size: Vector3, r: float, k := 4) -> ArrayMesh:
	var key := "rbox|%.3f,%.3f,%.3f|%.3f|%d" % [size.x, size.y, size.z, r, k]
	if _meshes.has(key):
		return _meshes[key]
	var h := size * 0.5
	r = minf(r, minf(h.x, minf(h.y, h.z)) * 0.98)
	var inner := h - Vector3.ONE * r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		for s in [-1.0, 1.0]:
			var u_ax := (axis + 1) % 3
			var v_ax := (axis + 2) % 3
			var us := _samples(h[u_ax], r, k)
			var vs := _samples(h[v_ax], r, k)
			var grid := []
			for ui in us.size():
				var row := []
				for vi in vs.size():
					var p := Vector3.ZERO
					p[axis] = h[axis] * s
					p[u_ax] = us[ui]
					p[v_ax] = vs[vi]
					var cl := p.clamp(-inner, inner)
					var n := (p - cl).normalized()
					row.append([cl + n * r, n])
				grid.append(row)
			for ui in us.size() - 1:
				for vi in vs.size() - 1:
					_quad(st, grid[ui][vi], grid[ui + 1][vi], grid[ui + 1][vi + 1], grid[ui][vi + 1])
	var m := st.commit()
	_meshes[key] = m
	return m


static func _samples(hh: float, r: float, k: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in k + 1:
		out.append(-hh + r * float(i) / k)
	for i in k + 1:
		out.append(hh - r + r * float(i) / k)
	return out


static func _quad(st: SurfaceTool, a: Array, b: Array, cc: Array, d: Array) -> void:
	for tri in [[a, b, cc], [a, cc, d]]:
		var p0: Vector3 = tri[0][0]
		var p1: Vector3 = tri[1][0]
		var p2: Vector3 = tri[2][0]
		if (p1 - p0).length_squared() < 1e-12 or (p2 - p0).length_squared() < 1e-12:
			continue
		var n: Vector3 = tri[0][1] + tri[1][1] + tri[2][1]
		if (p1 - p0).cross(p2 - p0).dot(n) > 0.0:  # Godot front faces wind clockwise
			tri = [tri[0], tri[2], tri[1]]
		for v in tri:
			st.set_normal(v[1])
			st.add_vertex(v[0])


static func sphere(r: float, segs := 24) -> SphereMesh:
	var key := "sph|%.3f|%d" % [r, segs]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = segs
		m.rings = maxi(4, segs / 2)
		_meshes[key] = m
	return _meshes[key]


## Upright cylinder (axis Y). r_top 0 makes a cone.
static func cyl(r: float, hgt: float, r_top := -1.0, segs := 24) -> CylinderMesh:
	var key := "cyl|%.3f|%.3f|%.3f|%d" % [r, hgt, r_top, segs]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = r if r_top < 0.0 else r_top
		m.bottom_radius = r
		m.height = hgt
		m.radial_segments = segs
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


## Ring in the XZ plane (rotate x 90 to face the camera).
static func torus(r_in: float, r_out: float, segs := 32) -> TorusMesh:
	var key := "tor|%.3f|%.3f|%d" % [r_in, r_out, segs]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = r_in
		m.outer_radius = r_out
		m.rings = segs
		m.ring_segments = 14
		_meshes[key] = m
	return _meshes[key]


static func quad(size: Vector2) -> QuadMesh:
	var key := "quad|%.2f|%.2f" % [size.x, size.y]
	if not _meshes.has(key):
		var m := QuadMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


# --- placing ---------------------------------------------------------------------------------------

## Add a mesh to parent. rot in degrees. Returns it so callers can tweak shadows or materials.
static func put(parent: Node3D, mesh: Mesh, col: Color, pos := Vector3.ZERO, rot := Vector3.ZERO,
		scl := Vector3.ONE, emit := 0.0, outline := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(col, emit, 0.62, outline)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


## Same, with a material you already have (glass, glow).
static func put_mat(parent: Node3D, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO,
		scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func group(parent: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := 1.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot
	n.scale = Vector3.ONE * scl
	parent.add_child(n)
	return n


## A stick from a to b (cables, rails, struts).
static func rod(parent: Node3D, a: Vector3, b: Vector3, r: float, col: Color) -> MeshInstance3D:
	var d := b - a
	var mi := put(parent, cyl(r, d.length(), -1.0, 10), col, (a + b) * 0.5)
	mi.basis = basis_y(d.normalized())
	return mi


static func basis_y(up: Vector3) -> Basis:
	var side := Vector3(0, 0, 1) if absf(up.z) < 0.9 else Vector3(1, 0, 0)
	var x := up.cross(side).normalized()
	var z := x.cross(up).normalized()
	return Basis(x, up, z)


static func no_shadow(n: Node) -> void:
	for mi in n.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
