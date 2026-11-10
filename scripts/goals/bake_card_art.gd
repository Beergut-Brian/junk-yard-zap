## Bakes CardArt pictures to assets/sprites/goals/<id>.png (512 px, transparent), plus a contact sheet
## of every card at the HUD corner size to check they read without words. Needs a renderer:
##   godot-render --path . res://scripts/goals/bake_card_art.tscn -- [--sheet=<png>]
## then `godot --headless --path . --import`.
extends Node

const OUT := "res://assets/sprites/goals/"
const PX := 512
const HUD := 220

var _id: StringName   # members, not locals: a lambda captures locals by value
var _band := 1


func _ready() -> void:
	_bake.call_deferred()


func _bake() -> void:
	var guns := {}
	for g in Zapper.load_guns():
		guns[g.id] = g
		guns[g.effect_id()] = g
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var vp := SubViewport.new()
	vp.size = Vector2i(PX, PX)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var face := Control.new()
	face.size = Vector2(PX, PX)
	vp.add_child(face)
	face.draw.connect(func() -> void: CardArt.draw(face, _id, _band, Rect2(Vector2.ZERO, Vector2(PX, PX)), guns))
	for card in CardArt.CARDS:
		_id = card
		_band = int(String(card).substr(1, 1))
		face.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT.path_join("%s.png" % card)))
		print("baked ", card)
	# The contact sheet: every card in its frame at HUD size, on the yard's sky.
	var sheet_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sheet="):
			sheet_path = a.trim_prefix("--sheet=")
	if sheet_path != "":
		var cols := 5
		var rows := ceili(CardArt.CARDS.size() / float(cols))
		var sv := SubViewport.new()
		sv.size = Vector2i(cols * (HUD + 20) + 20, rows * (HUD + 20) + 20)
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		var c := Control.new()
		c.size = Vector2(sv.size)
		sv.add_child(c)
		var texes := {}
		for card in CardArt.CARDS:
			texes[card] = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(OUT.path_join("%s.png" % card))))
		c.draw.connect(func() -> void:
			c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.55, 0.75, 0.6))
			for i in CardArt.CARDS.size():
				var g := GoalData.new()
				g.picture = texes[CardArt.CARDS[i]]
				Pictos.card(c, g, Rect2(Vector2(20 + (i % cols) * (HUD + 20), 20 + (i / cols) * (HUD + 20)), Vector2(HUD, HUD)), guns))
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		sv.get_texture().get_image().save_png(sheet_path)
		print("sheet ", sheet_path)
	get_tree().quit()
