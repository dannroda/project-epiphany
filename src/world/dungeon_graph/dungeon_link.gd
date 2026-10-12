class_name DungeonLink
extends Resource
## Paso entre dos zonas. Una zona es una sala (`Hub`) o un lado de ella (`Ojos:N`).

@export var from: StringName
@export var to: StringName
## Puertas, rejas, puentes o muros agrietados del paso: su cerradura sale de la escena.
@export var through: Array[NodePath] = []
## Lo que el paso pide además (ítems o flags; `a|b` = cualquiera de los dos).
@export var needs: Array[StringName] = []
## Solo de `from` a `to` (una caída, un salto de una vía).
@export var one_way := false
