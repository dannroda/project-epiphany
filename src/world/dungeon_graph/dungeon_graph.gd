class_name DungeonGraph
extends Resource
## Grafo llave-cerradura de una mazmorra: las zonas, cómo se conectan y qué hace falta en cada lugar.
## Lo que dice la escena (tipo de puerta, interruptores de cada reja, contenido de los cofres) no se repite acá:
## el test de alcanzabilidad lo lee de la escena y busca un orden de juego que deje al jugador sin salida.
## Sin escena es un grafo de diseño: las cerraduras y lo que da cada lugar se declaran en el grafo.

@export_file("*.tscn") var scene: String
## Zona donde se entra (al lado del portal de salida).
@export var start: StringName
## Flag que da la mazmorra por terminada.
@export var goal: StringName
## Ítems que el jugador trae al entrar (los que pide la puerta de afuera).
@export var brings: Array[StringName] = []
## Ítem de la mazmorra: sin él no se llega al objetivo.
@export var item: StringName
## Lo que da vencer al sub-jefe: el ítem no se consigue sin eso, y el sub-jefe se vence sin el ítem.
@export var guard: StringName
@export var links: Array[DungeonLink] = []
@export var spots: Array[DungeonSpot] = []
