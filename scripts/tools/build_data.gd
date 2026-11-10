## Writes the grey-box content: data/objects/*.tres, data/guns/*.tres, data/goals/*.tres and
## data/yard_layout.tres. Run once after changing the tables below:
##   godot --headless --path . -s scripts/tools/build_data.gd
## The Content lane owns data/ after this and edits the .tres files directly (then this tool retires).
extends SceneTree

const W := Color(0.96, 0.96, 0.93)
const INK := Color(0.12, 0.1, 0.1)

# id: [shape, size, mass, colour, bounce, face_at, face_size, parts]
var OBJECTS := {
	&"ball": [ObjectData.Shape.SPHERE, Vector3(0.9, 0.9, 0.9), 0.4, Color(0.95, 0.55, 0.3), 0.55, Vector3(0.0, 0.1, 0.5), 0.3, []],
	&"crate": [ObjectData.Shape.BOX, Vector3(1, 1, 1), 1.0, Color(0.8, 0.6, 0.35), 0.1, Vector3(0.0, 0.1, 0.5), 0.4, []],
	&"tire": [ObjectData.Shape.CYLINDER, Vector3(1.0, 1.0, 0.45), 0.6, Color(0.2, 0.2, 0.22), 0.45, Vector3(0.0, 0.0, 0.5), 0.3,
		[{"shape": "cylinder", "size": Vector3(0.45, 0.45, 0.47), "at": Vector3.ZERO, "color": Color(0.6, 0.6, 0.62)}]],
	&"wheelbarrow": [ObjectData.Shape.TUB, Vector3(1.4, 0.55, 0.8), 2.0, Color(0.35, 0.5, 0.65), 0.1, Vector3(0.0, 0.0, 0.5), 0.3,
		[{"shape": "cylinder", "size": Vector3(0.45, 0.45, 0.15), "at": Vector3(0.6, -0.4, 0), "color": INK}]],
	&"car": [ObjectData.Shape.BOX, Vector3(2.6, 1.0, 1.4), 12.0, Color(0.35, 0.5, 0.75), 0.1, Vector3(0.38, 0.05, 0.5), 0.45,
		[{"shape": "box", "size": Vector3(1.4, 0.6, 1.2), "at": Vector3(-0.2, 0.75, 0), "color": Color(0.7, 0.85, 0.95)},
		{"shape": "cylinder", "size": Vector3(0.6, 0.6, 1.5), "at": Vector3(-0.8, -0.5, 0), "color": INK},
		{"shape": "cylinder", "size": Vector3(0.6, 0.6, 1.5), "at": Vector3(0.8, -0.5, 0), "color": INK}]],
	&"bathtub": [ObjectData.Shape.TUB, Vector3(2.0, 0.85, 1.1), 4.0, Color(0.9, 0.93, 1.0), 0.15, Vector3(0.3, -0.15, 0.5), 0.35,
		[{"shape": "box", "size": Vector3(0.18, 0.22, 0.9), "at": Vector3(-0.75, -0.52, 0), "color": Color(0.85, 0.75, 0.3)},
		{"shape": "box", "size": Vector3(0.18, 0.22, 0.9), "at": Vector3(0.75, -0.52, 0), "color": Color(0.85, 0.75, 0.3)}]],
	&"fridge": [ObjectData.Shape.BOX, Vector3(0.9, 1.8, 0.8), 6.0, Color(0.92, 0.92, 0.88), 0.1, Vector3(0.0, 0.2, 0.5), 0.4,
		[{"shape": "box", "size": Vector3(0.06, 0.4, 0.06), "at": Vector3(0.35, 0.45, 0.42), "color": Color(0.5, 0.5, 0.5)}]],
	&"plank": [ObjectData.Shape.BOX, Vector3(4.0, 0.25, 0.8), 1.0, Color(0.72, 0.6, 0.42), 0.1, Vector3(0.38, 0.0, 0.5), 0.2, []],
	&"duck": [ObjectData.Shape.SPHERE, Vector3(0.55, 0.55, 0.55), 0.05, Color(1.0, 0.85, 0.2), 0.3, Vector3(0.25, 0.35, 0.5), 0.18,
		[{"shape": "sphere", "size": Vector3(0.32, 0.32, 0.32), "at": Vector3(0.15, 0.32, 0), "color": Color(1.0, 0.85, 0.2)},
		{"shape": "box", "size": Vector3(0.16, 0.06, 0.14), "at": Vector3(0.36, 0.3, 0), "color": Color(1.0, 0.55, 0.1)}]],
	&"log": [ObjectData.Shape.BOX, Vector3(2.2, 0.5, 0.5), 0.5, Color(0.5, 0.35, 0.22), 0.1, Vector3(0.38, 0.0, 0.5), 0.25, []],
	&"cow": [ObjectData.Shape.BOX, Vector3(1.9, 1.0, 0.8), 6.0, W, 0.1, Vector3(0.62, 0.4, 0.5), 0.35,
		[{"shape": "box", "size": Vector3(0.6, 0.6, 0.7), "at": Vector3(1.1, 0.35, 0), "color": W},
		{"shape": "box", "size": Vector3(0.5, 0.4, 0.82), "at": Vector3(-0.3, 0.1, 0), "color": INK},
		{"shape": "box", "size": Vector3(0.2, 0.5, 0.2), "at": Vector3(-0.7, -0.7, 0.25), "color": W},
		{"shape": "box", "size": Vector3(0.2, 0.5, 0.2), "at": Vector3(0.7, -0.7, 0.25), "color": W},
		{"shape": "box", "size": Vector3(0.2, 0.5, 0.2), "at": Vector3(-0.7, -0.7, -0.25), "color": W},
		{"shape": "box", "size": Vector3(0.2, 0.5, 0.2), "at": Vector3(0.7, -0.7, -0.25), "color": W},
		{"shape": "box", "size": Vector3(0.14, 0.25, 0.14), "at": Vector3(1.1, 0.75, 0.2), "color": Color(0.85, 0.8, 0.6)},
		{"shape": "box", "size": Vector3(0.14, 0.25, 0.14), "at": Vector3(1.1, 0.75, -0.2), "color": Color(0.85, 0.8, 0.6)}]],
	&"chicken": [ObjectData.Shape.BOX, Vector3(0.45, 0.45, 0.35), 0.2, Color(1, 1, 0.97), 0.2, Vector3(0.4, 0.55, 0.5), 0.16,
		[{"shape": "box", "size": Vector3(0.25, 0.28, 0.25), "at": Vector3(0.18, 0.3, 0), "color": Color(1, 1, 0.97)},
		{"shape": "box", "size": Vector3(0.1, 0.05, 0.08), "at": Vector3(0.34, 0.3, 0), "color": Color(1.0, 0.6, 0.1)},
		{"shape": "box", "size": Vector3(0.08, 0.1, 0.06), "at": Vector3(0.18, 0.48, 0), "color": Color(1.0, 0.45, 0.2)}]],
	&"hay": [ObjectData.Shape.BOX, Vector3(1.2, 0.8, 0.8), 1.0, Color(0.9, 0.78, 0.4), 0.1, Vector3(0.0, 0.1, 0.5), 0.35, []],
	&"cannonball": [ObjectData.Shape.SPHERE, Vector3(0.6, 0.6, 0.6), 3.0, Color(0.25, 0.25, 0.3), 0.1, Vector3(0.0, 0.1, 0.5), 0.22, []],
	&"piano": [ObjectData.Shape.BOX, Vector3(1.8, 1.3, 0.7), 10.0, Color(0.2, 0.15, 0.15), 0.1, Vector3(0.0, 0.25, 0.5), 0.4,
		[{"shape": "box", "size": Vector3(1.6, 0.12, 0.3), "at": Vector3(0, -0.05, 0.45), "color": W}]],
}

# key, object id, x, y, roll
var LAYOUT := [
	[&"ball", &"ball", -37.0, 0.45, 0.0], [&"crate", &"crate", -31.0, 0.5, 0.0], [&"crate_2", &"crate", -30.8, 1.5, 0.0],
	[&"tire", &"tire", -36.0, 0.5, 0.0], [&"wheelbarrow", &"wheelbarrow", -40.5, 0.6, 0.0],
	[&"car", &"car", -26.5, 0.85, 0.0], [&"bathtub", &"bathtub", -17.0, 0.45, 0.0], [&"fridge", &"fridge", -21.0, 1.75, 0.0],
	[&"plank", &"plank", -12.0, 0.15, 0.0],
	[&"duck", &"duck", 1.5, 0.0, 0.0], [&"log", &"log", 5.0, 0.0, 0.0],
	[&"cow", &"cow", 12.5, 1.0, 0.0], [&"chicken", &"chicken", 10.2, 0.25, 0.0], [&"chicken_2", &"chicken", 25.0, 4.5, 0.0],
	[&"chicken_3", &"chicken", 27.5, 4.5, 0.0], [&"hay", &"hay", 15.2, 0.4, 0.0],
	[&"piano", &"piano", 33.0, 0.65, 0.0], [&"cannonball", &"cannonball", 41.0, 3.6, 0.0],
]

# file, id, kind, beam colour, params, body colour
var GUNS := [
	["1_size", &"size", GunData.Kind.SIZE, Color(0.62, 0.35, 1.0), {"repeat": 0.45}],
	["2_grab", &"grab", GunData.Kind.GRAB, Color(1.0, 0.6, 0.15), {"reach": 1.0, "throw_speed": 14.0}],
	["3_bouncy", &"bouncy", GunData.Kind.BOUNCY, Color(1.0, 0.85, 0.1), {}],
	["4_balloon", &"balloon", GunData.Kind.BALLOON, Color(1.0, 0.45, 0.85), {}],
	["5_freeze", &"freeze", GunData.Kind.FREEZE, Color(0.45, 0.9, 1.0), {}],
	["6_glue", &"glue", GunData.Kind.GLUE, Color(0.98, 0.95, 0.8), {}],
	["7_magnet", &"magnet", GunData.Kind.MAGNET, Color(0.25, 0.45, 1.0), {}],
]

# id, description, condition, subject, other, effect, amount, hints
var GOALS := [
	[&"b1_big_cow", "Make the cow big", GoalData.Condition.OBJECT_SCALE_AT_LEAST, &"cow", &"", &"", 2.0, [&"cow"]],
	[&"b1_float_chicken", "Float a chicken", GoalData.Condition.OBJECT_HAS_EFFECT, &"chicken", &"", &"balloon", 0.0, [&"chicken"]],
	[&"b1_duck_in_tub", "Put the duck in the bathtub", GoalData.Condition.OBJECT_IN_ZONE, &"duck", &"bathtub", &"", 0.0, [&"duck", &"bathtub"]],
	[&"b1_glue_two", "Glue two things together", GoalData.Condition.GLUED_PAIR, &"any", &"any", &"", 0.0, []],
	[&"b1_bouncy_any", "Make anything bouncy", GoalData.Condition.OBJECT_HAS_EFFECT, &"any", &"", &"bouncy", 0.0, []],
]


func _init() -> void:
	for d in ["res://data/objects", "res://data/guns", "res://data/goals"]:
		DirAccess.make_dir_recursive_absolute(d)
	for id in OBJECTS:
		var r: Array = OBJECTS[id]
		var o := ObjectData.make(id, r[0], r[1], r[2], r[3])
		o.bounce = r[4]
		o.face_at = r[5]
		o.face_size = r[6]
		var parts: Array[Dictionary] = []
		for p in r[7]:
			parts.append(p)
		o.parts = parts
		_save(o, "res://data/objects/%s.tres" % id)
	for g in GUNS:
		var gd := GunData.new()
		gd.id = g[1]
		gd.kind = g[2]
		gd.beam_color = g[3]
		gd.params = g[4]
		gd.cue = StringName("zap_%s" % g[1])
		_save(gd, "res://data/guns/%s.tres" % g[0])
	for g in GOALS:
		var gl := GoalData.new()
		gl.id = g[0]
		gl.description = g[1]
		gl.band = 1
		gl.condition = g[2]
		gl.subject = g[3]
		gl.other = g[4]
		gl.effect = g[5]
		gl.amount = g[6]
		var hints: Array[StringName] = []
		hints.assign(g[7])
		gl.hint_objects = hints
		_save(gl, "res://data/goals/%s.tres" % g[0])
	var lay := YardLayout.new()
	for e in LAYOUT:
		var le := YardLayoutEntry.new()
		le.key = e[0]
		le.object = load("res://data/objects/%s.tres" % e[1])
		le.position = Vector3(e[2], e[3], 0)
		le.rotation_deg = e[4]
		lay.entries.append(le)
	_save(lay, "res://data/yard_layout.tres")
	quit()


func _save(r: Resource, path: String) -> void:
	var err := ResourceSaver.save(r, path)
	print("%s %s" % ["wrote" if err == OK else "FAILED", path])
