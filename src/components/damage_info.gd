class_name DamageInfo
extends RefCounted

## Elementos (`element`); vacío es físico. Los escudos los nombran en ItemData.protects_against.
const PHYSICAL := &"physical"
const EXPLOSIVE := &"explosive"
const BLAST := &"blast"
const DASH := &"dash"
const HOOK := &"hook"
const SPIKES := &"spikes"
const ELEMENTS: Array[StringName] = [PHYSICAL, EXPLOSIVE, BLAST, DASH, HOOK, SPIKES]

var amount: int = 0
var knockback: float = 0.0
var source: Node3D
var team: EntityConfig.Team = EntityConfig.Team.NEUTRAL
var element: StringName = &""
var reflectable: bool = false
var stun_time: float = 0.0
## Ni el escudo ni los i-frames la frenan (caer al pozo, los apretones del agarre).
var unavoidable := false
## Golpe fuerte (martillo, 11.191): lo leen la placa STRIKE, lo que solo se rompe a martillazos y las guardias.
var strong := false
## Golpe contra el piso (golpe en picada, 11.34): hunde las placas STRIKE como el martillo, sin ser golpe fuerte.
var slam := false


static func make(amount_: int, knockback_: float, source_: Node3D, element_ := &"") -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount_
	info.knockback = knockback_
	info.source = source_
	info.element = element_
	return info
