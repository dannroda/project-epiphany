class_name HitSwitch
extends StaticBody3D
## Cristal en un poste que se prende de un espadazo y se apaga solo a los `open_time` segundos (11.27, la persiana de
## Giros). Las flechas, las bombas y el gancho no lo prenden.

signal activated
signal deactivated

@export var open_time := 8.0

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var glow: AnimationPlayer = %Glow

var active := false


func _ready() -> void:
	hurtbox.hit.connect(_on_hit)


func _on_hit(info: DamageInfo) -> void:
	if active or info.element != &"" or info.source is Projectile:
		return
	active = true
	glow.play(&"on")
	Feel.sfx(&"click", global_position)
	Feel.burst(&"sparks", global_position + Vector3.UP * 1.2, Vector3.UP)
	activated.emit()
	var left := open_time
	while left > 0.0:
		var step := minf(left, 1.0 if left > 2.0 else 0.5)
		await Tweens.wait(self, step)
		left -= step
		if left > 0.0:
			Feel.sfx(&"click", global_position)
	active = false
	glow.play(&"off")
	Feel.sfx(&"block", global_position)
	deactivated.emit()
