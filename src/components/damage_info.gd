class_name DamageInfo
extends RefCounted

var amount: int = 0
var knockback: float = 0.0
var source: Node3D
var team: EntityConfig.Team = EntityConfig.Team.NEUTRAL
var element: StringName = &""
var reflectable: bool = false
var stun_time: float = 0.0
