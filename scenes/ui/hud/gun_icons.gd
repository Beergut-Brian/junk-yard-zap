## PT10-1 / PT10-2 (playtest 2026-11-10): one bold token per gun that shows what the gun *does*,
## not the gadget. A disc in the gun's beam colour with an ink rim and a lit edge, and on it a little
## cream junk crate (with eyes, like everything in the yard) going through the effect:
##   size    a small crate and a big crate, a fat arrow between
##   grab    an open hand lifting a crate
##   bouncy  a ball bouncing along a dotted trail
##   balloon a balloon carrying a crate up
##   freeze  a crate locked in an ice block
##   glue    two crates stuck by a glue blob
##   magnet  a horseshoe magnet pulling a crate in
## motif(t) is also the switch preview: t runs 0 -> 1 over the preview and t = 1 is the icon, so the
## preview literally plays the icon's story. Drawn in code (crisp at any size, no assets to credit).
class_name GunIcons
extends RefCounted

const INK := Color("#1b1630")
const CREAM := Color("#fff5e6")
const ICE := Color(0.86, 0.97, 1.0)
## What each token shows (and what its preview plays), one story per kind.
const STORY := {
	GunData.Kind.SIZE: "a small crate becomes a big crate",
	GunData.Kind.GRAB: "an open hand lifts a crate",
	GunData.Kind.BOUNCY: "a ball bounces along a dotted trail",
	GunData.Kind.BALLOON: "a balloon blows up and carries a crate up",
	GunData.Kind.FREEZE: "a shivering crate is locked in an ice block",
	GunData.Kind.GLUE: "two crates slide together and a glue blob sticks them",
	GunData.Kind.MAGNET: "a horseshoe magnet pulls a crate in, clank",
}


## The token: rim, beam-colour disc, lit edge, then the effect at stage t (1 = the icon).
static func token(ci: CanvasItem, kind: GunData.Kind, col: Color, m: Vector2, s: float, t := 1.0, alpha := 1.0) -> void:
	ci.draw_circle(m + Vector2(0, s * 0.07), s, Color(INK, 0.35 * alpha))   # drop shadow
	ci.draw_circle(m, s, Color(INK, alpha))
	ci.draw_circle(m, s * 0.9, Color(col, alpha))
	ci.draw_circle(m + Vector2(0, s * 0.12), s * 0.78, Color(col.darkened(0.12), alpha))
	ci.draw_circle(m, s * 0.74, Color(col, alpha))
	ci.draw_arc(m, s * 0.8, PI * 1.12, PI * 1.62, 16, Color(col.lightened(0.55), alpha), s * 0.07, true)
	motif(ci, kind, m, s * 0.9, t, alpha)


## The effect picture inside a disc of radius s, at stage t of its little story.
static func motif(ci: CanvasItem, kind: GunData.Kind, m: Vector2, s: float, t := 1.0, alpha := 1.0) -> void:
	t = clampf(t, 0.0, 1.0)
	var ow := maxf(1.5, s * 0.075)
	var P := func(x: float, y: float) -> Vector2: return m + Vector2(x, y) * s
	match kind:
		GunData.Kind.SIZE:
			var k := _back(t)
			box(ci, P.call(-0.45, 0.33), s * 0.15, ow, alpha)
			var at: Vector2 = P.call(-0.45, 0.33).lerp(P.call(0.17, -0.02), minf(1.0, t * 1.6))
			box(ci, at, s * lerpf(0.15, 0.4, k), ow, alpha)
			if t > 0.55:
				var a := (t - 0.55) / 0.45
				_arrow(ci, P.call(-0.55, 0.02), P.call(-0.36, -0.36), s * 0.1, ow, Color(1, 1, 1, alpha * a))
		GunData.Kind.GRAB:
			var lift := _out(t)
			box(ci, P.call(0.0, lerpf(-0.05, -0.4, lift)), s * 0.23, ow, alpha, sin(t * 9.0) * 0.12 * (1.0 - t))
			hand(ci, P.call(0.0, lerpf(0.05, -0.08, lift)), s * 1.25, ow, alpha)
			for i in 2:   # lift chevrons
				var y := lerpf(0.0, -0.15, fposmod(t * 2.0 + i * 0.5, 1.0))
				_chevron(ci, P.call(-0.5 + i, y), s * 0.12, ow, Color(CREAM, alpha * (0.4 + 0.6 * t)))
		GunData.Kind.BOUNCY:
			var ground := 0.5
			ci.draw_line(P.call(-0.62, ground + 0.17), P.call(0.62, ground + 0.17), Color(INK, alpha), ow * 1.4, true)
			var steps := int(t * 14.0)
			for i in steps:   # the dotted trail it bounced along
				ci.draw_circle(_bounce(P, (i + 0.5) / 14.0), s * 0.065, Color(INK, alpha * 0.8))
				ci.draw_circle(_bounce(P, (i + 0.5) / 14.0), s * 0.04, Color(CREAM, alpha))
			var at := _bounce(P, t)
			var squash := 1.0
			if at.y > m.y + s * (ground - 0.1):
				squash = 0.7
			ball(ci, at, s * 0.27, ow, alpha, squash)
		GunData.Kind.BALLOON:
			var inflate := _back(minf(1.0, t / 0.5))
			var rise := _out(clampf((t - 0.45) / 0.55, 0.0, 1.0))
			var dy := (1.0 - rise) * 0.22
			var b: Vector2 = P.call(0.0, -0.3 + dy)
			var crate: Vector2 = P.call(0.0, 0.36 + dy)
			ci.draw_line(b + Vector2(0, s * 0.27 * inflate), crate - Vector2(0, s * 0.15), Color(INK, alpha), ow, true)
			box(ci, crate, s * 0.15, ow, alpha)
			balloon(ci, b, s * 0.28 * inflate, ow, alpha)
			if rise > 0.0:
				for side in [-1.0, 1.0]:
					_chevron(ci, P.call(side * 0.5, 0.15 - rise * 0.2), s * 0.11, ow, Color(CREAM, alpha * rise))
		GunData.Kind.FREEZE:
			var shiver := sin(t * 60.0) * s * 0.03 * (1.0 - smoothstep(0.25, 0.45, t))
			box(ci, m + Vector2(shiver, s * 0.05), s * 0.22, ow, alpha)
			var ice := smoothstep(0.3, 0.75, t)
			if ice > 0.0:
				var r := Rect2(m - Vector2(s, s) * 0.4, Vector2(s, s) * 0.8)
				r = Rect2(r.get_center() - r.size * 0.5 * lerpf(0.6, 1.0, ice), r.size * lerpf(0.6, 1.0, ice))
				r.position.y += s * 0.05
				ci.draw_rect(r.grow(ow * 0.5), Color(INK, alpha * ice), false, ow)
				ci.draw_rect(r, Color(ICE, alpha * 0.55 * ice))
				ci.draw_line(r.position + r.size * Vector2(0.15, 0.35), r.position + r.size * Vector2(0.35, 0.15), Color(1, 1, 1, alpha * ice), ow, true)
				ci.draw_line(r.position + r.size * Vector2(0.15, 0.6), r.position + r.size * Vector2(0.6, 0.15), Color(1, 1, 1, alpha * ice * 0.7), ow * 0.7, true)
			if t > 0.7:
				flake(ci, P.call(0.48, -0.45), s * 0.2 * _back((t - 0.7) / 0.3), ow, alpha)
		GunData.Kind.GLUE:
			var slide := _out(minf(1.0, t / 0.6))
			var gap := lerpf(0.6, 0.27, slide)
			var wob := sin(t * 20.0) * 0.08 * clampf((t - 0.6) / 0.2, 0.0, 1.0) * (1.0 - t) * 4.0
			box(ci, P.call(-gap, 0.12), s * 0.27, ow, alpha, -wob)
			box(ci, P.call(gap, 0.12), s * 0.27, ow, alpha, wob)
			if t > 0.55:
				blob(ci, P.call(0.0, -0.2), s * 0.13 * _back((t - 0.55) / 0.45), ow, alpha)
		GunData.Kind.MAGNET:
			var pull := pow(clampf(t / 0.75, 0.0, 1.0), 2.2)
			var bx := lerpf(0.6, 0.3, pull)
			for i in 2:   # pulsing field lines
				var ph := fposmod(t * 2.5 + i * 0.5, 1.0) if t < 0.8 else 0.35 + i * 0.4
				var x := lerpf(bx - 0.2, -0.1, ph)
				ci.draw_arc(P.call(x - 0.25, 0.0), s * 0.3, -0.7, 0.7, 10, Color(CREAM, alpha * (1.0 - ph * 0.6)), ow * 1.1, true)
			horseshoe(ci, P.call(-0.32, 0.0), s * 0.32, ow, alpha)
			box(ci, P.call(bx + 0.04, 0.0), s * 0.22, ow, alpha, -0.2 * (1.0 - pull))
			if t > 0.75:   # clank
				var k := (t - 0.75) / 0.25
				for a in [-0.6, 0.0, 0.6]:
					var d := Vector2.from_angle(a)
					ci.draw_line(P.call(0.5, 0.0) + d * s * 0.05, P.call(0.5, 0.0) + d * s * (0.1 + 0.12 * k), Color(CREAM, alpha * (1.0 - k * 0.5)), ow, true)


# ------------------------------------------------------------------------------------- pieces

## Polygons skipped because they had no area (launch-ready: tests read it).
static var skipped := 0


## draw_colored_polygon, except a shape squashed to nothing (a token popping in from size 0, an
## arrow of zero length) is skipped: the engine can't triangulate it and logs an error every frame.
static func fill(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> bool:
	if not has_area(pts):
		skipped += 1
		return false
	ci.draw_colored_polygon(pts, col)
	return true


## At least three points and more than a quarter of a square pixel inside (shoelace); smaller is
## invisible anyway.
static func has_area(pts: PackedVector2Array) -> bool:
	if pts.size() < 3:
		return false
	var a := 0.0
	for i in pts.size():
		a += pts[i].cross(pts[(i + 1) % pts.size()])
	return absf(a) * 0.5 > 0.25


## A cream junk crate with eyes, half-size h, turned by rot.
static func box(ci: CanvasItem, at: Vector2, h: float, ow: float, alpha := 1.0, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pts.append(at + (c * h).rotated(rot))
	fill(ci, pts, Color(CREAM, alpha))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(INK, alpha), ow, true)
	var slat := Color(0.85, 0.72, 0.55, alpha)
	ci.draw_line(at + Vector2(-h * 0.7, h * 0.45).rotated(rot), at + Vector2(h * 0.7, h * 0.45).rotated(rot), slat, maxf(1.0, ow * 0.6), true)
	if h > ow * 2.2:
		for x in [-0.32, 0.32]:
			ci.draw_circle(at + Vector2(x * h, -h * 0.18).rotated(rot), maxf(1.0, h * 0.13), Color(INK, alpha))


static func ball(ci: CanvasItem, at: Vector2, r: float, ow: float, alpha := 1.0, squash := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(at + Vector2(cos(a) * r / squash, sin(a) * r * squash + r * (1.0 - squash)))
	fill(ci, pts, Color(CREAM, alpha))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(INK, alpha), ow, true)
	ci.draw_arc(at, r * 0.62, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, alpha), ow * 0.8, true)
	if squash < 1.0:
		ci.draw_line(at + Vector2(-r * 0.7, r * 1.15), at + Vector2(r * 0.7, r * 1.15), Color(INK, alpha), ow, true)


static func balloon(ci: CanvasItem, at: Vector2, r: float, ow: float, alpha := 1.0) -> void:
	if r <= 0.5:
		return
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(at + Vector2(cos(a) * r * 0.86, sin(a) * r))
	fill(ci, pts, Color(CREAM, alpha))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(INK, alpha), ow, true)
	fill(ci, PackedVector2Array([at + Vector2(-r * 0.15, r * 1.12), at + Vector2(r * 0.15, r * 1.12), at + Vector2(0, r * 0.95)]), Color(INK, alpha))
	ci.draw_arc(at, r * 0.62, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, alpha), ow, true)


## An open hand, palm up, fingers spread under whatever it lifts. at = palm centre-ish.
static func hand(ci: CanvasItem, at: Vector2, s: float, ow: float, alpha := 1.0) -> void:
	var parts := []   # [a, b, width]
	parts.append([at + Vector2(-0.13, 0.42) * s, at + Vector2(0.13, 0.42) * s, 0.32 * s])
	for x in [-0.165, -0.055, 0.055, 0.165]:
		parts.append([at + Vector2(x, 0.34) * s, at + Vector2(x * 1.3, 0.1 + absf(x) * 0.5) * s, 0.1 * s])
	parts.append([at + Vector2(-0.2, 0.45) * s, at + Vector2(-0.36, 0.3) * s, 0.11 * s])
	for p in parts:
		_cap(ci, p[0], p[1], p[2] + ow * 2.0, Color(INK, alpha))
	for p in parts:
		_cap(ci, p[0], p[1], p[2], Color(CREAM, alpha))


static func flake(ci: CanvasItem, at: Vector2, r: float, ow: float, alpha := 1.0) -> void:
	if r <= 0.5:
		return
	for pass_i in 2:
		var c := Color(INK, alpha) if pass_i == 0 else Color(1, 1, 1, alpha)
		var w := ow * (2.6 if pass_i == 0 else 1.2)
		for i in 3:
			var d := Vector2.from_angle(i * PI / 3.0 + PI / 6.0) * r
			ci.draw_line(at - d, at + d, c, w, true)


## A glue blob with a drip.
static func blob(ci: CanvasItem, at: Vector2, r: float, ow: float, alpha := 1.0) -> void:
	if r <= 0.5:
		return
	ci.draw_circle(at, r + ow, Color(INK, alpha))
	_cap(ci, at, at + Vector2(r * 0.25, r * 1.6), r * 0.7 + ow * 2.0, Color(INK, alpha))
	ci.draw_circle(at, r, Color(1, 1, 1, alpha))
	_cap(ci, at, at + Vector2(r * 0.25, r * 1.6), r * 0.7, Color(1, 1, 1, alpha))
	ci.draw_circle(at + Vector2(-r * 0.35, -r * 0.35), r * 0.22, Color(0.85, 0.95, 1.0, alpha))


## A horseshoe magnet opening to the right, bend centred at at, radius r.
static func horseshoe(ci: CanvasItem, at: Vector2, r: float, ow: float, alpha := 1.0) -> void:
	var w := r * 0.62
	for pass_i in 2:
		var c := Color(INK, alpha) if pass_i == 0 else Color(CREAM, alpha)
		var ww := w + (ow * 2.0 if pass_i == 0 else 0.0)
		ci.draw_arc(at, r, PI * 0.5, PI * 1.5, 18, c, ww, true)
		for side in [-1.0, 1.0]:
			var y: float = side * r
			var len := r * 1.15 + (ow if pass_i == 0 else 0.0)
			ci.draw_rect(Rect2(at + Vector2(-0.5, y - ww * 0.5), Vector2(len, ww)), c)
	for side in [-1.0, 1.0]:   # the metal tips
		ci.draw_rect(Rect2(at + Vector2(r * 0.75, side * r - w * 0.5), Vector2(r * 0.38, w)), Color(0.72, 0.76, 0.84, alpha))


static func _cap(ci: CanvasItem, a: Vector2, b: Vector2, w: float, c: Color) -> void:
	ci.draw_line(a, b, c, w, true)
	ci.draw_circle(a, w * 0.5, c)
	ci.draw_circle(b, w * 0.5, c)


static func _chevron(ci: CanvasItem, at: Vector2, w: float, ow: float, c: Color) -> void:
	ci.draw_polyline(PackedVector2Array([at + Vector2(-w, w * 0.5), at + Vector2(0, -w * 0.3), at + Vector2(w, w * 0.5)]), c, ow * 1.3, true)


static func _arrow(ci: CanvasItem, from: Vector2, to: Vector2, w: float, ow: float, c: Color) -> void:
	var d := (to - from).normalized()
	var n := Vector2(-d.y, d.x)
	var head := PackedVector2Array([to + d * w * 1.2, to - d * w + n * w * 1.5, to - d * w - n * w * 1.5])
	ci.draw_line(from, to - d * w * 0.5, Color(INK, c.a), w + ow * 2.0, true)
	var hh := PackedVector2Array([head[0] + d * ow * 1.5, head[1] + (n - d) * ow * 1.3, head[2] + (-n - d) * ow * 1.3])
	fill(ci, hh, Color(INK, c.a))
	ci.draw_line(from, to - d * w * 0.5, c, w, true)
	fill(ci, head, c)


## Where the bouncing ball is at t: two hops, the last one ending at its top.
static func _bounce(P: Callable, t: float) -> Vector2:
	var x := lerpf(-0.5, 0.22, t)
	var ph := t * 2.5   # half-hops: 0..1 down, ...
	var h := 0.72 if t > 0.4 else 0.5
	var y := 0.4 - absf(sin(ph * PI)) * h
	return P.call(x, y)


static func _back(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)


static func _out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3)
