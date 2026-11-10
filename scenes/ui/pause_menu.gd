## Pause menu over the blurred, dimmed game: Resume, Restart (back to the lobby), Settings,
## Back to Open Jar (asks "Leave the game?" first). Shows who paused, in their colour.
## Either pad moves the cursor, A presses, B resumes or backs out of Settings / the question.
## Start is Game's (it resumes from anywhere). Shown while Game.state == PAUSED.
extends Control

enum Choice { RESUME, RESTART, SETTINGS, DOOR }

var focus := Choice.RESUME
## The player whose Start opened the menu (P1 for the keyboard).
var paused_by := Players.P1:
	set(v):
		paused_by = v
		if is_node_ready():
			_by.queue_redraw()

var _tw: Tween

@onready var _buttons: Array = [$Card/Buttons/Resume, $Card/Buttons/Restart, $Card/Buttons/Settings, $Card/Buttons/Door]
@onready var _card: Control = $Card
@onready var _by: Control = $Card/PausedBy
@onready var _settings: SettingsPanel = $Settings
@onready var _confirm: ConfirmDialog = $Confirm


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("openjar_pause_menu")
	Game.state_changed.connect(_on_state_changed)
	_confirm.chosen.connect(_on_confirm_chosen)
	_by.draw.connect(_draw_paused_by)
	_card.pivot_offset = _card.size * 0.5
	visible = Game.state == Game.State.PAUSED
	_set_focus(Choice.RESUME, false)


## Before Game sees the Start press: remember whose it was.
func _input(event: InputEvent) -> void:
	if Game.state != Game.State.PLAYING or not event.is_action_pressed("pause"):
		return
	if Players.solo:
		paused_by = Players.solo_focus
		return
	paused_by = Players.P1
	if event is InputEventJoypadButton:
		for p in [Players.P1, Players.P2]:
			if Players.device_of(p) == event.device:
				paused_by = p


func _process(_delta: float) -> void:
	if not visible or Game.state != Game.State.PAUSED:
		return
	var input := MenuInput.read()
	if _confirm.active:
		_confirm.handle(input)
	elif _settings.active:
		_settings.handle(input)
	else:
		if input.move.y != 0:
			move_focus(input.move.y)
		if input.a != -1:
			press()
		elif input.b != -1:
			back()


func move_focus(dir: int) -> void:
	_set_focus(MenuItem.step(_buttons, focus, dir) as Choice)


func press(choice: Choice = focus) -> void:
	_set_focus(choice, false)
	_buttons[choice].press()
	match choice:
		Choice.RESUME:
			Game.resume()
		Choice.RESTART:
			Audio.play("ui_confirm")
			Game.to_lobby()
		Choice.SETTINGS:
			_settings.open()
		Choice.DOOR:
			_confirm.open()


## B: out of the question or Settings, else resume.
func back() -> void:
	if _confirm.active:
		_confirm.choose(false)
	elif _settings.active:
		_settings.close()
	else:
		Audio.play("ui_back")
		Game.resume()


func in_submenu() -> bool:
	return _settings.active or _confirm.active


func _set_focus(to: Choice, sound := true) -> void:
	# Bumping the end still makes a sound: every move does something.
	if sound:
		Audio.play("ui_move")
	focus = to
	for i in _buttons.size():
		_buttons[i].focused = i == focus


func _on_confirm_chosen(leave: bool) -> void:
	if leave:
		Game.quit()


func _on_state_changed(_from: int, to: int) -> void:
	visible = to == Game.State.PAUSED
	_settings.dismiss()
	_confirm.dismiss()
	if not visible:
		return
	_set_focus(Choice.RESUME, false)
	if _tw:
		_tw.kill()
	_tw = create_tween().set_parallel()
	_tw.tween_property(self, "modulate:a", 1.0, 0.2).from(0.0)
	_tw.tween_property(_card, "scale", Vector2.ONE, 0.28).from(Vector2.ONE * 0.95) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw_paused_by() -> void:
	var col := UiStyle.player_color(paused_by)
	var text := "%s paused" % UiStyle.player_name(paused_by)
	var f := UiStyle.font(UiStyle.Role.BODY)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 34.0
	var c := _by.size * 0.5
	_by.draw_circle(Vector2(c.x - w * 0.5 + 10, c.y), 10.0, col, true, -1.0, true)
	UiStyle.draw_text(_by, Vector2(c.x - w * 0.5 + 34, c.y), text, UiStyle.Role.BODY, col.lightened(0.25), 0, 30)
