## S-18: draw every material the yard only makes during play once, before play, so its shader and its
## pipelines compile at load (the lobby, or the bench's warmup) and not in the frame of the first zap.
## On a cold shader cache the first burst on the 1060 stalled 2-4 s; on a warm one each new kind still
## compiled its pipelines in the frame (RenderingServer "draw" pipeline compilations, .scratch findings).
## Each kind is drawn the way play draws it: as a plain mesh and as CPU particles (a multimesh, which has
## its own pipelines), shadow casting on, from the same factories play uses (Fx, GunHits, Effects.Glue,
## Refusal, PhysicsObject, LooseBalloon). The meshes sit a hair in front of the camera at 1 mm, so nothing
## shows; after FRAMES frames they free themselves. The materials stay alive for the session (`keep`):
## a StandardMaterial3D's shader is shared by every material with the same flags and dropped when the
## last one goes, so a kept one means a zap ring never brings it back from nothing.
class_name RenderPrewarm
extends Node3D

const FRAMES := 6
const SIZE := 0.001
## Every material drawn, alive until the game quits (see above).
static var keep: Array[Material] = []
## Times run() built the kit (tests).
static var runs := 0

var _left := FRAMES


## One material per kind of thing made during play (colours don't matter: the flags pick the shader).
static func materials() -> Array[Material]:
	var c := Color(0.9, 0.5, 0.2)
	var a := Color(0.9, 0.5, 0.2, 0.8)
	var out: Array[Material] = [
		Fx.flat_mat(c),                  # burst dots, gun hits, the zzz: opaque flat
		Fx.flat_mat(a),                  # dust, see-through hits
		Fx.ring_mat(a),                  # zap rings (and GunHits rings: same flags)
		Effects.Glue.glow_mat(c, 0.6),   # glue string and blob
		Refusal.strand_mat(a),           # snapped glue strand
		Refusal.flat_mat(a, 0),          # refusal signs (billboards)
		PhysicsObject.overlay_mat(),     # effect tint over the art
		LooseBalloon.puff_mat(),         # balloon pop puffs
		# The effect looks (EffectLook): built on an object at its first bouncy / freeze / magnet / grab /
		# balloon. Their boxes are prewarmed (jyz-hitch-1); these are their materials' kinds.
		ArtKit.mat(c, ArtKit.EMIT, 0.3),            # lit-from-inside bands, balls, blobs
		ArtKit.mat(c),                              # plain rim (strings, tips)
		ArtKit.mat(a, ArtKit.EMIT, 0.3),            # see-through lit
		ArtKit.glow(c, 1.0),                        # sparks, shines
		ArtKit.glow(Color(c, 0.22), 1.3),           # the grab shell
		ArtKit.glass(Color(0.7, 0.9, 1.0, 0.5)),    # ice
		ArtKit.glass(Color(0.7, 0.9, 1.0, 0.5), 0.4),
	]
	return out


## Builds the kit in front of `camera` under `parent` (null camera = the viewport's). Returns it.
static func run(parent: Node, camera: Camera3D = null) -> RenderPrewarm:
	runs += 1
	var kit := RenderPrewarm.new()
	kit.name = "RenderPrewarm"
	parent.add_child(kit)
	if camera == null:
		camera = kit.get_viewport().get_camera_3d()
	if camera:
		kit.global_transform = camera.global_transform.translated_local(Vector3(0, 0, -(camera.near + 0.5)))
	var mesh := SphereMesh.new()
	mesh.radius = SIZE
	mesh.height = SIZE * 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	var kept: Array[Material] = []   # the old set goes only once the new one holds the shaders
	for m in materials():
		kept.append(m)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		kit.add_child(mi)
		var pm := mesh.duplicate() as SphereMesh
		pm.material = m
		var p := CPUParticles3D.new()
		p.mesh = pm
		p.amount = 1
		p.lifetime = 1.0
		p.explosiveness = 1.0
		p.gravity = Vector3.ZERO
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 0.0
		kit.add_child(p)
		p.emitting = true
	# The overlay is drawn as an overlay in play (material_overlay), its own pass.
	var over := MeshInstance3D.new()
	over.mesh = mesh
	over.material_overlay = PhysicsObject.overlay_mat()
	kept.append(over.material_overlay)
	kit.add_child(over)
	keep = kept
	return kit


func _process(_delta: float) -> void:
	_left -= 1
	if _left <= 0:
		queue_free()
