## Start fresh (Kaden's feel rule, audited 2026-11-13): with a yard saved, the start menu offers
## Continue and New yard. New asks first (FreshCard: A held), then keeps the whole save (yard,
## deck, trophies, last guns) as a backup file and opens the layout's yard with a new deck. Nothing
## is ever deleted: Settings > Restore old yard brings the newest backup back, and keeps the yard it
## replaces as a backup too (so a second Restore undoes the first).
## Backups: user://saves/backups/<profile>--<UTC stamp>-<n>.json, the save file's own JSON.
class_name FreshStart
extends RefCounted

const DIR := "user://saves/backups"


## A yard has been saved on this profile (a returning player).
static func has_save() -> bool:
	return Save.get_value(YardLevel.SAVE_KEY) is Dictionary


## This profile's backups, oldest first (file names, under DIR).
static func backups() -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.begins_with(Save.profile + "--") and f.ends_with(".json"):
			out.append(f)
	out.sort()
	return out


static func has_backup() -> bool:
	return not backups().is_empty()


## The save as it is now, written to a new backup. Returns its path ("" if there was nothing to keep
## or it could not be written).
static func back_up() -> String:
	var data := Save.data()
	if data.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp := Time.get_datetime_string_from_system(true).replace(":", "").replace("-", "")
	var path := ""
	for n in 1000:
		path = DIR.path_join("%s--%s-%03d.json" % [Save.profile, stamp, n])
		if not FileAccess.file_exists(path):
			break
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("FreshStart: could not write %s" % path)
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return path


## New yard. The yard is saved as it is this second, backed up, then the save starts empty and the
## level goes back to the layout with a new deck. Returns the backup's path. Refuses (returns "",
## nothing changed) if there is a save it could not back up: never a wipe without a copy.
static func start_fresh(level: YardLevel) -> String:
	if level and level.use_save:
		level.save_yard()
	var path := back_up()
	if path == "" and not Save.data().is_empty():
		return ""
	Save.replace({})
	if level:
		level.fresh_yard()
	return path


## Restore old yard: the newest backup becomes the save (the one it replaces is backed up first).
static func restore(level: YardLevel) -> bool:
	var list := backups()
	if list.is_empty():
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(list[-1])))
	if not parsed is Dictionary:
		return false
	if level and level.use_save:
		level.save_yard()
	back_up()
	Save.replace(parsed)
	if level:
		level.reload_from_save()
	return true
