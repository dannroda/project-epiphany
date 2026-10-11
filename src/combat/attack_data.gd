class_name AttackData
extends Resource

@export var animation: StringName
@export_range(0.0, 1.0) var active_from: float = 0.3
@export_range(0.0, 1.0) var active_to: float = 0.55
## Desde qué punto (0..1) se puede cortar con otro golpe, rodar, cubrirse o moverse.
@export_range(0.0, 1.0) var cancel_from: float = 0.6
## Velocidad del paso hacia adelante al arrancar (m/s); se frena sola.
@export var lunge: float = 0.0
@export var hitbox: StringName = &"front"
@export var damage_multiplier: float = 1.0
@export var knockback_multiplier: float = 1.0
## Segundos que deja aturdido al que recibe el golpe (0 = no aturde).
@export var stun_time: float = 0.0
## Estela del arma (Trail) mientras la hitbox está activa.
@export var trail := false
