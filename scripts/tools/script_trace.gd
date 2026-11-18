## jyz-hitch-7: which scripts the bench's `process` time goes to. `-- --bench --bench-trace --bench-scripts`
## (main.gd). Off by default: without the flag nothing here exists, so normal play pays nothing.
##
## Every node that runs a `_process` (or an internal process: Timer, AnimationPlayer, CPUParticles3D, ...) is
## grouped by its script (or its native class). Each group gets its own process_priority, in the order of
## the original priorities, with a marker node just before it. So per frame:
##   own   marker j -> marker j+1: the group's own `_process` cost.
##   defer each marker also queues a deferred stamp. Deferred calls run in the order they were queued, so the
##         time between stamp j and stamp j+1 in the flush after _process is the deferred work group j
##         queued: its `queue_redraw()` (the whole redraw of a 2D item, its _draw included), set_deferred, ...
## Within one original priority, groups run one after another instead of in tree order: that is the only
## thing the flag changes, and only under the flag.
## At the end it prints the most expensive groups:
##   BENCH-SCRIPTS <key> n=<nodes> own=<mean ms> defer=<mean ms> sum_p99=<ms> max=<ms> slow=<mean ms in slow frames>
## plus the process time left over (outside the groups and their deferred calls) and per-call counters.
class_name ScriptTrace
extends Node

const ARG := "--bench-scripts"
const TOP := 12

var trace: BenchTrace
## groups[i] = {key, orig, prio, nodes}
var groups: Array = []
## frame (Engine.get_process_frames()) -> [own: PackedFloat32Array, defer: PackedFloat32Array, flush gap ms,
## flush end usec, after-flush ms (appended at frame_pre_draw)]
var frames := {}
var _index := {}           # "<orig priority>|<key>" -> group index
var _orig := {}            # instance id -> the node's original process_priority
var _markers: Array = []   # marker j runs just before the group in slot j; the last one after every group
var _stamps := PackedInt64Array()
var _dstamps := PackedInt64Array()
var _pending: Array = []
var _dirty := false
var _face0 := 0
var _hint0 := 0
var _hud0 := 0
var _card0 := 0
var _poses0 := 0


static func wanted(args: PackedStringArray) -> bool:
	return args.has(ARG)


func _ready() -> void:
	_face0 = ObjectFace.part_writes
	_hint0 = HintPanel.redraws
	_hud0 = Hud.redraws
	_card0 = Hud._CardLayer.redraws
	_poses0 = ObjectFace.poses
	get_tree().node_added.connect(_on_node_added)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	_scan(get_tree().root)
	_renumber()


## Puts every node's own priority back (a test that adds and frees the trace leaves the tree as it was).
func _exit_tree() -> void:
	get_tree().node_added.disconnect(_on_node_added)
	RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
	_restore(get_tree().root)


func _restore(n: Node) -> void:
	var id := n.get_instance_id()
	if _orig.has(id):
		n.process_priority = _orig[id]
	for c in n.get_children():
		_restore(c)


func _on_node_added(n: Node) -> void:
	if not (n is _Marker) and n != self:
		_pending.append(n)


## The first marker each frame: the nodes added since are ready now.
func _take_pending() -> void:
	if _pending.is_empty() and not _dirty:
		return
	for n in _pending:
		if is_instance_valid(n) and n.is_inside_tree():
			_add(n)
	_pending.clear()
	if _dirty:
		_renumber()


func _scan(n: Node) -> void:
	if not (n is _Marker) and n != self:
		_add(n)
	for c in n.get_children():
		_scan(c)


static func key_of(n: Node) -> String:
	var s: Script = n.get_script()
	if s and s.resource_path != "":
		return s.resource_path.get_file()
	if s:
		return "(inline %s)" % n.get_class()
	return "(native %s)" % n.get_class()


func _add(n: Node) -> void:
	if not (n.is_processing() or n.is_processing_internal()):
		return
	var id := n.get_instance_id()
	if _orig.has(id):
		return
	var orig := n.process_priority
	_orig[id] = orig
	var k := "%d|%s" % [orig, key_of(n)]
	var gi: int = _index.get(k, -1)
	if gi < 0:
		gi = groups.size()
		_index[k] = gi
		groups.append({"key": key_of(n), "orig": orig, "prio": 0, "nodes": 0})
		_dirty = true
	groups[gi].nodes += 1
	if not _dirty:
		n.process_priority = groups[gi].prio


## Group in slot i gets priority 2i+1 (slots ordered by the original priority), marker i gets 2i.
func _renumber() -> void:
	var order: Array = range(groups.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		if groups[a].orig != groups[b].orig:
			return groups[a].orig < groups[b].orig
		return groups[a].key < groups[b].key)
	for i in order.size():
		groups[order[i]].prio = 2 * i + 1
	while _markers.size() < groups.size() + 1:
		var m := _Marker.new()
		m.owner_trace = self
		m.process_mode = Node.PROCESS_MODE_ALWAYS
		_markers.append(m)
		add_child(m)
	for j in _markers.size():
		var m: _Marker = _markers[j]
		m.slot = j
		m.process_priority = 2 * j
		m.group = order[j] if j < order.size() else -1
	_stamps.resize(_markers.size())
	_dstamps.resize(_markers.size())
	_reapply(get_tree().root)
	_dirty = false


func _reapply(n: Node) -> void:
	var id := n.get_instance_id()
	if _orig.has(id):
		var gi: int = _index.get("%d|%s" % [_orig[id], key_of(n)], -1)
		if gi >= 0:
			n.process_priority = groups[gi].prio
	for c in n.get_children():
		_reapply(c)


func _stamp(slot: int) -> void:
	if slot == 0:
		_take_pending()
	_stamps[slot] = Time.get_ticks_usec()
	_dstamp.call_deferred(slot)


func _dstamp(slot: int) -> void:
	_dstamps[slot] = Time.get_ticks_usec()
	var last := _markers.size() - 1
	if slot != last:
		return
	var own := PackedFloat32Array()
	var defer := PackedFloat32Array()
	own.resize(groups.size())
	defer.resize(groups.size())
	for j in last:   # marker j runs just before group j, marker j+1 just after it
		var g: int = _markers[j].group
		if g >= 0 and g < own.size():
			own[g] = (_stamps[j + 1] - _stamps[j]) / 1000.0
			defer[g] = (_dstamps[j + 1] - _dstamps[j]) / 1000.0
	frames[Engine.get_process_frames()] = [own, defer, (_dstamps[0] - _stamps[last]) / 1000.0, _dstamps[last]]


func _on_pre_draw() -> void:
	var f: Variant = frames.get(Engine.get_process_frames())
	if f != null and f.size() == 4:
		f.append((Time.get_ticks_usec() - int(f[3])) / 1000.0)


## The counted frames' entries [all, slow] (joined with BenchTrace's rows on the process frame).
func _counted() -> Array:
	var all: Array = []
	var slow: Array = []
	if trace == null:
		return [frames.values(), []]
	for r: Array in trace.rows:
		if r.size() > 9 and frames.has(int(r[9])):
			all.append(frames[int(r[9])])
			if float(r[2]) > BenchTrace.SLOW_MS:
				slow.append(frames[int(r[9])])
	return [all, slow]


## {key, nodes, own, defer, sum_p99, max, slow} per group, the most expensive (own + defer) first.
func table() -> Array:
	var c := _counted()
	var counted: Array = c[0]
	var slow: Array = c[1]
	var out: Array = []
	for gi in groups.size():
		var sums: Array = []
		var own := 0.0
		var defer := 0.0
		for f: Array in counted:
			var o: float = f[0][gi] if gi < f[0].size() else 0.0
			var d: float = f[1][gi] if gi < f[1].size() else 0.0
			own += o
			defer += d
			sums.append(o + d)
		var sv := 0.0
		for f: Array in slow:
			sv += (f[0][gi] if gi < f[0].size() else 0.0) + (f[1][gi] if gi < f[1].size() else 0.0)
		sums.sort()
		var n := sums.size()
		out.append({"key": groups[gi].key, "nodes": groups[gi].nodes, "own": own / maxf(n, 1),
				"defer": defer / maxf(n, 1), "sum_p99": sums[mini(n - 1, int(n * 0.99))] if n else 0.0,
				"max": sums[n - 1] if n else 0.0, "slow": sv / maxf(slow.size(), 1)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.own + a.defer > b.own + b.defer)
	return out


## Mean ms per counted frame: [the groups' own + defer, the flush's start gap, after the flush (transform
## notifications, freed nodes, timers, tweens, navigation, the RenderingServer sync; 0 headless)].
func leftover() -> Array:
	var out := [0.0, 0.0, 0.0]
	var counted: Array = _counted()[0]
	for f: Array in counted:
		for x in f[0]:
			out[0] += x
		for x in f[1]:
			out[0] += x
		out[1] += float(f[2])
		out[2] += float(f[4]) if f.size() > 4 else 0.0
	for i in 3:
		out[i] /= maxf(counted.size(), 1)
	return out


func lines() -> PackedStringArray:
	var out := PackedStringArray()
	var n := maxf(frames.size(), 1)
	out.append("BENCH-SCRIPTS counters per_frame: face_poses=%.1f face_part_writes=%.1f hud_redraws=%.2f card_redraws=%.2f hint_redraws=%.2f" % [
			(ObjectFace.poses - _poses0) / n, (ObjectFace.part_writes - _face0) / n, (Hud.redraws - _hud0) / n,
			(Hud._CardLayer.redraws - _card0) / n, (HintPanel.redraws - _hint0) / n])
	out.append("BENCH-SCRIPTS groups=%.3f flush_gap=%.3f after_flush=%.3f (ms per frame, means)" % leftover())
	var t := table()
	for i in mini(TOP, t.size()):
		var d: Dictionary = t[i]
		out.append("BENCH-SCRIPTS %s n=%d own=%.3f defer=%.3f sum_p99=%.3f max=%.2f slow=%.3f" % [
				d.key, d.nodes, d.own, d.defer, d.sum_p99, d.max, d.slow])
	return out


func finish() -> void:
	for l in lines():
		print(l)


class _Marker extends Node:
	var owner_trace: ScriptTrace
	var slot := 0
	var group := -1

	func _process(_d: float) -> void:
		owner_trace._stamp(slot)
