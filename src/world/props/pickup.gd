class_name Pickup
extends Area3D
## Recolectable: rebota al aparecer, se acerca al player si está cerca y parpadea antes de desaparecer.

signal collected

const SCENE_PATH := "res://src/world/props/pickup.tscn"
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
## Malla del corazón que cura (los que no tienen ítem).
@export var heart_mesh: Mesh
## Vueltas por segundo de la malla.

@onready var sprite: Sprite3D = $Sprite
@onready var model: MeshInstance3D = $Model

var _age := 0.0
var _rest_height := 0.5
var _vertical_speed := 5.0
var _visual: Node3D
var _touching: Array[Node3D] = []
## Lo apaga y prende el clip "blink" de $Blink cuando está por desaparecer.
var shown := true:
	set(value):
		shown = value
		if _visual:
			_visual.visible = value


## Sin agregar al árbol: el que llama ajusta lo que quiera y lo agrega.
static func make(what: ItemData, how_many := 1, heals := 0) -> Pickup:
	var pickup: Pickup = (load(SCENE_PATH) as PackedScene).instantiate()
	pickup.item = what
	pickup.amount = how_many
	pickup.heal = heals
	return pickup


## Premio de una sola vez (contenedor, pieza de llave): lo agrega a `parent` si `flag` no está y la marca al agarrarlo.
static func offer_once(pickup: Pickup, flag: StringName, parent: Node) -> bool:
	if pickup.is_inside_tree() or GameState.get_flag(flag) == true:
		return false
	parent.add_child(pickup)
	pickup.collected.connect(func() -> void: GameState.set_flag(flag, true), CONNECT_ONE_SHOT)
	return true


func _ready() -> void:
	body_entered.connect(_touching.append)
	body_exited.connect(_touching.erase)
	var mesh := item.pickup_mesh if item else heart_mesh
	if mesh:
		var box := mesh.get_aabb()
		model.mesh = mesh
		model.scale = Vector3.ONE * world_size * 0.75 / maxf(box.size.x, maxf(box.size.y, box.size.z))
		sprite.hide()
		_visual = model
		_rest_height = world_size * 0.2
	else:
		sprite.texture = item.icon if item else HEART_ICON
		sprite.pixel_size = world_size / sprite.texture.get_width()
		model.hide()
		_visual = sprite
		_rest_height = world_size * 0.6
	_visual.position.y = _rest_height


func _physics_process(delta: float) -> void:
	_age += delta
	_bounce(delta)
	var player := Players.nearest(global_position)
	if player and _age >= pickup_delay:
		var to := player.global_position - global_position
		to.y = 0.0
		if to.length() < magnet_radius:
			global_position += to.limit_length(magnet_speed * delta)
		if player in _touching:
			collect(player)
			return
	if lifetime <= 0.0:
		return
	if _age >= lifetime - blink_time and not $Blink.is_playing():
		$Blink.play(&"blink")
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
	_consume()


func _consume() -> void:
	queue_free()


func _bounce(delta: float) -> void:
	if is_zero_approx(_vertical_speed) and is_equal_approx(_visual.position.y, _rest_height):
		return
	_vertical_speed -= GRAVITY * delta
	_visual.position.y += _vertical_speed * delta
	if _visual.position.y <= _rest_height:
		_visual.position.y = _rest_height
		_vertical_speed = -_vertical_speed * 0.45 if _vertical_speed < -1.5 else 0.0
