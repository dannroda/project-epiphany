extends GPUParticles3D
## Partículas de ambiente (15.21): en Mobile arrancan sin preprocess. Las ~200 del overworld lo simulaban todo en el primer
## cuadro (miles de pasos de cómputo) y en el Mali del G23 esa entrega pasaba los 3 s del driver y perdía el dispositivo.


func _enter_tree() -> void:
	if RenderingServer.get_current_rendering_method() == "mobile":
		preprocess = 0.0
