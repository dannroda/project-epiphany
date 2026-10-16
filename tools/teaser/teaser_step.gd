class_name TeaserStep
extends Marker3D
## Lo que hace el player en una toma del teaser, a los `at` segundos de empezar a grabar.
## WALK: camina hasta este marcador (con `navigate`, por el navmesh del nivel: puentes, rampas). CHASE: va hacia el enemigo más cercano hasta quedar a `reach` metros.
## PRESS: aprieta y suelta `action`. HOLD: la mantiene `duration` segundos. EQUIP: pone el ítem `action` en `button`.
## Con `on_floor` espera a que el player pise el suelo (por ejemplo, para encadenar saltos).
## LOCK: fija `target` (o el mejor blanco si está vacío). UNLOCK: suelta el fijado.

enum Kind { WALK, CHASE, PRESS, HOLD, EQUIP, LOCK, UNLOCK }

@export var kind := Kind.WALK
@export var at := 0.0
@export var action: StringName
@export var duration := 0.0
@export var button := 0
@export var reach := 1.6
@export var target: NodePath
@export var on_floor := false
@export var navigate := false
