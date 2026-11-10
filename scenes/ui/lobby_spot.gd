## One player's join panel in the lobby: "PLAYER 1" header with their colour, their character in
## the middle, the next step at the bottom. Empty: "Press [a] to join" (gently pulsing). Joined:
## a colour outline. Ready: a colour glow and a READY badge. `hold` (0..1) fills a bar while that
## player holds A on Play to start alone. Player colours are used here only as player identity.
extends Control

@export var player: int = 0
## How opaque the panel is: games that show their level behind the lobby turn it down.
@export_range(0.0, 1.0) var fill_alpha := 1.0:
	set(v):
		fill_alpha = v
		queue_redraw()

var joined := false:
	set(v):
		joined = v
		queue_redraw()
var readied := false:
	set(v):
		if v and not readied:
			_pop()
		readied = v
		queue_redraw()
var hold := 0.0:
	set(v):
		hold = clampf(v, 0.0, 1.0)
		queue_redraw()

var _t := 0.0


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _process(delta: float) -> void:
	if not joined:
		_t += delta
		queue_redraw()


func _pop() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween()
	scale = Vector2.ONE * 1.03
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var col: Color = UiStyle.player_color(player)
	var r := Rect2(Vector2.ZERO, size)
	if readied:
		draw_style_box(UiStyle.glow(col, UiStyle.RADIUS_PANEL, 34), r)
	var bg := UiStyle.PANEL_RAISED if joined else UiStyle.PANEL
	var sb := UiStyle.panel(Color(bg, bg.a * fill_alpha), UiStyle.RADIUS_PANEL, int(28 * fill_alpha))
	draw_style_box(sb, r)
	var border := UiStyle.LINE
	var bw := 2
	if readied:
		border = col
		bw = 5
	elif joined:
		border = Color(col, 0.7)
		bw = 3
	draw_style_box(UiStyle.outline(border, bw), r)
	# Header: colour chip + PLAYER N, status badge on the right.
	var hy := 52.0
	var chip := UiStyle.panel(col if joined else Color(col, 0.45), 6, 0)
	draw_style_box(chip, Rect2(Vector2(36, hy - 16), Vector2(32, 32)))
	UiStyle.draw_text(self, Vector2(84, hy), UiStyle.player_name(player).to_upper(), UiStyle.Role.CAPTION,
			UiStyle.TEXT if joined else UiStyle.TEXT_FAINT, 0, 28)
	if readied:
		var label := "READY"
		var f := UiStyle.font(UiStyle.Role.CAPTION)
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 76.0
		var pill := Rect2(Vector2(size.x - 32 - w, hy - 22), Vector2(w, 44))
		draw_style_box(UiStyle.panel(col, 22, 0), pill)
		var tc := pill.position + Vector2(30, 22)
		draw_polyline(PackedVector2Array([tc + Vector2(-9, 0), tc + Vector2(-3, 7), tc + Vector2(9, -7)]),
				Color.WHITE, 4.5, true)
		UiStyle.draw_text(self, Vector2(pill.position.x + 48, hy), label, UiStyle.Role.CAPTION, Color.WHITE, 0, 24)
	elif joined:
		UiStyle.draw_text(self, Vector2(size.x - 36, hy), "Joined", UiStyle.Role.HINT, UiStyle.TEXT_DIM, 2)
	draw_line(Vector2(28, 100), Vector2(size.x - 28, 100), Color(UiStyle.LINE, 0.7 * maxf(fill_alpha, 0.5)), 2.0)
	# Footer: what to do next.
	var fy := size.y - 72.0
	if not joined:
		var a := 0.7 + 0.3 * (0.5 + 0.5 * sin(_t * 2.6))
		UiStyle.draw_rich(self, Vector2(size.x * 0.5, fy), "Press [a] to join", UiStyle.Role.BODY,
				Color(UiStyle.TEXT, a), 1, 34)
	elif not readied:
		UiStyle.draw_rich(self, Vector2(size.x * 0.5, fy), "Press [a] to ready up", UiStyle.Role.BODY,
				UiStyle.TEXT, 1, 34)
	elif hold > 0.0:
		UiStyle.draw_text(self, Vector2(size.x * 0.5, fy - 14), "Starting solo", UiStyle.Role.BODY, UiStyle.TEXT, 1, 32)
		var bar := Rect2(Vector2(56, fy + 24), Vector2(size.x - 112, 10))
		draw_style_box(UiStyle.panel(Color(UiStyle.LINE, 1.0), 5, 0), bar)
		draw_style_box(UiStyle.panel(col, 5, 0), Rect2(bar.position, Vector2(maxf(bar.size.x * hold, 10), bar.size.y)))
	else:
		UiStyle.draw_rich(self, Vector2(size.x * 0.5, fy), "[b] Not ready", UiStyle.Role.HINT, UiStyle.TEXT_DIM, 1)
