## The built-in benchmark: `-- --bench` (main.gd adds it; Game treats --bench as a demo). Both demo bots
## play the whole yard with the soak's stress on (scripts/tools/soak.gd: an effect zapped every 0.4 s, glue
## made and undone), seeded, so every run walks the same route. After a WARMUP (shaders compile, the yard
## settles; not counted) it times `duration` seconds of real wall clock (default 60, `--bench-seconds=<s>`):
##   0-1/3  the shared camera following both players (what the kids see),
##   1/3-2/3 the "yard wide" shot (every object on screen: the worst case),
##   2/3-end following again.
## Every REPORT_EVERY seconds it prints one "bench:" line (avg fps, 1%-low fps, mean and worst frame ms) and at
## the end one summary line, then quits (code 0):
##   BENCH avg=58.9 low1=44.1 frame_ms=16.98 worst_ms=31.2 frames=3534 seconds=60.0 tier=low cap=60 vsync=on hz=60 adapter="..."
## avg = frames / seconds; low1 = 1000 / the mean of the slowest 1% of frame times. Real wall clock: on a
## software renderer the numbers are meaningless, on the TV box they are the answer.
class_name BenchProbe
extends Node

const WARMUP := 3.0
const REPORT_EVERY := 5.0
const ARG := "--bench-seconds="

var duration := 60.0
var warmup := WARMUP
var report_every := REPORT_EVERY
## The camera to drive through the route (main.gd's CameraRig); null = leave the camera alone.
var camera: Node
## Tests set this off so the probe finishes without ending the process.
var quit_when_done := true
## Every line printed, in order (tests read it).
var lines := PackedStringArray()
var done := false
signal finished(summary: String)

var _last := 0
var _clock := 0.0          # real seconds since the probe started
var _all := PackedInt64Array()      # every counted frame's usec
var _window := PackedInt64Array()   # this report window's frames
var _next_report := 0.0
var _sum := 0               # usec counted so far


static func seconds_from_args(args: PackedStringArray) -> float:
	for a in args:
		if a.begins_with(ARG):
			return maxf(float(a.trim_prefix(ARG)), 1.0)
	return 60.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_next_report = report_every
	_last = Time.get_ticks_usec()
	_say("bench: start tier=%s warmup=%.0fs seconds=%.0f route=follow,wide,follow cap=%d adapter=\"%s\"" % [
			Graphics.tier, warmup, duration, Engine.max_fps, RenderingServer.get_video_adapter_name()])


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := now - _last
	_last = now
	if done:
		return
	_clock += dt / 1000000.0
	if _clock < warmup:
		return
	feed(dt)


## Counts one frame of `usec` microseconds (the bench's own clock is the sum of what it is fed).
func feed(usec: int) -> void:
	if done:
		return
	_all.append(usec)
	_sum += usec
	_window.append(usec)
	var t := elapsed()
	_route(t)
	if t >= _next_report:
		_next_report += report_every
		var st := stats(_window)
		_say("bench: t=%5.1f seg=%s fps=%.1f low1=%.1f frame_ms=%.2f worst_ms=%.1f" % [
				t, segment(t), st.avg, st.low1, st.frame_ms, st.worst_ms])
		_window = PackedInt64Array()
	if t >= duration:
		finish()


## Counted seconds so far.
func elapsed() -> float:
	return _sum / 1000000.0


func segment(t: float) -> String:
	return "wide" if t >= duration / 3.0 and t < duration * 2.0 / 3.0 else "follow"


func _route(t: float) -> void:
	if camera and "overview" in camera:
		camera.set("overview", segment(t) == "wide")


## {avg, low1, frame_ms, worst_ms, frames, seconds} over frame times in usec.
static func stats(frames: PackedInt64Array) -> Dictionary:
	var n := frames.size()
	if n == 0:
		return {"avg": 0.0, "low1": 0.0, "frame_ms": 0.0, "worst_ms": 0.0, "frames": 0, "seconds": 0.0}
	var total := 0
	for u in frames:
		total += u
	var sorted := frames.duplicate()
	sorted.sort()
	var k := maxi(1, ceili(n * 0.01))
	var slow := 0
	for i in k:
		slow += sorted[n - 1 - i]
	var secs := total / 1000000.0
	return {"avg": n / maxf(secs, 0.000001), "low1": 1000000.0 / maxf(float(slow) / k, 1.0),
			"frame_ms": total / 1000.0 / n, "worst_ms": sorted[n - 1] / 1000.0, "frames": n, "seconds": secs}


func summary() -> String:
	var st := stats(_all)
	return "BENCH avg=%.1f low1=%.1f frame_ms=%.2f worst_ms=%.1f frames=%d seconds=%.1f tier=%s cap=%d %s adapter=\"%s\"" % [
			st.avg, st.low1, st.frame_ms, st.worst_ms, st.frames, st.seconds, Graphics.tier, Engine.max_fps,
			display(), RenderingServer.get_video_adapter_name()]


## jyz-hitch-5: the present mode and the screen's refresh rate, so a BENCH line says whether its frame times
## can be rounded up to whole refreshes (project.godot asks for vsync, yet the 1060 box averaged 72 fps).
## "vsync=off|on|adaptive|mailbox hz=<refresh, -1 unknown>".
static func display() -> String:
	var modes := {DisplayServer.VSYNC_DISABLED: "off", DisplayServer.VSYNC_ENABLED: "on",
			DisplayServer.VSYNC_ADAPTIVE: "adaptive", DisplayServer.VSYNC_MAILBOX: "mailbox"}
	var hz := DisplayServer.screen_get_refresh_rate() if DisplayServer.get_name() != "headless" else -1.0
	return "vsync=%s hz=%.0f" % [modes.get(DisplayServer.window_get_vsync_mode(), "?"), hz]


func finish() -> void:
	if done:
		return
	done = true
	if camera and "overview" in camera:
		camera.set("overview", false)
	var line := summary()
	_say(line)
	finished.emit(line)
	if quit_when_done:
		Game.quit(0)


func _say(line: String) -> void:
	lines.append(line)
	print(line)
