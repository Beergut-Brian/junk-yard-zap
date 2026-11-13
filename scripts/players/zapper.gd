## A player (P1 green, P2 red) as whoever they picked in the lobby (Roster; Jeff and Chuck by
## default) on the locked Z plane with a belt of guns (GAME.md "Camera and
## controls"). Left stick moves and aims, A fires (hold for grow/shrink steps and gravity grab),
## B jumps (tap = short hop, hold = higher up to a cap; floaty, forgiving), Select held 1.5 s resets the yard, RB/LB cycle the belt, right stick also aims.
## Zapping the partner does something harmless and funny for at most PARTNER_TIME seconds.
## P2 can start asleep in the tire pile; any press of his pad wakes him with a snort.
class_name Zapper
extends CharacterBody3D

signal zapped(player: int, gun: StringName, target: Node3D)
signal gun_changed(player: int, gun: GunData)
signal woke(player: int)
signal partner_zapped(player: int, gun: StringName)

const JOIN_LINE_DELAY := 0.55   # seconds after the wake-up snort before the hello line
const GROUP := &"zappers"
const SPEED := 6.0
const ACCEL := 40.0
const JUMP_DATA := "res://data/players/jump.tres"   # tap = hop, hold = higher (JumpTuning)
## Hold Select this long (real play seconds) to reset the yard; a tap does nothing.
const RESET_HOLD := 1.5
const PARTNER_TIME := 1.0      # kid-design: never hinders for more than a second
const SIZE_REPEAT := 0.45
const FLICK_WINDOW := 0.18
const HEIGHT := 1.55
const BEAM_LEN := 4.0
const GUNS_DIR := "res://data/guns/"
## Generic barks for a character with no voice of their own yet (never another character's voice).
const GENERIC_BARK := "bark"

@export var player := Players.P1
## Roster id of the Jarling this player is. Empty (the default): Roster.pick(player), read once at
## spawn; main.gd respawns everyone on the way back from the lobby, so a new pick shows next round.
@export var character := ""
## Variable jump numbers (data/players/jump.tres when empty).
@export var jump_tuning: JumpTuning
## Joined mid-session or not joined yet: asleep in the tire pile until his pad presses something.
const BEAM_SHADER := preload("res://scripts/fx/beam.gdshader")
var asleep := false
## Template name for the same thing (tests/test_lobby.gd, main.gd).
var waiting: bool:
	get: return asleep
	set(v): set_asleep(v)

var guns: Array[GunData] = []
var gun_index := 0
var aim_dir := Vector2.RIGHT
var facing := 1.0
var target: Node3D
var glue_first: PhysicsObject
var held: PhysicsObject
## Tests and the demo bot drive the player through this instead of the InputMap:
## {"move": Vector2, "aim": Vector2, "action": bool, "jump": bool, "next": bool, "prev": bool,
##  "reset": bool (Select), "start": bool (this player's Start)}
var input_override: Dictionary = {}
## While > 0 the player is a statue (partner freeze) and ignores input.
var statue_left := 0.0

var rig: JarlingRig
## Barks, reaction poses and idle bits (scripts/players/reactions.gd).
var reactions: Reactions
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial   # scripts/fx/beam.gdshader: a pattern per gun (PT10-2)
var _marker: MeshInstance3D
var _zzz: CPUParticles3D
var _partner_look: EffectLook
var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := true
var _action_was := false
## Every action beeps (feel rule, 2026-11-13): buttons as they were last frame, read even while a
## statue, so a fresh press on a frozen player is refused out loud (_statue_refusals).
var _raw_was := {}
var _statue_nope := 0.0
var _jump_was := false
var _jump_held := false      # B still down since take-off: the rise isn't cut yet
var _jump_cut := false       # B came up during this rise: the heavier released_rise_gravity
## Select hold: seconds held, and "spent" (Start, the solo swap, a pause or a finished reset
## happened on this press: nothing more until Select comes up).
var reset_held := 0.0
var _reset_spent := false
var _next_was := false
var _prev_was := false
var _size_latched: PhysicsObject
var _size_repeat := 0.0
var _stick_hist: Array = []   # [time, Vector2]
var _clock := 0.0
var _partner_left := 0.0
var _partner_kind := -1
var _float_up := 0.0
var _snore := 2.0
var _refused := false        # this press played "nope" (the reactions blame the partner)


func _ready() -> void:
	add_to_group(GROUP)
	axis_lock_linear_z = true
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = HEIGHT
	cs.shape = cap
	cs.position.y = HEIGHT * 0.5
	add_child(cs)
	if character == "":
		character = Roster.pick(player)
	if character == "":
		character = Roster.default_for(player)
	rig = JarlingRig.new()
	rig.character = StringName(character)
	rig.name = "Rig"
	add_child(rig)
	rig.equip_gun(Players.COLOR[player])
	_build_beam()
	_partner_look = EffectLook.new()
	_partner_look.size = Vector3(0.7, HEIGHT, 0.6)
	_partner_look.position.y = HEIGHT * 0.5
	add_child(_partner_look)
	_zzz = CPUParticles3D.new()
	_zzz.amount = 4
	_zzz.lifetime = 2.0
	_zzz.direction = Vector3(0.3, 1, 0)
	_zzz.spread = 15.0
	_zzz.gravity = Vector3.ZERO
	_zzz.initial_velocity_min = 0.5
	_zzz.initial_velocity_max = 0.7
	var zm := BoxMesh.new()
	zm.size = Vector3(0.18, 0.18, 0.02)
	var zmat := StandardMaterial3D.new()
	zmat.albedo_color = Color(0.9, 0.95, 1.0)
	zmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zm.material = zmat
	_zzz.mesh = zm
	_zzz.position = Vector3(0.3, 0.9, 0.3)
	_zzz.emitting = false
	add_child(_zzz)
	reactions = Reactions.new()
	reactions.name = "Reactions"
	reactions.zapper = self
	add_child(reactions)
	Audio.big_impact.connect(_on_big_impact)
	if jump_tuning == null:
		jump_tuning = load(JUMP_DATA) as JumpTuning
	Game.state_changed.connect(_on_game_state)
	if guns.is_empty():
		guns = load_guns()
	set_gun(gun_index, false)
	set_asleep(asleep)


static func load_guns(dir := GUNS_DIR) -> Array[GunData]:
	var out: Array[GunData] = []
	var files := ResourceLoader.list_directory(dir)
	var sorted: Array = []
	for f in files:
		if f.ends_with(".tres") or f.ends_with(".res"):
			sorted.append(f)
	sorted.sort()   # files are numbered: 1_size.tres ... 7_magnet.tres (belt order)
	for f in sorted:
		var g := load(dir.path_join(f)) as GunData
		if g:
			out.append(g)
	return out


func gun() -> GunData:
	return guns[gun_index] if not guns.is_empty() else null


func set_gun(i: int, sound := true) -> void:
	if guns.is_empty():
		return
	_let_go(false)
	_size_latched = null
	glue_first = null
	gun_index = posmod(i, guns.size())
	_beam_mat.set_shader_parameter(&"color", gun().beam_color)
	_beam_mat.set_shader_parameter(&"pattern", int(gun().kind))
	rig.show_gun(gun().effect_id())
	if sound:
		Audio.play("wheel_move")
	gun_changed.emit(player, gun())


func set_asleep(on: bool) -> void:
	asleep = on
	if not is_node_ready():
		return
	_zzz.emitting = on
	rig.rotation = Vector3(0, 0, PI * 0.5 if on else 0.0)
	rig.position = Vector3(0.6, 0.35, 0) if on else Vector3.ZERO
	rig.play("idle", 0.3 if on else 1.0)
	_beam.visible = not on
	_marker.visible = false


## His pad pressed something: up he gets, with a snort.
func wake() -> void:
	if not asleep:
		return
	set_asleep(false)
	velocity.y = jump_tuning.takeoff_speed * 0.8
	Audio.play("snort", global_position)
	Fx.burst(get_tree(), global_position + Vector3(0, 0.8, 0), Color(0.9, 0.9, 0.8, 0.8), 14, 0.8, 0.5)
	rig.set_expression("surprised")
	woke.emit(player)
	# Then, once the snort is out, hello in their own voice (the pack's "join" line).
	get_tree().create_timer(JOIN_LINE_DELAY).timeout.connect(func() -> void:
		if is_instance_valid(self) and not asleep and say("join") != "":
			rig.set_expression("happy"))


func radius() -> float:
	return 0.6


## The middle of the body. global_position is the feet, so rings and aim marks use this instead
## (a partner's aim ring at the feet read as a player ring in the wrong colour).
func center() -> Vector3:
	return global_position + Vector3(0, HEIGHT * 0.5, 0)


## Where a gravity-grabbed object floats: arm's length along the aim, clear of the body.
func hold_point(t: Node3D = null) -> Vector3:
	var r: float = t.radius() * 0.8 if t and t.has_method(&"radius") else 0.5
	var reach: float = gun().param("reach", 1.0) if gun() else 1.0
	var d := Vector3(aim_dir.x, aim_dir.y, 0.0)
	return global_position + Vector3(0, HEIGHT * 0.6, 0) + d * (0.5 + reach + r)


# ------------------------------------------------------------------------------------------ input

func _read() -> Dictionary:
	if not input_override.is_empty():
		return input_override
	var aim := Input.get_vector(Players.action(player, "aim_left"), Players.action(player, "aim_right"),
			Players.action(player, "aim_up"), Players.action(player, "aim_down"))
	return {
		"move": Players.move_vector(player), "aim": aim,
		"action": Input.is_action_pressed(Players.action(player, "action")),
		"jump": Input.is_action_pressed(Players.action(player, "jump")),
		"next": Input.is_action_pressed(Players.action(player, "gun_next")),
		"prev": Input.is_action_pressed(Players.action(player, "gun_prev")),
		"reset": Input.is_action_pressed(Players.action(player, "reset")),
		"start": Players.start_held(player),
	}


func _physics_process(delta: float) -> void:
	_clock += delta
	var inp := _read()
	var live := Game.state == Game.State.PLAYING
	if asleep:
		_snore -= delta
		if _snore <= 0.0:
			_snore = 2.5
			Audio.play("snore", global_position)
		_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
		move_and_slide()
		return
	_tick_partner(delta)
	_tick_reset(inp, delta, live)
	_statue_refusals(inp, live)
	if statue_left > 0.0 or not live:
		inp = {"move": Vector2.ZERO, "aim": Vector2.ZERO, "action": false, "jump": false, "next": false, "prev": false}
	var mv: Vector2 = inp.get("move", Vector2.ZERO)
	var aim: Vector2 = inp.get("aim", Vector2.ZERO)
	_stick_hist.append([_clock, mv])
	while _stick_hist.size() > 2 and _clock - _stick_hist[0][0] > FLICK_WINDOW:
		_stick_hist.pop_front()
	# Move.
	_gravity(delta)
	var want := mv.x * SPEED
	velocity.x = move_toward(velocity.x, want, ACCEL * delta)
	if absf(mv.x) > 0.2:
		facing = signf(mv.x)
	var on_floor := is_on_floor()
	var jt := jump_tuning
	_coyote = jt.coyote if on_floor else _coyote - delta
	var jump: bool = inp.get("jump", false)
	if jump and not _jump_was:
		_jump_buffer = jt.buffer
	_jump_was = jump
	_jump_buffer -= delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jt.takeoff_speed
		_jump_buffer = 0.0
		_coyote = 0.0
		_jump_held = true
		_jump_cut = false
		Audio.play("jump", global_position)
		Fx.burst(get_tree(), global_position, Color(0.8, 0.7, 0.55, 0.7), 8, 0.4, 0.4)
	if not jump and _jump_held:
		# Let go while rising: the rise is cut, so a tap is a short hop (a buffered jump whose
		# B already came up is a hop too). Holding to the top is the full, capped jump.
		_jump_held = false
		_jump_cut = true
		if velocity.y > jt.cut_speed:
			velocity.y = jt.cut_speed
	move_and_slide()
	if on_floor and not _was_on_floor:
		Audio.play("land", global_position)
		Fx.burst(get_tree(), global_position, Color(0.8, 0.7, 0.55, 0.7), 6, 0.35, 0.35)
	_was_on_floor = on_floor
	# Aim: right stick wins, then the left stick, else straight ahead.
	if aim.length() > 0.3:
		aim_dir = Vector2(aim.x, -aim.y).normalized()
	elif mv.length() > 0.2:
		aim_dir = Vector2(mv.x, -mv.y).normalized()
	elif absf(aim_dir.y) > 0.9 and not inp.get("action", false):
		aim_dir = Vector2(facing, 0.0)
	if aim_dir.x != 0.0 and absf(aim_dir.x) > 0.3:
		facing = signf(aim_dir.x)
	rig.face_dir(reactions.facing(facing), delta)
	if absf(velocity.x) > 0.5 and on_floor:
		rig.play("run", absf(velocity.x) / SPEED * 1.2)
	elif _partner_left <= 0.0 and not reactions.busy():
		rig.play("idle")
	# Belt.
	var nxt: bool = inp.get("next", false)
	var prv: bool = inp.get("prev", false)
	if nxt and not _next_was:
		set_gun(gun_index + 1)
	if prv and not _prev_was:
		set_gun(gun_index - 1)
	_next_was = nxt
	_prev_was = prv
	# Fire.
	_update_target()
	var action: bool = inp.get("action", false)
	if action and not _action_was:
		_press()
	elif action:
		_hold(delta, mv)
	elif _action_was:
		_release(mv)
	_action_was = action
	var active := action or nxt or prv or aim.length() > 0.3
	var moved := jump or mv.length() > 0.2
	reactions.tick(delta, active, on_floor and statue_left <= 0.0 and _partner_left <= 0.0 and live and held == null, moved)
	_update_beam()


func _gravity(delta: float) -> void:
	up_direction = Yard.up_at(global_position)
	var g := Yard.gravity_at(global_position)
	if _float_up > 0.0:
		_float_up -= delta
		velocity.y = move_toward(velocity.y, 1.8, 12.0 * delta)
		return
	if not is_on_floor():
		var rising := velocity.dot(up_direction) > 0.0
		var jt := jump_tuning
		var k := (jt.released_rise_gravity if _jump_cut else jt.rise_gravity) if rising else jt.fall_gravity
		if not rising:
			_jump_held = false
			_jump_cut = false
		velocity += g * k * delta
		velocity.y = maxf(velocity.y, -16.0)


# ------------------------------------------------------------------------------------- reset yard

## Hold Select RESET_HOLD s: the yard resets (whoosh and bell). A tap fills a bit of the ring and
## drains; nothing happens. Start (solo's Select + Start, either order), the solo swap
## (LB + RB + Select), a pause or a statue spend the press: no reset until Select comes up.
## A statue (partner freeze, at most PARTNER_TIME) ignores its buttons. A fresh press of A, B, LB
## or RB on one still says so: the refusal "nope" and a puff of ice chips off the player, whose ice
## look is the cause. At most one every 0.25 s; a button already down when the freeze hit is not new.
func _statue_refusals(inp: Dictionary, live: bool) -> bool:
	var fresh := false
	for k in ["action", "jump", "next", "prev"]:
		var down: bool = inp.get(k, false)
		if down and not _raw_was.get(k, false):
			fresh = true
		_raw_was[k] = down
	_statue_nope = maxf(0.0, _statue_nope - get_physics_process_delta_time())
	if not fresh or statue_left <= 0.0 or not live or _statue_nope > 0.0:
		return false
	_statue_nope = 0.25
	Audio.play("nope", global_position)
	Fx.burst(get_tree(), center(), Color(0.75, 0.9, 1.0, 0.9), 6, 0.3, 0.3)
	return true


func _tick_reset(inp: Dictionary, delta: float, live: bool) -> void:
	var down: bool = inp.get("reset", false)
	if not down:
		_reset_spent = false
		reset_held = 0.0
		return
	var blocked: bool = inp.get("start", false) or inp.get("next", false) or inp.get("prev", false) \
			or not live or statue_left > 0.0
	if blocked:
		_reset_spent = true
	if _reset_spent:
		reset_held = 0.0
		return
	if reset_held == 0.0:
		Audio.play("reset_hold", global_position)
		Fx.ring(get_tree(), center(), Players.COLOR[player], 0.6)
	reset_held += delta
	if reset_held < RESET_HOLD:
		return
	reset_held = 0.0
	_reset_spent = true
	Players.spend_select(player)   # the same Select press can't start solo either
	var level := YardLevel.find(self)
	if level:
		level.reset_yard(self)


## 0..1 of the Select hold, for the ring by the player (hud.gd).
func reset_progress() -> float:
	return clampf(reset_held / RESET_HOLD, 0.0, 1.0)


## Coming back from pause (Start, or solo's Select + Start): a Select still down is spent.
func _on_game_state(_from: int, _to: int) -> void:
	reset_held = 0.0
	_reset_spent = true


# ------------------------------------------------------------------------------------------- guns

func candidates() -> Array:
	var out: Array = get_tree().get_nodes_in_group(PhysicsObject.GROUP).duplicate()
	for z in get_tree().get_nodes_in_group(GROUP):
		if z != self and not (z as Zapper).asleep:   # the sleeper in the tire pile isn't a target
			out.append(z)
	out.append_array(get_tree().get_nodes_in_group(&"zap_targets"))
	if gun() and gun().kind == GunData.Kind.GLUE:
		for j in get_tree().get_nodes_in_group(&"glue_joints"):
			var glue: Effects.Glue = j.get_meta(&"glue")
			if is_instance_valid(glue.blob):
				out.append(glue.blob)
	if held:
		out.erase(held)
	return out


func aim_origin() -> Vector3:
	return global_position + Vector3(0, HEIGHT * 0.6, 0)


func _update_target() -> void:
	if held:
		target = held
	elif is_instance_valid(_size_latched):
		target = _size_latched
	else:
		target = Aim.pick(aim_origin(), aim_dir, candidates())


func _press() -> void:
	var g := gun()
	if g == null:
		return
	var level := YardLevel.find(self)
	if level and level.near_reset_sign(self):
		level.reset_hold_begin(player)
		return
	_flash()
	_refused = false
	rig.set_expression("determined")
	if target == null:
		Audio.play("sparkle", global_position)
		Fx.sparkle(get_tree(), aim_origin() + Vector3(aim_dir.x, aim_dir.y, 0) * 4.0)
		zapped.emit(player, g.id, null)
		return
	if target is Zapper:
		(target as Zapper).partner_zap(g, self)
		Audio.play(g.zap_cue(), global_position)
		zapped.emit(player, g.id, target)
		return
	if target.is_in_group(&"zap_targets"):
		Audio.play(g.zap_cue(), global_position)
		target.call(&"zapped_by", self, g)
		zapped.emit(player, g.id, target)
		return
	var changed := false
	match g.kind:
		GunData.Kind.SIZE:
			_size_latched = target as PhysicsObject
			_size_repeat = SIZE_REPEAT
			changed = _size_step(-1 if _stick_down() else 1)
		GunData.Kind.GRAB:
			var o := target as PhysicsObject
			if o and Effects.grab(o, self, Players.COLOR[player]):
				held = o
				o.last_touch = &"gun"
				Audio.play("grab", o.global_position)
				o.speak("grabbed")
				changed = true
			else:
				Audio.play("nope", global_position)
				_refused = true
				var on: Effects.Grab = o.stack.get_effect(&"grab") if o else null
				if on:   # the cause: someone else is carrying it (a ring in their colour)
					Refusal.held(o, on.color)
		GunData.Kind.GLUE:
			changed = _fire_glue()
		_:
			var o := target as PhysicsObject
			changed = Effects.zap(g.effect_id(), o)
			Audio.play(g.zap_cue() if changed else "nope", o.global_position)
			_refused = not changed
			if changed:
				o.speak()
				o.last_touch = &"gun"
	if changed:
		GunHits.play(get_tree(), g.kind, target.global_position, g.beam_color, (target as PhysicsObject).radius() if target is PhysicsObject else 1.0)
	# Chuck narrates his own zaps and blames the partner when one is refused (GAME.md "Audio");
	# at most one bark per zap, through the gate.
	reactions.own_zap(changed, _refused)
	zapped.emit(player, g.id, target)


func _stick_down() -> bool:
	var mv: Vector2 = _read().get("move", Vector2.ZERO)
	var aim: Vector2 = _read().get("aim", Vector2.ZERO)
	return mv.y > 0.5 or aim.y > 0.5


func _stick_up() -> bool:
	var mv: Vector2 = _read().get("move", Vector2.ZERO)
	var aim: Vector2 = _read().get("aim", Vector2.ZERO)
	return mv.y < -0.5 or aim.y < -0.5


func _size_step(dir: int) -> bool:
	var o := _size_latched
	if not is_instance_valid(o):
		return false
	var ok := Effects.zap(&"grow" if dir > 0 else &"shrink", o)
	# The boing is pitched by the new size: a tiny thing boings high, a giant one low.
	Audio.play(("grow" if dir > 0 else "shrink") if ok else "nope", o.global_position,
		Audio.size_pitch(o.target_scale) if ok else 1.0)
	_refused = not ok
	# The size ladder shows how big it is now; at a cap the end square blinks and a bar says stop.
	Refusal.size_ladder(o, 0 if ok else dir)
	if ok:
		o.speak()
		o.last_touch = &"gun"
		Fx.ring(get_tree(), o.global_position, gun().beam_color, o.radius())
	return ok


func _hold(delta: float, _mv: Vector2) -> void:
	var level := YardLevel.find(self)
	if level and level.reset_holding(player):
		if level.near_reset_sign(self):
			level.reset_hold_step(player, delta)
		else:
			level.reset_hold_end(player)   # walked away from the sign: no reset
		return
	if gun() == null:
		return
	if gun().kind == GunData.Kind.SIZE and is_instance_valid(_size_latched):
		var dir := 1 if _stick_up() else (-1 if _stick_down() else 0)
		if dir == 0:
			_size_repeat = 0.0   # neutral: the next push steps at once
			return
		_size_repeat -= delta
		if _size_repeat <= 0.0:
			_size_repeat = gun().param("repeat", SIZE_REPEAT)
			_size_step(dir)
			_flash()
	elif held and (held.freeze or not held.stack.has(&"grab")):
		_let_go(false)


func _release(_mv: Vector2) -> void:
	var level := YardLevel.find(self)
	if level and level.reset_holding(player):
		level.reset_hold_end(player)
		return
	_size_latched = null
	if held:
		_let_go(_flicked())


## A flick: the stick moved hard within the last FLICK_WINDOW seconds.
func _flicked() -> bool:
	if _stick_hist.size() < 2:
		return false
	var newest: Vector2 = _stick_hist[-1][1]
	for h in _stick_hist:
		if (newest - (h[1] as Vector2)).length() > 0.9 and newest.length() > 0.6:
			return true
	return false


func _let_go(throw: bool) -> void:
	if not is_instance_valid(held):
		held = null
		return
	var o := held
	held = null
	if throw:
		var speed: float = gun().param("throw_speed", 14.0) if gun() else 14.0
		Effects.release(o, Vector3(aim_dir.x, aim_dir.y + 0.25, 0).normalized() * speed + Vector3(velocity.x, 0, 0))
		Audio.play("throw", o.global_position)
		o.speak("thrown")
		Fx.burst(get_tree(), o.global_position, Color(1, 1, 1, 0.6), 10, 0.8, 0.4)
	else:
		Effects.release(o)
		Audio.play("drop", o.global_position)


func _fire_glue() -> bool:
	if target is MeshInstance3D:   # a glue blob: split
		(target.get_parent().get_meta(&"glue") as Effects.Glue).undo(null)
		glue_first = null
		Audio.play("unglue", target.global_position)
		return true
	var obj := target as PhysicsObject
	if glue_first == null or not is_instance_valid(glue_first) or glue_first == obj:
		glue_first = obj
		Audio.play("glue_pick", obj.global_position)
		obj.speak()   # the first pick reacts too: every gun gets a voice and a face (Y-12)
		obj.react_look(ObjectFace.Mood.WIDE, 0.6)
		Fx.burst(get_tree(), obj.global_position, gun().beam_color, 10, 0.5, 0.4)
		return false
	var stuck := Effects.Glue.between(glue_first, obj)
	var ok := Effects.glue(glue_first, obj) != null
	if stuck and not ok:   # the cause: these two are already glued (their blob pulses)
		Refusal.already_glued(stuck)
	glue_first = null
	Audio.play(gun().zap_cue() if ok else "nope", obj.global_position)
	_refused = not ok
	if ok:
		obj.speak()
	return ok


# --------------------------------------------------------------------------------- partner zaps

## Harmless and funny, never more than PARTNER_TIME (GAME.md "Players and characters").
func partner_zap(g: GunData, from: Zapper) -> void:
	if asleep:
		Audio.play("snore", global_position)   # he sleeps through it, grumbling
		return
	_end_partner()
	_partner_kind = g.kind
	_partner_left = PARTNER_TIME
	rig.set_expression("surprised")
	Fx.ring(get_tree(), global_position + Vector3(0, HEIGHT * 0.5, 0), g.beam_color, 1.0)
	var fake: Array[Effect] = []
	match g.kind:
		GunData.Kind.SIZE:
			var big := not from._stick_down()
			var to := 1.8 if big else 0.55
			var tw := rig.create_tween()
			tw.tween_property(rig, "scale", Vector3.ONE * to, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			Audio.play("grow" if big else "shrink", global_position)
		GunData.Kind.GRAB:
			_float_up = PARTNER_TIME * 0.6
			fake.append(Effects.Grab.new(null, Players.COLOR[from.player]))
		GunData.Kind.BOUNCY:
			velocity.y = jump_tuning.takeoff_speed * 1.4
			fake.append(Effects.Bouncy.new())
			Audio.play("boing", global_position)
		GunData.Kind.BALLOON:
			_float_up = PARTNER_TIME
			fake.append(Effects.Balloon.new())
		GunData.Kind.FREEZE:
			statue_left = PARTNER_TIME
			fake.append(Effects.Freeze.new())
			if rig.anim:
				rig.anim.pause()
		GunData.Kind.GLUE:
			var splat := Effect.new()
			splat.id = &"splat"
			splat.color = g.beam_color
			fake.append(splat)
			Fx.burst(get_tree(), global_position + Vector3(0, HEIGHT, 0), g.beam_color, 20, 0.6, 0.8)
			Audio.play("squelch", global_position)
		GunData.Kind.MAGNET:
			fake.append(Effects.Magnet.new())
			for o in get_tree().get_nodes_in_group(PhysicsObject.GROUP):
				var po := o as PhysicsObject
				var d := global_position + Vector3(0, 1, 0) - po.global_position
				if d.length() < 4.0 and po.volume_mass() < 5.0 and not po.freeze:
					po.apply_central_impulse(d.normalized() * po.mass * 3.0)
	_partner_look.sync(fake)
	# He keeps talking: one bark per zap, in his own voice (GAME.md "Audio").
	if Audio.can_bark(self):
		bark()
	partner_zapped.emit(player, g.id)


func _tick_partner(delta: float) -> void:
	statue_left = maxf(0.0, statue_left - delta)
	if _partner_left <= 0.0:
		return
	_partner_left -= delta
	if _partner_left <= 0.0:
		_end_partner()


func _end_partner() -> void:
	if _partner_kind == GunData.Kind.SIZE:
		rig.create_tween().tween_property(rig, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _partner_kind == GunData.Kind.FREEZE and rig.anim:
		rig.anim.play()
		Audio.play("crack", global_position)
	_partner_kind = -1
	_partner_left = 0.0
	statue_left = 0.0
	_float_up = 0.0
	var none: Array[Effect] = []
	_partner_look.sync(none)
	rig.set_expression("happy")


## Cheer (a goal card got done).
func cheer() -> void:
	rig.play("cheer")
	rig.set_expression("happy")
	bark("cheer")
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(self):
			rig.play("idle"))


## One bark in this character's own voice: the game's recorded cue bark_<id>[_<kind>] if there is
## one, else the character's vendored voice pack (Roster.bark), else the generic bark[_<kind>].
## Returns the cue name it used ("roster:<id>" for the voice pack). Never another character's voice.
func bark(kind := "") -> String:
	return Audio.bark(character, kind, self)


## A line in their own voice if the bark gate lets them (nobody talks over anybody); the cue it
## used, or "" when the gate held it back.
func say(kind := "") -> String:
	return bark(kind) if Audio.can_bark(self) else ""


## Everyone wobbles at a big impact near him; Jeff claps and delights (GAME.md "Audio"), at most one
## bark at a time (Reactions.big_impact).
func _on_big_impact(at: Vector3, band: String) -> void:
	reactions.big_impact(at, band)


# ------------------------------------------------------------------------------------------ visuals

func _build_beam() -> void:
	_beam = MeshInstance3D.new()
	_beam.mesh = _cone_mesh()
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = BEAM_SHADER
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position = Vector3(0, HEIGHT * 0.6, 0.2)
	add_child(_beam)
	_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.8
	tm.outer_radius = 1.0
	_marker.mesh = tm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Players.COLOR[player]
	mm.no_depth_test = true
	_marker.material_override = mm
	_marker.rotation_degrees.x = 90
	_marker.top_level = true
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)


func _update_beam() -> void:
	_beam.rotation.z = aim_dir.angle()
	_marker.visible = target != null
	if target:
		_marker.global_position = marker_point(target)
		if target is Zapper:   # round the whole partner, centred on his body, never at his feet
			_marker.scale = Vector3.ONE * HEIGHT * 0.55
		else:
			var r: float = target.radius() if target.has_method(&"radius") else 0.4
			_marker.scale = Vector3.ONE * maxf(0.5, r * 0.8)


## Where this player's aim ring sits for `t`: in front of its centre, on the camera side.
static func marker_point(t: Node3D) -> Vector3:
	var c: Vector3 = (t as Zapper).center() if t is Zapper else t.global_position
	return c + Vector3(0, 0, 1.2)


func _flash() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _beam_mat.set_shader_parameter(&"flash", v), 1.0, 0.0, 0.35)


## A flat wedge on the play plane showing the aim cone.
func _cone_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	const HALF := Aim.HALF_ANGLE * 0.5   # drawn narrower than the snap cone, so it reads as a beam
	for i in n:
		var a0 := -HALF + 2.0 * HALF * i / n
		var a1 := -HALF + 2.0 * HALF * (i + 1) / n
		st.set_uv(Vector2(0.0, (i + 0.5) / n))
		st.add_vertex(Vector3.ZERO)
		st.set_uv(Vector2(1.0, float(i) / n))
		st.add_vertex(Vector3(cos(a0), sin(a0), 0) * BEAM_LEN)
		st.set_uv(Vector2(1.0, float(i + 1) / n))
		st.add_vertex(Vector3(cos(a1), sin(a1), 0) * BEAM_LEN)
	return st.commit()
