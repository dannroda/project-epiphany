extends "res://tests/test_case.gd"

const ITEMS_DIR := "res://data/items"
const ITEM_COUNT := 17


class DoubleDamage extends ItemModifier:
	func modify_damage(info: DamageInfo) -> void:
		info.amount *= 2


func test_every_item_file_loads_with_its_id() -> void:
	var files := Array(DirAccess.get_files_at(ITEMS_DIR)).filter(func(f: String) -> bool: return f.ends_with(".tres"))
	assert_eq(files.size(), ITEM_COUNT)
	for file: String in files:
		var item := load(ITEMS_DIR.path_join(file)) as ItemData
		assert_true(item != null, file)
		if item:
			assert_eq(String(item.id), file.get_basename())
			assert_true(not item.display_name.is_empty(), file)
			assert_true(item.max_stack >= 1, file)


func test_database_has_every_item_once() -> void:
	var seen := {}
	for item in Items.database.items:
		assert_true(not seen.has(item.id), "repetido: %s" % item.id)
		seen[item.id] = true
	assert_eq(seen.size(), ITEM_COUNT)


func test_get_item() -> void:
	assert_eq(Items.get_item(&"sword_basic").display_name, "Espada")
	assert_eq(Items.get_item(&"no_existe"), null)


func test_sword_combo() -> void:
	var melee := Items.get_item(&"sword_basic").behavior as MeleeBehavior
	assert_true(melee != null)
	if melee:
		assert_eq(melee.get_attack(0).animation, &"CombatMelee/Melee_1H_Attack_Slice_Diagonal")
		assert_eq(melee.get_attack(3), melee.get_attack(0))


func test_inventory_respects_max_stack() -> void:
	var inventory := Inventory.new()
	var changes: Array = []
	inventory.changed.connect(func(id: StringName, count: int) -> void: changes.append([id, count]))
	assert_eq(inventory.add(&"arrow", 50), 30)
	assert_eq(inventory.count(&"arrow"), 30)
	assert_eq(inventory.add(&"arrow"), 0)
	assert_eq(inventory.remove(&"arrow", 31), false)
	assert_eq(inventory.remove(&"arrow", 30), true)
	assert_eq(inventory.has(&"arrow"), false)
	assert_eq(inventory.ids(), [] as Array[StringName])
	assert_eq(changes, [[&"arrow", 30], [&"arrow", 0]])


func test_make_damage_applies_modifiers() -> void:
	var sword := Items.get_item(&"sword_basic").duplicate() as ItemData
	sword.modifiers = [DoubleDamage.new()]
	var info := sword.make_damage(null)
	assert_eq(info.amount, Items.get_item(&"sword_basic").damage * 2)
	assert_eq(info.knockback, sword.knockback)


func test_every_item_has_an_icon() -> void:
	for item in Items.database.items:
		assert_true(item.icon != null, "%s sin ícono" % item.id)
