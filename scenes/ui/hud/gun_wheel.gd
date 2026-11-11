## PT10-1 / PT10-2: the belt wheel that pops round a player's head on RB / LB, with weight.
## Seven tokens on a dark ring; the chosen one sits at the top, big, in a ring of the player's colour
## under a pointer, and lands with a scale punch; the ring spins to it (back ease). The middle of the
## wheel plays the chosen gun's switch preview (its token telling its little story, picture only),
## which stays by the player for a moment after the ring folds away.
class_name GunWheel
extends RefCounted

const OPEN := 0.14        # s: ring pops open
const RING_TIME := 0.95   # s: ring shown after the last flick
const PREVIEW_TIME := 1.8 # s: the preview plays this long (PT10-2: 1-2 s)
const SPIN := 0.22        # s: ring turns to the new gun
const R := 122.0          # ring radius at 1080p
const DEEP := Color("#33201a")


## One wheel. age = seconds since the last flick; from_index = the gun before it (for the spin).
## scale: 1 at 1080p.
static func draw(ci: CanvasItem, guns: Array, index: int, from_index: int, at: Vector2, col: Color, age: float, scale := 1.0) -> void:
	var n := guns.size()
	if n == 0:
		return
	var open := _back(age / OPEN)
	var fold := 1.0 - clampf((age - RING_TIME) / 0.16, 0.0, 1.0)
	var ring_k := open * fold
	var spin := _back(age / SPIN)
	var delta := wrapf(float(index - from_index), -n * 0.5, n * 0.5)   # shortest way round
	var turn := float(index) - delta * (1.0 - spin)
	var punch := 1.0 + 0.35 * exp(-age * 9.0)
	if ring_k > 0.01:
		var rr := R * scale * ring_k
		ci.draw_arc(at, rr, 0, TAU, 48, Color(GunIcons.INK, 0.85), 100.0 * scale * ring_k, true)
		ci.draw_arc(at, rr, 0, TAU, 48, Color(DEEP, 0.92), 88.0 * scale * ring_k, true)
		ci.draw_arc(at, rr + 44.0 * scale * ring_k, 0, TAU, 48, Color(col, 0.9), 5.0 * scale, true)
		var order := []   # draw the chosen one last so it sits on top
		for i in n:
			if i != index:
				order.append(i)
		order.append(index)
		for i in order:
			var k := float(i) - turn
			var ang := -PI / 2 + TAU * k / n
			var p := at + Vector2.from_angle(ang) * rr
			var g: GunData = guns[i]
			if i == index:
				var big := 60.0 * scale * ring_k * punch
				ci.draw_circle(p, big + 12.0 * scale, Color(GunIcons.INK, 0.9))
				ci.draw_circle(p, big + 9.0 * scale, col)
				Pictos.gun_icon(ci, g, Rect2(p - Vector2(big, big), Vector2(big, big) * 2.0))
				# The pointer: a fat wedge in the player's colour above the chosen gun.
				var tip := p + Vector2(0, -big - 12.0 * scale)
				var w := 20.0 * scale
				ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-w - 4 * scale, -w - 8 * scale), tip + Vector2(w + 4 * scale, -w - 8 * scale), tip + Vector2(0, 5 * scale)]), GunIcons.INK)
				ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-w, -w - 5 * scale), tip + Vector2(w, -w - 5 * scale), tip]), col)
			else:
				var sz := 30.0 * scale * ring_k
				Pictos.gun_icon(ci, g, Rect2(p - Vector2(sz, sz), Vector2(sz, sz) * 2.0), 0.8)
	# The preview in the middle: bigger once the ring is gone, then it pops away.
	if age < PREVIEW_TIME:
		var t := clampf((age - 0.08) / (PREVIEW_TIME - 0.55), 0.0, 1.0)
		var size := 62.0 * scale * open * lerpf(1.0, 1.15, 1.0 - fold)
		var out := clampf((PREVIEW_TIME - age) / 0.15, 0.0, 1.0)
		size *= _back(out)
		if size > 1.0:
			var g: GunData = guns[index]
			var c := at if fold > 0.0 else at.lerp(at + Vector2(0, R * scale * 0.4), 1.0 - fold)
			ci.draw_circle(c, size + 8.0 * scale, Color(GunIcons.INK, 0.9))
			ci.draw_circle(c, size + 5.0 * scale, Color(1, 1, 1))
			Pictos.gun_preview(ci, g, Rect2(c - Vector2(size, size), Vector2(size, size) * 2.0), t)


## The gun the player holds, in their bottom corner: the token in a ring of their colour.
static func badge(ci: CanvasItem, g: GunData, at: Vector2, col: Color, since_change: float, scale := 1.0) -> void:
	var punch := 1.0 + 0.3 * exp(-since_change * 8.0)
	var r := 58.0 * scale * punch
	ci.draw_circle(at + Vector2(0, 6 * scale), r + 14.0 * scale, Color(GunIcons.INK, 0.35))
	ci.draw_circle(at, r + 14.0 * scale, GunIcons.INK)
	ci.draw_circle(at, r + 10.0 * scale, col)
	Pictos.gun_icon(ci, g, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0))


static func _back(t: float) -> float:
	return GunIcons._back(t)
