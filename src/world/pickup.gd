class_name Pickup
extends Area3D
## Recolectable: rebota al aparecer, se acerca al player si está cerca y parpadea antes de desaparecer.

signal collected

const HEART_ICON := preload("res://assets/ui/heart_full.svg")
const GRAVITY := 18.0

@export var item: ItemData
@export var amount: int = 1
@export var heal: int = 0
## 0 = no desaparece (recompensas).
@export var lifetime := 12.0
## Lo levanta con la animación y la caja de item get (contenedor de corazón).
@export var item_get := false
@export var blink_time := 3.0
## Antes de esto no se agarra, así se ve el rebote.
@export var pickup_delay := 0.3
@export var magnet_radius := 2.2
@export var magnet_speed := 6.0
## Ancho en metros, sea cual sea el tamaño del ícono.
@export var world_size := 1.1

@onready var sprite: Sprite3D = $Sprite

var _age := 0.0
var _rest_height := 0.5
var _vertical_speed := 5.0


func _ready() -> void:
	sprite.texture = item.icon if item else HEART_ICON
	sprite.pixel_size = world_size / sprite.texture.get_width()
	_rest_height = world_size * 0.6
	sprite.position.y = _rest_height


func _physics_process(delta: float) -> void:
	_age += delta
	_bounce(delta)
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if player and not player.is_dead and _age >= pickup_delay:
		var to := player.global_position - global_position
		to.y = 0.0
		if to.length() < magnet_radius:
			global_position += to.limit_length(magnet_speed * delta)
		if get_overlapping_bodies().has(player):
			collect(player)
			return
	if lifetime <= 0.0:
		return
	if _age >= lifetime - blink_time:
		sprite.visible = fmod(_age * 10.0, 2.0) < 1.3
	if _age >= lifetime:
		queue_free()


func collect(player: PlayerCharacter) -> void:
	if heal > 0:
		player.health.heal(heal)
	if item:
		GameState.give(item, amount)
		if item_get:
			player.play_item_get(item, amount)
	Feel.sfx(&"pickup", global_position)
	collected.emit()
	queue_free()


func _bounce(delta: float) -> void:
	if is_zero_approx(_vertical_speed) and is_equal_approx(sprite.position.y, _rest_height):
		return
	_vertical_speed -= GRAVITY * delta
	sprite.position.y += _vertical_speed * delta
	if sprite.position.y <= _rest_height:
		sprite.position.y = _rest_height
		_vertical_speed = -_vertical_speed * 0.45 if _vertical_speed < -1.5 else 0.0
