extends State
## WallRun (MOVE-12, D-09): the player runs along an active wall-run pad (group wall_run_surface) at max(entry speed, wall_run_speed)
## with gravity scaled to wall_run_gravity_scale and a small press into the wall (wall_run_stick_speed) that keeps the contact. Like
## Dash it owns its velocity for the duration: move_velocity is rewritten every tick, gravity_scale is restored in exit().
## Exits in order: jump -> WallJump, Loader press -> Loader, dash press -> Dash, floor contact -> Run or Idle, wall_run_time up or the wall contact lost for
## longer than wall_contact_grace (the pad ended) -> Fall. Every exit starts wall_run_cooldown, so a pad cannot be re-grabbed at once.
## Presentation: the run clip plus the ProceduralPose roll lean toward the wall (no new clip, MOVE-11 composition).

var _timer: float = 0.0
var _normal: Vector3 = Vector3.ZERO
var _tangent: Vector3 = Vector3.ZERO
var _speed: float = 0.0


func enter(_previous: StringName) -> void:
	var config: MovementConfig = actor.config
	_timer = 0.0
	_normal = actor.wall_normal
	_tangent = actor.wall_tangent()
	var entry_speed: float = Vector2(actor.wall_pre_velocity.x, actor.wall_pre_velocity.z).length()
	_speed = maxf(entry_speed, config.wall_run_speed)
	actor.gravity_scale = config.wall_run_gravity_scale
	# A wall-run starts with a defined rise, never with the take-off speed of a jump (a held jump would turn the pad into a launcher).
	actor.vertical_speed = config.wall_run_entry_rise
	actor.air_speed_cap = maxf(actor.air_speed_cap, _speed)
	actor.face_now(_tangent)
	EventBus.wall_run_started.emit(actor.global_position, _normal)


func exit() -> void:
	actor.gravity_scale = 1.0
	actor.wall_run_cooldown_timer = actor.config.wall_run_cooldown
	# Drop the press into the wall; the next state starts with the run along it.
	var into_wall: float = actor.move_velocity.dot(_normal)
	if into_wall < 0.0:
		actor.move_velocity -= _normal * into_wall
	EventBus.wall_run_ended.emit(actor.global_position)


func physics_update(delta: float) -> StringName:
	var config: MovementConfig = actor.config
	_timer += delta
	actor.move_velocity = _tangent * _speed - _normal * config.wall_run_stick_speed
	actor.move_velocity.y = 0.0
	if actor.wants_jump():
		return &"WallJump"
	if actor.loader_press_starts_loader():
		return &"Loader"
	if actor.dash_press_starts_dash():
		return &"Dash"
	if actor.is_grounded() and actor.vertical_speed <= 0.0:
		if actor.input_direction() != Vector3.ZERO:
			return &"Run"
		return &"Idle"
	# wall_surface folds in wall_contact_grace and re-checks the group every tick: a plain wall or a pad switched off ends the run.
	if _timer >= config.wall_run_time or not actor.wall_surface(&"wall_run_surface"):
		return &"Fall"
	return &""
