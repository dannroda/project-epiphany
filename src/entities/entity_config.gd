class_name EntityConfig
extends Resource

enum Team { PLAYER, ENEMY, NEUTRAL }
enum Feature { TARGETABLE = 1, PUSHABLE = 2, BURNABLE = 4, REFLECTS = 8, GRABBABLE = 16 }

const _GROUPS: Dictionary[Feature, StringName] = {
	Feature.TARGETABLE: Targeting.GROUP,
	Feature.PUSHABLE: &"pushable",
	Feature.BURNABLE: &"burnable",
	Feature.REFLECTS: &"reflects",
	Feature.GRABBABLE: &"grabbable",
}

@export_flags("Targetable:1", "Pushable:2", "Burnable:4", "Reflects:8", "Grabbable:16")
var features: int = 0
@export var team: Team = Team.ENEMY
@export_range(1, 400, 1, "or_greater") var max_health: int = 8 ## HP (1 corazón = 4)
@export_range(0.0, 10.0, 0.05, "or_greater") var target_height: float = 1.0 ## Dónde apunta el lock-on / indicador
@export_range(0.0, 1.0, 0.05) var knockback_resistance: float = 0.0 ## 0 = recibe todo, 1 = inamovible
@export_range(0, 40, 1, "or_greater") var attack_damage: int = 2 ## Daño base de sus ataques (sin arma equipada)
@export_range(0.0, 30.0, 0.1, "or_greater") var attack_knockback: float = 6.0
## Su golpe cuerpo a cuerpo (timing y aviso); sin esto usa el de su árbol de comportamiento.
@export var attack: AttackData
@export var drops: DropTable
## Opcional: otro modelo (una escena "Visuals" de src/entities/models/) en lugar del de la escena.
@export var model: PackedScene

@export_group("IA")
@export_range(0.0, 15.0, 0.1, "or_greater") var move_speed: float = 3.0
@export_range(0.0, 40.0, 0.5, "or_greater") var vision_range: float = 12.0
@export_range(0.0, 10.0, 0.05, "or_greater") var attack_range: float = 1.6
## Radianes por segundo; 0 = gira de golpe. Lento: se le puede rodar a la espalda.
@export_range(0.0, 30.0, 0.1, "or_greater") var turn_speed: float = 0.0
## Mientras no ve a nadie deambula a puntos al azar a esta distancia de donde empezó (0 = se queda quieto).
@export_range(0.0, 15.0, 0.1, "or_greater") var wander_radius: float = 3.0
@export_range(0.0, 10.0, 0.1, "or_greater") var wander_speed: float = 1.2
## Pausa entre paseos, en segundos (mínimo y máximo).
@export var wander_pause := Vector2(1.5, 3.5)


func has(feature: Feature) -> bool:
	return (features & feature) != 0


func apply_to(entity: Node) -> void:
	for feature in _GROUPS:
		if has(feature):
			entity.add_to_group(_GROUPS[feature])


func make_damage(source: Node3D) -> DamageInfo:
	var info := DamageInfo.make(attack_damage, attack_knockback, source)
	info.team = team
	return info
