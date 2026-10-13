class_name AfterTheEye
extends Node
## El overworld después del jefe final: luz de amanecer, el ojo de la fachada apagado, sin temblores y la reja de la
## cima del templo abierta. Lo aplica al entrar a la escena, al vencerlo y al cargar una partida.

@export var flag: StringName = &"te_boss_defeated"
@export var sun: DirectionalLight3D
@export var dawn_color := Color(1.0, 0.84, 0.66)
@export var dawn_energy := 1.15
## Visibles solo mientras el ojo sigue despierto.
@export var awake: Array[Node3D] = []
@export var tremors: TremorZone
@export var summit_gate: Gate

var _day_color := Color.WHITE
var _day_energy := 1.0


func _ready() -> void:
	if sun:
		_day_color = sun.light_color
		_day_energy = sun.light_energy
	GameState.flag_changed.connect(func(id: StringName, _value: Variant) -> void:
		if id == flag:
			_apply())
	GameState.loaded.connect(_apply)
	_apply()


func is_over() -> bool:
	return GameState.get_flag(flag) == true


func _apply() -> void:
	var over := is_over()
	if sun:
		sun.light_color = dawn_color if over else _day_color
		sun.light_energy = dawn_energy if over else _day_energy
	for node in awake:
		node.visible = not over
	if tremors:
		tremors.process_mode = Node.PROCESS_MODE_DISABLED if over else Node.PROCESS_MODE_INHERIT
	if summit_gate:
		if over and not summit_gate.is_open:
			summit_gate.open(false)
		elif not over and summit_gate.is_open:
			summit_gate.close()
