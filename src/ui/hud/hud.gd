extends CanvasLayer
## HUD del juego: corazones y slots X/Y; después llaves (6.3) y la barra del jefe (9.2).

const HP_PER_HEART := 4
const BUTTON_ACTIONS: Array[StringName] = [&"item_1", &"item_2"]

@export var pulse_scale := 1.3
@export var pulse_time := 0.18

@onready var hearts: HFlowContainer = %Hearts
@onready var keys: HBoxContainer = %Keys
@onready var small_key_count: Label = %SmallKeyCount
@onready var boss_key: TextureRect = %BossKey
@onready var item_slots: HBoxContainer = %ItemSlots
@onready var prompt: PanelContainer = %Prompt
@onready var area_name: HBoxContainer = %AreaName
@onready var area_label: Label = %AreaLabel
@onready var prompt_icon: TextureRect = %PromptIcon
@onready var prompt_text: Label = %PromptText
@onready var saved_label: Label = %Saved

var _health: Health
var _focus: Interactable
var _area_tween: Tween
var _dungeon: DungeonState
var _shown_hp := -1
var _saved_tween: Tween


func _ready() -> void:
	add_to_group(&"hud")
	SaveManager.saved.connect(func(_slot: int) -> void: _flash_saved())
	GameState.item_buttons_changed.connect(_refresh_item_slots)
	GameState.inventory.changed.connect(func(_id: StringName, _count: int) -> void: _refresh_item_slots())
	GameState.loaded.connect(_refresh_item_slots)
	InputDevice.input_device_changed.connect(func(_d: int) -> void:
		_refresh_item_slots()
		_refresh_prompt())
	MenuStack.changed.connect(_refresh_prompt)
	GameState.dungeon_changed.connect(_bind_dungeon)
	GameState.loaded.connect(_bind_dungeon)
	_bind_dungeon()
	_refresh_item_slots()
	_bind_player.call_deferred()


func _refresh_item_slots() -> void:
	for i in BUTTON_ACTIONS.size():
		var body := item_slots.get_child(i).get_node(^"Body")
		var id := GameState.item_buttons[i]
		var item := Items.get_item(id) if id != &"" else null
		body.visible = item != null
		var icon := body.get_node(^"Icon") as TextureRect
		icon.texture = item.icon if item else null
		icon.modulate.a = 1.0 if item and GameState.inventory.has(id) else 0.35
		(body.get_node(^"Badge") as TextureRect).texture = InputPrompts.icon_for_current(BUTTON_ACTIONS[i])
		var ammo_label := body.get_node(^"Ammo") as Label
		var ammo: ItemData = item.behavior.ammo if item and item.behavior else null
		ammo_label.visible = ammo != null
		if ammo:
			ammo_label.text = str(GameState.inventory.count(ammo.id))


func _bind_player() -> void:
	if not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group(&"player") as PlayerCharacter
	if player == null:
		return
	_health = player.health
	player.item_denied.connect(_shake_slot)
	player.get_node(^"InteractionDetector").focus_changed.connect(func(target: Interactable) -> void:
		_focus = target
		_refresh_prompt())
	_health.changed.connect(_on_health_changed)
	_on_health_changed(_health.current, _health.max_health)


func _refresh_prompt() -> void:
	prompt.visible = _focus != null and is_instance_valid(_focus) and not MenuStack.is_open()
	if prompt.visible:
		prompt_text.text = _focus.prompt
		prompt_icon.texture = InputPrompts.icon_for_current(&"interact")


## Nombre de la sala o la zona al entrar por primera vez: aparece, queda un rato y se va.
## Llaves: solo dentro de una mazmorra, siguiendo los cambios de su DungeonState.
func _bind_dungeon() -> void:
	if _dungeon and _dungeon.changed.is_connected(_refresh_keys):
		_dungeon.changed.disconnect(_refresh_keys)
	_dungeon = GameState.current_dungeon_state() if GameState.current_dungeon != &"" else null
	if _dungeon:
		_dungeon.changed.connect(_refresh_keys)
	_refresh_keys()


func _refresh_keys() -> void:
	keys.visible = _dungeon != null
	if _dungeon:
		small_key_count.text = "×%d" % _dungeon.small_keys
		boss_key.modulate.a = 1.0 if _dungeon.has_boss_key else 0.35


func show_area_name(text: String) -> void:
	area_label.text = text
	if _area_tween:
		_area_tween.kill()
	_area_tween = create_tween()
	_area_tween.tween_property(area_name, "modulate:a", 1.0, 0.4)
	_area_tween.tween_interval(2.0)
	_area_tween.tween_property(area_name, "modulate:a", 0.0, 0.6)


func _shake_slot(button: int) -> void:
	var body := item_slots.get_child(button).get_node(^"Body") as Control
	var tween := body.create_tween()
	for offset in [6.0, -5.0, 4.0, -2.0, 0.0]:
		tween.tween_property(body, "position:x", offset, 0.04)


func _on_health_changed(current: int, max_value: int) -> void:
	var count := ceili(max_value / float(HP_PER_HEART))
	while hearts.get_child_count() < count:
		hearts.add_child(HeartIcon.create())
	while hearts.get_child_count() > count:
		var extra := hearts.get_child(hearts.get_child_count() - 1)
		hearts.remove_child(extra)
		extra.queue_free()
	for i in count:
		var heart := hearts.get_child(i) as HeartIcon
		var quarters := clampi(current - i * HP_PER_HEART, 0, HP_PER_HEART)
		if heart.quarters != quarters and _shown_hp >= 0:
			_pulse(heart)
		heart.quarters = quarters
	_shown_hp = current


func _pulse(heart: Control) -> void:
	var tween := heart.create_tween()
	heart.scale = Vector2.ONE * pulse_scale
	tween.tween_property(heart, "scale", Vector2.ONE, pulse_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash_saved() -> void:
	if _saved_tween:
		_saved_tween.kill()
	_saved_tween = create_tween()
	_saved_tween.tween_property(saved_label, "modulate:a", 1.0, 0.2)
	_saved_tween.tween_interval(1.2)
	_saved_tween.tween_property(saved_label, "modulate:a", 0.0, 0.5)

