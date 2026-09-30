class_name Enemy
extends CharacterBody3D

@onready var anim_player: AnimationPlayer = $ModelController/AnimationPlayer
@onready var bt_player: BTPlayer = $BTPlayer
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var model: Node3D = $ModelController

@export var max_health: int = 50
var current_health: int
var is_dead: bool = false

const KNOCKBACK_FRICTION: float = 18.0

func _ready() -> void:
	current_health = max_health
	add_to_group("targetable")
	
	if bt_player and bt_player.blackboard:
		bt_player.blackboard.set_var("is_hit", false)
		bt_player.blackboard.set_var("is_dead", false)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_FRICTION * delta)
	velocity.z = move_toward(velocity.z, 0.0, KNOCKBACK_FRICTION * delta)

	move_and_slide()

func select() -> void:
	pass
	#print_rich("[color=Green]Enemigo fijado por Z-Target:[/color] %s" % name)

func deselect() -> void:
	pass
	#print_rich("[color=Yellow]Enemigo liberado de Z-Target:[/color] %s" % name)

func take_hit(damage: int, knockback: Vector3) -> void:
	if is_dead: return
	
	current_health -= damage
	#print_rich("[color=Red]%s recibió golpe![/color] Vida restante: %d" % [name, current_health])

	velocity = knockback
	
	var hit_dir := Vector3(knockback.x, 0, knockback.z)
	if not hit_dir.is_zero_approx():
		look_at(global_position + hit_dir, Vector3.UP)
		model.rotation = Vector3.ZERO
		
	if current_health <= 0:
		_start_death()
	else:
		if bt_player and bt_player.blackboard:
			bt_player.blackboard.set_var("is_hit", true)
			bt_player.restart()
			
func _start_death() -> void:
	is_dead = true
	
	remove_from_group("targetable")
	deselect()
	
	#collision.set_deferred("disabled", true)
	if bt_player and bt_player.blackboard:
		bt_player.blackboard.set_var("is_dead", true)
		bt_player.restart()
		
func on_death_finished() -> void:
	bt_player.active = false
	#printt(collision_layer, collision_mask)
	collision_layer = 4
	#collision_mask = 1
	#var tween := create_tween()
	#tween.tween_property(self, "scale", Vector3.ZERO, 0.5)
	#tween.tween_callback(queue_free)
