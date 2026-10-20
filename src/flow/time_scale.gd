class_name TimeScale
## Engine.time_scale con dueños, como `Pause`: cada uno (anillo de ítems, congelado de un golpe grande) pide su
## escala y la suelta; manda la más lenta, así soltar una no pisa la del otro.

static var _scales: Dictionary[StringName, float] = {}


static func hold(reason: StringName, scale: float) -> void:
	_scales[reason] = scale
	_apply()


static func release(reason: StringName) -> void:
	_scales.erase(reason)
	_apply()


static func is_held(reason: StringName) -> bool:
	return _scales.has(reason)


static func clear() -> void:
	_scales.clear()
	_apply()


static func _apply() -> void:
	var scale := 1.0
	for each: float in _scales.values():
		scale = minf(scale, each)
	Engine.time_scale = scale
