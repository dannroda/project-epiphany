class_name QualityProfile
extends Resource
## Un perfil de calidad (15.19): los valores gráficos de Settings que pone de una vez. Bajo, Medio y Alto en data/quality/.

@export var id: StringName
## Escala de la resolución 3D en % (uno de los de Opciones: 100, 85, 70, 50).
@export var render_scale := 100
## Sombra del sol: 2 alta, 1 baja, 0 sin sombra.
@export_range(0, 2) var shadows := 2
## Con false, las plantas no proyectan sombra.
@export var plant_shadows := true
@export var ssao := true
## Efectos LA: 2 todos; 1 sin las sombras de nubes; 0 tampoco el AO.
@export_range(0, 2) var look_effects := 2
## Tope de cuadros por segundo (0 = sin límite).
@export var max_fps := 60
