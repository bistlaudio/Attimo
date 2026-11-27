extends AirState
## Jump: launches with the speed of config.jump_height_for_stage(stage) and emits the jumped fact on enter.
## The stage comes from the ground chain (D-05): Jump 1, Jump 2 and Jump 3 (the highest ground
## jump). The jump itself is physics only; ProceduralPose spins the Mannequin during Jump 3 only with jump_3_pirouette on (D-07, MOVE-09).
## A released button cuts the rise (variable height); hands over to Fall at the apex.
## Jump 3 in Moto Perpetuo (D-10) rises to moto_jump_height under moto_jump_gravity_scale; exit() gives gravity_scale back.
## Gravity and the heavier fall come from the controller.


func enter(_previous: StringName) -> void:
	actor.consume_jump()
	# Jump 2 and Jump 3 only raise the maximum height; the release cut below still applies (D-04).
	var stage: int = actor.advance_chain_for_ground_jump()
	var height: float = actor.config.jump_height_for_stage(stage)
	actor.vertical_speed = actor.config.jump_speed(height)
	if stage == 3 and actor.arm_energy.is_moto():
		# v0 from the apex height and the scaled gravity: v = sqrt(2 * g * scale * h), so the apex stays moto_jump_height.
		actor.gravity_scale = actor.config.moto_jump_gravity_scale
		actor.vertical_speed = sqrt(2.0 * actor.config.rise_gravity * actor.config.moto_jump_gravity_scale * actor.config.moto_jump_height)
	# A buffered press that was released before this tick gives the tap height at every tick rate.
	apply_jump_cut()
	EventBus.jumped.emit(actor.global_position)


func exit() -> void:
	actor.gravity_scale = 1.0


func _air_update(_delta: float) -> StringName:
	apply_jump_cut()
	if actor.vertical_speed <= 0.0:
		return &"Fall"
	return &""
