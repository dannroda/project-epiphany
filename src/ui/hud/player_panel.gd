class_name PlayerPanel
extends Control
## Corazones, slots X/Y y prompt de un player (13.5). El HUD instancia player_panel_solo.tscn jugando solo y un
## player_panel.tscn compacto por player en co-op (mockup HUD_Coop).

const HP_PER_HEART := 4

@export var pulse_scale := 1.3
@export var pulse_time := 0.18
@export var heart_size := HeartIcon.SIZE

@onready var hearts: Container = %Hearts
@onready var item_slots: HBoxContainer = %ItemSlots
@onready var prompt: PanelContainer = %Prompt
@onready var prompt_icon: TextureRect = %PromptIcon
@onready var prompt_text: Label = %PromptText
## Solo en co-op: P1, P2… con el color del player.
@onready var tag: PanelContainer = get_node_or_null(^"%Tag")
## Solo jugando de a uno: las llaves van debajo de los corazones.
@onready var keys_spot: Control = get_node_or_null(^"%KeysSpot")

var player: PlayerCharacter
var _focus: Interactable
var _shown_hp := -1


func _ready() -> void:
	GameState.item_buttons_changed.connect(refresh_item_slots)
	GameState.inventory.changed.connect(_on_inventory_changed)
	GameState.loaded.connect(refresh_item_slots)
	InputDevice.input_device_changed.connect(_on_device_changed)
	MenuStack.changed.connect(_refresh_prompt)


func bind(who: PlayerCharacter, color: Color) -> void:
	player = who
	if is_layout_rtl() and hearts is FlowContainer:
		(hearts as FlowContainer).alignment = FlowContainer.ALIGNMENT_END
	if tag:
		tag.self_modulate = color
		(tag.get_node(^"Label") as Label).text = "P%d" % (who.controls.slot + 1)
	who.item_denied.connect(_shake_slot)
	who.interaction_detector.focus_changed.connect(_on_focus_changed)
	who.health.changed.connect(_on_health_changed)
	_on_health_changed(who.health.current, who.health.max_health)
	refresh_item_slots()


func refresh_item_slots() -> void:
	if not is_instance_valid(player):
		return
	for i in PlayerCharacter.ITEM_ACTIONS.size():
		var body := item_slots.get_child(i).get_node(^"Body")
		var id := GameState.buttons_of(player.controls.slot)[i]
		var item := GameState.item_for(id)
		body.visible = item != null
		var icon := body.get_node(^"Icon") as TextureRect
		icon.texture = item.icon if item else null
		icon.modulate.a = 1.0 if item and GameState.inventory.has(id) else 0.35
		(body.get_node(^"Badge") as TextureRect).texture = InputPrompts.icon_for(PlayerCharacter.ITEM_ACTIONS[i], player)
		var ammo_label := body.get_node(^"Ammo") as Label
		var ammo: ItemData = item.behavior.ammo if item and item.behavior else null
		ammo_label.visible = ammo != null
		if ammo:
			ammo_label.text = str(GameState.inventory.count(ammo.id))


func _on_inventory_changed(_id: StringName, _count: int) -> void:
	refresh_item_slots()


func _on_device_changed(_device: int) -> void:
	refresh_item_slots()
	_refresh_prompt()


func _on_focus_changed(target: Interactable) -> void:
	_focus = target
	_refresh_prompt()


func _refresh_prompt() -> void:
	if not is_instance_valid(player):
		return
	prompt.visible = _focus != null and is_instance_valid(_focus) and not MenuStack.is_open()
	if prompt.visible:
		prompt_text.text = _focus.prompt
		prompt_icon.texture = InputPrompts.icon_for(&"interact", player)


func _shake_slot(button: int) -> void:
	var body := item_slots.get_child(button).get_node(^"Body") as Control
	var tween := body.create_tween()
	for offset in [6.0, -5.0, 4.0, -2.0, 0.0]:
		tween.tween_property(body, "position:x", offset, 0.04)


func _on_health_changed(current: int, max_value: int) -> void:
	var count := ceili(max_value / float(HP_PER_HEART))
	while hearts.get_child_count() < count:
		hearts.add_child(HeartIcon.create(0, heart_size))
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
