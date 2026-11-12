## Runs SessionFlow over main.tscn in its own save profile, settings file and picks file, then
## writes <out>/flow.txt and exits with the number of failed steps. scripts/tools/session_flow.sh.
extends Node


func _ready() -> void:
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--flow-out="):
			out = a.trim_prefix("--flow-out=")
	Save.profile = "session_flow"
	Save.wipe()
	Save.settings_path = "user://session_flow_settings.json"
	Save.wipe_settings()
	Roster.picks_path = "user://session_flow_picks.json"
	# A run that was killed never reached the wipe at the end: start from the defaults every time.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Roster.picks_path))
	Roster.reload()
	Game.quit_exits = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var flow := SessionFlow.new()
	flow.shot_dir = out
	add_child(flow)
	await flow.run(main)
	var bad := flow.failures().size()
	var lines := PackedStringArray()
	for s in flow.steps:
		lines.append("%s %s %s" % ["PASS" if s.ok else "FAIL", s.step, s.note])
	lines.append("steps=%d failed=%d" % [flow.steps.size(), bad])
	print("flow: steps=%d failed=%d" % [flow.steps.size(), bad])
	if out != "":
		var f := FileAccess.open(out.path_join("flow.txt"), FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
	Save.wipe()
	Save.wipe_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Roster.picks_path))
	get_tree().quit(bad)
