extends GroundState
## Sprint: hold-to-sprint (D-03). Accelerates toward run_speed * sprint_multiplier along the camera-relative
## input. Up to run speed it uses ground_accel, so a sprint start is never slower than a run start; the step
## from run speed to sprint speed uses the slower sprint_accel (A26). Releasing the sprint action returns to
## Run, which brakes down to run speed. Running_A plays in place (Locomotion blend by the animator).


func _ground_update(delta: float) -> StringName:
	var direction: Vector3 = actor.input_direction()
	if direction == Vector3.ZERO:
		# Run owns the braking from here on and hands over to Idle at a standstill.
		actor.accelerate_ground(Vector3.ZERO, 0.0, actor.config.ground_decel, delta)
		return &"Run"
	if not Input.is_action_pressed(&"sprint"):
		return &"Run"
	actor.face(direction, delta)
	var accel: float = actor.config.ground_accel
	if actor.horizontal_speed() >= actor.config.run_speed:
		accel = actor.config.sprint_accel
	actor.accelerate_ground(direction, actor.config.run_speed * actor.config.sprint_multiplier, accel, delta)
	return &""
