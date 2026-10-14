extends "res://tests/test_case.gd"

const ITEMS_DIR := "res://data/items"
const ITEM_COUNT := 26


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
	assert_eq(Items.get_item(&"sword_basic").display_name, "ITEM_SWORD_BASIC_NAME")
	assert_eq(Items.get_item(&"no_existe"), null)


func test_sword_attack() -> void:
	var melee := Items.get_item(&"sword_basic").behavior as MeleeBehavior
	assert_true(melee != null)
	if melee:
		assert_eq(melee.attack.animation, &"CombatMelee/Melee_1H_Attack_Slice_Diagonal")


## 11.85: la animación que suena es la del AttackData (su tree_state), no una elegida aparte: si no, la hitbox se
## desincroniza.
func test_player_attacks_play_their_own_animation() -> void:
	const NODE_OF := {&"Slash": "SwordSlice", &"ShieldThrust": "ShieldThrust"}
	var player: Node = load("res://player/player.tscn").instantiate()
	var tree_root := (player.get_node(^"ModelController/AnimationTree") as AnimationTree).tree_root as AnimationNodeBlendTree
	var types := tree_root.get_node(&"AttackType") as AnimationNodeTransition
	for attack: AttackData in [(Items.get_item(&"sword_basic").behavior as MeleeBehavior).attack, PlayerCharacter.SHIELD_THRUST]:
		var inputs := range(types.input_count).map(func(i: int) -> StringName: return types.get_input_name(i))
		assert_true(attack.tree_state in inputs, "%s: AttackType tiene la entrada %s" % [attack.resource_path, attack.tree_state])
		var node := tree_root.get_node(NODE_OF[attack.tree_state]) as AnimationNodeAnimation
		assert_eq(node.animation, attack.animation, "%s: la entrada %s reproduce su animación" % [attack.resource_path, attack.tree_state])
	player.free()


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


func test_every_item_has_an_icon() -> void:
	for item in Items.database.items:
		assert_true(item.icon != null, "%s sin ícono" % item.id)


## 11.84: cada ítem dice con qué evento arranca; la máquina de estados no pregunta tipos.
func test_items_choose_how_they_start() -> void:
	const EVENTS := [&"use_item", &"aim_item", &"jump", &"dash", &"hook"]
	var expected := {&"bow": &"aim_item", &"bomb_bag": &"use_item", &"feather": &"jump", &"sandals": &"dash", &"hookshot": &"hook"}
	for item in Items.database.items:
		if item.behavior == null:
			continue
		assert_true(item.behavior.entry_event() in EVENTS, "%s: %s es un evento de la HSM" % [item.id, item.behavior.entry_event()])
		if expected.has(item.id):
			assert_eq(item.behavior.entry_event(), expected[item.id], String(item.id))
	var new_aimer := ItemBehavior.new()
	new_aimer.hold_to_aim = true
	assert_eq(new_aimer.entry_event(), &"aim_item", "un ítem nuevo de apuntar es solo data")
	var bow := Items.get_item(&"bow").behavior
	assert_eq(bow.aim_animation, &"CombatRanged/Ranged_Bow_Draw", "la animación del arco sale de su .tres")
	assert_eq(Items.get_item(&"bomb_bag").behavior.hold_time, 0.25, "las bombas se mantienen para apuntar")
