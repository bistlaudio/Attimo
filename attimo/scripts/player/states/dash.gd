extends State
## Dash (D-10, D-11, D-12): a fixed burst in the input direction (the facing without input) at config.dash_speed
## for config.dash_time. The facing snaps on the first tick. The burst is a velocity override that the
## controller's single swept move call integrates, so walls stop it and no tunnelling guard is needed.
## On the ground the floor snap keeps it on slopes. In the air it holds altitude (air_dash_gravity_scale, one
## air dash per airtime, spent in PlayerController.start_dash). The exit speed is maxf(run_speed, dash_exit_speed)
## and air control continues afterwards. A ground dash breaks the ground-jump chain and keeps the long-jump stack.
## A jump press during a ground dash leaves it into the LongJump (D-06; the hop sets its own speed per stage).
## During an air dash a jump press only stays in the buffer: there is no air jump (MOVE-05). A ground dash that
## ended on the ground opens the config.dash_jump_grace window in which a jump is still a long jump (GroundState).
## Emits the dash_started fact once on enter.

## Direction of this dash (flattened, normalized). Read by the long jump of a later plan.
var direction: Vector3 = Vector3.ZERO
## True when the dash started off the floor.
var in_air: bool = false

var _timer: float = 0.0


func enter(_previous: StringName) -> void:
	_timer = 0.0
	direction = actor.input_direction()
	if direction == Vector3.ZERO:
		direction = actor.visual_root.global_basis.z
	direction.y = 0.0
	direction = direction.normalized()
	# A dodge snaps its facing instead of turning toward it.
	actor.face_now(direction)
	in_air = not actor.is_grounded()
	actor.start_dash(direction, in_air)
	if not in_air:
		actor.on_ground_dash_started()
	if in_air:
		actor.gravity_scale = actor.config.air_dash_gravity_scale
		actor.vertical_speed = 0.0
	EventBus.dash_started.emit(actor.global_position, direction, in_air)


func exit() -> void:
	actor.gravity_scale = 1.0


func physics_update(delta: float) -> StringName:
	_timer += delta
	if _timer >= actor.config.dash_time:
		return _finish()
	actor.move_velocity = direction * actor.config.dash_speed
	if actor.wants_jump():
		# A30: a ground dash that ran off a ledge can still be cancelled into the long jump while coyote time lasts.
		if not in_air and (actor.is_grounded() or actor.can_coyote_jump()):
			return &"LongJump"
	return &""


## Horizontal speed leaving the dash: config.dash_exit_speed, never below run speed.
func _exit_speed() -> float:
	var config: MovementConfig = actor.config
	return maxf(config.run_speed, config.dash_exit_speed)


## Replaces the dash velocity by the exit carry. Airborne, the air control target speed follows it, so
## steering after the dash works and the carry cannot be exceeded by holding a direction.
func _apply_exit_carry() -> void:
	var carry: float = _exit_speed()
	actor.move_velocity = direction * carry
	if not actor.is_grounded():
		actor.air_speed_cap = maxf(actor.config.run_speed, carry)


func _finish() -> StringName:
	_apply_exit_carry()
	if not in_air and actor.is_grounded():
		actor.dash_jump_grace_timer = actor.config.dash_jump_grace
		actor.hold_combo_through_grace()
	if not actor.is_grounded():
		return &"Fall"
	if actor.input_direction() == Vector3.ZERO:
		return &"Idle"
	return &"Run"
