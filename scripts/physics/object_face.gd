## Two googly eyes, two brows and a dotted mouth on the front of a yard object, and the moods they make
## (GAME.md Art direction: wide-eyed when grabbed, dizzy when thrown, smug when bouncy, panicked when
## ballooning). The Golden Afternoon look (art/direction/frame_a.png): white sclera, ink pupil with a
## glint, ink brows that do most of the acting. Built from cached spheres so it reads at any size.
class_name ObjectFace
extends Node3D

enum Mood { NEUTRAL, HAPPY, WIDE, DIZZY, SMUG, PANIC, SHUT, SAD }

const MOUTH_DOTS := 7
## Eyes follow the nearest player within this many metres (calm moods only).
const WATCH_RANGE := 7.0
const WATCH_LOOK := 0.95   # how far the pupils slide toward them (1 = to the eye's rim, near enough)
const INK := Color("#24181a")
## Own RNG: blinking must never shift a seeded simulation (the stress run).
static var _rng := RandomNumberGenerator.new()

var mood := Mood.NEUTRAL
## The mood the effects on the object ask for; flashes (react) fall back to it.
var base_mood := Mood.NEUTRAL
var _flash_left := 0.0
var _blink := 2.0
var _t := 0.0
var _eyes: Array[MeshInstance3D] = []
var _pupils: Array[Node3D] = []
var _brows: Array[MeshInstance3D] = []
var _mouth: Array[MeshInstance3D] = []
var _sweat: MeshInstance3D
var _size := 0.35
var _watch := Vector2(0.15, 0.1)   # smoothed look while calm: toward the nearest player, else ahead
var _watching := false


func setup(face_size: float) -> void:
	_size = face_size
	var ink := ArtKit.mat(INK, 0.0, 0.35)
	var white := ArtKit.mat(Color(1, 1, 1), 0.0, 0.3)
	for i in 2:
		var eye := _dot(_size * 0.23, white, self, 16)
		eye.position = Vector3((i * 2 - 1) * _size * 0.27, _size * 0.12, -0.01)
		var pupil := Node3D.new()
		eye.add_child(pupil)
		var p := _dot(_size * 0.11, ink, pupil, 12)
		p.scale = Vector3(1, 1, 0.6)
		var glint := _dot(_size * 0.035, white, pupil, 8)
		glint.position = Vector3(_size * 0.035, _size * 0.045, _size * 0.06)
		_eyes.append(eye)
		_pupils.append(pupil)
		var brow := MeshInstance3D.new()
		brow.mesh = ArtKit.rbox(Vector3(_size * 0.3, _size * 0.065, _size * 0.06), _size * 0.03, 2)
		brow.material_override = ink
		brow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(brow)
		_brows.append(brow)
	for i in MOUTH_DOTS:
		_mouth.append(_dot(_size * 0.042, ink, self, 8))
	_sweat = _dot(_size * 0.07, ArtKit.glass(Color(0.75, 0.92, 1.0, 0.85)), self, 10)
	_sweat.scale = Vector3(0.8, 1.2, 0.6)
	_sweat.visible = false
	_pose(0.0)


func _dot(r: float, mat: Material, parent: Node3D, segs := 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ArtKit.sphere(r, segs)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A quick reaction for `seconds`, then back to base_mood.
func react(m: Mood, seconds := 0.8) -> void:
	mood = m
	_flash_left = seconds


func set_base(m: Mood) -> void:
	base_mood = m
	if _flash_left <= 0.0:
		mood = m


func _process(delta: float) -> void:
	_t += delta
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			mood = base_mood
	_blink -= delta
	if _blink < -0.12:
		_blink = _rng.randf_range(2.0, 4.5)
	_update_watch(delta)
	_pose(delta)


## True while the eyes are following a player.
func watching() -> bool:
	return _watching


## Where a calm face looks: at the nearest player's head within WATCH_RANGE, smoothed so the eyes
## glide; nobody near, back to looking ahead. Uses the face's own axes, so a tipped-over crate still
## looks the right way.
func _update_watch(delta: float) -> void:
	var want := Vector2(0.15, 0.1)
	_watching = false
	if is_inside_tree():
		var best := WATCH_RANGE
		var me := global_position
		var inv := global_transform.basis.orthonormalized().inverse()
		for z in get_tree().get_nodes_in_group(Zapper.GROUP):
			var n := z as Node3D
			if n == null or not n.visible:
				continue
			var d := n.global_position + Vector3(0, 1.1, 0) - me
			var dist := d.length()
			if dist < best and dist > 0.05:
				best = dist
				var local := inv * d
				var v := Vector2(local.x, local.y)
				want = v.normalized() * WATCH_LOOK if v.length() > 0.01 else Vector2.ZERO
				_watching = true
	_watch = _watch.lerp(want, 1.0 - exp(-8.0 * delta))


func _pose(_delta: float) -> void:
	if _eyes.is_empty():
		return
	var s := _size
	var eye := 1.0
	var lid := 1.0         # eye height: 1 open, ~0.1 a closed line
	var pupil := 1.0
	var look := _watch
	var curve := 0.45      # + smile, - frown
	var open := 0.0        # 0 a line of dots, 1 a round O
	var width := 1.0
	var tilt := 0.0        # smirk: one corner up
	var wave := 0.0        # wobbly mouth
	var brow_y := 0.0      # + raised
	var brow_rot := 0.0    # + inner ends up (worried), - inner ends down (cross/smug)
	match mood:
		Mood.HAPPY:
			curve = 1.0; brow_y = 0.05; lid = 0.85
		Mood.WIDE:
			eye = 1.4; pupil = 0.7; open = 0.65; width = 0.8; brow_y = 0.22; look = Vector2.ZERO
		Mood.DIZZY:
			curve = -0.1; wave = 1.0; brow_rot = 18.0
			look = Vector2(cos(_t * 12.0), sin(_t * 12.0)) * 0.55
		Mood.SMUG:
			lid = 0.5; curve = 0.6; tilt = 0.7; width = 1.1; brow_y = -0.06; brow_rot = -12.0; look = Vector2(0.55, 0.0)
		Mood.PANIC:
			eye = 1.35; pupil = 0.55; open = 1.0; width = 0.6; brow_y = 0.2; brow_rot = 24.0
			look = Vector2(sin(_t * 40.0) * 0.25, 0.3)
		Mood.SHUT:
			lid = 0.1; curve = 0.15; brow_y = -0.03
		Mood.SAD:
			curve = -0.8; brow_rot = 20.0; look = Vector2(0.0, -0.3)
	if _blink < 0.0 and mood != Mood.SHUT and mood != Mood.PANIC and mood != Mood.WIDE:
		lid = 0.1
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var e := _eyes[i]
		e.scale = Vector3(eye, eye * 1.12 * lid, 0.55)
		var pp := _pupils[i]
		var lx := look.x if mood != Mood.DIZZY else look.x * side
		pp.position = Vector3(lx * s * 0.07, look.y * s * 0.07, s * 0.17)
		pp.scale = Vector3(pupil, pupil, 1.0)
		pp.visible = lid > 0.3
		var b := _brows[i]
		b.position = Vector3(side * s * 0.27, s * (0.37 + brow_y) * (eye * 0.5 + 0.5) - (1.0 - lid) * s * 0.12, s * 0.06)
		b.rotation_degrees = Vector3(0, 0, -side * brow_rot)
	for i in MOUTH_DOTS:
		var u := float(i) / (MOUTH_DOTS - 1) * 2.0 - 1.0   # -1..1 across the mouth
		var y := -s * 0.2 - curve * (1.0 - u * u) * s * 0.1 + tilt * u * s * 0.06 + wave * sin(u * 6.0 + _t * 9.0) * s * 0.03
		var line := Vector3(u * s * 0.2 * width, y, s * 0.04)
		var ang := (u * 0.5 + 0.5) * TAU
		var ring := Vector3(cos(ang) * s * 0.075, -s * 0.24 + sin(ang) * s * 0.09, s * 0.04)
		_mouth[i].position = line.lerp(ring, open)
	_sweat.visible = mood == Mood.PANIC
	if _sweat.visible:
		_sweat.position = Vector3(s * 0.52, s * (0.3 - fmod(_t * 0.6, 0.4)), s * 0.03)
