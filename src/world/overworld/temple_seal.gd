class_name TempleSeal
extends Gate
## El sello del templo: se abre como una reja, pero la primera vez sacude el mundo (el ojo se entera).


func open(animate := true) -> void:
	if is_open:
		return
	super.open(animate)
	if animate:
		Feel.shake(0.9)
		Feel.sfx(&"rumble", global_position)
		Feel.burst(&"dust", global_position + Vector3.UP * 1.2, Vector3.UP)
