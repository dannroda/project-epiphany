extends "res://player/states/attacking.gd"
## El giro cargado (SwordCharge): un golpe en redondo que no sigue ningún combo.


func _setup() -> void:
	pass


func _pick_attack() -> AttackData:
	return player.spin_attack()
