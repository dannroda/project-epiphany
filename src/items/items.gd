# Autoload
extends Node

var database: ItemDatabase


func _ready() -> void:
	database = load(ItemDatabase.PATH)


func get_item(id: StringName) -> ItemData:
	return database.get_item(id)
