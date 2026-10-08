extends "res://tests/test_case.gd"

const REGISTRY_PATH := "res://data/flag_registry.tres"


func test_registry_knows_its_flags() -> void:
	var registry := load(REGISTRY_PATH) as FlagRegistry
	assert_true(registry != null)
	assert_eq(registry.has(&"ow_test_chest"), true)
	assert_eq(registry.has(&"no_existe"), false)
	assert_eq(registry.default_of(&"ow_test_chest"), false)
	assert_eq(registry.default_of(&"no_existe"), null)


func test_flag_ids_are_unique() -> void:
	var seen := {}
	for definition in (load(REGISTRY_PATH) as FlagRegistry).definitions:
		assert_true(not seen.has(definition.id), "repetida: %s" % definition.id)
		seen[definition.id] = true
