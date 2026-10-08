class_name PlayerCharacter
extends CharacterBody3D

@onready var model: Node3D = $ModelController
@onready var anim_player: AnimationPlayer = $ModelController/AnimationPlayer
@onready var anim_tree: AnimationTree = $ModelController/AnimationTree

@onready var movement_state: LimboHSM = $MovementState
@onready var target_detector: Area3D = $TargetDetector
@onready var target_detector_shape: CollisionShape3D = $TargetDetector/DetectorShape

@onready var shield_hand: Node3D = $ModelController/Skeleton3D/Hand_L/shield_badge
@onready var shield_back: Node3D = $ModelController/Skeleton3D/BackShield/shield_badge

@export var default_targeting_range: float = 12.0
@export var equipped_item: EquippableItem

var possible_targets: Array[Node3D]

func _ready() -> void:
	add_to_group(&"player")
	_register_monitors()
	movement_state.initialize(self)
	movement_state.set_active(true)
	
	if equipped_item:
		equip_item(equipped_item)
	else:
		set_targeting_range(default_targeting_range)

func _physics_process(delta: float) -> void:
	movement_state.update(delta)
	_watch_debug_values()

func _watch_debug_values() -> void:
	var state := movement_state.get_active_state()
	var target: Variant = movement_state.blackboard.get_var("target", null)
	DebugOverlay.watch("player/state", state.name if state else &"-")
	DebugOverlay.watch("player/animation", anim_tree.get(&"parameters/Movement/current_state"))
	DebugOverlay.watch("player/velocity", velocity.snappedf(0.01))
	DebugOverlay.watch("player/target", target.name if is_instance_valid(target) else &"-")

static func _register_monitors() -> void:
	if Performance.has_custom_monitor("epiphany/target_locked"):
		return
	Performance.add_custom_monitor("epiphany/target_locked", func() -> int:
		var tree := Engine.get_main_loop() as SceneTree
		var player := tree.get_first_node_in_group(&"player") as PlayerCharacter
		if not player or not player.movement_state.blackboard:
			return 0
		return 1 if is_instance_valid(player.movement_state.blackboard.get_var("target", null)) else 0)

func set_targeting_range(new_radius: float) -> void:
	if not target_detector_shape or not target_detector_shape.shape:
		return
	
	if not target_detector_shape.shape.resource_local_to_scene:
		target_detector_shape.shape = target_detector_shape.shape.duplicate()
	
	var cylinder := target_detector_shape.shape as CylinderShape3D
	if cylinder:
		cylinder.radius = new_radius

func equip_item(item: EquippableItem) -> void:
	equipped_item = item
	if item and item.targeting_range > 0.0:
		set_targeting_range(item.targeting_range)
	else:
		set_targeting_range(default_targeting_range)

var guard_tween: Tween
func set_guard(active: bool) -> void:
	if guard_tween and guard_tween.is_valid():
		guard_tween.kill()
	guard_tween = create_tween()
	
	if active:
		shield_hand.visible = true
		shield_back.visible = false
		guard_tween.tween_property(anim_tree, "parameters/GuardBlend/blend_amount", 1.0, 0.15)
	else:
		guard_tween.tween_property(anim_tree, "parameters/GuardBlend/blend_amount", 0.0, 0.15)
		guard_tween.finished.connect(func():
			if not movement_state.blackboard.get_var("is_blocking", false):
				shield_hand.visible = false
				shield_back.visible = true
		)

func _on_target_detector_body_entered(body: Node3D) -> void:
	if body.is_in_group("targetable"):
		possible_targets.append(body)

func _on_target_detector_body_exited(body: Node3D) -> void:
	if possible_targets.has(body):
		possible_targets.erase(body)
	if movement_state and movement_state.blackboard:
		if movement_state.blackboard.get_var("target", null) == body:
			movement_state._clear_target()
