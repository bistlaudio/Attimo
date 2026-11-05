extends AirState
## LongJump (D-05, D-06): the jump out of a ground dash, during it or within config.dash_jump_grace after it.
## It travels along the dash direction at the carried dash speed: the take-off speed is
## minf(maxf(carried, config.long_jump_speed(stage)), config.long_jump_speed_cap), where carried is the speed
## along the dash direction at the press (the full dash speed during the dash, the exit carry in the grace).
## The speed is set, never added, and capped, so dash and long jump cannot stack (Pitfall 12). The chain stage
## sizes the arc: its height (config.long_jump_height) and the per-stage speed floor come from the tunable rows,
## so Jump 1 -> Jump 2 -> Dash -> Jump is the maximum long jump. The chain is consumed. The release cut
## applies like for every jump (D-04). Emits the long_jumped fact on enter.


func enter(_previous: StringName) -> void:
	actor.consume_jump()
	actor.dash_jump_grace_timer = 0.0
	var config: MovementConfig = actor.config
	var stage: int = actor.take_chain_for_long_jump()
	var direction: Vector3 = _direction()
	var carried: float = maxf(actor.move_velocity.dot(direction), 0.0)
	var speed: float = minf(maxf(carried, config.long_jump_speed(stage)), config.long_jump_speed_cap)
	actor.move_velocity = direction * speed
	actor.vertical_speed = config.jump_speed(config.long_jump_height(stage))
	# The air control target follows the take-off speed, so steering works and the carry cannot be exceeded.
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
