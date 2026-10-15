@tool
extends BTCondition
## Mientras `variable` no esté en true (sin declararla en el blackboard: falta = false); un BTSetVar la prende.

@export var variable: StringName


func _generate_name() -> String:
	return "NotYet(%s)" % LimboUtility.decorate_var(variable)


func _tick(_delta: float) -> Status:
	return FAILURE if blackboard.get_var(variable, false, false) else SUCCESS
