extends AirState
## WallJump (MOVE-12, MECH-04 E, D-09): the kick off a pad, from a WallRun or from the air against a wall-jump pad (group
## wall_jump_surface). On enter the velocity points away from the wall (wall_jump_out_speed) plus a share of the speed along the wall
## (wall_jump_keep_along), the rise reaches wall_jump_height with the jump held, and air control is locked for wall_jump_control_lock
## so steering does not eat the kick. It starts the wall-run cooldown, so the pad is not re-grabbed at once. Hands over to Fall at the
## apex; a released button cuts the rise like every jump (variable height). Shown as the Jump clip.


func enter(_previous: StringName) -> void:
	var config: MovementConfig = actor.config
	actor.consume_jump()
	actor.arm_energy.try_spend(config.wall_jump_cost, &"wall_jump")
	var normal: Vector3 = actor.wall_normal
	var flat: Vector3 = Vector3(actor.move_velocity.x, 0.0, actor.move_velocity.z)
	var along: Vector3 = flat - normal * flat.dot(normal)
	actor.move_velocity = normal * config.wall_jump_out_speed + along * config.wall_jump_keep_along
	actor.move_velocity.y = 0.0
	actor.vertical_speed = config.jump_speed(config.wall_jump_height)
	actor.air_speed_cap = maxf(config.run_speed, actor.horizontal_speed())
	actor.lock_air_control(config.wall_jump_control_lock)
	actor.face_now(normal)
	actor.wall_run_cooldown_timer = config.wall_run_cooldown
	EventBus.wall_jumped.emit(actor.global_position, normal)


func _air_update(_delta: float) -> StringName:
	apply_jump_cut()
	if actor.vertical_speed <= 0.0:
		return &"Fall"
	return &""
