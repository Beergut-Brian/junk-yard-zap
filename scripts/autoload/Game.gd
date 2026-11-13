## Session state machine. Autoload: Game.
## LOBBY (start screen / main menu) -> PLAYING <-> PAUSED, ROUND_END between rounds.
## CLI (after --): --demo skips the lobby and plays with two virtual players.
extends Node

## TITLE is the old name of LOBBY, kept so games written against it still compile.
enum State { LOBBY, PLAYING, PAUSED, ROUND_END, TITLE = 0 }

signal state_changed(from: State, to: State)
signal round_started(round_index: int)
signal round_ended(round_index: int, result: Dictionary)
signal lobby_ready(players: Array)
signal back_to_lobby()
signal quit_requested()

var state: State = State.LOBBY
var round_index: int = 0
var demo := false
## Tests turn this off so quit() does everything but exit.
var quit_exits := true
## PF-6: how long the engine gets to shut down after quit() before the exit watchdog ends the process.
## A clean shutdown takes 1-3.5 s on the software renderer and well under that on a real GPU.
const EXIT_GRACE_MS := 6000
## The exit watchdog's thread, kept so it outlives this node while the engine shuts down.
static var _exit_watch: Thread


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	demo = OS.get_cmdline_user_args().has("--demo")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			pause()
		elif state == State.PAUSED:
			resume()
	elif event.is_action_pressed("restart") and state in [State.PLAYING, State.ROUND_END]:
		restart()


func start_round() -> void:
	round_index += 1
	get_tree().paused = false
	_set_state(State.PLAYING)
	Audio.play("round_start")
	round_started.emit(round_index)


func end_round(result: Dictionary = {}) -> void:
	_set_state(State.ROUND_END)
	Audio.play("round_end")
	Save.flush()
	round_ended.emit(round_index, result)


func pause() -> void:
	get_tree().paused = true
	Audio.play("pause")
	_set_state(State.PAUSED)


func resume() -> void:
	get_tree().paused = false
	Audio.play("pause")
	_set_state(State.PLAYING)


func restart() -> void:
	get_tree().paused = false
	Audio.play("ui_confirm")
	start_round()


## Back to the start screen: the game clears its level on back_to_lobby.
func to_lobby() -> void:
	get_tree().paused = false
	Save.flush()
	round_index = 0
	_set_state(State.LOBBY)
	back_to_lobby.emit()


## The lobby countdown finished.
func finish_lobby(players: Array) -> void:
	lobby_ready.emit(players)
	start_round()


## Clean exit, code 0 for the launcher, which resumes when the process ends.
## PF-6: the save is written first, then an exit watchdog is armed, then the tree quits. If the engine's
## own shutdown never ends (seen on the software Vulkan renderer when the window closes seconds after
## launch: the main thread waits forever in WorkerThreadPool::exit_languages_threads()), the watchdog
## ends the process after EXIT_GRACE_MS so the launcher isn't left waiting. On a clean shutdown the
## process is gone long before the watchdog wakes.
func quit(code: int = 0) -> void:
	quit_requested.emit()
	Save.flush()
	if quit_exits:
		arm_exit_watchdog(EXIT_GRACE_MS)
		get_tree().quit(code)


## Starts the exit watchdog: a plain Thread (not a WorkerThreadPool task, so the engine's shutdown never
## waits for it) that sleeps natively for `grace_ms`, then calls `on_overdue` (default: end this
## process). Returns the thread. Safe to call once per quit; a second call keeps the first watchdog.
static func arm_exit_watchdog(grace_ms: int, on_overdue := Callable()) -> Thread:
	if _exit_watch != null and _exit_watch.is_started() and on_overdue.is_null():
		return _exit_watch
	var t := Thread.new()
	t.start(_exit_watchdog.bind(grace_ms, on_overdue, OS.get_process_id()))
	if on_overdue.is_null():
		_exit_watch = t
	return t


static func _exit_watchdog(grace_ms: int, on_overdue: Callable, pid: int) -> void:
	OS.delay_msec(grace_ms)   # one native sleep: a clean exit ends the process while we are in here
	if on_overdue.is_valid():
		on_overdue.call()
		return
	printerr("Game: shutdown still running %d ms after quit(); ending the process (PF-6)" % grace_ms)
	OS.kill(pid)


func _set_state(to: State) -> void:
	if to == state:
		return
	var from := state
	state = to
	state_changed.emit(from, to)
