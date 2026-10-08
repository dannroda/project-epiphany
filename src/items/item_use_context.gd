class_name ItemUseContext
extends RefCounted

var user: Node3D
var origin: Vector3
var direction: Vector3
var inventory: Inventory
var equipped: Node3D
## Apuntando: el punto del suelo hacia donde lanzar (bombas). null = colocar delante.
var throw_to: Variant = null
