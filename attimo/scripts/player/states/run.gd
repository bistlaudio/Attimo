extends GroundState
## Run: accelerates toward run_speed along the camera-relative input, skids when the input reverses
## and brakes to a stop when released. Running_A plays in place (Locomotion blend by the animator).


func _ground_update(delta: float) -> StringName:
	var direction: Vector3 = actor.input_direction()
	if direction == Vector3.ZERO:
		actor.accelerate_ground(Vector3.ZERO, 0.0, actor.config.ground_decel, delta)
		if actor.horizontal_speed() < 0.01:
			return &"Idle"
		return &""
	actor.face(direction, delta)
	actor.accelerate_ground(direction, actor.config.run_speed, actor.config.ground_accel, delta)
	return &""
