class_name PhysicsLayers
## Las capas de física del proyecto (Project Settings › Layer Names › 3D Physics), como bits.

const LEVEL := 1
const PLAYER := 1 << 1
const ENEMIES := 1 << 2
const OBJECT := 1 << 3
const HURTBOX := 1 << 4
const INTERACTABLE := 1 << 5


## Un sensor: no lo detecta nadie y él ve al player (y al nivel).
static func sensor(area: Area3D, mask := LEVEL | PLAYER) -> void:
	area.collision_layer = 0
	area.collision_mask = mask
	area.monitorable = false
