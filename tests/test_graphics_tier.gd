## jyz-igpu-1: graphics tiers (data/graphics.json, scripts/autoload/Graphics.gd) and the bench
## (scripts/tools/bench.gd). The TV box is an Intel HD 530: it must auto-pick low; a GTX 1060 picks high;
## --graphics= overrides; low is applied to viewports, environments, lights, cameras and particles; high
## is pinned to exactly today's look; -- --bench runs by itself, prints the summary line and quits.
## Scratch picks file; the bench child runs on a scratch XDG_DATA_HOME (its own players.json and saves).
class_name TestGraphicsTier
extends GdUnitTestSuite

const PICKS := "user://test_graphics_tier_picks.json"
const INTEL := "Mesa Intel(R) HD Graphics 530 (SKL GT2)"
const GTX := "NVIDIA GeForce GTX 1060 6GB"

var _real_picks := ""


func before() -> void:
	_real_picks = Roster.picks_path
	Roster.picks_path = PICKS


func after() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PICKS))
	Roster.picks_path = _real_picks


func _low() -> Dictionary:
	return Graphics.tier_settings("low")


# ------------------------------------------------------------------------------------------ the pick

func test_intel_hd_530_picks_low() -> void:
	assert_str(Graphics.pick(INTEL, "Intel", Graphics.TYPE_INTEGRATED).tier).is_equal("low")
	assert_str(Graphics.pick("Intel(R) HD Graphics 530", "Intel Corporation").tier).is_equal("low")
	assert_str(Graphics.pick("Mesa Intel(R) HD Graphics 530 (SKL GT2)", "").tier).is_equal("low")
	assert_str(Graphics.pick(INTEL, "Intel", Graphics.TYPE_INTEGRATED).reason).contains("Intel")


func test_gtx_1060_picks_high() -> void:
	assert_str(Graphics.pick(GTX, "NVIDIA", Graphics.TYPE_DISCRETE).tier).is_equal("high")
	assert_str(Graphics.pick("NVIDIA GeForce GTX 1060", "NVIDIA Corporation").tier).is_equal("high")


func test_amd_discrete_high_integrated_and_unknown_low() -> void:
	assert_str(Graphics.pick("AMD Radeon RX 580 Series (RADV POLARIS10)", "AMD", Graphics.TYPE_DISCRETE).tier).is_equal("high")
	assert_str(Graphics.pick("AMD Radeon RX 580 Series", "AMD").tier).is_equal("high")
	assert_str(Graphics.pick("AMD Radeon Graphics (RADV RENOIR)", "AMD", Graphics.TYPE_INTEGRATED).tier).is_equal("low")
	assert_str(Graphics.pick("llvmpipe (LLVM 21.1.8, 256 bits)", "Unknown", Graphics.TYPE_CPU).tier).is_equal("low")
	assert_str(Graphics.pick("Some Future GPU", "Mystery").tier).is_equal("low")


func test_the_flag_overrides_the_adapter() -> void:
	assert_str(Graphics.pick(INTEL, "Intel", Graphics.TYPE_INTEGRATED, "high").tier).is_equal("high")
	assert_str(Graphics.pick(GTX, "NVIDIA", Graphics.TYPE_DISCRETE, "low").tier).is_equal("low")
	assert_str(Graphics.pick(GTX, "NVIDIA", Graphics.TYPE_DISCRETE, "low").reason).is_equal("flag")
	assert_str(Graphics.flag_from_args(PackedStringArray(["--demo", "--graphics=low"]))).is_equal("low")
	assert_str(Graphics.flag_from_args(PackedStringArray(["--graphics=HIGH"]))).is_equal("high")
	assert_str(Graphics.flag_from_args(PackedStringArray(["--demo"]))).is_equal("")


func test_headless_stays_high_unless_flagged() -> void:
	assert_str(Graphics.pick("", "", Graphics.TYPE_OTHER, "", true).tier).is_equal("high")
	assert_str(Graphics.pick("", "", Graphics.TYPE_OTHER, "low", true).tier).is_equal("low")
	assert_str(Graphics.tier).is_equal("high")   # this suite runs headless with no flag


# ------------------------------------------------------------------------------------------ low applied

func test_low_tunes_a_viewport() -> void:
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X
	Graphics.tune_viewport(vp, _low())
	assert_int(vp.msaa_3d).is_equal(Viewport.MSAA_DISABLED)
	assert_int(vp.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_FXAA)
	assert_int(vp.scaling_3d_mode).is_equal(Viewport.SCALING_3D_MODE_FSR)
	assert_float(vp.scaling_3d_scale).is_between(0.5, 0.75)
	assert_float(vp.mesh_lod_threshold).is_greater(1.0)
	var sub := SubViewport.new()
	sub.msaa_3d = Viewport.MSAA_4X
	Graphics.tune_subviewport(sub, _low())
	assert_int(sub.msaa_3d).is_equal(Viewport.MSAA_DISABLED)
	vp.free()
	sub.free()


func test_low_tunes_the_yard_environment_light_and_camera() -> void:
	var env := YardLight.environment()
	Graphics.tune_environment(env, _low())
	assert_bool(env.fog_enabled).is_false()   # low keeps the diorama clear (see graphics.json _doc)
	Graphics.tune_environment(env, {"fog_depth_begin": 70.0, "fog_depth_end": 170.0, "fog_density": 0.6})
	assert_bool(env.ssao_enabled).is_false()
	assert_bool(env.ssil_enabled).is_false()
	assert_bool(env.ssr_enabled).is_false()
	assert_bool(env.glow_enabled).is_false()
	assert_bool(env.volumetric_fog_enabled).is_false()
	assert_bool(env.sdfgi_enabled).is_false()
	assert_bool(env.fog_enabled).is_true()
	assert_int(env.fog_mode).is_equal(Environment.FOG_MODE_DEPTH)
	assert_object(env.fog_light_color).is_equal(env.background_color)   # the fog is the sky: no grey band
	var holder := Node3D.new()
	var sun := YardLight.add(holder)
	Graphics.tune_light(sun, _low())
	assert_int(sun.directional_shadow_mode).is_equal(DirectionalLight3D.SHADOW_ORTHOGONAL)
	assert_float(sun.directional_shadow_max_distance).is_less_equal(60.0)
	var cam := Camera3D.new()
	cam.far = 300.0
	Graphics.tune_camera(cam, _low())
	assert_float(cam.far).is_equal(300.0)   # low never cuts the painted sky off (the wide shot is ~150 m from it)
	Graphics.tune_camera(cam, {"camera_far": 170.0})
	assert_float(cam.far).is_equal(170.0)
	cam.free()
	holder.free()
	var d := _low()
	assert_int(int(d.max_fps)).is_equal(60)
	assert_bool(d.vsync).is_true()
	assert_float(float(d.particles)).is_less(1.0)


func test_low_applied_tunes_the_root_and_every_node_that_enters() -> void:
	var root := get_tree().root
	var was := [root.msaa_3d, root.screen_space_aa, root.scaling_3d_mode, root.scaling_3d_scale, root.mesh_lod_threshold, Engine.max_fps]
	Graphics.apply("low", "test")
	assert_int(root.msaa_3d).is_equal(Viewport.MSAA_DISABLED)
	assert_int(root.scaling_3d_mode).is_equal(Viewport.SCALING_3D_MODE_FSR)
	assert_int(Engine.max_fps).is_equal(60)
	var n := Node3D.new()
	YardLight.add(n)   # the light and environment exist before they enter the tree, as in the yard
	var p := CPUParticles3D.new()
	p.amount = 16
	n.add_child(p)
	var cam := Camera3D.new()
	cam.far = 300.0
	n.add_child(cam)
	add_child(n)
	await get_tree().process_frame
	var we := n.get_node("Environment") as WorldEnvironment
	assert_bool(we.environment.ssao_enabled).is_false()
	assert_bool(we.environment.glow_enabled).is_false()
	assert_int((n.get_node("KeyLight") as DirectionalLight3D).directional_shadow_mode).is_equal(DirectionalLight3D.SHADOW_ORTHOGONAL)
	assert_int(p.amount).is_equal(8)
	assert_float(cam.far).is_equal(300.0)
	# back to high: the hook stops, the root and the engine are restored by hand
	Graphics.apply("high", "headless")
	root.msaa_3d = was[0]
	root.screen_space_aa = was[1]
	root.scaling_3d_mode = was[2]
	root.scaling_3d_scale = was[3]
	root.mesh_lod_threshold = was[4]
	Engine.max_fps = was[5]
	var q := CPUParticles3D.new()
	q.amount = 16
	add_child(q)
	assert_int(q.amount).is_equal(16)
	n.free()
	q.free()


# ------------------------------------------------------------------------------------------ high pinned

func test_high_is_todays_look_exactly() -> void:
	assert_dict(Graphics.tier_settings("high")).is_empty()
	# Today's look, pinned: project MSAA 2x, Forward+, the Golden Afternoon light.
	assert_int(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d"))).is_equal(Viewport.MSAA_2X)
	assert_str(str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))).is_equal("forward_plus")
	assert_int(int(ProjectSettings.get_setting("display/window/vsync/vsync_mode"))).is_equal(1)
	var root := get_tree().root
	assert_int(root.msaa_3d).is_equal(Viewport.MSAA_2X)
	assert_int(root.scaling_3d_mode).is_equal(Viewport.SCALING_3D_MODE_BILINEAR)
	assert_float(root.scaling_3d_scale).is_equal(1.0)
	assert_int(root.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_int(Engine.max_fps).is_equal(0)
	var env := YardLight.environment()
	var before := _snapshot(env)
	Graphics.tune_environment(env, {})
	assert_dict(_snapshot(env)).is_equal(before)
	assert_bool(env.ssao_enabled).is_true()
	assert_bool(env.glow_enabled).is_true()
	assert_bool(env.fog_enabled).is_false()
	var holder := Node3D.new()
	var sun := YardLight.add(holder)
	Graphics.tune_light(sun, {})
	assert_bool(sun.shadow_enabled).is_true()
	assert_int(sun.directional_shadow_mode).is_equal(DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	assert_float(sun.directional_shadow_max_distance).is_equal(140.0)
	assert_float(sun.shadow_blur).is_equal(1.5)
	holder.free()
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X
	Graphics.tune_viewport(vp, {})
	Graphics.tune_subviewport(vp, {})
	assert_int(vp.msaa_3d).is_equal(Viewport.MSAA_2X)
	assert_float(vp.scaling_3d_scale).is_equal(1.0)
	vp.free()


func _snapshot(o: Object) -> Dictionary:
	var out := {}
	for p in o.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE:
			out[p.name] = o.get(p.name)
	return out


func test_dev_builds_show_the_tier_by_the_version() -> void:
	assert_bool(Graphics.is_dev_build()).is_true()   # tests run a debug build
	assert_str(Graphics.label_suffix()).contains("high")


# ------------------------------------------------------------------------------------------ the bench

func test_bench_stats_avg_and_one_percent_low() -> void:
	var f := PackedInt64Array()
	for i in 99:
		f.append(10000)   # 10 ms
	f.append(50000)       # one 50 ms hitch: the slowest 1%
	var st := BenchProbe.stats(f)
	assert_float(st.low1).is_equal_approx(20.0, 0.01)
	assert_float(st.avg).is_equal_approx(100.0 / 1.04, 0.01)
	assert_float(st.worst_ms).is_equal_approx(50.0, 0.001)
	assert_float(BenchProbe.seconds_from_args(PackedStringArray(["--bench-seconds=12"]))).is_equal(12.0)
	assert_float(BenchProbe.seconds_from_args(PackedStringArray([]))).is_equal(60.0)


func test_bench_runs_its_route_and_finishes_with_the_summary_line() -> void:
	var b := BenchProbe.new()
	b.quit_when_done = false
	b.duration = 3.0
	b.report_every = 1.0
	b.warmup = 0.0
	var cam := CameraRig.new()   # the route drives the shared camera's overview (not in the tree: no _ready)
	b.camera = cam
	add_child(b)
	for i in 180:   # 3 s of 60 fps frames
		b.feed(16667)
		if i == 30:
			assert_bool(cam.overview).is_false()   # follow
		if i == 90:
			assert_bool(cam.overview).is_true()    # the yard-wide middle third
	assert_bool(b.done).is_true()
	assert_bool(cam.overview).is_false()       # handed back
	assert_str(b.lines[b.lines.size() - 1]).starts_with("BENCH avg=")
	assert_str(b.lines[b.lines.size() - 1]).contains("low1=").contains("tier=high")
	assert_int(b.lines.size()).is_equal(1 + 3 + 1)   # start, a line per second, the summary
	assert_str(b.segment(0.5)).is_equal("follow")
	assert_str(b.segment(1.5)).is_equal("wide")
	assert_str(b.segment(2.5)).is_equal("follow")
	b.free()
	cam.free()


func test_bench_mode_quits_by_itself_and_prints_the_summary() -> void:
	var scratch := ProjectSettings.globalize_path("user://bench_child")
	DirAccess.make_dir_recursive_absolute(scratch)
	var out := []
	var cmd := "XDG_DATA_HOME='%s' timeout 150 '%s' --headless --path '%s' -- --bench --bench-seconds=3 --graphics=low 2>&1" % [
			scratch, OS.get_executable_path(), ProjectSettings.globalize_path("res://")]
	var code := OS.execute("bash", ["-c", cmd], out)
	var text: String = "\n".join(out)
	OS.execute("rm", ["-rf", "--", scratch])
	assert_int(code).override_failure_message("exit %d\n%s" % [code, text.right(2000)]).is_equal(0)
	assert_str(text).contains("Graphics: tier=low (flag)")
	assert_str(text).contains("bench: start tier=low")
	var summary := ""
	for l in text.split("\n"):
		if l.begins_with("BENCH avg="):
			summary = l
	assert_str(summary).override_failure_message(text.right(2000)).contains("low1=").contains("tier=low")
	assert_str(text).not_contains("SCRIPT ERROR")
