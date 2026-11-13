## The comedy layer on one player (GAME.md "Players and characters", "Audio"): what the character
## does and says around the zapping. A child of its Zapper; works for any picked Jarling.
##
## - Big impact nearby: everyone awake wobbles (the reaction clip). A "delight" character (Jeff,
##   and any roster character without a fixed style) also claps (`cheer` action), hops, beams and
##   barks `delight`.
## - Own zap that worked: a "narrate" character (Chuck, and the others) puffs up proud and barks
##   `zap` (takes the credit).
## - Own zap that was refused ("nope"): a blamer (anyone who narrates; never Jeff, who is
##   delighted by everything) turns to the partner, stamps, a ring in the partner's colour pops
##   round the partner, and he barks a plain bark (no `blame` cue exists: the plain `bark` is the
##   closest, "hey!").
## - Standing still: idle bits every few seconds. Jeff pokes at the junk next to him and hums;
##   Chuck kicks a tire and checks his hat; anyone else does any of the four. Each bit asks the
##   character's own rig for its action (rig.has_action) and falls back to idle, with a tilt / hop
##   on top so it always shows, plus a sound.
##
## Every bark goes through Audio.can_bark (per-speaker and global gaps), and a zap asks for at most
## one bark, so a zap never makes two barks. A reaction that is gated out plays nothing at all.
class_name Reactions
extends Node

const IMPACT_RANGE := 30.0
## Seconds standing still before the first idle bit, then between bits.
const IDLE_AFTER := 4.0
const IDLE_GAP := Vector2(4.5, 7.0)
const REACH := 2.2          # poke / kick reach from the player's middle
const POKE_PUSH := 1.2      # m/s given to what he pokes (it rocks, it doesn't fly)
const KICK_PUSH := 3.0
## Which bits each character does; anyone else does all of them.
const BITS := {"jeff": ["poke", "hum"], "chuck": ["kick_tire", "check_hat"]}
const ALL_BITS := ["poke", "hum", "kick_tire", "check_hat"]
## The rig action each bit asks for. The standard Jarling has only `kick`; the rest fall back to
## idle with the procedural tilt on top.
const BIT_ACTION := {"poke": "poke", "hum": "hum", "kick_tire": "kick", "check_hat": "check_hat"}
const BIT_SECS := {"poke": 1.0, "hum": 1.6, "kick_tire": 0.9, "check_hat": 1.3}
const WAIT_LINE_AFTER := 12.0  # seconds standing still before the one "wait" line of that stretch
const OOPS_GAP := 8.0         # seconds: the shortest wait between two "oops" lines from one player
## The cue each bit plays (existing cues only; see handoff/REPORT.md).
const HUM_CUE := "sparkle"        # glockenspiel notes, played low: the closest thing to a hum
const HAT_CUE := "wheel_move"     # a click: the hat brim straightened
const KICK_CUE := "impact_light"  # the boot on rubber (the tire also says its own bwomp)
const KICK_AIR_CUE := "land"      # nothing in reach: a stamp

var zapper: Zapper
## Seconds of an action bit / reaction pose left; the zapper doesn't force idle while > 0.
var busy_left := 0.0
var still_time := 0.0
var _last_oops := -100.0
var _waited := false          # this still stretch already had its "wait" line
var next_bit := IDLE_AFTER
## Last idle bit and the rig action it actually played ("idle" when the rig hasn't got it).
var last_bit := ""
var last_action := ""
## Last reaction ("delight", "narrate", "blame", "wobble"): tests and the demo log.
var last_reaction := ""
var bits_done := 0
## While look_left > 0 the body turns to look_dir (at the junk he pokes, at the partner he blames);
## the player's aim and facing don't change.
var look_dir := 0.0
var look_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = hash(zapper.character) + zapper.player * 7919 if zapper else 1


func bits() -> Array:
	return BITS.get(zapper.character, ALL_BITS)


func busy() -> bool:
	return busy_left > 0.0


## Called every physics frame by the zapper. active: the player pressed or moved something (no
## idle bit for a while); moved: he walked or jumped (that also cuts a bit or pose short; a press
## doesn't, or Chuck could never finish taking the credit).
func tick(delta: float, active: bool, can_idle: bool, moved := false) -> void:
	busy_left = maxf(0.0, busy_left - delta)
	look_left = maxf(0.0, look_left - delta)
	if moved and (busy_left > 0.0 or look_left > 0.0):
		_cancel()
	if active or moved or not can_idle:
		still_time = 0.0
		next_bit = IDLE_AFTER
		_waited = false
		return
	still_time += delta
	if not _waited and still_time >= WAIT_LINE_AFTER and busy_left <= 0.0 and Audio.can_bark(zapper):
		wait_line()
		return
	if still_time >= next_bit and busy_left <= 0.0:
		do_bit(bits()[_rng.randi() % bits().size()])
		next_bit = still_time + _rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)


## Which way the body faces now: look_dir while a bit or reaction looks somewhere, else facing.
func facing(f: float) -> float:
	return look_dir if look_left > 0.0 and look_dir != 0.0 else f


func _cancel() -> void:
	busy_left = 0.0
	look_left = 0.0
	var m := zapper.rig.model
	if m:
		m.rotation.x = 0.0
		m.rotation.z = 0.0
		m.position.y = 0.0


# ------------------------------------------------------------------------------------- idle bits

## Long enough standing still: once per still stretch, a look round and their pack's "wait" line
## ("I'll just look at this rock."). Never a hurry-up: the lines are idle chatter.
func wait_line() -> String:
	_waited = true
	last_reaction = "wait"
	busy_left = 1.2
	var rig := zapper.rig
	rig.set_expression("happy")
	rig.tilt(Vector2(0.0, -0.2), 0.8, 0.4)   # head tilts, looking round
	return zapper.bark("wait")


## Do one idle bit now; returns the bit actually done (a poke or kick with nothing in reach turns
## into the character's other bit).
func do_bit(bit: String) -> String:
	var rig := zapper.rig
	var near := nearest_object(bit == "kick_tire")
	if (bit == "poke" or bit == "kick_tire") and near == null:
		bit = "hum" if bit == "poke" else "check_hat"
	last_bit = bit
	bits_done += 1
	last_action = rig.play_action(BIT_ACTION[bit])
	busy_left = BIT_SECS[bit]
	var pos := zapper.global_position
	match bit:
		"poke":
			_face(near.global_position.x)
			rig.tilt(Vector2(0.35, 0.0), 0.7, 0.15)
			rig.set_expression("determined")
			_later(0.25, func() -> void:
				if not is_instance_valid(near):
					return
				var d := signf(near.global_position.x - zapper.global_position.x)
				near.apply_central_impulse(Vector3(d * POKE_PUSH, 0.6, 0) * near.mass)
				near.speak()
				Fx.sparkle(get_tree(), near.global_position + Vector3(0, near.radius() * 0.5, 0.4))
				rig.set_expression("happy"))
		"hum":
			Audio.play(HUM_CUE, pos, 0.75)
			rig.set_expression("happy")
			rig.tilt(Vector2(0.0, 0.18), 0.8, 0.4)
			_notes(pos + Vector3(0.25, zapper.HEIGHT + 0.1, 0.3))
		"kick_tire":
			_face(near.global_position.x)
			rig.set_expression("determined")
			_later(0.3, func() -> void:
				if not is_instance_valid(near):
					return
				var d := signf(near.global_position.x - zapper.global_position.x)
				near.apply_central_impulse(Vector3(d * KICK_PUSH, 1.2, 0) * near.mass)
				near.speak()
				Audio.play(KICK_CUE, near.global_position)
				Fx.burst(get_tree(), near.global_position, Color(0.8, 0.7, 0.55, 0.7), 8, 0.4, 0.4)
				rig.set_expression("happy"))
		"check_hat":
			Audio.play(HAT_CUE, pos)
			rig.tilt(Vector2(-0.3, 0.0), 0.9, 0.35)   # leans back to look up at the brim
			rig.set_expression("surprised")
			Fx.sparkle(get_tree(), pos + Vector3(0, zapper.HEIGHT + 0.35, 0.2))
			_later(0.6, func() -> void: rig.set_expression("happy"))
	return bit


## The nearest loose object within REACH of the player's middle (tires first when tires_first).
func nearest_object(tires_first := false) -> PhysicsObject:
	var best: PhysicsObject = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(PhysicsObject.GROUP):
		var o := n as PhysicsObject
		if o == null or o.freeze or o.stack.has(&"grab"):
			continue
		var d := o.global_position.distance_to(zapper.center()) - o.radius()
		if d > REACH:
			continue
		if tires_first and o.data and String(o.data.id).contains("tire"):
			d -= 100.0
		if d < best_d:
			best_d = d
			best = o
	return best


func _face(x: float) -> void:
	var d := signf(x - zapper.global_position.x)
	if d != 0.0:
		look_dir = d
		look_left = maxf(busy_left, 0.6)


func _notes(at: Vector3) -> void:
	for i in 3:
		_later(i * 0.35, func() -> void:
			var p := Fx.burst(get_tree(), at + Vector3(i * 0.12, 0, 0), Color(1.0, 0.85, 0.3), 1, 0.5, 1.1)
			if p:
				p.direction = Vector3(0.3, 1, 0)
				p.spread = 12.0
				p.initial_velocity_min = 0.6
				p.initial_velocity_max = 0.8
				p.gravity = Vector3(0, 0.4, 0)
				p.scale_amount_min = 2.4
				p.scale_amount_max = 2.8)


func _later(secs: float, f: Callable) -> void:
	get_tree().create_timer(secs).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_instance_valid(zapper):
			f.call())


# -------------------------------------------------------------------------------------- reactions

## A heavy / huge landing somewhere. Returns the bark used ("" when none).
func big_impact(at: Vector3, band: String) -> String:
	if zapper.asleep:
		return ""
	if at != Vector3.ZERO and at.distance_to(zapper.global_position) > IMPACT_RANGE:
		return ""
	if busy_left <= 0.0 or last_reaction != "delight":
		zapper.rig.wobble(1.3 if band == "impact_huge" else 1.0)
		last_reaction = "wobble"
	if not Audio.bark_style(zapper.character, "delight") or not Audio.can_bark(zapper):
		return ""
	last_reaction = "delight"
	_cancel()
	busy_left = 1.0
	zapper.rig.play_action("cheer", 1.4)   # the clap
	zapper.rig.hop(0.5, 0.45)
	zapper.rig.set_expression("happy")
	Fx.burst(get_tree(), zapper.center() + Vector3(0, 0.7, 0.3), Color(1.0, 0.85, 0.25), 18, 0.9, 0.7)
	return zapper.bark("delight")


## The player's own zap is done: changed = it did something, refused = it played "nope".
## At most one bark comes out of this, and only through the gate.
func own_zap(changed: bool, refused: bool) -> String:
	if changed and Audio.bark_style(zapper.character, "narrate") and Audio.can_bark(zapper):
		last_reaction = "narrate"
		busy_left = 0.5
		var rig := zapper.rig
		rig.set_expression("happy")
		rig.tilt(Vector2(-0.22, 0.0), 0.5, 0.15)   # chest out: that was me
		if rig.model:
			var rest := Vector3.ONE * JarlingRig.SCALE
			var tw := rig.model.create_tween()
			tw.tween_property(rig.model, "scale", rest * 1.14, 0.1)
			tw.tween_property(rig.model, "scale", rest, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return zapper.bark("zap")
	if refused and blames() and Audio.can_bark(zapper):
		return blame()
	if refused and Audio.can_bark(zapper) and Audio.now() - _last_oops >= OOPS_GAP:
		return oops()
	return ""


## A zap that couldn't happen, for someone who doesn't blame (Jeff): a sheepish shrug and their
## pack's gentle "oops" line ("Oops. Sorry, little fence."). Not more than once every OOPS_GAP s,
## so mashing at the size cap never turns into a nag.
func oops() -> String:
	last_reaction = "oops"
	busy_left = 0.6
	_last_oops = Audio.now()
	var rig := zapper.rig
	rig.set_expression("surprised")
	rig.hop(0.1, 0.25)
	rig.tilt(Vector2(0.0, 0.18), 0.5, 0.15)   # a little head tilt
	return zapper.bark("oops")


## Does this character blame the partner when something doesn't work?
func blames() -> bool:
	return Audio.bark_style(zapper.character, "narrate")


## Turn on the partner, stamp, pop a ring in the partner's colour round him, and say so.
func blame() -> String:
	last_reaction = "blame"
	busy_left = 0.8
	var mate := partner()
	var rig := zapper.rig
	if mate:
		_face(mate.global_position.x)
		Fx.ring(get_tree(), mate.center(), Players.COLOR[mate.player], 0.9)
		mate.rig.set_expression("surprised")
	rig.set_expression("determined")
	rig.hop(0.12, 0.25)
	rig.tilt(Vector2(0.25, 0.0), 0.6, 0.2)
	Fx.burst(get_tree(), zapper.global_position, Color(0.8, 0.7, 0.55, 0.7), 8, 0.4, 0.35)
	return zapper.bark("oops")   # "Oh! That wasn't me." (a random plain line could be a cheer)


## The other awake player, or null.
func partner() -> Zapper:
	for n in get_tree().get_nodes_in_group(Zapper.GROUP):
		var z := n as Zapper
		if z and z != zapper and not z.asleep:
			return z
	return null
