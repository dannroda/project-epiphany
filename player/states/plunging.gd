class_name Plunging
extends PlayerState
## Golpe en picada (11.34 paso 4, se aprende en la piedra de la Arboleda): atacar en cualquier momento del salto de la
## pluma sube `rise_height` más con la espada en alto, cuelga `hang_time` arriba girando la espada hasta apuntar derecho
## abajo y cae a `fall_speed`. Al tocar el piso suelta `wave` (×2 en 1,2 m) con polvo, sacudón y golpe; la espada queda
## clavada `stuck_time` y la saca antes de volver. Las poses son Carry/Plunge_* (tools/blender/build_carry_anims.py).

const LEARNED := &"ow_tech_plunge"

enum Phase { RISE, HANG, FALL, STUCK, PULL }

@export var wave: PackedScene
@export_group("Ajuste")
## Cuánto sube por encima de donde atacó.
@export var rise_height := 1.0
## Quieto arriba antes de caer.
@export var hang_time := 0.24
@export var fall_speed := 9.0
## Con la espada clavada en el piso.
@export var stuck_time := 0.9
## Sacándola (Carry/Plunge_Pull).
@export var pull_time := 0.7
@export var shake := 0.4
@export_group("")

var phase := Phase.RISE
var _phase_time := 0.0
var _shadow: Decal


func _enter() -> void:
	_set_phase(Phase.RISE)
	player.velocity = Vector3.UP * sqrt(2.0 * player.get_gravity().length() * rise_height)
	player.anim_tree.set(&"parameters/Carry/transition_request", "On")
	player.anim_tree.set(&"parameters/CarryPhase/transition_request", "PlungeRise")
	Feel.sfx(&"roll", player.global_position)
	_shadow = player.get_node(^"%JumpShadow")
	_shadow.show()


func _update(delta: float) -> void:
	_phase_time += delta
	match phase:
		Phase.RISE:
			player.velocity.x = 0.0
			player.velocity.z = 0.0
			player.move_and_slide()
			if player.velocity.y <= 0.0 or player.is_on_ceiling():
				_set_phase(Phase.HANG)
				player.anim_tree.set(&"parameters/CarryPhase/transition_request", "PlungeFall")
		Phase.HANG:
			player.velocity = Vector3.ZERO
			if _phase_time >= hang_time:
				_set_phase(Phase.FALL)
		Phase.FALL:
			player.velocity = Vector3.DOWN * fall_speed
			player.move_and_slide()
			if player.is_on_floor():
				_impact()
		Phase.STUCK:
			_hold()
			if _phase_time >= stuck_time:
				_set_phase(Phase.PULL)
				player.anim_tree.set(&"parameters/CarryPhase/transition_request", "PlungePull")
		Phase.PULL:
			_hold()
			if _phase_time >= pull_time:
				dispatch("finished")
	if phase <= Phase.FALL:
		_place_shadow()


func _exit() -> void:
	_shadow.hide()
	player.anim_tree.set(&"parameters/Carry/transition_request", "Off")


func _set_phase(next: Phase) -> void:
	phase = next
	_phase_time = 0.0


func _hold() -> void:
	player.velocity = Vector3.ZERO
	player.move_and_slide()


func _impact() -> void:
	_set_phase(Phase.STUCK)
	_shadow.hide()
	player.anim_tree.set(&"parameters/CarryPhase/transition_request", "PlungeStuck")
	var at := player.global_position
	var hit := wave.instantiate() as Hitbox
	hit.team = player.hurtbox.team
	hit.damage_factory = player._make_damage
	hit.landed.connect(player._on_hit_landed)
	Spawns.root(player).add_child(hit)
	hit.global_position = at
	Feel.burst(&"dust", at + Vector3.UP * 0.1, Vector3.UP)
	Feel.sfx(&"hit_stone", at)
	Feel.shake(shake, Vector3.ZERO, player.controls.joypads)


func _place_shadow() -> void:
	var from := player.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0, player.collision_mask, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	_shadow.visible = not hit.is_empty()
	if hit:
		_shadow.global_position = hit.position + Vector3.UP * 0.5
