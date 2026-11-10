## Boot scene: lobby (start screen and main menu), drop-in players, round loop, pause menu.
## Replace the Arena node with this game's level scene; keep the node names other lanes use.
## A pad that joins mid-game waits on its spawn (see-through) and plays from the next round.
extends Node2D

@onready var spawns: Node2D = $Arena/Spawns
@onready var players_root: Node2D = $Arena/Players

const PLAYER_SCENE := preload("res://scenes/players/player.tscn")
var _players := {}


func _ready() -> void:
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	Game.lobby_ready.connect(_on_lobby_ready)
	Game.back_to_lobby.connect(_clear_players)
	Game.round_started.connect(_on_round_started)
	if Game.demo:
		(func() -> void:
			Players.join_virtual(Players.P1)
			Players.join_virtual(Players.P2)
			Game.start_round()).call_deferred()
	elif Game.state != Game.State.LOBBY:
		Game.to_lobby()


func _on_lobby_ready(players: Array) -> void:
	for p in players:
		_spawn(p)


func _on_round_started(_round: int) -> void:
	for p in Players.active_players():
		_spawn(p)
		_players[p].waiting = false


func _on_player_joined(player: int, _device: int) -> void:
	if Game.state != Game.State.LOBBY:
		_spawn(player, true)


func _on_player_left(player: int) -> void:
	if _players.has(player):
		_players[player].queue_free()
		_players.erase(player)


func _clear_players() -> void:
	for p in _players.values():
		p.queue_free()
	_players.clear()


func _spawn(player: int, waiting := false) -> void:
	if _players.has(player):
		return
	var p := PLAYER_SCENE.instantiate()
	p.player = player
	p.waiting = waiting
	p.global_position = spawns.get_child(player).global_position
	players_root.add_child(p)
	_players[player] = p
