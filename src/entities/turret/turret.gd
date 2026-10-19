class_name Turret
extends StaticBody3D
## Ojo menor: gira hacia el player, se carga (brillo creciente) y dispara orbes reflejables.
## Solo lo dañan proyectiles del player (su propio orbe reflejado, flechas); la espada rebota.

signal defeated(turret: Turret)

const ORB := preload("res://src/entities/projectile.tscn")

@export var config: EntityConfig
@export var orb_speed := 9.0
@export var turn_speed := 5.0
## Destruida, vuelve cuando el player sale de su sala: suele ser la fuente de orbes de un puzzle (un ojo, un cristal) y
## matarla antes de usarla trabaría la sala.
@export var revives := true

@onready var head: Node3D = %Head
@onready var muzzle: Marker3D = %Muzzle
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var bt_player: BTPlayer = $BTPlayer
@onready var moves: AnimationPlayer = %Moves

var is_dead: bool:
	get:
		return health.current <= 0

var _glow := StandardMaterial3D.new()


func _ready() -> void:
	config.apply_to(self)
	add_to_group(Enemy.GROUP)
	health.max_health = config.max_health
	health.current = config.max_health
	health.invulnerability_time = 0.3
	hurtbox.team = config.team
	hurtbox.hit.connect(_on_hit)
	health.died.connect(_on_died)
	_glow.albedo_color = Color(0.95, 0.85, 0.7)
	_glow.emission_enabled = true
	_glow.emission = Color(1.0, 0.35, 0.15)
	(%Iris as MeshInstance3D).material_override = _glow
	set_charge(0.0)
	if revives:
		_watch_room.call_deferred()


## Gira la cabeza hacia el punto; true cuando ya lo mira.
func turn_towards(point: Vector3, delta: float) -> bool:
	var direction := point - head.global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return true
	var desired := atan2(direction.x, direction.z)
	head.global_rotation.y = rotate_toward(head.global_rotation.y, desired, turn_speed * delta)
	return absf(angle_difference(head.global_rotation.y, desired)) < deg_to_rad(4.0)


## Aviso antes de disparar: 0 apagado, 1 a punto de disparar.
func set_charge(amount: float) -> void:
	_glow.emission_energy_multiplier = lerpf(0.2, 5.0, amount)
	%Iris.scale = Vector3.ONE * lerpf(1.0, 1.6, amount)
	%Glow.light_energy = lerpf(0.0, 3.0, amount * amount)


func fire_at(target: Node3D) -> void:
	var info := config.make_damage(self)
	info.reflectable = true
	var aim_point := target.global_position + Vector3.UP * 1.1
	Projectile.fire(ORB, self, muzzle.global_position, (aim_point - muzzle.global_position).normalized() * orb_speed, info)
	Feel.sfx(&"click", muzzle.global_position)
	set_charge(0.0)


func _on_hit(info: DamageInfo) -> void:
	if not info.source is Projectile:
		Feel.burst(&"sparks", head.global_position, Vector3.UP)
		Feel.sfx(&"block", global_position)
		return
	if health.damage(info.amount):
		Log.info(&"combat", name, "recibió", info.amount, "de daño. Vida:", health.current)
		Feel.sfx(&"hit", global_position)


func _on_died() -> void:
	Log.info(&"combat", name, "destruida")
	defeated.emit(self)
	bt_player.active = false
	remove_from_group(Targeting.GROUP)
	hurtbox.set_deferred(&"monitorable", false)
	set_charge(0.0)
	Feel.burst(&"shards", head.global_position, Vector3.UP)
	Feel.sfx(&"break", global_position)
	Feel.shake(Feel.settings.shake_give)
	moves.play(&"die")
	if config.drops:
		config.drops.drop_at.call_deferred(global_position + Vector3.UP * 0.2, get_parent())


func _watch_room() -> void:
	if not is_inside_tree():
		return
	for room: Room in get_tree().get_nodes_in_group(Room.GROUP):
		if room.contains(global_position):
			room.player_left.connect(func(_room: Room) -> void: revive())


func revive() -> void:
	if not is_dead:
		return
	health.reset(config.max_health)
	moves.stop(true)
	head.scale = Vector3.ONE
	head.show()
	hurtbox.set_deferred(&"monitorable", true)
	bt_player.active = true
