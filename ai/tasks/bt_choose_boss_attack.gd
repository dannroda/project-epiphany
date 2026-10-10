@tool
extends BTAction
## Le pide al jefe el ataque con más utilidad para la fase; falla si no hay ninguno posible (manos caídas, ojo cerrado).

@export var phase := 1


func _generate_name() -> String:
	return "ChooseBossAttack (fase %d)" % phase


func _tick(_delta: float) -> Status:
	return SUCCESS if agent.choose_attack(phase) else FAILURE
