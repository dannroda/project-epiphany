class_name BenchCase
extends Node
## Un caso del benchmark (15.14): carga `scenario` y pasea al player en círculo de `radius` alrededor de `center` (o de
## donde aparece, con `use_spawn`) a `speed` m/s durante `seconds`.

@export var scenario := "start"
@export var use_spawn := true
@export var center := Vector3.ZERO
@export var radius := 4.0
@export var speed := 4.0
@export var seconds := 6.0
