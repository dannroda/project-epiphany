class_name DropTable
extends Resource
## Tabla ponderada de drops. La usan enemigos, vasijas y pasto.

## Con un cuarto o menos de la munición que entra (flechas, bombas), su fila pesa tanto más.
const LOW_AMMO_SHARE := 0.25
const LOW_AMMO_BOOST := 4.0

@export var entries: Array[DropEntry] = []


## Elige una fila según los pesos, ignorando las que piden un ítem que el player no tiene.
func roll(rng: RandomNumberGenerator) -> DropEntry:
	var options := entries.filter(func(entry: DropEntry) -> bool:
		return entry.requires == null or GameState.inventory.has(entry.requires.id))
	var weights := options.map(_weight)
	var total := 0.0
	for weight: float in weights:
		total += weight
	if total <= 0.0:
		return null
	var point := rng.randf() * total
	for i in options.size():
		point -= weights[i]
		if point < 0.0:
			return options[i]
	return options.back()


func _weight(entry: DropEntry) -> float:
	if entry.requires == null or entry.item == null:
		return entry.weight
	var capacity := GameState.inventory.capacity(entry.item.id)
	if capacity > 0 and GameState.inventory.count(entry.item.id) <= capacity * LOW_AMMO_SHARE:
		return entry.weight * LOW_AMMO_BOOST
	return entry.weight


## `near` es cualquier nodo del nivel: el pickup cuelga de Spawns.root.
func drop_at(position: Vector3, near: Node, rng: RandomNumberGenerator = null) -> Pickup:
	if not is_instance_valid(near) or not near.is_inside_tree():
		return null
	if rng == null:
		rng = RandomNumberGenerator.new()
	var entry := roll(rng)
	if entry == null or entry.is_nothing():
		return null
	var pickup := Pickup.make(entry.item, entry.amount, entry.heal)
	Spawns.root(near).add_child(pickup)
	pickup.global_position = position
	return pickup
