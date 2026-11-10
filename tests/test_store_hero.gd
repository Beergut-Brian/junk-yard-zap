## store/hero.png (the launcher's wide banner, V-11) exists at 920x430. Rendered by
## art/tools/render_store.sh hero (golden hour, front gate to tower in frame).
class_name TestStoreHero
extends GdUnitTestSuite

const HERO := "res://store/hero.png"
const GRID := "res://store/grid.png"


func test_store_hero_exists_at_920x430() -> void:
	var path := ProjectSettings.globalize_path(HERO)
	assert_bool(FileAccess.file_exists(path)).is_true()
	var img := Image.load_from_file(path)
	assert_object(img).is_not_null()
	assert_int(img.get_width()).is_equal(920)
	assert_int(img.get_height()).is_equal(430)


func test_store_grid_still_600x900() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(GRID))
	assert_object(img).is_not_null()
	assert_int(img.get_width()).is_equal(600)
	assert_int(img.get_height()).is_equal(900)
