## Graphics tiers (data/graphics.json). Autoload: Graphics, first in the list so the tier is set before
## any scene builds its lights.
## high = today's look (the GTX 1060): no overrides at all, nothing here touches a node.
## low  = the Intel HD 530 (Skylake GT2, Mesa ANV) on the TV box: no MSAA (FXAA), 0.75 render scale with
##        FSR 1, one short shadow cascade, SSAO / SSIL / SSR / SDFGI / glow / volumetrics off, LOD bias up,
##        half the particles, 60 fps cap, vsync on. camera_far + depth fog are supported keys but not used:
##        the yard is a closed diorama whose painted sky is the farthest thing, so a shorter far only cut
##        the sky off (see data/graphics.json _doc).
## Auto-pick at boot from the adapter (pick()): NVIDIA, or AMD discrete -> high; Intel, software, AMD
## integrated, anything unknown -> low. `--graphics=low|high` (either side of `--`) overrides. Headless runs
## (tests, tools) have no renderer and stay high unless the flag says otherwise. The pick is logged as one
## "Graphics:" line; dev builds show the tier next to the version label (label_suffix()).
extends Node

const DATA := "res://data/graphics.json"
const TIERS: Array[String] = ["high", "low"]
const FLAG := "--graphics="

## RenderingDevice.DeviceType values, kept here so pick() reads without a RenderingDevice.
const TYPE_OTHER := 0
const TYPE_INTEGRATED := 1
const TYPE_DISCRETE := 2
const TYPE_VIRTUAL := 3
const TYPE_CPU := 4

signal tier_applied(tier: String)

## The tier in force ("high" until boot picks).
var tier := "high"
## Why: "auto: ..." or "flag" or "headless".
var reason := ""
## The tier's overrides ({} for high).
var settings := {}
var _tiers := {}
var _hooked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tiers = load_tiers()
	var adapter := RenderingServer.get_video_adapter_name()
	var vendor := RenderingServer.get_video_adapter_vendor()
	var type := int(RenderingServer.get_video_adapter_type())
	var headless := DisplayServer.get_name() == "headless"
	var p := pick(adapter, vendor, type, flag_from_args(OS.get_cmdline_args() + OS.get_cmdline_user_args()), headless)
	apply(p.tier, p.reason)
	print("Graphics: tier=%s (%s) adapter=\"%s\" vendor=\"%s\" type=%d" % [tier, reason, adapter, vendor, type])


## "--graphics=low" -> "low"; "" when absent or not a known tier.
static func flag_from_args(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with(FLAG):
			var t := a.trim_prefix(FLAG).strip_edges().to_lower()
			if t in TIERS:
				return t
			push_warning("Graphics: unknown tier '%s' (want high or low); auto-picking" % t)
	return ""


## The tier for an adapter: {tier, reason}. Pure, so tests feed it adapter strings.
static func pick(adapter: String, vendor: String, type := TYPE_OTHER, flag := "", headless := false) -> Dictionary:
	if flag != "":
		return {"tier": flag, "reason": "flag"}
	if headless:
		return {"tier": "high", "reason": "headless"}
	var s := (adapter + " " + vendor).to_lower()
	if type == TYPE_CPU or "llvmpipe" in s or "lavapipe" in s or "swiftshader" in s or "software" in s:
		return {"tier": "low", "reason": "auto: software renderer"}
	if "nvidia" in s or "geforce" in s or "quadro" in s:
		return {"tier": "high", "reason": "auto: NVIDIA"}
	if "amd" in s or "radeon" in s or "ati technologies" in s or "advanced micro devices" in s:
		var discrete := type == TYPE_DISCRETE
		if type == TYPE_OTHER:   # no type reported: the discrete Radeon names
			for k in [" rx ", "rx 5", "rx 6", "rx 7", "rx 9", " r9 ", " r7 ", "vega 56", "vega 64", "radeon pro w"]:
				if k in " " + s + " ":
					discrete = true
		if discrete:
			return {"tier": "high", "reason": "auto: AMD discrete"}
		return {"tier": "low", "reason": "auto: AMD integrated"}
	if "intel" in s:
		return {"tier": "low", "reason": "auto: Intel"}
	return {"tier": "low", "reason": "auto: unknown adapter"}


static func load_tiers() -> Dictionary:
	var f := FileAccess.get_file_as_string(DATA)
	var d = JSON.parse_string(f) if f != "" else null
	if not d is Dictionary:
		push_error("Graphics: %s missing or broken; every tier is high" % DATA)
		return {"high": {}, "low": {}}
	var out := {}
	for t in TIERS:
		out[t] = d.get(t, {}) if d.get(t, {}) is Dictionary else {}
	return out


## The overrides a tier sets ({} for high).
func tier_settings(t: String) -> Dictionary:
	if _tiers.is_empty():
		_tiers = load_tiers()
	return _tiers.get(t, {})


## Puts a tier in force: the root viewport, the engine caps, every node already in the tree, and from then on
## every node that enters it (lights, environments, cameras, SubViewports, particles). high with no overrides
## touches nothing. Switching back from low to high at runtime only stops the hook: what low already tuned stays
## (restart the game to get high back; tests restore by hand).
func apply(t: String, why := "") -> void:
	tier = t if t in TIERS else "high"
	reason = why
	settings = tier_settings(tier)
	if settings.is_empty() and _hooked:   # back to high (tests): stop tuning new nodes; what was tuned stays
		get_tree().node_added.disconnect(_on_node_added)
		_hooked = false
	if not settings.is_empty():
		var root := get_tree().root
		tune_viewport(root, settings)
		tune_engine(settings)
		_walk(root)
		if not _hooked:
			get_tree().node_added.connect(_on_node_added)
			_hooked = true
	tier_applied.emit(tier)


## The text after the version label in dev builds (" · low"), "" in release builds.
func label_suffix() -> String:
	return "  ·  %s" % tier if is_dev_build() else ""


static func is_dev_build() -> bool:
	return OS.is_debug_build() or "-dev" in str(ProjectSettings.get_setting("application/config/version", ""))


func _walk(n: Node) -> void:
	_tune(n)
	for c in n.get_children():
		_walk(c)


func _on_node_added(n: Node) -> void:
	_tune(n)


func _tune(n: Node) -> void:
	if n is SubViewport:
		tune_subviewport(n as SubViewport, settings)
	elif n is WorldEnvironment:
		if (n as WorldEnvironment).environment:
			tune_environment((n as WorldEnvironment).environment, settings)
	elif n is DirectionalLight3D:
		tune_light(n as DirectionalLight3D, settings)
	elif n is Camera3D:
		# Rigs set far in their own _ready, after node_added: tune after them, and again if the environment is the camera's.
		(func() -> void:
			if is_instance_valid(n):
				tune_camera(n as Camera3D, settings)).call_deferred()
	elif n is CPUParticles3D:
		(n as CPUParticles3D).amount = maxi(1, roundi((n as CPUParticles3D).amount * float(settings.get("particles", 1.0))))
	elif n is GPUParticles3D:
		(n as GPUParticles3D).amount = maxi(1, roundi((n as GPUParticles3D).amount * float(settings.get("particles", 1.0))))


# ------------------------------------------------------------------------------- the settings, one target each
# Each one is pure (settings in, the target changed) so tests run them on their own viewports and environments.
# A key that is absent leaves the target alone: that is how high stays exactly as today.

const SCALING := {"bilinear": Viewport.SCALING_3D_MODE_BILINEAR, "fsr": Viewport.SCALING_3D_MODE_FSR, "fsr2": Viewport.SCALING_3D_MODE_FSR2}
const SCREEN_AA := {"off": Viewport.SCREEN_SPACE_AA_DISABLED, "fxaa": Viewport.SCREEN_SPACE_AA_FXAA, "smaa": Viewport.SCREEN_SPACE_AA_SMAA}
const SHADOW_MODE := {"orthogonal": DirectionalLight3D.SHADOW_ORTHOGONAL, "2_splits": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "4_splits": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS}
const SOFT_SHADOW := {"hard": RenderingServer.SHADOW_QUALITY_HARD, "soft_very_low": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "soft_low": RenderingServer.SHADOW_QUALITY_SOFT_LOW}


static func tune_viewport(vp: Viewport, s: Dictionary) -> void:
	if s.has("msaa_3d"):
		vp.msaa_3d = int(s.msaa_3d) as Viewport.MSAA
	if s.has("screen_space_aa"):
		vp.screen_space_aa = SCREEN_AA.get(s.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED)
	if s.has("scaling_3d_mode"):
		vp.scaling_3d_mode = SCALING.get(s.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR)
	if s.has("scaling_3d_scale"):
		vp.scaling_3d_scale = float(s.scaling_3d_scale)
	if s.has("mesh_lod_threshold"):
		vp.mesh_lod_threshold = float(s.mesh_lod_threshold)


## SubViewports (the lobby's podium characters, the blurred menu yard, the fence cards): no MSAA, LOD up.
## Their render scale stays 1: they are small already.
static func tune_subviewport(vp: SubViewport, s: Dictionary) -> void:
	if s.has("subviewport_msaa_3d"):
		vp.msaa_3d = int(s.subviewport_msaa_3d) as Viewport.MSAA
	if s.has("mesh_lod_threshold"):
		vp.mesh_lod_threshold = float(s.mesh_lod_threshold)


static func tune_engine(s: Dictionary) -> void:
	if s.has("max_fps"):
		Engine.max_fps = int(s.max_fps)
	if s.has("vsync") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if s.vsync else DisplayServer.VSYNC_DISABLED)
	if s.has("shadow_atlas_size"):
		RenderingServer.directional_shadow_atlas_set_size(int(s.shadow_atlas_size), true)
	if s.has("soft_shadow_quality"):
		var q: int = SOFT_SHADOW.get(s.soft_shadow_quality, RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		RenderingServer.directional_soft_shadow_filter_set_quality(q as RenderingServer.ShadowQuality)
		RenderingServer.positional_soft_shadow_filter_set_quality(q as RenderingServer.ShadowQuality)


static func tune_environment(env: Environment, s: Dictionary) -> void:
	if s.has("ssao"):
		env.ssao_enabled = bool(s.ssao)
	if s.has("ssil"):
		env.ssil_enabled = bool(s.ssil)
	if s.has("ssr"):
		env.ssr_enabled = bool(s.ssr)
	if s.has("sdfgi"):
		env.sdfgi_enabled = bool(s.sdfgi)
	if s.has("glow"):
		env.glow_enabled = bool(s.glow)
	if s.has("volumetric_fog"):
		env.volumetric_fog_enabled = bool(s.volumetric_fog)
	if s.has("fog_depth_end"):
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_depth_begin = float(s.get("fog_depth_begin", 0.0))
		env.fog_depth_end = float(s.fog_depth_end)
		env.fog_density = float(s.get("fog_density", 1.0))
		env.fog_light_color = env.background_color if env.background_mode == Environment.BG_COLOR else Color(0.85, 0.9, 0.95)
		env.fog_light_energy = 1.0
		env.fog_sun_scatter = 0.0
		env.fog_aerial_perspective = 0.0
		env.fog_sky_affect = 0.0


static func tune_light(sun: DirectionalLight3D, s: Dictionary) -> void:
	if s.has("shadow_mode"):
		sun.directional_shadow_mode = SHADOW_MODE.get(s.shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL)
	if s.has("shadow_max_distance"):
		sun.directional_shadow_max_distance = minf(sun.directional_shadow_max_distance, float(s.shadow_max_distance))
	if s.has("shadow_blur"):
		sun.shadow_blur = float(s.shadow_blur)
	if s.has("shadows") and not bool(s.shadows):
		sun.shadow_enabled = false


static func tune_camera(cam: Camera3D, s: Dictionary) -> void:
	if s.has("camera_far"):
		cam.far = minf(cam.far, float(s.camera_far))
