class_name PlayerState
extends LimboState

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const ROTATION_SPEED = 10

var velocity:Vector3 :
	get:
		return agent.velocity

var player:PlayerCharacter:
	get:
		if agent is PlayerCharacter:
			return get_root().player
		return player
