extends "res://tests/test_case.gd"

const ITEMS_DIR := "res://data/items"


func test_every_item_file_loads_with_its_id() -> void:
	var files := Array(DirAccess.get_files_at(ITEMS_DIR)).filter(func(f: String) -> bool: return f.ends_with(".tres"))
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
	var files := Array(DirAccess.get_files_at(ITEMS_DIR)).filter(func(f: String) -> bool: return f.ends_with(".tres")).map(func(f: String) -> StringName: return StringName(f.get_basename()))
	files.sort()
	var ids := seen.keys()
	ids.sort()
	assert_eq(ids, files, "la base tiene exactamente los ítems de data/items")


func test_shields_protect_against_known_elements() -> void:
	for item in Items.database.items:
		for element in item.protects_against:
			assert_true(element in DamageInfo.ELEMENTS, "%s: elemento desconocido %s" % [item.id, element])


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
	const NODE_OF := {&"Slash": "SwordSlice", &"Stab": "Stab"}
	var player: Node = load("res://player/player.tscn").instantiate()
	var tree_root := (player.get_node(^"ModelController/AnimationTree") as AnimationTree).tree_root as AnimationNodeBlendTree
	var types := tree_root.get_node(&"AttackType") as AnimationNodeTransition
	for attack: AttackData in [(Items.get_item(&"sword_basic").behavior as MeleeBehavior).attack, PlayerCharacter.SWORD_STAB]:
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


func test_the_golden_sword_hits_twice_as_hard_with_its_own_trail_and_sparks() -> void:
	var basic := Items.get_item(&"sword_basic")
	var golden := Items.get_item(&"sword_golden")
	assert_eq(golden.damage, basic.damage * 2, "pega el doble")
	assert_true(golden.equip_on_get, "se equipa sola")
	assert_true(golden.trail != null and basic.trail == null, "estela propia; la común sigue con la del player")
	assert_eq(golden.hit_burst, &"sparks_gold")
	assert_eq(basic.hit_burst, &"sparks")


func test_what_an_item_does_when_got_is_data() -> void:
	var expected := {
		&"small_key": ItemData.OnGet.SMALL_KEY, &"boss_key": ItemData.OnGet.BOSS_KEY,
		&"boss_key_piece": ItemData.OnGet.BOSS_KEY_PIECE, &"dungeon_map": ItemData.OnGet.DUNGEON_MAP,
		&"compass": ItemData.OnGet.COMPASS, &"heart_container": ItemData.OnGet.HEART_CONTAINER,
		&"heart_piece": ItemData.OnGet.HEART_PIECE,
	}
	for item in Items.database.items:
		assert_eq(item.on_get, expected.get(item.id, ItemData.OnGet.INVENTORY), String(item.id))
	assert_true(not Items.database.new_game_equipment.is_empty(), "hay equipo de partida nueva")
	for item in Items.database.new_game_equipment:
		assert_true(item.is_equipment(), "%s se puede llevar puesto" % item.id)
