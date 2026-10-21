class_name TerrainStyleArea
extends Node3D
## Rectángulo del overworld (en XZ, centrado en el nodo) con un estilo del terreno orgánico (STYLES de
## tools/blender/build_terreno_organico.py); lo lee tools/export_terreno_overworld.gd. Va aparte de las AreaZone: las zonas
## son del juego (nombre, mapa, persecución) y cambiarlas no cambia cómo se ve el terreno.

## Las claves de STYLES (build_terreno_organico.py falla con otra); vacío, el terreno por defecto.
@export_enum("necropolis", "laguna", "cumbre", "explanada", "cardonal", "quebrada") var style: String = ""
@export var size := Vector2(8, 8)
