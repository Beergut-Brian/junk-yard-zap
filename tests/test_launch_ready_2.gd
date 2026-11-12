## Launch-readiness, second pass (feature/launch-ready-2): ship hygiene checks on the files that go
## into the exported build, and the template's leftover placeholder player gone.
## Reads files only: never touches the save, the settings or the shared picks file.
class_name TestLaunchReady2
extends GdUnitTestSuite


func _preset_value(key: String) -> String:
	var cfg := ConfigFile.new()
	assert_int(cfg.load("res://export_presets.cfg")).is_equal(OK)
	return str(cfg.get_value("preset.0", key, ""))


## GAME.md holds the family's first name and planning notes; nothing in the game reads it, so it
## must not ride along inside the exported .pck (the template's include filter had it).
func test_the_export_never_ships_the_design_doc_or_any_notes() -> void:
	var include := _preset_value("include_filter")
	for part in include.split(",", false):
		assert_bool(part.strip_edges().ends_with(".md")).override_failure_message(
				"export include filter ships %s" % part).is_false()
	assert_str(include).contains("data/*.json")   # the roster and object data still ship
	var exclude := _preset_value("exclude_filter")
	for folder in ["tests/*", "playtests/*", "docs/*"]:
		assert_str(exclude).contains(folder)


## The text the game shows or ships as data never names the family or a real place.
func test_shipped_data_names_no_one_real() -> void:
	var words := ["kaden", "gary", "gmail", "/home/"]
	var dirs := ["res://data", "res://data/objects", "res://data/goals", "res://data/guns", "res://data/players"]
	var checked := 0
	for d in dirs:
		if not DirAccess.dir_exists_absolute(d):
			continue
		for f in DirAccess.get_files_at(d):
			if not (f.ends_with(".json") or f.ends_with(".tres")):
				continue
			var text := FileAccess.get_file_as_string(d.path_join(f)).to_lower()
			checked += 1
			for w in words:
				assert_bool(text.contains(w)).override_failure_message(
						"%s mentions '%s'" % [d.path_join(f), w]).is_false()
	assert_int(checked).is_greater(10)


## The template's coloured-box player was never used by this game (players are Zappers).
func test_the_template_placeholder_player_is_gone() -> void:
	assert_bool(ResourceLoader.exists("res://scenes/players/player.tscn")).is_false()
	assert_bool(ResourceLoader.exists("res://scenes/players/zapper.tscn")).is_true()


## Every playable Jarling in the synced roster has its model, pixel form and catchphrase on disk,
## so the chooser never comes up silent or empty (roster v0.5.3: 22 Jarlings).
func test_every_roster_character_has_its_files() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/roster.json"))
	var ids: Array = data.roster
	assert_int(ids.size()).is_greater_equal(2)
	for id in ids:
		var c: Dictionary = data.characters[id]
		for key in ["glb", "pixel", "catchphrase"]:
			assert_bool(ResourceLoader.exists(str(c.get(key, "")))).override_failure_message(
					"%s has no %s" % [id, key]).is_true()
