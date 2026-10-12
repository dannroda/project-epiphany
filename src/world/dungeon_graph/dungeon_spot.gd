class_name DungeonSpot
extends Resource
## Algo que se hace en una zona: abrir un cofre, apretar un interruptor, despertar un ojo, ganar una pelea.
## Da el ítem del cofre o el flag del nodo; `gives` es para nodos sin flag propio.

@export var area: StringName
@export var node: NodePath
## Lo que hace falta (ítems o flags; `a|b` = cualquiera de los dos).
@export var needs: Array[StringName] = []
## Rejas que hay que tener abiertas para llegar.
@export var through: Array[NodePath] = []
@export var gives: StringName
