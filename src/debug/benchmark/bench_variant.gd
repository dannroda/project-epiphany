class_name BenchVariant
extends Node
## Una calidad del benchmark (15.14): las opciones de Settings que pone antes de cada caso. `flat_materials` cambia todos los
## materiales por uno estándar liso, para ver cuánto cuestan los shaders propios. Las demás apagan una parte para medir
## cuánto cuesta: las luces (no direccionales), las sondas de reflejo, los efectos del compositor (LA) y los GridMap.

@export var render_scale := 100
@export var shadows := 2
@export var ssao := true
@export var flat_materials := false
@export var lights := true
@export var probes := true
@export var effects := true
@export var gridmaps := true
