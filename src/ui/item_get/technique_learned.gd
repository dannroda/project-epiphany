extends UiScreen
## Técnica nueva (11.34, mockup Technique_Learned): el ícono de la técnica en anillos celestes y la caja de texto con
## cómo se hace (íconos de botón) y el muñeco para probarla. Pausa hasta confirmar.

signal closed

const CYAN := Color("#9fd8ff")
const TEXTS: DialogueResource = preload("res://data/dialogue/techniques.dialogue")

var technique: TechniqueData
var anchor := Vector2(640, 215)
var text_box: TextBox

@onready var rings: Control = %Rings
@onready var icon: TextureRect = %Icon


func _ready() -> void:
	icon.texture = technique.icon
	rings.position = anchor - rings.size / 2.0
	rings.draw.connect(_draw_rings)
	text_box = TextBox.SCENE.instantiate()
	text_box.style = TextBox.Style.ITEM
	text_box.title_override = tr("TECH_NEW").format({name = tr(technique.display_name)})
	text_box.resource = TEXTS
	text_box.cue = technique.id
	text_box.finished.connect(MenuStack.pop)
	add_child(text_box)
	move_child(text_box, 0)
	tree_exiting.connect(closed.emit)


func _draw_rings() -> void:
	var center := rings.size / 2.0
	rings.draw_circle(center, 58.0, Color(CYAN, 0.1))
	rings.draw_arc(center, 75.0, 0.0, TAU, 96, Color(CYAN, 0.55), 2.0, true)
	rings.draw_arc(center, 58.0, 0.0, TAU, 96, Color(CYAN, 0.8), 1.0, true)
