extends GroundState
## Idle: brakes to a stop. Hands over to Run as soon as a move direction is held, and already
## accelerates on that tick so no input tick is lost.


func _ground_update(delta: float) -> StringName:
	var direction: Vector3 = actor.input_direction()
	if direction == Vector3.ZERO:
		actor.accelerate_ground(Vector3.ZERO, 0.0, actor.config.ground_decel, delta)
		return &""
	actor.face(direction, delta)
	actor.accelerate_ground(direction, actor.config.run_speed, actor.config.ground_accel, delta)
	return &"Run"
