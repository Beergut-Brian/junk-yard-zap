## Playtest #1 readiness: P1 = Jeff = green and P2 = Chuck = red everywhere, the partner aim ring
## sits on the partner's body (not at his feet, where it read as a ring in the wrong colour), the
## mouse pointer stays hidden in play, and the camera never looks under the table.
class_name TestPlaytest1
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const GREEN := Color("3cc24a")
const RED := Color("e4393c")
const IDLE := {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}

var world: Node3D


func before() -> void:
	Save.profile = "gdunit"


func before_test() -> void:
	Players.reset()
	Game.demo = false
	Game.start_round()
	world = Node3D.new()
	add_child(world)
	world.add_child(YardStrip.new())


func after_test() -> void:
	if is_instance_valid(world):
		world.free()
	Yard.reset_world()
	Players.reset()


func step(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func zapper(player: int, x: float) -> Zapper:
	var z: Zapper = load("res://scenes/players/zapper.tscn").instantiate()
	z.player = player
	z.position = Vector3(x, 0.05, 0)
	world.add_child(z)
	z.input_override = IDLE.duplicate()
	return z


func _tape_color(z: Zapper) -> Color:
	var tape := z.rig.find_child("tape", true, false) as MeshInstance3D
	assert_object(tape).is_not_null()
	return (tape.material_override as StandardMaterial3D).albedo_color


func test_p1_is_jeff_and_green_p2_is_chuck_and_red() -> void:
	assert_that(Players.COLOR[P1]).is_equal(GREEN)
	assert_that(Players.COLOR[P2]).is_equal(RED)
	var jeff := zapper(P1, -3.0)
	var chuck := zapper(P2, 3.0)
	await step(3)
	assert_str(String(jeff.rig.character)).is_equal("jeff")
	assert_str(String(chuck.rig.character)).is_equal("chuck")
	# Gun tape, aim ring.
	assert_that(_tape_color(jeff)).is_equal(GREEN)
	assert_that(_tape_color(chuck)).is_equal(RED)
	assert_that((jeff._marker.material_override as StandardMaterial3D).albedo_color).is_equal(GREEN)
	assert_that((chuck._marker.material_override as StandardMaterial3D).albedo_color).is_equal(RED)
	# The gun survives a belt cycle with the right tape.
	chuck.set_gun(3)
	await step(2)
	assert_that(_tape_color(chuck)).is_equal(RED)
	# Grab glow in the grabber's colour.
	var o := PhysicsObject.new(ObjectData.make(&"box", ObjectData.Shape.BOX, Vector3.ONE * 0.6, 1.0, Color.TAN))
	o.position = Vector3(4.5, 0.5, 0)
	world.add_child(o)
	await step(2)
	var g := Effects.grab(o, chuck, Players.COLOR[chuck.player])
	assert_that(g.color).is_equal(RED)


## The cause of "a red ring under Jeff": Chuck's aim ring snapped to Jeff and was drawn at his
## feet (a Zapper's origin), where it looked like Jeff's own player ring. It now circles his body.
func test_partner_aim_ring_circles_the_partner_not_his_feet() -> void:
	var jeff := zapper(P1, -1.5)
	var chuck := zapper(P2, 1.5)
	await step(10)
	chuck.input_override = IDLE.merged({"aim": Vector2.LEFT}, true)
	await step(3)
	assert_object(chuck.target).is_same(jeff)
	assert_bool(chuck._marker.visible).is_true()
	var feet := jeff.global_position
	assert_float(chuck._marker.global_position.y - feet.y).is_greater(Zapper.HEIGHT * 0.35)
	assert_float(chuck._marker.global_position.x).is_equal_approx(feet.x, 0.01)
	# Big enough to go round him: reads as "aimed at", never as a ring on the floor.
	assert_float(chuck._marker.scale.x).is_greater_equal(Zapper.HEIGHT * 0.5)


func test_a_sleeping_partner_is_not_a_target() -> void:
	var jeff := zapper(P1, -1.5)
	var chuck := zapper(P2, 1.5)
	chuck.set_asleep(true)
	await step(5)
	assert_bool(jeff.candidates().has(chuck)).is_false()
	chuck.wake()
	assert_bool(jeff.candidates().has(chuck)).is_true()


func test_mouse_pointer_hidden_in_play_shown_only_after_mouse_use_in_menus() -> void:
	assert_bool(Cursor.should_show(Game.State.PLAYING, true)).is_false()
	assert_bool(Cursor.should_show(Game.State.PLAYING, false)).is_false()
	assert_bool(Cursor.should_show(Game.State.LOBBY, false)).is_false()
	assert_bool(Cursor.should_show(Game.State.PAUSED, true)).is_true()
	assert_bool(Cursor.should_show(Game.State.LOBBY, true)).is_true()
	var c := Cursor.new()
	world.add_child(c)
	var mm := InputEventMouseMotion.new()
	c._input(mm)
	assert_bool(c.mouse_recent).is_true()
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	c._input(pad)
	assert_bool(c.mouse_recent).is_false()


## The wide shots and the widest play zoom: the bottom of the frame lands on the table apron.
func test_camera_never_looks_under_the_table() -> void:
	var cam := CameraRig.new()
	world.add_child(cam)
	await step(1)
	var tilt := deg_to_rad(CameraRig.LOOK_DOWN + cam.fov * 0.5)
	for ov in [true, false]:
		cam.overview = ov
		var jeff := zapper(P1, YardLevel.LEFT + 2.0)
		var chuck := zapper(P2, YardLevel.RIGHT - 2.0)   # as far apart as they can be
		await step(2)
		var p := cam.goal_position()
		var bottom := p.y - (p.z - YardDressing.TABLE_FRONT_Z) * tan(tilt)
		assert_float(bottom).override_failure_message("overview=%s bottom %.2f" % [ov, bottom]) \
				.is_greater_equal(YardDressing.APRON_BOTTOM)
		jeff.free()
		chuck.free()
