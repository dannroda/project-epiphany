class_name DropTable
extends Resource
## Tabla ponderada de drops. La usan enemigos, vasijas y pasto.

const PICKUP := preload("res://src/world/pickup.tscn")

@export var entries: Array[DropEntry] = []


## Elige una fila según los pesos, ignorando las que piden un ítem que el player no tiene.
func roll(rng: RandomNumberGenerator) -> DropEntry:
	var options := entries.filter(func(entry: DropEntry) -> bool:
		return entry.requires == null or GameState.inventory.has(entry.requires.id))
	var total := 0.0
	for entry: DropEntry in options:
		total += entry.weight
	if total <= 0.0:
		return null
	var point := rng.randf() * total
	for entry: DropEntry in options:
		point -= entry.weight
		if point < 0.0:
			return entry
	return options.back()


func drop_at(position: Vector3, parent: Node, rng: RandomNumberGenerator = null) -> Pickup:
	if rng == null:
		rng = RandomNumberGenerator.new()
	var entry := roll(rng)
	if entry == null or entry.is_nothing():
		return null
	var pickup: Pickup = PICKUP.instantiate()
	pickup.item = entry.item
	pickup.amount = entry.amount
	pickup.heal = entry.heal
	parent.add_child(pickup)
	pickup.global_position = position
	return pickup
