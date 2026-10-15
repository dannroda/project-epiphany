extends "res://tests/test_case.gd"
## 12.39: cada mazmorra usa las variantes de sus guerreros comunes (src/entities/guerreros/<tipo>_<mazmorra>.tscn), también
## en las oleadas; un refresh de la_walls que vuelva a las escenas base lo hace fallar.

const DUNGEONS := ["chullpa", "quenoa", "totora", "cumbre", "templo"]
const BASES := {
	"res://src/entities/enemy.tscn": "skeleton",
	"res://src/entities/shield_skeleton.tscn": "shield_skeleton",
	"res://src/entities/archer_skeleton.tscn": "archer_skeleton",
	"res://src/entities/armored_skeleton.tscn": "armored_skeleton",
}


func test_each_dungeon_uses_its_own_warriors() -> void:
	for dungeon: String in DUNGEONS:
		var text := FileAccess.get_file_as_string("res://levels/%s.tscn" % dungeon)
		for base: String in BASES:
			assert_true(not text.contains('path="%s"' % base), "%s no usa %s" % [dungeon, base.get_file()])
		var used := RegEx.create_from_string('path="res://src/entities/guerreros/([a-z_]+)\\.tscn"').search_all(text)
		assert_true(not used.is_empty(), "%s tiene guerreros" % dungeon)
		for m in used:
			assert_true(m.get_string(1).ends_with("_" + dungeon), "%s usa %s" % [dungeon, m.get_string(1)])
