class_name TopDownCamera
extends Camera3D

@export var target_node: PlayerCharacter
@export var offset: Vector3 = Vector3(0, 12, 7) # Altura (Y=12) y distancia hacia atrás (Z=7)
@export var smooth_speed: float = 8.0
@export var trauma_decay := 1.6
@export var max_shake_offset := Vector2(0.35, 0.25)

var trauma := 0.0
var _shake_time := 0.0

func _ready() -> void:
	top_level = true
	if not target_node and get_parent() is PlayerCharacter:
		target_node = get_parent()

	look_at_from_position(global_position, global_position - offset, Vector3.UP)

func _physics_process(delta: float) -> void:
	if not target_node:
		return

	var focus_point := target_node.global_position

	var locked_target := target_node.targeting.current if target_node.targeting else null
	if locked_target and is_instance_valid(locked_target):
		focus_point = (target_node.global_position + locked_target.global_position) / 2.0

	var desired_pos := focus_point + offset
	global_position = global_position.lerp(desired_pos, 1.0 - exp(-smooth_speed * delta))


## Sacudida por trauma: suma, decae sola y mueve solo el encuadre (h/v offset), no la cámara.
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if trauma <= 0.0:
		h_offset = 0.0
		v_offset = 0.0
		return
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	var shake := trauma * trauma
	_shake_time += delta * 30.0
	h_offset = max_shake_offset.x * shake * sin(_shake_time * 1.7)
	v_offset = max_shake_offset.y * shake * sin(_shake_time * 2.3)
