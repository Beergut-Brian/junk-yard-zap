## S-18 hitches (jyz-hitch-1). The 2026-11-17 GTX 1060 bench averaged 68.5 fps but its 1%-low was 33.5
## (worst frame 43-45 ms). Timed headless on the bench route, the slow frames were main-thread work done
## at the moment of a zap or a landing: every Audio.play built a new Vorbis decoder (0.7-1.5 ms each, 3-4
## in a busy frame), the first effect look on an object built its rounded boxes in the frame (1-2.5 ms
## each), and every burst and ring made a fresh mesh and material. These pin the three fixes: SFX play
## from PCM decoded at boot on a worker, the yard prewarms every look's rounded boxes off the main thread,
## and bursts / rings share their meshes. Nothing here changes what is seen or heard.
class_name TestHitch
extends GdUnitTestSuite

var world: Node3D


func before_test() -> void:
	Game.demo = false
	world = Node3D.new()
	add_child(world)


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()


func level() -> YardLevel:
	var l := YardLevel.new()
	l.use_save = false
	l.layout = load(YardLevel.LAYOUT)
	world.add_child(l)
	var players := Node3D.new()
	players.name = "Players"
	l.add_child(players)
	return l


func _sfx_files() -> int:
	var n := 0
	for f in ResourceLoader.list_directory(Audio.SFX_DIR):
		if f.ends_with(".ogg"):
			n += 1
	return n


# ------------------------------------------------------------------------------------------- audio

func test_every_sfx_file_is_decoded_to_pcm_at_boot() -> void:
	Audio.wait_pcm()
	assert_bool(Audio.pcm_ready()).is_true()
	assert_int(Audio.pcm_count).is_equal(_sfx_files())
	assert_int(Audio.pcm_count).is_greater(100)


func test_play_starts_the_pcm_copy_of_the_same_sound() -> void:
	Audio.wait_pcm()
	Audio.stop_all()
	Audio.play("impact_medium")
	var playing: AudioStreamPlayer = null
	for p in Audio._pool:
		if p.playing and p.get_meta(&"cue") == "impact_medium":
			playing = p
	assert_object(playing).is_not_null()
	assert_object(playing.stream).is_instanceof(AudioStreamWAV)
	var ogg: AudioStream = load(Audio.SFX_DIR + "impact_medium_%d.ogg" % (Audio.last_variant["impact_medium"] + 1))
	# Same sound: as long as the file, at the mixer's rate, so it plays without resampling.
	assert_float(playing.stream.get_length()).is_equal_approx(ogg.get_length(), 0.01)
	assert_int((playing.stream as AudioStreamWAV).mix_rate).is_equal(roundi(AudioServer.get_mix_rate()))
	Audio.stop_all()


func test_decoded_pcm_matches_the_ogg_samples() -> void:
	var ogg: AudioStream = load(Audio.SFX_DIR + "boing.ogg") if ResourceLoader.exists(Audio.SFX_DIR + "boing.ogg") \
			else load(Audio.SFX_DIR + "impact_medium_1.ogg")
	var rate := AudioServer.get_mix_rate()
	var wav := Audio.decode_pcm(ogg, rate)
	assert_object(wav).is_not_null()
	var pb := ogg.instantiate_playback()
	pb.start(0.0)
	var ref := pb.mix_audio(1.0, 2048)
	var step := 4 if wav.stereo else 2
	var worst := 0.0
	for i in ref.size():
		worst = maxf(worst, absf(wav.data.decode_s16(i * step) / 32767.0 - ref[i].x))
	assert_float(worst).is_less(0.001)   # 16-bit rounding, nothing else


func test_looping_or_missing_streams_are_left_alone() -> void:
	var loop: AudioStreamOggVorbis = (load(Audio.SFX_DIR + "impact_medium_1.ogg") as AudioStreamOggVorbis).duplicate()
	loop.loop = true
	assert_object(Audio.decode_pcm(loop, 44100.0)).is_null()
	assert_object(Audio.decode_pcm(null, 44100.0)).is_null()
	var beep := Synth.beep("nope_not_a_file")
	assert_object(Audio.pcm(beep)).is_same(beep)


# ------------------------------------------------------------------------------------- effect looks

func test_yard_prewarms_every_effect_look_off_the_frame() -> void:
	var l := level()
	ArtKit.wait_rbox_prewarm()
	var before := ArtKit.rbox_built_now
	for o: PhysicsObject in l.objects.values():
		for kind in [&"bouncy", &"freeze", &"magnet", &"grab"]:
			var n := o.look._build(kind, Color.WHITE)
			if n:
				n.free()
	assert_int(ArtKit.rbox_built_now).override_failure_message(
			"%d rounded boxes were built in the frame" % (ArtKit.rbox_built_now - before)).is_equal(before)


func test_prewarmed_box_is_the_same_mesh_as_one_built_on_the_spot() -> void:
	var sz := Vector3(1.234, 0.987, 0.811)
	var arrays := ArtKit.rbox_arrays(sz, 0.2, 3)
	ArtKit.prewarm_rboxes([[sz, 0.2, 3]])
	ArtKit.wait_rbox_prewarm()
	var before := ArtKit.rbox_built_now
	var m := ArtKit.rbox(sz, 0.2, 3)
	assert_int(ArtKit.rbox_built_now).is_equal(before)
	var got := m.surface_get_arrays(0)
	assert_int((got[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()).is_equal((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	assert_that(got[Mesh.ARRAY_VERTEX]).is_equal(arrays[Mesh.ARRAY_VERTEX])
	assert_object(ArtKit.rbox(sz, 0.2, 3)).is_same(m)   # cached from then on


# ------------------------------------------------------------------------------------ bursts / rings

func test_bursts_and_rings_share_their_meshes() -> void:
	var tree := get_tree()
	var was := tree.current_scene
	var scene := Node3D.new()   # Fx draws into the current scene; the test runner has none
	tree.root.add_child(scene)
	tree.current_scene = scene
	var col := Color(0.75, 0.65, 0.5, 0.8)
	var a := Fx.burst(tree, Vector3.ZERO, col, 10, 0.7, 0.4)
	var made := Fx.meshes_made
	var b := Fx.burst(tree, Vector3.ONE, col, 10, 0.7, 0.4)
	assert_object(b.mesh).is_same(a.mesh)
	assert_int(Fx.meshes_made).is_equal(made)
	var c := Fx.burst(tree, Vector3.ONE, Color(1, 1, 0.8), 10, 0.7, 0.4)   # another colour: its own mesh
	assert_object(c.mesh).is_not_same(a.mesh)
	assert_that((c.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color).is_equal(Color(1, 1, 0.8))
	# Gun hits: the second zap of a kind at the same size builds no mesh.
	for kind in [GunData.Kind.SIZE, GunData.Kind.FREEZE, GunData.Kind.MAGNET, GunData.Kind.GLUE]:
		GunHits.play(tree, kind, Vector3.ZERO, Color(0.3, 0.5, 1.0), 1.0)
		var after_first := Fx.meshes_made
		GunHits.play(tree, kind, Vector3.ZERO, Color(0.3, 0.5, 1.0), 1.0)
		assert_int(Fx.meshes_made).override_failure_message("kind %d made a mesh on its second hit" % kind) \
				.is_equal(after_first)
	Fx.ring(tree, Vector3.ZERO, Color.YELLOW, 1.0)
	Fx.ring(tree, Vector3.ZERO, Color.YELLOW, 1.0)
	var rings := scene.get_children().filter(func(n): return n is MeshInstance3D and n.mesh == Fx.torus())
	assert_int(rings.size()).is_greater_equal(2)
	assert_object(rings[0].mesh).is_same(rings[1].mesh)
	assert_object(rings[0].material_override).is_not_same(rings[1].material_override)   # each fades its own
	tree.current_scene = was
	scene.free()
