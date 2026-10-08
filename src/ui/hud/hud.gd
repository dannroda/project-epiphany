extends CanvasLayer
## HUD del juego: corazones y slots X/Y; después llaves (6.3) y la barra del jefe (9.2).

const HP_PER_HEART := 4
const BUTTON_ACTIONS: Array[StringName] = [&"item_1", &"item_2"]
const SLOT_SIZE := Vector2(76, 76)

@export var pulse_scale := 1.3
@export var pulse_time := 0.18

@onready var hearts: HFlowContainer = %Hearts
@onready var item_slots: HBoxContainer = %ItemSlots

var _health: Health
var _shown_hp := -1


func _ready() -> void:
	_build_item_slots()
	GameState.item_buttons_changed.connect(_refresh_item_slots)
	GameState.inventory.changed.connect(func(_id: StringName, _count: int) -> void: _refresh_item_slots())
	GameState.loaded.connect(_refresh_item_slots)
	InputDevice.input_device_changed.connect(func(_d: int) -> void: _refresh_item_slots())
	_refresh_item_slots()
	_bind_player.call_deferred()


func _build_item_slots() -> void:
	for i in BUTTON_ACTIONS.size():
		var slot := Control.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame := Panel.new()
		frame.theme_type_variation = &"HudSlot"
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(frame)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var badge := TextureRect.new()
		badge.name = "Badge"
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.size = Vector2(34, 34)
		badge.position = Vector2(-14, -14)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(badge)
		var ammo := Label.new()
		ammo.name = "Ammo"
		ammo.theme_type_variation = &"HudAmmo"
		ammo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		ammo.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		ammo.grow_vertical = Control.GROW_DIRECTION_BEGIN
		ammo.offset_right = -7
		ammo.offset_bottom = -1
		ammo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ammo)
		item_slots.add_child(slot)


func _refresh_item_slots() -> void:
	for i in BUTTON_ACTIONS.size():
		var slot := item_slots.get_child(i)
		var id := GameState.item_buttons[i]
		var item := Items.get_item(id) if id != &"" else null
		(slot.get_node(^"Icon") as TextureRect).texture = item.icon if item else null
		(slot.get_node(^"Badge") as TextureRect).texture = InputPrompts.icon_for_current(BUTTON_ACTIONS[i])
		var ammo_label := slot.get_node(^"Ammo") as Label
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
	_health.changed.connect(_on_health_changed)
	_on_health_changed(_health.current, _health.max_health)


func _on_health_changed(current: int, max_value: int) -> void:
	var count := ceili(max_value / float(HP_PER_HEART))
	while hearts.get_child_count() < count:
		hearts.add_child(HeartIcon.new())
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
