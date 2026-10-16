class_name TeaserAngle
extends Node3D
## Un ángulo de cámara de una toma; record.sh graba la misma acción desde cada uno. GAME: la cámara del juego, con HUD.
## RAIL: de From a To (posición y giro), o mirando a Mira si está. FOLLOW: sigue al player desde `offset`, mirando a
## `look_height` sobre él. ORBIT: gira alrededor de Mira (o del player) de `from_degrees` a `to_degrees` a `radius` y
## `height`. Fuera de GAME no hay HUD.

enum Kind { GAME, RAIL, FOLLOW, ORBIT }

@export var kind := Kind.GAME
@export var fov := 45.0
@export var offset := Vector3(0.0, 2.0, 5.0)
@export var look_height := 1.0
@export var smoothing := 4.0
@export var radius := 6.0
@export var height := 2.5
@export var from_degrees := -30.0
@export var to_degrees := 30.0
