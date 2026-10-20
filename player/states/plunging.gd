class_name Plunging
extends PlayerState
## Golpe en picada (11.34 paso 4, se aprende en la piedra de la Arboleda): atacar en el aire del salto de la pluma frena
## un instante arriba y clava la espada hacia abajo; al tocar el piso suelta `wave` (×2 en 1,2 m).

const LEARNED := &"ow_tech_plunge"
const ANIMATION := &"CombatMelee/Melee_2H_Attack_Chop"

@export var wave: PackedScene
## Quieto en el aire antes de caer.
@export var hang_time := 0.1
@export var fall_speed := 14.0
## Quieto en el piso después de la onda.
@export var recover_time := 0.3

var _elapsed := 0.0
var _landed_at := -1.0


func _enter() -> void:
	_elapsed = 0.0
	_landed_at = -1.0
	player.velocity = Vector3.ZERO
	var root := player.anim_tree.tree_root as AnimationNodeBlendTree
	(root.get_node(&"ItemAnim") as AnimationNodeAnimation).animation = ANIMATION
	player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	Feel.sfx(&"roll", player.global_position)


func _update(delta: float) -> void:
	_elapsed += delta
	if _landed_at >= 0.0:
		player.velocity = Vector3.ZERO
		player.move_and_slide()
		if _elapsed - _landed_at >= recover_time:
			dispatch("finished")
		return
	player.velocity = Vector3.ZERO if _elapsed < hang_time else Vector3.DOWN * fall_speed
	player.move_and_slide()
	if _elapsed >= hang_time and player.is_on_floor():
		_landed_at = _elapsed
		_strike()


func _exit() -> void:
	player.anim_tree.set(&"parameters/UseItem/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func _strike() -> void:
	var hit := wave.instantiate() as Hitbox
	hit.team = player.hurtbox.team
	hit.damage_factory = player._make_damage
	hit.landed.connect(player._on_hit_landed)
	Spawns.root(player).add_child(hit)
	hit.global_position = player.global_position
