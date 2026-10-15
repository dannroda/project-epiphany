@tool
extends BTCondition
## Con la vida en esta fracción o menos.

@export_range(0.0, 1.0, 0.05) var fraction := 0.34


func _generate_name() -> String:
	return "Health ≤ %d%%" % roundi(fraction * 100.0)


func _tick(_delta: float) -> Status:
	var health: Health = agent.health
	return SUCCESS if health.current <= health.max_health * fraction else FAILURE
