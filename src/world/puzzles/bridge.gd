class_name Bridge
extends StaticBody3D
## Puente que sube desde el fondo de un hueco cuando se cumplen sus interruptores (y queda arriba). Si tiene un
## `NavigationLink3D` hijo (de orilla a orilla), lo habilita arriba: la navmesh horneada no incluye el puente.

@export var switches: Array[NodePath] = []
@export var condition: Wiring.Condition = Wiring.Condition.ALL
@export var drop := 3.0
@export var duration := 0.8
## La primera vez que lo suben sus interruptores, el juego se pausa y la cámara lo muestra.
@export var reveal_on_raise := true

## 0 abajo `drop`, 1 en su lugar: la anima el clip "raise" de %Rise.
var height := 1.0:
	set(value):
		height = value
		position.y = _base_y - drop * (1.0 - height)

var is_up := false
var _base_y := 0.0
var _wiring: Wiring

@onready var rise: AnimationPlayer = %Rise


func _ready() -> void:
	_base_y = position.y
	height = 0.0
	$CollisionShape3D.disabled = true
	_set_link(false)
	if switches.is_empty():
		return
	_wiring = Wiring.create(self, switches, condition)
	_wiring.changed.connect(func(satisfied: bool) -> void:
		if satisfied and reveal_on_raise:
			TopDownCamera.reveal_unlock(self, raise)
		elif satisfied:
			raise())
	_wiring.settled.connect(func(satisfied: bool) -> void:
		if satisfied:
			raise(false))


func raise(animate := true) -> void:
	if is_up:
		return
	is_up = true
	$CollisionShape3D.set_deferred(&"disabled", false)
	_set_link(true)
	if not animate:
		Clips.jump(rise, &"raise", true)
		return
	Clips.run(rise, &"raise", true, duration)
	Feel.sfx(&"secret", global_position)


func _set_link(on: bool) -> void:
	var link := get_node_or_null(^"NavigationLink3D") as NavigationLink3D
	if link:
		link.enabled = on
