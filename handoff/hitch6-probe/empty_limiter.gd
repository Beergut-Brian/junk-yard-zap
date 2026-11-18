extends Node
## Baseline: an empty scene at --max-fps 60. Frame times between _process calls for 30 s, bench stats.
var last := 0
var f := PackedInt64Array()
var t0 := 0
func _ready() -> void:
	last = Time.get_ticks_usec(); t0 = last
func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	f.append(now - last); last = now
	if now - t0 > 33000000:
		f = f.slice(180)
		var st := BenchProbe.stats(f)
		var over := 0
		for u in f:
			if u > 25000: over += 1
		print("EMPTY avg=%.1f low1=%.1f worst_ms=%.1f frames=%d over25=%d" % [st.avg, st.low1, st.worst_ms, st.frames, over])
		get_tree().quit()
