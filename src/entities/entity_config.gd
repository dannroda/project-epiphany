class_name EntityConfig
extends Resource

enum Team { PLAYER, ENEMY, NEUTRAL }
enum Feature { TARGETABLE = 1, PUSHABLE = 2, BURNABLE = 4, REFLECTS = 8, GRABBABLE = 16 }

const _GROUPS: Dictionary[Feature, StringName] = {
	Feature.TARGETABLE: &"targetable",
	Feature.PUSHABLE: &"pushable",
	Feature.BURNABLE: &"burnable",
	Feature.REFLECTS: &"reflects",
	Feature.GRABBABLE: &"grabbable",
}

@export_flags("Targetable:1", "Pushable:2", "Burnable:4", "Reflects:8", "Grabbable:16")
var features: int = 0
@export var team: Team = Team.ENEMY
@export var max_health: int = 8 ## HP (1 corazón = 4)
@export var target_height: float = 1.0 ## Dónde apunta el lock-on / indicador
@export var knockback_resistance: float = 0.0 ## 0 = recibe todo, 1 = inamovible
@export var attack_damage: int = 2 ## Daño base de sus ataques (sin arma equipada)
@export var attack_knockback: float = 6.0
@export var drops: DropTable
## Opcional: otro modelo (una escena "Visuals" de src/entities/models/) en lugar del de la escena.
@export var model: PackedScene

@export_group("IA")
@export var move_speed: float = 3.0
@export var vision_range: float = 12.0
@export var attack_range: float = 1.6
## Radianes por segundo; 0 = gira de golpe. Lento: se le puede rodar a la espalda.
@export var turn_speed: float = 0.0

@export_group("Escudo")
## Frena de frente golpes y proyectiles; las explosiones pasan.
@export var guards_front := false
@export var guard_angle_deg := 70.0
## Un golpe que aturde (el golpe de escudo) le baja la guardia este tiempo.
@export var guard_break_time := 1.5


func has(feature: Feature) -> bool:
	return (features & feature) != 0


func apply_to(entity: Node) -> void:
	for feature in _GROUPS:
		if has(feature):
			entity.add_to_group(_GROUPS[feature])


func make_damage(source: Node3D) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = attack_damage
	info.knockback = attack_knockback
	info.source = source
	info.team = team
	return info
