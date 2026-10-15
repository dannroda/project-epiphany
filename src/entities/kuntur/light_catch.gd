class_name LightCatch
extends StaticBody3D
## Cuerpo que avisa cuando lo toca un LightBeam (el Apu Kuntur posado). Sin capa no lo ve el haz.

signal lit


func receive_light() -> void:
	lit.emit()
