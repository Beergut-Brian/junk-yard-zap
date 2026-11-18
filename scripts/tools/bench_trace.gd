## jyz-hitch-6: where a slow bench frame's time goes. `-- --bench --bench-trace[=<path>]` adds this to the bench
## (main.gd). It splits every main-loop iteration with the engine's own signals, in the order the loop runs them:
##   physics  first physics_frame -> process_frame     (the iteration's physics steps: Jolt + _physics_process)
##   process  process_frame -> frame_pre_draw          (every _process, tweens, the deferred-call flush)
##   draw     frame_pre_draw -> frame_post_draw        (render CPU on the main thread, incl. waits on the GPU
##                                                       and the swapchain: the thread model is Safe)
##   idle     frame_post_draw -> next iteration        (the 60 fps limiter's sleep, window events)
## plus steps (physics steps in the iteration) and gpu (the viewport's measured GPU ms, a frame or two late).
## One CSV row per counted frame goes to <path> (default user://bench_trace.csv). At the end it prints one line:
##   BENCH-TRACE slow=<frames over SLOW_MS>/<frames> slow_med: frame=.. physics=.. steps=.. process=.. draw=..
##     idle=.. gpu=.. all_med: ... cause=<physics|process|draw|idle|mixed> ("<part>(all)" when every frame is slow)
## A slow frame whose time is mostly idle did no extra work: the limiter or the present held it (a pacing
## matter: the cap or the present mode, a producer call), not the game.
class_name BenchTrace
extends Node

const ARG := "--bench-trace"
const SLOW_MS := 25.0
const COLS := ["t", "seg", "frame_ms", "physics_ms", "steps", "process_ms", "draw_ms", "idle_ms", "gpu_ms"]

var bench: BenchProbe
var path := "user://bench_trace.csv"
## Every counted frame: [t, seg, frame, physics, steps, process, draw, idle, gpu] (ms; tests read it).
var rows: Array = []
var summary := ""

var _start := 0        # usec at the first physics_frame (or process_frame) of the iteration
var _proc := 0
var _pre := 0
var _post := 0
var _proc_end := 0     # this node's own _process (it runs last: process_priority), the fallback when no draw
var _steps := 0
var _vp := RID()


## The path from `--bench-trace[=<path>]`, "" when the flag is absent.
static func path_from_args(args: PackedStringArray) -> String:
	for a in args:
		if a == ARG:
			return "user://bench_trace.csv"
		if a.begins_with(ARG + "="):
			return a.trim_prefix(ARG + "=")
	return ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1 << 20   # after every other _process
	get_tree().physics_frame.connect(_on_physics)
	get_tree().process_frame.connect(_on_process)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	if bench:
		bench.finished.connect(func(_s: String) -> void: finish())


## A physics step or a process after this iteration's process starts the next iteration.
func _on_physics() -> void:
	var now := Time.get_ticks_usec()
	if _start == 0 or _proc > 0:
		_begin(now)
	_steps += 1


func _on_process() -> void:
	var now := Time.get_ticks_usec()
	if _start == 0 or _proc > 0:   # an iteration with no physics step
		_begin(now)
	_proc = now


func _process(_delta: float) -> void:
	_proc_end = Time.get_ticks_usec()


func _on_pre_draw() -> void:
	_pre = Time.get_ticks_usec()


func _on_post_draw() -> void:
	_post = Time.get_ticks_usec()


## A new iteration starts at `now`: close the previous one (its idle runs up to here).
func _begin(now: int) -> void:
	if _start > 0 and _proc > 0:
		var pre := _pre if _pre > _proc else maxi(_proc_end, _proc)   # headless: no draw signals
		var post := _post if _post >= pre else pre
		record((now - _start) / 1000.0, (_proc - _start) / 1000.0, _steps, (pre - _proc) / 1000.0,
				(post - pre) / 1000.0, (now - post) / 1000.0)
	_start = now
	_steps = 0
	_proc = 0
	_pre = 0
	_post = 0
	_proc_end = 0


## One finished frame (ms). Counted only while the bench counts (after its warmup, before it's done).
func record(frame: float, physics: float, steps: int, process: float, draw: float, idle: float) -> void:
	if bench and (bench.done or bench._clock < bench.warmup):
		return
	var t := bench.elapsed() if bench else 0.0
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_vp) if _vp.is_valid() else 0.0
	rows.append([t, bench.segment(t) if bench else "", frame, physics, steps, process, draw, idle, gpu])


static func _median(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return float(s[s.size() / 2])


## Medians of each column over `which` rows.
static func medians(which: Array) -> Dictionary:
	var out := {}
	for c in range(2, COLS.size()):
		out[COLS[c]] = _median(which.map(func(r: Array) -> float: return float(r[c])))
	return out


## Which part grew in the slow frames: the column whose median rose the most over the all-frames median,
## if it covers at least half of the slow frame's extra time; else "mixed".
static func cause(slow: Dictionary, all: Dictionary) -> String:
	var extra := float(slow.frame_ms) - float(all.frame_ms)
	if extra <= 0.0:   # every frame is slow (a software renderer): name the biggest part
		var big := "none"
		var most := 0.0
		for k in ["physics_ms", "process_ms", "draw_ms", "idle_ms"]:
			if float(slow[k]) > most:
				most = float(slow[k])
				big = k.trim_suffix("_ms")
		return big + "(all)"
	var best := "mixed"
	var grew := 0.0
	for k in ["physics_ms", "process_ms", "draw_ms", "idle_ms"]:
		var g := float(slow[k]) - float(all[k])
		if g > grew:
			grew = g
			best = k.trim_suffix("_ms")
	return best if grew >= extra * 0.5 else "mixed"


static func line(rows_in: Array, slow_ms := SLOW_MS) -> String:
	var slow := rows_in.filter(func(r: Array) -> bool: return float(r[2]) > slow_ms)
	var a := medians(rows_in)
	var s := medians(slow)
	var fmt := func(d: Dictionary) -> String:
		return "frame=%.1f physics=%.1f steps=%.0f process=%.1f draw=%.1f idle=%.1f gpu=%.1f" % [
				d.frame_ms, d.physics_ms, d.steps, d.process_ms, d.draw_ms, d.idle_ms, d.gpu_ms]
	return "BENCH-TRACE slow=%d/%d over=%.0fms slow_med: %s all_med: %s cause=%s" % [
			slow.size(), rows_in.size(), slow_ms, fmt.call(s), fmt.call(a),
			cause(s, a) if not slow.is_empty() else "none"]


func finish() -> void:
	summary = line(rows)
	print(summary)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("BENCH-TRACE: could not write %s" % path)
		return
	f.store_line(",".join(COLS))
	for r: Array in rows:
		f.store_line("%.3f,%s,%.3f,%.3f,%d,%.3f,%.3f,%.3f,%.3f" % r)
	f.close()
	print("BENCH-TRACE: %d frames -> %s" % [rows.size(), ProjectSettings.globalize_path(path)])
