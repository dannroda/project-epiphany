class_name PausePage
extends Control
## Una pestaña del menú de pausa: el menú le pasa el foco y el Atrás.


## Por defecto, el primer control enfocable y visible.
func focus_default() -> void:
	for control in find_children("*", "Control", true, false):
		if (control as Control).focus_mode == FOCUS_ALL and (control as Control).is_visible_in_tree():
			(control as Control).grab_focus()
			return


## Atrás: true si la pestaña lo resolvió sola; si no, se cierra el menú.
func cancel() -> bool:
	return false
