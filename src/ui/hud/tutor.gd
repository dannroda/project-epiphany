class_name Tutor
extends Control
## Chip del HUD con la tarea del mini tutorial pendiente (11.105, mockup HUD_Practice_Chip), hasta hacerla una vez; si
## pasan `hint_delay` s sin usar el ítem, marca con su ícono el objetivo sin resolver más cercano. Los avisos de combate
## aparecen con el primer enemigo a `enemy_range` de un player.

@export var catalog: TutorialCatalog
@export var hint_delay := 30.0
## Hasta dónde de un player busca un objetivo para marcar (m).
@export var hint_range := 14.0
@export var marker_height := 1.6
@export var enemy_range := 6.0

@onready var chip: Control = %Chip
@onready var chip_icon: TextureRect = %ChipIcon
@onready var chip_task: Label = %ChipTask
@onready var chip_with: Control = %ChipWith
@onready var chip_keys: RichTextLabel = %ChipKeys
@onready var marker: Control = %Marker
@onready var marker_icon: TextureRect = %MarkerIcon

var current: TutorialData
## Segundos sin usar el ítem del tutorial pendiente.
var idle := 0.0
var _hooked := {}


func _ready() -> void:
	GameState.flag_changed.connect(func(id: StringName, _value: Variant) -> void:
		if String(id).begins_with("tut_"):
			refresh())
	GameState.loaded.connect(refresh)
	GameState.cleared.connect(refresh)
	GameState.item_buttons_changed.connect(refresh)
	InputDevice.input_device_changed.connect(func(_device: int) -> void: refresh())
	get_tree().node_added.connect(func(node: Node) -> void: _hook.call_deferred(node))
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	var pending := catalog.pending()
	if pending != current:
		current = pending
		idle = 0.0
		for node in get_tree().get_nodes_in_group(&"player"):
			_hook(node)
		if current and current.target_group != &"":
			for node in get_tree().get_nodes_in_group(current.target_group):
				_hook(node)
	chip.visible = current != null
	marker.visible = false
	if not current:
		return
	chip_icon.visible = current.item != null
	if current.item:
		chip_icon.texture = current.item.icon
		marker_icon.texture = current.item.icon
	chip_task.text = tr(current.task)
	var action := current.chip_action()
	chip_with.visible = action != &""
	chip_keys.visible = action != &""
	if action != &"":
		TextBox.fill_rich(chip_keys, "{btn:%s}" % action, 26)


func _process(delta: float) -> void:
	marker.visible = false
	_check_enemies()
	if not current or current.target_group == &"":
		return
	idle += delta
	if idle < hint_delay:
		return
	var target := _nearest_target()
	var camera := get_viewport().get_camera_3d()
	if not target or not camera:
		return
	var at := target.global_position + Vector3.UP * marker_height
	if camera.is_position_behind(at):
		return
	marker.position = camera.unproject_position(at) - Vector2(marker.size.x / 2.0, marker.size.y)
	marker.visible = true


func _input(event: InputEvent) -> void:
	if not current or current.done_actions.is_empty():
		return
	for action in current.done_actions:
		if event.is_action_pressed(action):
			_complete(current)
			return


func _check_enemies() -> void:
	var waiting := catalog.tutorials.filter(func(tutorial: TutorialData) -> bool:
		return tutorial.trigger == TutorialData.Trigger.ENEMY_NEAR and not tutorial.is_shown())
	if waiting.is_empty() or not _enemy_near():
		return
	for tutorial: TutorialData in waiting:
		GameState.set_flag(tutorial.shown_flag(), true)


func _enemy_near() -> bool:
	for player: Node3D in get_tree().get_nodes_in_group(&"player"):
		for enemy in get_tree().get_nodes_in_group(&"enemies"):
			if enemy is Enemy and not enemy.is_dead and player.global_position.distance_to(enemy.global_position) < enemy_range:
				return true
	return false


func _nearest_target() -> Node3D:
	var players := get_tree().get_nodes_in_group(&"player")
	var best: Node3D
	var best_distance := hint_range
	for target in get_tree().get_nodes_in_group(current.target_group):
		if not target is Node3D or current.is_solved(target):
			continue
		for player: Node3D in players:
			var distance := player.global_position.distance_to(target.global_position)
			if distance < best_distance:
				best_distance = distance
				best = target
	return best


func _hook(node: Node) -> void:
	if not is_instance_valid(node) or not current:
		return
	var key := "%d:%s" % [node.get_instance_id(), current.id]
	if _hooked.has(key):
		return
	if node is PlayerCharacter:
		_hooked[key] = true
		if not node.item_used.is_connected(_on_item_used):
			node.item_used.connect(_on_item_used)
	elif current.target_group != &"" and node.is_in_group(current.target_group) and node.has_signal(current.done_signal):
		_hooked[key] = true
		node.connect(current.done_signal, _complete.bind(current))


func _on_item_used(item: ItemData) -> void:
	if not current or item != current.item:
		return
	idle = 0.0
	if current.target_group == &"" and current.done_actions.is_empty():
		_complete(current)


func _complete(tutorial: TutorialData) -> void:
	if tutorial.is_shown() and not tutorial.is_done():
		GameState.set_flag(tutorial.done_flag(), true)
