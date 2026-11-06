extends AirState
## LongJump (D-05, D-06): the dash hop, the jump out of a ground dash, during it or within config.dash_jump_grace after it.
## It travels along the dash direction at the speed of its stage, config.long_jump_speed(stage). The speed is set,
## never added and never taken from the dash, so a faster dash cannot raise it and the stack tops out at the stage 3
## row (Pitfall 12). The stage comes from actor.advance_long_jump_stage(): 1 for the first hop, one more for each
## clean repeat (a ground dash started inside the landing window after touchdown, then a jump), then 3 again.
## Its height (config.long_jump_height) and speed rows size the arc. The ground-jump chain is reset. The release cut
## applies like for every jump (D-04). Emits the long_jumped fact on enter.


func enter(_previous: StringName) -> void:
	actor.consume_jump()
	actor.dash_jump_grace_timer = 0.0
	var config: MovementConfig = actor.config
	var stage: int = actor.advance_long_jump_stage()
	var direction: Vector3 = _direction()
	var speed: float = config.long_jump_speed(stage)
	actor.move_velocity = direction * speed
	actor.vertical_speed = config.jump_speed(config.long_jump_height(stage))
	# The air control target follows the take-off speed, so steering works and the take-off speed cannot be exceeded.
	actor.air_speed_cap = maxf(config.run_speed, speed)
	actor.face_now(direction)
	apply_jump_cut()
	EventBus.long_jumped.emit(actor.global_position, stage)


func _air_update(_delta: float) -> StringName:
	apply_jump_cut()
	if actor.vertical_speed <= 0.0:
		return &"Fall"
	return &""


## The dash direction, flattened. Falls back to the input, then to the facing.
func _direction() -> Vector3:
	var direction: Vector3 = actor.last_dash_direction
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = actor.input_direction()
		direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = actor.visual_root.global_basis.z
		direction.y = 0.0
	return direction.normalized()
