class_name BenchVariant
extends Node
## Una calidad del benchmark (15.14): las opciones de Settings que pone antes de cada caso. `flat_materials` cambia todos los
## materiales por uno estándar liso, para ver cuánto cuestan los shaders propios. Las demás apagan una parte para medir
## cuánto cuesta: las luces (no direccionales), las sondas de reflejo, los efectos del compositor (LA), los GridMap y los
## LODs de las mallas (siempre el detalle completo).

@export var render_scale := 100
@export var shadows := 2
@export var ssao := true
@export var flat_materials := false
@export var lights := true
@export var probes := true
@export var effects := true
## Con false, la cámara queda sin CameraAttributes (el DOF de las mazmorras LA).
@export var dof := true
## DOF más barato: calidad del bokeh (0 muy baja … 3 alta) y forma (0 caja, 1 hexágono, 2 círculo); -1: lo del proyecto.
@export var dof_quality := -1
@export var dof_shape := -1
@export var gridmaps := true
@export var lods := true
## Con flat_materials, solo la geometría con algún material de estos shaders (con flat_except, toda menos esa).
@export var flat_shaders: Array[Shader] = []
@export var flat_except := false
## Parámetros que pone en los materiales de parameters_shader mientras corre, y después los devuelve.
@export var parameters_shader: Shader
@export var parameters := {}
## Con parameters_shader, lo cambia por este shader en esos materiales mientras corre (A/B de una versión del shader).
@export var swap_shader: Shader
## Con false, las plantas (escenas de src/world/plants y lo que cuelga de Decor) no proyectan sombra.
@export var plant_shadows := true
## Sombra del sol más barata: ortogonal (un solo split) en vez de PSSM, otra distancia máxima y otro tamaño de atlas
## (0: lo del nivel y de Settings).
@export var sun_orthogonal := false
@export var sun_distance := 0.0
@export var shadow_atlas := 0
## Efectos del compositor que apaga mientras corre (por script), y después los vuelve a prender.
@export var effects_off: Array[Script] = []
## Solo estos casos (vacío: todos).
@export var cases: Array[StringName] = []
## Diagnóstico (15.20): ningún Area3D monitorea, o todos los enemigos quietos. El juego no anda igual; solo para medir.
@export var monitoring_off := false
@export var enemies_off := false
## 15.25: sin el glow del entorno; escalado bilineal en vez de FSR (con render_scale < 100); ocultos los nodos (3D, 2D o
## CanvasLayer) cuya escena empieza con alguno de estos caminos o que se llaman así; la cámara sin ver ninguna capa.
@export var glow := true
@export var fsr := true
@export var hidden: Array[String] = []
@export var camera_cull := true
## Tope de pasos de física por cuadro mientras corre (0: el del proyecto).
@export var max_physics_steps := 0
## Modo de proceso y tamaño de radiancia del cielo mientras corre (-1: los del nivel).
@export var sky_process_mode := -1
@export var sky_radiance := -1
