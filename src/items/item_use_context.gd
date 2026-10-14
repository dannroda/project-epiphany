class_name ItemUseContext
extends RefCounted

var user: Node3D
var origin: Vector3
var direction: Vector3
var inventory: Inventory
## El ítem del inventario desde el que se usa: la botella, si se usa su contenido.
var source: StringName
## Apuntando: el punto del suelo hacia donde lanzar (bombas). null = colocar delante.
var throw_to: Variant = null
