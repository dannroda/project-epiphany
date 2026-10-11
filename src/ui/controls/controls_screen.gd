class_name ControlsScreen
extends UiScreen
## Controles a pantalla completa (mockups Controls_Gamepad y Controls_Keyboard), desde Opciones. Arranca en el
## dispositivo en uso; LB/RB (Q/E) o Y (T) cambian de vista.

const SCENE_PATH := "res://src/ui/controls/controls_screen.tscn"
const SELECTED := Color(0.8509804, 0.6431373, 0.25490198, 1)
const UNSELECTED := Color(0.654902, 0.62352943, 0.5568628, 1)

@onready var view: ControlsView = %View
@onready var pad_tab: Label = %PadTab
@onready var keys_tab: Label = %KeysTab
@onready var prev_key: TextureRect = %PrevKey
@onready var next_key: TextureRect = %NextKey


static func open() -> ControlsScreen:
	var screen: ControlsScreen = load(SCENE_PATH).instantiate()
	MenuStack.push(screen)
	return screen


func _ready() -> void:
	%Hints.hints = [[[&"ui_tab_left", &"ui_tab_right"], "CONTROLS_HINT_DEVICE"], [&"ui_cancel", "HINT_BACK"]]
	view.device_changed.connect(_paint)
	InputDevice.input_device_changed.connect(_on_input_device_changed)
	view.use_current_device()
	_paint(view.gamepad)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_tab_left") or event.is_action_pressed(&"ui_tab_right") \
			or event.is_action_pressed(&"ui_toggle_view"):
		view.toggle()
		get_viewport().set_input_as_handled()


func _paint(gamepad: bool) -> void:
	pad_tab.modulate = SELECTED if gamepad else UNSELECTED
	keys_tab.modulate = UNSELECTED if gamepad else SELECTED
	prev_key.texture = InputPrompts.icon_for_current(&"ui_tab_left")
	next_key.texture = InputPrompts.icon_for_current(&"ui_tab_right")


func _on_input_device_changed(_device: int) -> void:
	_paint(view.gamepad)
