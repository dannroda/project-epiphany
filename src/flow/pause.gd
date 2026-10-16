class_name Pause
## La pausa del árbol con dueños: cada uno (menú, viaje, acercamiento de la cámara) pide la suya y la suelta, y el
## mundo queda en pausa mientras alguno la tenga. Así cerrar un menú en medio de un viaje no despausa el viaje.

static var _reasons := {}


static func hold(reason: StringName) -> void:
	_reasons[reason] = true
	_apply()


static func release(reason: StringName) -> void:
	_reasons.erase(reason)
	_apply()


static func is_held(reason: StringName) -> bool:
	return _reasons.has(reason)


## Al volver al título no queda ninguna.
static func clear() -> void:
	_reasons.clear()
	_apply()


static func _apply() -> void:
	(Engine.get_main_loop() as SceneTree).paused = not _reasons.is_empty()
