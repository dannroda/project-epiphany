class_name FeelSettings
extends Resource
## Valores del feedback de combate. Se editan en data/feel.tres.

@export_group("Hit-stop")
@export var hit_stop_give := 0.06 ## Al pegar
@export var hit_stop_take := 0.08 ## Al recibir

@export_group("Sacudida")
@export var shake_give := 0.25
@export var shake_take := 0.5
@export var shake_block := 0.15

@export_group("Impacto")
@export var sparks_on_hit := true

@export_group("Flash")
@export var flash_enabled := true ## Opción de accesibilidad
@export var flash_time := 0.12
@export var flash_color := Color(1, 1, 1)
@export var warn_color := Color(1, 0.25, 0.1) ## Aviso de ataque enemigo
@export_range(0.0, 1.0) var warn_strength := 0.6

@export_group("Sonido")
@export var sfx_volume_db := -6.0
@export var pitch_variation := 0.1
