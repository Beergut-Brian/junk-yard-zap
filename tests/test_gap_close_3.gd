## Gap-close lane 3 (jyz-gap-close-3). Y-19: vehicles and machines have no face (producer rule), so
## each one shows it felt a zap with a moving part: the fridge door swings open on a lit inside and
## shuts (GAME.md "the fridge door flaps"), the washer's porthole opens, the TV's antennae wobble, the
## toast pops, the car door opens, the tractor's exhaust cap pops with a puff, the cannon's barrel
## nods, the boat's oar rows and the wheelbarrow tips. Own settings file and save profile, fixture
## roster: never the family's files or the real roster.
class_name TestGapClose3
extends GdUnitTestSuite

const Clock := preload("res://tests/fixtures/physics_clock.gd")
var _clock := Clock.new()

const FIXTURE := "res://tests/fixtures/roster_two.json"
const OBJECTS := "res://data/objects/"

var world: Node3D
var _real_settings := ""
var _real_profile := ""
var _real_roster := ""
var _real_picks := ""


func before() -> void:
	_clock.pin()
	_real_profile = Save.profile
	Save.profile = "gdunit_gap_close_3"
	Save.wipe()
	_real_settings = Save.settings_path
	Save.settings_path = "user://test_settings_gap_close_3.json"
	Save.wipe_settings()
	_real_roster = Roster.data_path
	Roster.data_path = FIXTURE
	_real_picks = Roster.picks_path
	Roster.picks_path = "user://test_gap_close_3_players.json"
	Roster.args_override = PackedStringArray(["--no-picks"])
	Roster.reload()


func after() -> void:
	_clock.restore()
	Save.wipe()
	Save.profile = _real_profile
	Save.wipe_settings()
	Save.settings_path = _real_settings
	Save.reload_settings()
	Roster.data_path = _real_roster
	Roster.picks_path = _real_picks
	Roster.args_override = PackedStringArray()
	Roster.reload()


func before_test() -> void:
	Audio.history.clear()
	world = Node3D.new()
	add_child(world)
	world.add_child(YardStrip.new())


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func spawn(id: String) -> PhysicsObject:
	var o := PhysicsObject.new(load(OBJECTS + id + ".tres"))
	o.position = Vector3(0, 1.5, 0)
	world.add_child(o)
	return o


static func faceless_ids() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(OBJECTS):
		if f.ends_with(".tres"):
			var d: ObjectData = load(OBJECTS + f)
			if not d.has_face:
				out.append(f.get_basename())
	return out


static func turned(p: Node3D) -> float:
	return p.basis.get_rotation_quaternion().get_angle()


func test_every_faceless_machine_has_a_moving_part_and_faced_objects_do_not() -> void:
	var ids := faceless_ids()
	assert_int(ids.size()).is_equal(9)
	for id in ids:
		var o := spawn(id)
		assert_int(o._gags.size()).override_failure_message("%s has no moving part" % id).is_greater(0)
	for id in ["cow", "duck", "crate"]:
		assert_int(spawn(id)._gags.size()).is_equal(0)
	await step(1)


func test_the_fridge_door_flies_open_and_shuts_again() -> void:
	var fridge := spawn("fridge")
	await step(40)
	var door: Node3D = fridge._gags[0]
	assert_str(String(door.get_meta(&"gag")["kind"])).is_equal("swing")
	assert_float(turned(door)).is_equal_approx(0.0, 0.001)
	fridge.react_look(ObjectFace.Mood.WIDE, 0.6)
	assert_bool(fridge.gagging()).is_true()
	var widest := 0.0
	var outward := false
	for i in 40:
		await step(1)
		widest = maxf(widest, turned(door))
		# The free edge of the door comes out toward the camera (+z), not into the fridge.
		var edge := door.global_transform * Vector3(fridge.data.size.x * 0.9, 0, 0)
		outward = outward or (fridge.global_transform.affine_inverse() * edge).z > fridge.data.size.z * 0.5 + 0.3
	assert_float(widest).override_failure_message("the door only opened %.2f rad" % widest).is_greater(deg_to_rad(80.0))
	assert_bool(outward).is_true()
	await step(60)
	assert_bool(fridge.gagging()).is_false()
	assert_float(turned(door)).is_equal_approx(0.0, 0.001)


func test_zapping_a_machine_with_a_gun_plays_its_moving_part() -> void:
	var tv := spawn("tv")
	await step(40)
	assert_bool(Effects.zap(&"bouncy", tv)).is_true()
	assert_bool(tv.gagging()).is_true()
	var ears: Node3D = tv._gags[0]
	var moved := 0.0
	for i in 30:
		await step(1)
		moved = maxf(moved, turned(ears))
	assert_float(moved).is_greater(0.15)
	await step(60)
	assert_float(turned(ears)).is_equal_approx(0.0, 0.001)


func test_the_toast_pops_up_and_drops_back_in() -> void:
	var toaster := spawn("toaster")
	await step(40)
	var toast: Node3D = toaster._gags[0]
	var rest := toast.position
	toaster.react_look(ObjectFace.Mood.WIDE, 0.6)
	var highest := 0.0
	for i in 40:
		await step(1)
		highest = maxf(highest, toast.position.y - rest.y)
	assert_float(highest).is_greater(toaster.data.size.y * 0.5)
	await step(60)
	assert_vector(toast.position).is_equal_approx(rest, Vector3.ONE * 0.001)


func test_the_tractor_puffs_smoke_once_per_reaction() -> void:
	var tractor := spawn("tractor")
	await step(40)
	var before := Fx.bursts
	tractor.react_look(ObjectFace.Mood.WIDE, 0.6)
	assert_int(Fx.bursts).is_equal(before + 1)
	# A second zap while the cap is still up keeps the gag going but does not stack more smoke.
	tractor.react_look(ObjectFace.Mood.WIDE, 0.6)
	assert_int(Fx.bursts).is_equal(before + 1)
	await step(1)


func test_gag_poses_start_and_end_at_rest() -> void:
	var root := Node3D.new()
	world.add_child(root)
	for kind in [&"swing", &"wiggle", &"pop"]:
		var h := ObjectArt.gag(root, kind, Vector3(0.3, 0.2, 0.1), Vector3.UP, 1.0)
		var p := h.get_parent() as Node3D
		assert_vector(h.position).is_equal(-Vector3(0.3, 0.2, 0.1))
		ObjectArt.pose_gag(p, 0.3)
		var moved := turned(p) > 0.05 or p.position.distance_to(Vector3(0.3, 0.2, 0.1)) > 0.05
		assert_bool(moved).override_failure_message("%s did not move" % kind).is_true()
		ObjectArt.pose_gag(p, 1.0)
		assert_float(turned(p)).is_equal_approx(0.0, 0.0001)
		assert_vector(p.position).is_equal(Vector3(0.3, 0.2, 0.1))
	assert_int(ObjectArt.gags_in(root).size()).is_equal(3)

