class_name ItemData
extends Resource

enum Category { SWORD, SHIELD, ARMOR, USABLE, AMMO, DUNGEON, UPGRADE }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
## Lo que se ve cuando está tirado en el mundo (Pickup); sin malla, el ícono.
@export var pickup_mesh: Mesh
@export var category: Category
@export var max_stack: int = 1
@export var equip_scene: PackedScene
## Mejora de equipo: al conseguirla se equipa aunque la ranura ya tenga algo.
@export var equip_on_get := false
@export var behavior: ItemBehavior
## Viene con munición al conseguirlo (la bolsa trae bombas, el arco flechas).
@export var bundled: ItemData
@export var bundled_amount: int = 0

@export_group("Combate")
@export var damage: int = 0 ## En HP (1 corazón = 4)
@export var knockback: float = 0.0

@export_group("Pasivos")
@export var damage_reduction: float = 0.0
## Armaduras: material del cuerpo del player mientras está puesta (null = la textura del modelo).
@export var body_material: Material
## Co-op: el de cada invitado (P2, P3…), con sus colores.
@export var guest_body_materials: Array[Material] = []
## Escudos: refleja proyectiles y haces de luz.
@export var reflects := false
## Escudos: tipos de daño (DamageInfo.element) que frena; un elemento vacío es "physical".
@export var protects_against: Array[StringName] = []
## Mejoras de capacidad (carcaj grande): suman a la capacidad de otro ítem mientras se tengan.
@export var capacity_for: ItemData
@export var capacity_bonus: int = 0

@export_group("Botella")
## Contenido de botella (vacía, poción, agua bendita): no tiene casilla propia, va en una de las cuatro botellas.
@export var bottled := false
## Color del contenido en la botella de vidrio (alfa 0 = vacía); cualquier botella puede llevar cualquier contenido.
@export var liquid := Color(0, 0, 0, 0)
## Brillo propio del contenido (el agua bendita brilla).
@export var liquid_glow := 0.0


func is_equipment() -> bool:
	return category in [Category.SWORD, Category.SHIELD, Category.ARMOR]


func make_damage(source: Node3D) -> DamageInfo:
	return DamageInfo.make(damage, knockback, source)
