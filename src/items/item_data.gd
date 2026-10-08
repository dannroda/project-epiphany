class_name ItemData
extends Resource

enum Category { SWORD, SHIELD, ARMOR, USABLE, AMMO, DUNGEON, UPGRADE }

@export var id: StringName
@export var display_name: String
@export var article: String ## "el", "la", "una"… para "¡Conseguiste el Arco!"
@export_multiline var description: String
@export var icon: Texture2D
@export var category: Category
@export var max_stack: int = 1
@export var equip_scene: PackedScene
@export var behavior: ItemBehavior
@export var modifiers: Array[ItemModifier] = []

@export_group("Combate")
@export var damage: int = 0 ## En HP (1 corazón = 4)
@export var knockback: float = 0.0

@export_group("Pasivos")
@export var damage_reduction: float = 0.0
## Escudos: refleja proyectiles y haces de luz.
@export var reflects := false


func is_equipment() -> bool:
	return category in [Category.SWORD, Category.SHIELD, Category.ARMOR]


func make_damage(source: Node3D) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = damage
	info.knockback = knockback
	info.source = source
	for modifier in modifiers:
		modifier.modify_damage(info)
	return info
