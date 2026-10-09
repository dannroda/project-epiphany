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
## Mejora de equipo: al conseguirla se equipa aunque la ranura ya tenga algo.
@export var equip_on_get := false
@export var behavior: ItemBehavior
@export var modifiers: Array[ItemModifier] = []
## Viene con munición al conseguirlo (la bolsa trae bombas, el arco flechas).
@export var bundled: ItemData
@export var bundled_amount: int = 0

@export_group("Combate")
@export var damage: int = 0 ## En HP (1 corazón = 4)
@export var knockback: float = 0.0

@export_group("Pasivos")
@export var damage_reduction: float = 0.0
## Escudos: refleja proyectiles y haces de luz.
@export var reflects := false
## Escudos: tipos de daño (DamageInfo.element) que frena; un elemento vacío es "physical".
@export var protects_against: Array[StringName] = []
## Mejoras de capacidad (carcaj grande): suman a la capacidad de otro ítem mientras se tengan.
@export var capacity_for: ItemData
@export var capacity_bonus: int = 0


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
