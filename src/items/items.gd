# Autoload
extends Node

const DATABASE_PATH := "res://data/item_database.tres"

var database: ItemDatabase


func _ready() -> void:
	database = load(DATABASE_PATH)


func get_item(id: StringName) -> ItemData:
	return database.get_item(id)
