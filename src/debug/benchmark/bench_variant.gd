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
## Con flat_materials, solo la geometría con algún material de estos shaders (con flat_except, toda menos esa).
@export var flat_shaders: Array[Shader] = []
@export var flat_except := false
## Parámetros que pone en los materiales de parameters_shader mientras corre, y después los devuelve.
@export var parameters_shader: Shader
@export var parameters := {}
## Solo estos casos (vacío: todos).
@export var cases: PackedStringArray = []
