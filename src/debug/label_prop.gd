class_name LabelStateTracker
extends Label

@export var target:Node
@export var value_to_track:StringName
@export var call_props:Array
@export var negate:bool = false

func _ready() -> void:
	if not visible:
		queue_free()
		return
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func setup(_target:Node, _value:String):
	target = _target
	value_to_track = _value

func _update_text():
	if not target or not value_to_track: return
	var value = target.get_indexed(NodePath(value_to_track))
	if value is bool and negate:
		value = !value
	if value is AnimationNodeStateMachinePlayback:
		value = value.get_current_node()
	if value is Callable:
		value = value.callv(call_props)
	if value is Node:
		value = value.name
	text = "%s: %s" % [name, value]

func _process(delta: float) -> void:
	_update_text()
