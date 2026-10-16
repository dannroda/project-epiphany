class_name FlagDefinition
extends Resource

@export var id: StringName
@export_multiline var description: String
## Las flags son de sí o no; las cuentas van en el inventario o en DungeonState.
@export var default_value := false
