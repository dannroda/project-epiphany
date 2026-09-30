class_name Hand
extends BoneAttachment3D

var equipped_item:EquippableItem:
	get:
		if get_child_count() == 1:
			return get_child(0)
		return equipped_item

var is_empty:bool:
	get:
		return not is_instance_valid(equipped_item)
		
func trigger_equipped_item(_enable:bool) -> void:
	equipped_item.enable(_enable)
