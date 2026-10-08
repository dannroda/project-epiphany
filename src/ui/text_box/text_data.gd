class_name TextData
extends Resource
## Texto para la caja: páginas que pasan por tr(), así pueden ser claves de traducción.

enum Style { ITEM, STONE }

@export var style: Style = Style.STONE
## Rótulo chico arriba (STONE) o título dorado (ITEM).
@export var title: String
@export_multiline var pages: PackedStringArray = []


static func make(page_list: PackedStringArray, heading := "", box_style := Style.STONE) -> TextData:
	var data := TextData.new()
	data.pages = page_list
	data.title = heading
	data.style = box_style
	return data
