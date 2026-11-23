extends State
## Capture (MECH-04 C, MECH-05 tube, D-06, D-10): a mechanism (slingshot core, pneumatic tube) asks for it through
## PlayerController.capture_along. The state owns the whole body for its duration, like Dash: gravity is off, move_velocity and
## vertical_speed carry the player origin through capture_points at capture_speed, hold capture_hold seconds at the last point, then
## release with capture_exit_velocity (air control locked for EXIT_CONTROL_LOCK, the air dash refilled) into Fall. The move itself is
## still the controller's one swept move, so walls stop it; a path that makes no progress for STUCK_TIME, or any capture longer than
## MAX_CAPTURE_TIME, releases with zero exit velocity, so the state can never soft-lock (T-04.1-04). Jump and dash presses are ignored
## (the buffer simply expires). Presentation: the Fall pose. gravity_scale is restored in exit().

## Longest capture in seconds before the release (stuck guard of last resort).
const MAX_CAPTURE_TIME: float = 4.0
## Seconds without progress toward the current point that release the player.
const STUCK_TIME: float = 0.5
## Seconds air control stays off after the release so steering does not eat the throw.
const EXIT_CONTROL_LOCK: float = 0.15
## A point counts as reached this close (plus one step) in m.
const ARRIVE_MARGIN: float = 0.05
## Distance gained in m that counts as progress.
const PROGRESS_EPSILON: float = 0.02
## Largest exit speed in m/s the state ever applies (T-04.1-06).
const MAX_EXIT_SPEED: float = 40.0

var _index: int = 0
var _total_time: float = 0.0
var _hold_left: float = 0.0
var _best_distance: float = INF
var _stuck_time: float = 0.0


func enter(_previous: StringName) -> void:
	_index = 0
	_total_time = 0.0
	_hold_left = actor.capture_hold
	_best_distance = INF
	_stuck_time = 0.0
	actor.gravity_scale = 0.0
	actor.move_velocity = Vector3.ZERO
	actor.vertical_speed = 0.0
	EventBus.capture_started.emit(actor.global_position)


func exit() -> void:
	actor.gravity_scale = 1.0


func physics_update(delta: float) -> StringName:
	_total_time += delta
	if _total_time > MAX_CAPTURE_TIME:
		return _release(false)
	var points: PackedVector3Array = actor.capture_points
	var step: float = actor.capture_speed * delta
	while _index < points.size() and (points[_index] - actor.global_position).length() <= step + ARRIVE_MARGIN:
		_index += 1
		_best_distance = INF
		_stuck_time = 0.0
	if _index >= points.size():
		# Hold at the last point: close the last gap, then let go.
		_set_velocity_toward(points[points.size() - 1], delta)
		_hold_left -= delta
		if _hold_left <= 0.0:
			return _release(true)
		return &""
	var distance: float = (points[_index] - actor.global_position).length()
	if distance < _best_distance - PROGRESS_EPSILON:
		_best_distance = distance
		_stuck_time = 0.0
	else:
		_stuck_time += delta
		if _stuck_time >= STUCK_TIME:
			return _release(false)
	_set_velocity_toward(points[_index], delta)
	return &""


## Aims the owned velocity at `target`: capture_speed, or less when the target is closer than one step.
func _set_velocity_toward(target: Vector3, delta: float) -> void:
	var to: Vector3 = target - actor.global_position
	var velocity_3d: Vector3 = to.limit_length(actor.capture_speed * delta) / delta
	actor.move_velocity = Vector3(velocity_3d.x, 0.0, velocity_3d.z)
	actor.vertical_speed = velocity_3d.y


## Lets go: with the requested exit velocity (clamped), or with none after a stuck or time-out release.
func _release(with_exit: bool) -> StringName:
	var config: MovementConfig = actor.config
	var exit_velocity: Vector3 = actor.capture_exit_velocity.limit_length(MAX_EXIT_SPEED) if with_exit else Vector3.ZERO
	actor.move_velocity = Vector3(exit_velocity.x, 0.0, exit_velocity.z)
	actor.vertical_speed = clampf(exit_velocity.y, -config.terminal_speed, config.terminal_speed)
	actor.air_speed_cap = maxf(config.run_speed, actor.horizontal_speed())
	actor.lock_air_control(EXIT_CONTROL_LOCK)
	actor.refill_air_dash()
	EventBus.capture_released.emit(actor.global_position, exit_velocity)
	return &"Fall"
