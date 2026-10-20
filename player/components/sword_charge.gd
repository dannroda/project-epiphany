class_name SwordCharge
extends Node
## Mantener ataque carga el giro (Minish Cap): la espada brilla y, al soltar con la carga llena, gira en redondo.
## Cubriéndose (Z-target) no carga.

signal charged

const CHARGE_STATES: Array[StringName] = [&"Idle", &"Moving", &"Attacking"]

@export var player: PlayerCharacter
## Segundos con ataque apretado hasta que se puede soltar el giro.
@export var charge_time := 0.9
## Manteniendo hasta acá, el giro grande (MeleeBehavior.great_spin).
@export var great_charge_time := 2.2
## Desde cuándo se ve que carga (antes es un golpe normal que se mantuvo un poco).
@export var show_from := 0.3
## Fracción de la velocidad al caminar mientras carga.
@export var move_factor := 0.55
## El brillo de la espada: clips charging (sube), charged (late), great (late más fuerte) y RESET (apagado).
@export var glow: AnimationPlayer

var held := 0.0


func is_charging() -> bool:
	return held >= show_from


func is_charged() -> bool:
	return held >= charge_time


func is_great_charged() -> bool:
	return held >= great_charge_time and player.spin_attack(true) != player.spin_attack()


func _physics_process(delta: float) -> void:
	var state := player.movement_state.get_active_state()
	var allowed := player.spin_attack() != null and state != null and state.name in CHARGE_STATES
	if player.controls.just_pressed(&"attack"):
		_reset()
	if allowed and player.controls.pressed(&"attack"):
		var showing := is_charging()
		var was_charged := is_charged()
		var was_great := is_great_charged()
		held += delta
		if is_great_charged() and not was_great:
			glow.play(&"great")
			charged.emit()
		elif is_charged() and not was_charged:
			glow.play(&"charged")
			charged.emit()
		elif is_charging() and not showing:
			glow.play(&"charging")
		return
	if allowed and is_charged():
		player.movement_state.blackboard.set_var(PlayerState.BB_GREAT_SPIN, is_great_charged())
		player.movement_state.dispatch("spin")
	_reset()


func _reset() -> void:
	if held > 0.0 and glow.current_animation != &"RESET":
		glow.play(&"RESET")
	held = 0.0
