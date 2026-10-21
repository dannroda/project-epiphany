extends "res://tests/test_case.gd"

const REGISTRY_PATH := FlagRegistry.PATH


func test_registry_knows_its_flags() -> void:
	var registry := load(REGISTRY_PATH) as FlagRegistry
	assert_true(registry != null)
	assert_eq(registry.has(&"ow_test_chest"), true)
	assert_eq(registry.has(&"no_existe"), false)
	assert_eq(registry.default_of(&"ow_test_chest"), false)
	assert_eq(registry.default_of(&"no_existe"), null)


func test_flag_ids_are_unique() -> void:
	assert_eq((load(REGISTRY_PATH) as FlagRegistry).duplicates(), [] as Array[StringName], "sin flags repetidas")
	assert_eq((load(ItemDatabase.PATH) as ItemDatabase).duplicates(), [] as Array[StringName], "sin ítems repetidos")
	assert_eq(Registries.duplicates([&"a", &"b", &"a", &"a"]), [&"a"] as Array[StringName])


## 11.81: en una mazmorra el prefijo de cada flag es el id de su Dungeon, sin lista fija en el código; afuera, ow_ o
## flags de mazmorras que solo se leen.
func test_every_level_flag_has_its_dungeon_prefix() -> void:
	var checked := 0
	for level in ["overworld", "bomb_cave", "bush_cave", "grotto_cave", "shrine_cave", "spring_cave", "reflejos", "huaca", "chullpa", "quenoa", "totora", "cumbre", "templo", "test/dungeon_test"]:
		var root: Node = load("res://levels/%s.tscn" % level).instantiate()
		var prefix := PersistentFlag.prefix_for(root)
		assert_true(prefix != "" and not "_" in prefix, "%s: prefijo %s" % [level, prefix])
		for node in root.find_children("*", "", true, false):
			for property in [&"flag", &"solved_flag", &"defeated_flag", &"container_flag"]:
				var id: Variant = node.get(property)
				if id is StringName and id != &"":
					assert_eq(PersistentFlag.prefix_for(node), prefix, "%s: %s ve la misma mazmorra" % [level, node.name])
					assert_true(prefix == PersistentFlag.OVERWORLD_PREFIX or String(id).begins_with(prefix + "_"), "%s: %s.%s = %s empieza con %s_" % [level, node.name, property, id, prefix])
					checked += 1
		root.free()
	assert_true(checked > 150, "revisó los flags de los niveles (%d)" % checked)


func test_a_dungeon_without_id_warns() -> void:
	var dungeon := Dungeon.new()
	assert_eq(dungeon._get_configuration_warnings().size(), 1, "sin id")
	dungeon.id = &"cu"
	assert_eq(dungeon._get_configuration_warnings().size(), 0, "con id")
	dungeon.free()


func test_boss_arena_takes_its_flags_and_reward_from_the_scene() -> void:
	var root: Node = load("res://levels/templo.tscn").instantiate()
	var arena := root.get_node(^"BossArena") as BossArena
	assert_eq(arena._get_configuration_warnings().size(), 0, "la del templo está completa")
	assert_eq(arena.reward.id, &"heart_container")
	var empty := BossArena.new()
	assert_eq(empty._get_configuration_warnings().size(), 4, "vacía: dos flags, premio y fin")
	empty.free()
	root.free()
