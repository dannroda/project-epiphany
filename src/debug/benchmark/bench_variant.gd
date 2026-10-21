class_name BenchVariant
extends Node
## Una calidad del benchmark (15.14): las opciones de Settings que pone antes de cada caso. `flat_materials` cambia todos los
## materiales por uno estándar liso, para ver cuánto cuestan los shaders propios.

@export var render_scale := 100
@export var shadows := 2
@export var ssao := true
@export var flat_materials := false
