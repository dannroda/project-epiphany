class_name Liftable
extends Interactable
## Se levanta sobre la cabeza (vasijas, rocas chicas). Va de hijo del objeto: al levantarlo, el objeto pasa a vivir
## dentro de un ThrownObject (cuerpo físico) que sostiene el Carrier del player.

const THROWN_OBJECT := preload("res://src/world/thrown_object.tscn")
## Marca el stencil como el cuerpo del player: una vasija en el piso delante del player no lo pasa a silueta.
const STENCIL_MARK := preload("res://src/feel/stencil_mark.tres")

## Tirado, se rompe al chocar (vasija: suelta lo suyo); si no, queda en el piso y se puede volver a levantar.
@export var breaks := true
@export var damage := 2
@export var body_radius := 0.3
## Del pie del objeto al centro del cuerpo físico.
@export var body_height := 0.35
## Con las manos quietas, interactuar lo apoya en el piso de adelante en vez de tirarlo (el objeto da `drop_spot`).
@export var sets_down := false
## Contorno sobre el objeto mientras algún player lo tiene al alcance.
@export var highlight: Material = preload("res://src/world/liftable_outline.tres")

var target: Node3D
var _lit: Material


func _init() -> void:
	super()
	prompt = "PROMPT_LIFT"


func _ready() -> void:
	target = get_parent()
	if highlight:
		_lit = highlight.duplicate()
		_lit.next_pass = STENCIL_MARK
	interacted.connect(func(by: PlayerCharacter) -> void: by.lift(self))
	focused.connect(show_outline)
	show_outline(false)


## En las manos lo viste el Carrier (destello y silueta del player): no se pisa.
func show_outline(on: bool) -> void:
	var body := target.get_parent() as ThrownObject
	if body and body.freeze:
		return
	for mesh in target.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = _lit if on and _lit else STENCIL_MARK


## El cuerpo que se lleva: lo crea la primera vez (el objeto deja de ser estático) y después lo reusa.
func make_body() -> ThrownObject:
	var body := target.get_parent() as ThrownObject
	if body:
		return body
	body = THROWN_OBJECT.instantiate() as ThrownObject
	body.liftable = self
	((body.get_node(^"CollisionShape3D") as CollisionShape3D).shape as SphereShape3D).radius = body_radius
	var scene := target.get_tree().current_scene
	scene.add_child(body)
	body.global_position = target.global_position + Vector3.UP * body_height
	if target.has_method(&"lift_off"):
		target.lift_off()
	target.reparent(body)
	for solid in target.find_children("*", "StaticBody3D", true, false):
		(solid as StaticBody3D).process_mode = Node.PROCESS_MODE_DISABLED
	return body


## Vuelve a la escena antes de romperse, así lo que suelta no se va con el cuerpo.
func shatter() -> void:
	if target.has_method(&"smash"):
		target.reparent(target.get_tree().current_scene)
		target.smash()


## Lo deja en `spot` y el cuerpo físico se va: el objeto vuelve a ser lo que era antes de levantarlo.
func put_down(spot: Vector3) -> void:
	var body := target.get_parent() as ThrownObject
	target.reparent(target.get_tree().current_scene)
	target.set_down()
	target.global_transform = Transform3D(Basis.IDENTITY, spot)
	if body:
		body.queue_free()
