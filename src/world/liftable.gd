class_name Liftable
extends Interactable
## Se levanta sobre la cabeza (vasijas, rocas chicas). Va de hijo del objeto: al levantarlo, el objeto pasa a vivir
## dentro de un ThrownObject (cuerpo físico) que sostiene el Carrier del player.

## Tirado, se rompe al chocar (vasija: suelta lo suyo); si no, queda en el piso y se puede volver a levantar.
@export var breaks := true
@export var damage := 2
@export var body_radius := 0.3
## Del pie del objeto al centro del cuerpo físico.
@export var body_height := 0.35

var target: Node3D


func _init() -> void:
	super()
	prompt = "PROMPT_LIFT"


func _ready() -> void:
	target = get_parent()
	interacted.connect(func(by: PlayerCharacter) -> void: by.lift(self))


## El cuerpo que se lleva: lo crea la primera vez (el objeto deja de ser estático) y después lo reusa.
func make_body() -> ThrownObject:
	var body := target.get_parent() as ThrownObject
	if body:
		return body
	body = ThrownObject.new()
	body.liftable = self
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = body_radius
	shape.shape = sphere
	body.add_child(shape)
	var scene := target.get_tree().current_scene
	scene.add_child(body)
	body.global_position = target.global_position + Vector3.UP * body_height
	target.reparent(body)
	for solid in target.find_children("*", "StaticBody3D", true, false):
		(solid as StaticBody3D).process_mode = Node.PROCESS_MODE_DISABLED
	return body


## Vuelve a la escena antes de romperse, así lo que suelta no se va con el cuerpo.
func shatter() -> void:
	if target is Breakable:
		target.reparent(target.get_tree().current_scene)
		target.smash()
