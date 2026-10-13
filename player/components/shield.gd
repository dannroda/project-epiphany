class_name Shield
extends Node
## El escudo del player: bloquear de frente, el escudo de la espalda, el reflejo del espejo (proyectiles y haces de
## luz) y el empujón al bloquear. Si bloquea lo decide la máquina de estados (`PlayerCharacter.is_blocking`).

@export var player: PlayerCharacter
## Debug: el arco donde bloquea (`block_angle_deg`).
@export var block_cone: MeshInstance3D
@export var block_angle_deg := 60.0
@export var block_pushback := 0.3
## Un golpe cuerpo a cuerpo bloqueado deja al atacante quieto este rato.
@export var block_recoil := 0.45
## Sin bloquear, el escudo en la espalda frena los proyectiles que llegan dentro de este cono.
@export var back_shield_angle_deg := 45.0
## Bloqueando con el haz en el escudo espejo, el stick derecho (o el mouse) gira al player (rad/s).
@export var light_turn_speed := 2.2

var _guard_tween: Tween
var _light_frame := -10


func _ready() -> void:
	block_cone.mesh = _block_cone_mesh()


func _physics_process(delta: float) -> void:
	if player.is_blocking() and is_catching_light():
		turn_towards(player.aim.pointed_direction(), delta)


func _process(_delta: float) -> void:
	block_cone.visible = DebugOverlay.visible
	if block_cone.visible:
		var color := Color(0.3, 0.8, 1.0, 0.35) if player.is_blocking() else Color(1, 1, 1, 0.12)
		(block_cone.material_override as StandardMaterial3D).albedo_color = color


func item() -> ItemData:
	var id: StringName = GameState.equipment.get(ItemData.Category.SHIELD, &"")
	return Items.get_item(id) if id != &"" else null


func reflects() -> bool:
	var equipped := item()
	return equipped != null and equipped.reflects


func protects(info: DamageInfo) -> bool:
	var equipped := item()
	var kind := info.element if info.element != &"" else &"physical"
	return equipped != null and kind in equipped.protects_against


## Bloqueando con escudo y de frente a `point`.
func blocks_from(point: Vector3) -> bool:
	return player.is_blocking() and item() != null and _is_in_front(point)


## Sube o baja la guardia (la mezcla de la animación y el escudo en la mano).
func set_guard(active: bool) -> void:
	if _guard_tween and _guard_tween.is_valid():
		_guard_tween.kill()
	_guard_tween = create_tween()
	if active:
		_show_in_hand(true)
		_guard_tween.tween_property(player.anim_tree, "parameters/GuardBlend/blend_amount", 1.0, 0.15)
	else:
		_guard_tween.tween_property(player.anim_tree, "parameters/GuardBlend/blend_amount", 0.0, 0.15)
		_guard_tween.finished.connect(func() -> void:
			if not player.is_blocking():
				_show_in_hand(false))


## De frente bloqueando: el espejo refleja lo reflejable y el escudo frena lo que protege; lo demás pasa.
## En la espalda sin bloquear: solo proyectiles; el espejo los devuelve a quien los tiró.
func stops(info: DamageInfo) -> bool:
	if info.source == null:
		return false
	var projectile := info.source as Projectile
	var blocking := player.is_blocking()
	if blocking and _is_in_front(info.source.global_position):
		if projectile and info.reflectable and reflects():
			_reflect(projectile, player.aim.get_direction(), true)
			return true
		if protects(info):
			_on_blocked(info)
			return true
		Log.debug(&"combat", "El escudo no frena", info.element)
		Feel.burst(&"shards", _front_point(), player.model.global_basis.z)
		return false
	if projectile and not blocking and _is_behind(projectile.global_position):
		if info.reflectable and reflects():
			var back := projectile.shooter.global_position - player.global_position if is_instance_valid(projectile.shooter) else -projectile.velocity
			_reflect(projectile, back, false)
			return true
		if protects(info):
			Log.debug(&"combat", "Frenado por el escudo de la espalda:", projectile.name)
			Feel.burst(&"sparks", projectile.global_position, -projectile.velocity.normalized())
			Feel.sfx(&"block", player.global_position)
			return true
	return false


## El haz de luz que toca al player: el escudo espejo lo refleja como un espejo (de frente bloqueando, según
## hacia dónde mira el player; en la espalda, rebota). Con otro escudo o sin cubrirse, el haz se corta acá (null).
## Devuelve la nueva dirección y el punto de salida: el escudo, delante del centro del player.
func light_hit(direction: Vector3, point: Vector3) -> Variant:
	if not reflects():
		return null
	var from := point - direction
	var out: Vector3
	if player.is_blocking() and _is_in_front(from):
		_light_frame = Engine.get_physics_frames()
		var facing := player.model.global_basis.z
		facing.y = 0.0
		out = direction.bounce(facing.normalized()).normalized()
	elif not player.is_blocking() and _is_behind(from):
		var back := -player.model.global_basis.z
		back.y = 0.0
		out = direction.bounce(back.normalized()).normalized()
	else:
		return null
	var center := Vector3(player.global_position.x, point.y, player.global_position.z)
	return {direction = out, origin = center + out * 0.6}


## El escudo espejo está recibiendo un haz (este cuadro o el anterior).
func is_catching_light() -> bool:
	return Engine.get_physics_frames() - _light_frame <= 1


## Gira el modelo hacia `direction` a velocidad constante (para apuntar el haz con precisión).
func turn_towards(direction: Vector3, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var desired := atan2(direction.x, direction.z)
	var model := player.model
	model.global_rotation.y = rotate_toward(model.global_rotation.y, desired, light_turn_speed * Settings.stick_factor() * delta)


func _show_in_hand(in_hand: bool) -> void:
	if player.equipment.shield_in_hand:
		player.equipment.show_shield_in_hand(in_hand)


## El modelo KayKit mira a +Z local.
func _is_in_front(point: Vector3) -> bool:
	return _within(point, player.model.global_basis.z, block_angle_deg, true)


func _is_behind(point: Vector3) -> bool:
	return _within(point, -player.model.global_basis.z, back_shield_angle_deg, false)


## Si `point` cae dentro del cono de `angle_deg` alrededor de `axis` (en XZ); `if_degenerate` cuando no hay dirección.
func _within(point: Vector3, axis: Vector3, angle_deg: float, if_degenerate: bool) -> bool:
	axis.y = 0.0
	var to_point := point - player.global_position
	to_point.y = 0.0
	if to_point.is_zero_approx() or axis.is_zero_approx():
		return if_degenerate
	return rad_to_deg(axis.angle_to(to_point)) <= angle_deg


func _front_point() -> Vector3:
	return player.global_position + player.model.global_basis.z * 0.6 + Vector3.UP * 1.1


## Escudo espejo: el proyectil vuelve en esa dirección y pasa a ser del player.
func _reflect(projectile: Projectile, direction: Vector3, front: bool) -> void:
	projectile.reflect(direction, player.config.team)
	Log.debug(&"combat", "Reflejado:", projectile.name, "hacia", direction)
	if front:
		player.anim_tree.set(&"parameters/BlockHit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		Feel.shake(Feel.settings.shake_block, Vector3.ZERO, player.controls.joypads)
	Feel.burst(&"sparks", projectile.global_position, direction)
	Feel.sfx(&"reflect", player.global_position)


func _on_blocked(info: DamageInfo) -> void:
	Log.debug(&"combat", "Bloqueado:", info.source.name, info.amount, "de daño")
	player.anim_tree.set(&"parameters/BlockHit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	var away := player.global_position - info.source.global_position
	away.y = 0.0
	if not away.is_zero_approx():
		player.move_and_collide(away.normalized() * block_pushback)
	Feel.burst(&"sparks", _front_point(), player.model.global_basis.z)
	Feel.sfx(&"block", player.global_position)
	Feel.shake(Feel.settings.shake_block, Vector3.ZERO, player.controls.joypads)
	if info.source is Enemy:
		(info.source as Enemy).recoil(block_recoil, player.global_position)


func _block_cone_mesh() -> Mesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	var half := deg_to_rad(block_angle_deg)
	for i in steps:
		var a := -half + 2.0 * half * i / steps
		var b := -half + 2.0 * half * (i + 1) / steps
		mesh.surface_add_vertex(Vector3(0, 0.05, 0))
		mesh.surface_add_vertex(Vector3(sin(a), 0.05, cos(a)) * 1.5)
		mesh.surface_add_vertex(Vector3(sin(b), 0.05, cos(b)) * 1.5)
	mesh.surface_end()
	return mesh
