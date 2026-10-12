class_name DamageInfo
extends RefCounted

var amount: int = 0
var knockback: float = 0.0
var source: Node3D
var team: EntityConfig.Team = EntityConfig.Team.NEUTRAL
var element: StringName = &""
var reflectable: bool = false
var stun_time: float = 0.0
## Ni el escudo ni los i-frames la frenan (caer al pozo, los apretones del agarre).
var unavoidable := false


static func make(amount_: int, knockback_: float, source_: Node3D, element_ := &"") -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount_
	info.knockback = knockback_
	info.source = source_
	info.element = element_
	return info
