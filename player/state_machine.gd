extends LimboHSM


var player: PlayerCharacter


func _setup() -> void:
	player = agent
	blackboard.set_var(PlayerState.BB_TARGET, null)
	blackboard.set_var(PlayerState.BB_IS_BLOCKING, false)
	active_state_changed.connect(func(_current: LimboState, _previous: LimboState) -> void: _sync_guard())

	add_transition($Idle, $Moving, "move")
	add_transition($Idle, $Attacking, "attack")
	add_transition($Moving, $Idle, "idle")
	add_transition($Moving, $Attacking, "attack")
	add_transition($Attacking, $Idle, "finished")
	add_transition(anystate(), $Hurt, "hurt", func() -> bool: return not player.is_dead and (get_active_state() as PlayerState).can_be_hurt)
	add_transition(anystate(), $Dead, "die")
	add_transition($Dead, $Spirit, "spirit")
	add_transition($Spirit, $Idle, "revive")
	add_transition($Hurt, $Idle, "finished")
	add_transition($Idle, $Dodging, "dodge")
	add_transition($Moving, $Dodging, "dodge")
	add_transition($Attacking, $Dodging, "dodge", $Attacking.can_cancel)
	add_transition($Attacking, $Attacking, "attack", $Attacking.can_cancel)
	add_transition($Dodging, $Idle, "finished")
	add_transition($Idle, $UsingItem, "use_item")
	add_transition($Moving, $UsingItem, "use_item")
	add_transition($UsingItem, $Idle, "finished")
	add_transition($UsingItem, $AimingThrow, "aim_throw")
	add_transition($AimingThrow, $Idle, "finished")
	add_transition($AimingThrow, $Dodging, "dodge")
	add_transition($Idle, $Carrying, "lift")
	add_transition($Moving, $Carrying, "lift")
	add_transition($Carrying, $Idle, "finished")
	add_transition($Carrying, $Dodging, "dodge")
	add_transition($Idle, $AimingItem, "aim_item")
	add_transition($Moving, $AimingItem, "aim_item")
	add_transition($AimingItem, $Idle, "finished")
	add_transition($AimingItem, $Dodging, "dodge")
	add_transition($Idle, $Jumping, "jump")
	add_transition($Moving, $Jumping, "jump")
	add_transition($Jumping, $Idle, "finished")
	add_transition($Idle, $Dashing, "dash")
	add_transition($Moving, $Dashing, "dash")
	add_transition($Dashing, $Idle, "finished")
	add_transition($Dashing, $Jumping, "jump")
	add_transition($Idle, $Hooking, "hook")
	add_transition($Moving, $Hooking, "hook")
	add_transition($Hooking, $Idle, "finished")
	add_transition(anystate(), $Transition, "transition", func() -> bool: return (get_active_state() as PlayerState).follows_room_transition)
	add_transition($Transition, $Idle, "finished")
	add_transition($Moving, $Pushing, "push")
	add_transition($Pushing, $Idle, "finished")
	add_transition($Idle, $ItemGet, "item_get")
	add_transition($Moving, $ItemGet, "item_get")
	add_transition($ItemGet, $Idle, "finished")
	add_transition(anystate(), $Grabbed, "grabbed", func() -> bool: return (get_active_state() as PlayerState).can_be_grabbed)
	add_transition($Grabbed, $Idle, "finished")
	add_transition($Idle, $Climbing, "climb")
	add_transition($Moving, $Climbing, "climb")
	add_transition($Climbing, $Idle, "finished")

	initial_state = $Idle


func _update(delta: float) -> void:
	_sync_guard()
	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta

	var input_dir := player.controls.move()
	blackboard.set_var(PlayerState.BB_INPUT_DIR, input_dir)

	var buffer := player.input_buffer
	if buffer.has(&"dodge") and dispatch("dodge"):
		buffer.consume(&"dodge")
	elif buffer.has(&"attack") and dispatch("attack"):
		buffer.consume(&"attack")
	elif _try_item(buffer):
		pass
	elif input_dir:
		dispatch("move")
	else:
		dispatch("idle")


## Se cubre mientras mantiene el Z-target (con blanco o sin él; fijado en modo alternar). Sigue al botón mantenido,
## no a sus eventos: con el player congelado (hit-stop, pausa) se perderían.
func _sync_guard() -> void:
	var targeting := player.targeting
	var holding := player.controls.pressed(&"z-lock") or (targeting.lock_mode == Targeting.LockMode.TOGGLE and targeting.current != null)
	var state := get_active_state() as PlayerState
	var guard := holding and state != null and state.can_guard
	if guard != blackboard.get_var(PlayerState.BB_IS_BLOCKING, false):
		blackboard.set_var(PlayerState.BB_IS_BLOCKING, guard)
		player.shield.set_guard(guard)


## Si el botón no tiene nada usable, avisa enseguida; si sí, espera en el buffer a que el estado lo permita.
func _try_item(buffer: InputBuffer) -> bool:
	for i in PlayerCharacter.ITEM_ACTIONS.size():
		if not buffer.has(PlayerCharacter.ITEM_ACTIONS[i]):
			continue
		if player.usable_item(i) == null:
			buffer.consume(PlayerCharacter.ITEM_ACTIONS[i])
			player.deny_item(i)
			return true
		blackboard.set_var(PlayerState.BB_ITEM_BUTTON, i)
		if dispatch(player.usable_item(i).behavior.entry_event()):
			buffer.consume(PlayerCharacter.ITEM_ACTIONS[i])
			return true
	return false
