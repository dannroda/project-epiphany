extends LimboHSM

const ITEM_ACTIONS: Array[StringName] = [&"item_1", &"item_2"]

var player: PlayerCharacter

@onready var _guard_states: Array[LimboState] = [$Idle, $Moving, $Attacking, $Hurt, $Transition]


func _setup() -> void:
	player = agent
	blackboard.set_var("target", null)
	blackboard.set_var("is_blocking", false)

	add_transition($Spawning, $Idle, "idle")
	add_transition($Idle, $Moving, "move")
	add_transition($Idle, $Attacking, "attack")
	add_transition($Moving, $Idle, "idle")
	add_transition($Moving, $Attacking, "attack")
	add_transition($Attacking, $Idle, "finished")
	add_transition(anystate(), $Hurt, "hurt")
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
	for state in [$Idle, $Moving, $Attacking, $Dodging, $UsingItem, $AimingItem, $AimingThrow, $Carrying, $Hurt, $Jumping]:
		add_transition(state, $Transition, "transition")
	add_transition($Transition, $Idle, "finished")
	add_transition($Moving, $Pushing, "push")
	add_transition($Pushing, $Idle, "finished")
	add_transition($Idle, $ItemGet, "item_get")
	add_transition($Moving, $ItemGet, "item_get")
	add_transition($ItemGet, $Idle, "finished")
	for state in [$Idle, $Moving, $Attacking, $Dodging, $UsingItem, $AimingItem, $AimingThrow, $Carrying, $Hurt, $Pushing, $Jumping]:
		add_transition(state, $Grabbed, "grabbed")
	add_transition($Grabbed, $Idle, "finished")

	initial_state = $Spawning


func _update(delta: float) -> void:
	_sync_guard()
	if not player.is_on_floor():
		player.velocity += player.get_gravity() * delta

	var input_dir := player.controls.move()
	blackboard.set_var("input_dir", input_dir)

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


## El escudo sigue al botón mantenido, no a sus eventos: con el player congelado (hit-stop, pausa) se perderían.
func _sync_guard() -> void:
	var guard := player.controls.pressed(&"block") and get_active_state() in _guard_states
	if guard != blackboard.get_var("is_blocking", false):
		blackboard.set_var("is_blocking", guard)
		player.set_guard(guard)


## Si el botón no tiene nada usable, avisa enseguida; si sí, espera en el buffer a que el estado lo permita.
func _try_item(buffer: InputBuffer) -> bool:
	for i in ITEM_ACTIONS.size():
		if not buffer.has(ITEM_ACTIONS[i]):
			continue
		if player.usable_item(i) == null:
			buffer.consume(ITEM_ACTIONS[i])
			player.deny_item(i)
			return true
		blackboard.set_var("item_button", i)
		var behavior := player.usable_item(i).behavior
		var event := "jump" if behavior is JumpBehavior else "aim_item" if behavior.hold_to_aim else "use_item"
		if dispatch(event):
			buffer.consume(ITEM_ACTIONS[i])
			return true
	return false
