@tool
extends BTAction
## Corre el ataque elegido y espera a que la pieza termine de golpear.


func _generate_name() -> String:
	return "PerformBossAttack"


func _enter() -> void:
	agent.perform_chosen()


func _tick(_delta: float) -> Status:
	return RUNNING if agent.is_attack_running() else SUCCESS
