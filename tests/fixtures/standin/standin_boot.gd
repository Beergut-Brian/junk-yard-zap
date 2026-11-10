## Test-only boot: the game with tests/fixtures/roster_standin.json (Jeff, Chuck, the stand-in
## Sprocket) and a scratch picks file, then main.tscn. Pass --p1-char= / --p2-char= after "--".
extends Node


func _ready() -> void:
	Save.profile = "standin"
	Roster.data_path = "res://tests/fixtures/roster_standin.json"
	Roster.picks_path = "user://standin_players.json"
	Roster.reload()
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
