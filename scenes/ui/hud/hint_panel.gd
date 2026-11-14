## R-07 (Kaden's rule "Show the buttons that matter right now"): one hint panel per player in play.
## Pictures only (kid rules for gameplay): a short row of the lobby's controller glyphs
## (UiStyle.draw_glyph, the same art as the lobby footer and Settings), each next to a picture of
## what it does now (the held gun's token, a jump arrow, an open hand, the size arrows, ...). The row
## sits in the player's bottom corner beside their gun badge, in their slot colour (P1 green, P2 red,
## whoever they picked), and changes with what the player is doing. When an interaction is ready
## (a grab gun on something it can lift, a contraption in the beam) a small A glyph blinks above the
## player, off to the side away from the beam. A refused press (a statue, an unbound button, a zap
## that can't happen) shakes the same row: the nope cue state, never a new hint.
##
## The rules live in one pure function, `hint_for_state()`, so tests drive every context without a
## scene; `state_of()` reads a Zapper into that function's input. The panel never moves a character.
class_name HintPanel
extends Control

enum Context { HIDDEN, ASLEEP, ON_FOOT, AIMING, GRAB_READY, CARRYING, SIZING, COOLDOWN, SIGN, FROZEN }
## The picture beside a glyph.
enum Pic { WAKE, JUMP, BELT, FIRE, HAND, DROP, THROW, SIZE, SWIRL }

const ZAP_BEAT := 0.35     # s after a zap the A glyph shows sunk (the "cooldown" beat; no real fire cooldown)
const NOPE_TIME := 0.4     # s the row shakes after a refused press
const BLINK_PERIOD := 0.6  # s, the ready glyph above the player
const GLYPH_H := 46.0      # px at 1080p, glyph height in the row
const CHIP_W := 116.0
const CHIP_H := 70.0
const CHIP_GAP := 12.0
const BADGE_CLEAR := 100.0 # px from the badge centre to the first chip (GunWheel.badge is r 58 + 14)

var zapper: Zapper
var camera: CameraRig
var hud: Hud
var since_zap := 9.0
var since_nope := 9.0
var hint: Dictionary = {}
var _clock := 0.0


## The rules. `s` keys (all optional): live, asleep, statue, held, sizing, near_sign, target
## ("" | "object" | "partner" | "contraption"), grabbable, gun_kind (GunData.Kind or -1),
## since_zap, since_nope (seconds). Returns {context, glyphs: [{tok, pic, lit}], blink: "" | tok,
## iced: bool, nope: bool}. A refused press only sets `nope`; the glyphs stay the context's own.
static func hint_for_state(s: Dictionary) -> Dictionary:
	var ctx := context_for(s)
	var g := []
	var blink := ""
	match ctx:
		Context.ASLEEP:
			g = [_g("a", Pic.WAKE)]
		Context.ON_FOOT:
			g = [_g("b", Pic.JUMP), _g("rb", Pic.BELT)]
		Context.AIMING:
			g = [_g("a", Pic.FIRE), _g("b", Pic.JUMP), _g("rb", Pic.BELT)]
			if s.get("target", "") == "contraption":
				blink = "a"
		Context.GRAB_READY:
			g = [_g("a", Pic.HAND), _g("b", Pic.JUMP), _g("rb", Pic.BELT)]
			blink = "a"
		Context.CARRYING:
			g = [_g("a", Pic.DROP, true), _g("lr", Pic.THROW), _g("b", Pic.JUMP)]
		Context.SIZING:
			g = [_g("ud", Pic.SIZE), _g("a", Pic.FIRE, true)]
		Context.COOLDOWN:
			g = [_g("a", Pic.FIRE, true), _g("b", Pic.JUMP), _g("rb", Pic.BELT)]
		Context.SIGN:
			g = [_g("a", Pic.SWIRL), _g("b", Pic.JUMP), _g("rb", Pic.BELT)]
		Context.FROZEN:
			g = [_g("a", Pic.FIRE), _g("b", Pic.JUMP), _g("rb", Pic.BELT)]
	return {
		"context": ctx, "glyphs": g, "blink": blink, "iced": ctx == Context.FROZEN,
		"nope": ctx != Context.HIDDEN and ctx != Context.ASLEEP and float(s.get("since_nope", 9.0)) < NOPE_TIME,
	}


## Which context wins, most urgent first.
static func context_for(s: Dictionary) -> Context:
	if not s.get("live", true):
		return Context.HIDDEN
	if s.get("asleep", false):
		return Context.ASLEEP
	if s.get("statue", false):
		return Context.FROZEN
	if s.get("held", false):
		return Context.CARRYING
	if s.get("sizing", false):
		return Context.SIZING
	if float(s.get("since_zap", 9.0)) < ZAP_BEAT:
		return Context.COOLDOWN
	if s.get("near_sign", false):
		return Context.SIGN   # no blink here: the sign wipes the yard, so it is shown, never invited
	var t: String = s.get("target", "")
	if t == "object" and s.get("grabbable", false) and int(s.get("gun_kind", -1)) == GunData.Kind.GRAB:
		return Context.GRAB_READY
	if t != "":
		return Context.AIMING
	return Context.ON_FOOT


static func _g(tok: String, pic: Pic, lit := false) -> Dictionary:
	return {"tok": tok, "pic": pic, "lit": lit}


## A Zapper's live state, in hint_for_state()'s words.
static func state_of(z: Zapper, p_since_zap := 9.0, p_since_nope := 9.0) -> Dictionary:
	var t := ""
	var grabbable := false
	var tg := z.target
	if is_instance_valid(tg) and tg != z.held:
		if tg is Zapper:
			t = "partner"
		elif tg.is_in_group(&"zap_targets"):
			t = "contraption"
		else:
			t = "object"
			var po := tg as PhysicsObject
			if po:
				var on: Effects.Grab = po.stack.get_effect(&"grab")
				grabbable = on == null or on.holder == z
	var level := YardLevel.find(z)
	return {
		"live": Game.state == Game.State.PLAYING, "asleep": z.asleep, "statue": z.statue_left > 0.0,
		"held": is_instance_valid(z.held), "sizing": z.sizing(),
		"near_sign": level != null and level.reset_sign != null and level.near_reset_sign(z),
		"target": t, "grabbable": grabbable, "gun_kind": z.gun().kind if z.gun() else -1,
		"since_zap": p_since_zap, "since_nope": p_since_nope,
	}


## One panel for `z`, under the HUD (drawn over play, under the menus).
static func make(z: Zapper, p_camera: CameraRig, p_hud: Hud) -> HintPanel:
	var hp := HintPanel.new()
	hp.name = "HintP%d" % (z.player + 1)
	hp.zapper = z
	hp.camera = p_camera
	hp.hud = p_hud
	z.zapped.connect(hp._on_zapped)
	z.noped.connect(func(_p: int) -> void: hp.since_nope = 0.0)
	p_hud.add_child(hp)
	return hp


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_zapped(_player: int, _gun: StringName, _target: Node3D) -> void:
	if not zapper._refused:   # a refused press is the nope state, not the zap beat
		since_zap = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(zapper):
		queue_free()
		return
	_clock += delta
	since_zap += delta
	since_nope += delta
	hint = hint_for_state(state_of(zapper, since_zap, since_nope))
	queue_redraw()


func _draw() -> void:
	if hint.is_empty() or hint["context"] == Context.HIDDEN or camera == null or not camera.is_inside_tree():
		return
	var col: Color = Players.COLOR[zapper.player]
	# Solo: the player the pad isn't driving waits, so their row is quieter.
	var alpha := 0.5 if Players.solo and Players.solo_focus != zapper.player else 1.0
	_draw_row(col, alpha)
	if hint["blink"] != "" and alpha == 1.0:
		_draw_blink(hint["blink"], col)


func _draw_row(col: Color, alpha: float) -> void:
	var vs := get_viewport_rect().size
	var glyphs: Array = hint["glyphs"]
	var p1 := zapper.player == Players.P1
	var cy := vs.y - UiStyle.SAFE.y - 60.0
	var shake := 0.0
	if hint["nope"]:
		var k := since_nope / NOPE_TIME
		shake = sin(since_nope * 55.0) * 10.0 * (1.0 - k)
	for i in glyphs.size():
		var e: Dictionary = glyphs[i]
		var off := BADGE_CLEAR + CHIP_W * 0.5 + i * (CHIP_W + CHIP_GAP)
		if hint["context"] == Context.ASLEEP:
			off = CHIP_W * 0.5 - 60.0   # no badge while asleep: the wake chip takes its corner
		var cx := (UiStyle.SAFE.x + 60.0 + off) if p1 else (vs.x - UiStyle.SAFE.x - 60.0 - off)
		var c := Vector2(cx + shake, cy)
		_chip(c, e, col, alpha)


## One chip: a dark slanted pill edged in the player's colour, the glyph on the left, the picture right.
func _chip(c: Vector2, e: Dictionary, col: Color, alpha: float) -> void:
	var r := Rect2(c - Vector2(CHIP_W, CHIP_H) * 0.5, Vector2(CHIP_W, CHIP_H))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GunIcons.INK, 0.78 * alpha)
	sb.border_color = Color(col, alpha) if not hint["nope"] else Color(0.7, 0.7, 0.72, alpha)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(int(CHIP_H * 0.5))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var lit: bool = e["lit"]
	var gc := c + Vector2(-CHIP_W * 0.22, 3.0 if lit else 0.0)
	var gh := GLYPH_H * (0.86 if lit else 1.0)
	if e["tok"] == "a" and hint["context"] == Context.ASLEEP:
		gh *= 1.0 + 0.08 * sin(_clock * 5.0)   # the sleeper's wake glyph breathes
	var ga := alpha * (0.55 if hint["iced"] else 1.0)
	UiStyle.draw_glyph(self, gc, gh, e["tok"], ga)
	if lit:   # held down: a ring in the player's colour round the sunk glyph
		var w := gh * (1.5 if e["tok"] in ["lr", "ud", "lb", "rb"] else 1.0)
		draw_arc(gc, w * 0.5 + 4.0, 0, TAU, 32, Color(col, alpha), 4.0, true)
	_pic(c + Vector2(CHIP_W * 0.24, 0), e["pic"], col, ga)
	if hint["iced"]:   # a statue: the whole chip under ice (the same ice as the freeze look)
		var ice := sb.duplicate() as StyleBoxFlat
		ice.bg_color = Color(GunIcons.ICE, 0.42 * alpha)
		ice.border_color = Color(1, 1, 1, 0.8 * alpha)
		draw_style_box(ice, r.grow(-2))
		GunIcons.flake(self, r.position + Vector2(CHIP_W - 18, 14), 7.0, 1.5, alpha)


## What the button does now, as a picture (drawn in code from the HUD's own pieces).
func _pic(c: Vector2, pic: Pic, col: Color, alpha: float) -> void:
	var s := 25.0
	var ink := Color(GunIcons.INK, alpha)
	var cream := Color(GunIcons.CREAM, alpha)
	match pic:
		Pic.FIRE:
			var g := zapper.gun()
			if g:
				GunIcons.token(self, g.kind, g.beam_color, c, s, 1.0, alpha)
		Pic.BELT:   # the next gun on the belt, smaller, with a turn arrow
			var n := zapper.guns.size()
			if n > 0:
				var g: GunData = zapper.guns[(zapper.gun_index + 1) % n]
				GunIcons.token(self, g.kind, g.beam_color, c + Vector2(3, 3), s * 0.8, 1.0, alpha)
			draw_arc(c, s * 1.05, -PI * 0.95, -PI * 0.2, 12, ink, 7.0, true)
			draw_arc(c, s * 1.05, -PI * 0.95, -PI * 0.2, 12, cream, 3.5, true)
			var tip := c + Vector2.from_angle(-PI * 0.2) * s * 1.05
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-7, -5), tip + Vector2(6, -1), tip + Vector2(-1, 8)]), cream)
		Pic.JUMP:   # a fat up arrow over a little ground line
			draw_line(c + Vector2(-s, s * 0.85), c + Vector2(s, s * 0.85), ink, 6.0, true)
			GunIcons._arrow(self, c + Vector2(0, s * 0.6), c + Vector2(0, -s * 0.45), 7.0, 2.0, cream)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.95), c + Vector2(-s * 0.55, -s * 0.2), c + Vector2(s * 0.55, -s * 0.2)]), cream)
			draw_line(c + Vector2(0, s * 0.6), c + Vector2(0, -s * 0.25), cream, 7.0, true)
		Pic.HAND:   # the grab gun's open hand lifting a crate
			GunIcons.box(self, c + Vector2(0, -s * 0.45), s * 0.62, 2.0, alpha)
			GunIcons.hand(self, c + Vector2(0, -s * 0.55), s * 2.6, 2.0, alpha)
		Pic.DROP:   # the crate falling out of the hand
			GunIcons.hand(self, c + Vector2(-s * 0.25, -s * 1.25), s * 2.2, 2.0, alpha)
			GunIcons.box(self, c + Vector2(s * 0.3, s * 0.5), s * 0.55, 2.0, alpha)
			GunIcons._arrow(self, c + Vector2(s * 0.85, -s * 0.5), c + Vector2(s * 0.85, s * 0.3), 4.0, 1.5, cream)
		Pic.THROW:   # a crate flying off on an arc
			draw_arc(c + Vector2(0, s * 0.8), s * 0.95, -PI * 0.95, -PI * 0.35, 12, ink, 6.0, true)
			draw_arc(c + Vector2(0, s * 0.8), s * 0.95, -PI * 0.95, -PI * 0.35, 12, cream, 2.5, true)
			GunIcons.box(self, c + Vector2(s * 0.55, -s * 0.15), s * 0.4, 2.0, alpha, 0.4)
		Pic.SIZE:   # small crate, big crate (the size gun's own story)
			GunIcons.box(self, c + Vector2(-s * 0.55, s * 0.35), s * 0.3, 2.0, alpha)
			GunIcons.box(self, c + Vector2(s * 0.35, s * 0.05), s * 0.62, 2.0, alpha)
		Pic.SWIRL:
			UiGlyphs.reset_swirl(self, c, s * 1.1, Color(1, 0.86, 0.3, alpha))
		Pic.WAKE:   # a sun popping up: wake up
			draw_circle(c, s * 0.55 + 3, ink)
			draw_circle(c, s * 0.55, Color(1, 0.86, 0.3, alpha))
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8.0 + _clock)
				draw_line(c + d * s * 0.75, c + d * s * 1.05, Color(1, 0.86, 0.3, alpha), 4.0, true)


## The ready glyph above the player: small, blinking, behind their shoulder (away from the beam), and
## out of the way of the gun wheel, the first-fire beat and the reset ring that use the same spot.
func _draw_blink(tok: String, col: Color) -> void:
	if hud and (hud.wheel_showing(zapper.player) or zapper.reset_progress() > 0.0):
		return
	var head := zapper.global_position + Vector3(0, Zapper.HEIGHT + 0.35, 0)
	if not camera.sees(head):
		return
	var at := camera.unproject_position(head) + Vector2(-zapper.facing * 46.0, -10.0)
	var on := fmod(_clock, BLINK_PERIOD) < BLINK_PERIOD * 0.6
	var h := 38.0 if on else 32.0
	var a := 1.0 if on else 0.45
	draw_circle(at, h * 0.5 + 6.0, Color(GunIcons.INK, 0.7 * a))
	draw_arc(at, h * 0.5 + 4.0, 0, TAU, 28, Color(col, a), 4.0, true)
	UiStyle.draw_glyph(self, at, h, tok, a)
