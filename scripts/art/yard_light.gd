## The Golden Afternoon light: one warm key light with crisp soft-edged shadows, a cool sky ambient,
## filmic tone mapping, a whisper of glow for the gun colours. Shared by the yard, the previews and
## the store renders so they all match art/direction/frame_a.png.
class_name YardLight
extends RefCounted


static func add(parent: Node, shadow_distance := 140.0) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "KeyLight"
	sun.rotation_degrees = Vector3(ArtKit.KEY_PITCH, ArtKit.KEY_YAW, 0)
	sun.light_color = ArtKit.c("key")
	sun.light_energy = ArtKit.KEY_ENERGY
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 1.5
	sun.directional_shadow_max_distance = shadow_distance
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	parent.add_child(sun)
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = environment()
	parent.add_child(we)
	return sun


static func environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ArtKit.c("sky_horizon")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ArtKit.c("ambient")
	env.ambient_light_energy = ArtKit.AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.2
	env.glow_enabled = true
	env.glow_intensity = ArtKit.GLOW
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	return env
