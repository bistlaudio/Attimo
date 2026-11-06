class_name PlayerController
extends CharacterBody3D
## The player body. It owns move_velocity (horizontal) and vertical_speed, composes velocity from
## them and makes the one kinematic move call exactly once per physics tick. States only write move_velocity,
## vertical_speed and gravity_scale; they never touch velocity or call the move themselves.
## Every number comes from the shared MovementConfig resource (MOVE-10).

## The tunable movement numbers. player.tscn assigns res://resources/player/movement_default.tres.
@export var config: MovementConfig

## Horizontal velocity (x and z, y is always 0). Owned here, written by states.
var move_velocity: Vector3 = Vector3.ZERO
## Vertical speed in m/s, positive is up. Owned here, written by states.
var vertical_speed: float = 0.0
## Scales gravity for this tick. A state may lower it (air dash) and must restore it in exit().
var gravity_scale: float = 1.0
## Upper bound of the air control target speed, set on leaving the floor.
var air_speed_cap: float = 0.0
## Seconds left in which a ground jump is still allowed after walking off a ledge (D-09).
var coyote_timer: float = 0.0
## Seconds left in which a jump press is remembered (D-09).
var jump_buffer_timer: float = 0.0
## Seconds left before the next dash may start (D-11). Starts when a dash starts.
var dash_cooldown_timer: float = 0.0
## True while the one air dash of this airtime is unspent. Landing refills it (D-12).
var air_dash_available: bool = true
## Direction of the last dash started, flattened and normalized.
var last_dash_direction: Vector3 = Vector3.ZERO
## Ground-jump chain stage: 0 none, 1 after Jump 1, 2 after Jump 2, 3 after Jump 3, the salto (D-05). Changes emit chain_stage_changed.
var chain_stage: int = 0
## Seconds left of the landing window in which the next ground jump advances the chain. Counts down only
## while grounded; at 0 the chain resets (D-07).
var chain_timer: float = 0.0
## Seconds left after a ground dash ended in which a jump still is a long jump (D-06).
var dash_jump_grace_timer: float = 0.0

var _was_on_floor: bool = true
var _last_platform_velocity: Vector3 = Vector3.ZERO

@onready var visual_root: Node3D = $VisualRoot
@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	assert(config != null, "PlayerController.config is not assigned")
	# Platform carry is applied by hand in _leave_floor (the engine default would be overwritten).
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(config.floor_max_angle_deg)
	air_speed_cap = config.run_speed
	state_machine.setup(self)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	state_machine.physics_update(delta)
	_integrate(delta)


## True when the last post-move found the floor (true at spawn).
func is_grounded() -> bool:
	return _was_on_floor


## Horizontal speed in m/s.
func horizontal_speed() -> float:
	return Vector2(move_velocity.x, move_velocity.z).length()


## Movement input in world space, flattened, keeping the analog magnitude (<= 1).
## Camera-relative: a camera under a CameraRig steers through the rig's steering_yaw() (A40), any
## other current camera through its own yaw. Without a camera it falls back to world axes (W = -Z).
func input_direction() -> Vector3:
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var yaw: float = 0.0
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var rig: CameraRig = _find_rig(camera)
		if rig != null:
			yaw = rig.steering_yaw()
		else:
			yaw = camera.global_basis.get_euler(EULER_ORDER_YXZ).y
	var forward: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	return right * input.x - forward * input.y


## Moves move_velocity toward direction * target_speed. The rate is turn_decel when the current
## velocity points against the wanted one (skid), ground_decel when there is no input or the speed
## is above the target, otherwise `accel`.
func accelerate_ground(direction: Vector3, target_speed: float, accel: float, delta: float) -> void:
	var desired: Vector3 = Vector3(direction.x, 0.0, direction.z) * target_speed
	var rate: float = accel
	if desired == Vector3.ZERO or horizontal_speed() > desired.length() + 0.0001:
		rate = config.ground_decel
	if move_velocity.dot(desired) < 0.0:
		rate = config.turn_decel
	move_velocity = move_velocity.move_toward(desired, rate * delta)
	move_velocity.y = 0.0


## Air control (D-02): toward direction * air_speed_cap with air_accel, toward zero with air_decel without input.
func accelerate_air(direction: Vector3, delta: float) -> void:
	if direction == Vector3.ZERO:
		move_velocity = move_velocity.move_toward(Vector3.ZERO, config.air_decel * delta)
	else:
		var desired: Vector3 = Vector3(direction.x, 0.0, direction.z) * air_speed_cap
		move_velocity = move_velocity.move_toward(desired, config.air_accel * delta)
	move_velocity.y = 0.0


## Turns VisualRoot toward `direction` (the Mannequin faces +Z).
## Called from state physics_update so the rotation happens inside the physics tick.
func face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(direction.x, direction.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, minf(config.turn_rate * delta, 1.0))


## Snaps the VisualRoot yaw toward `direction` without turning.
func face_now(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	visual_root.rotation.y = atan2(direction.x, direction.z)


## Places the body, zeroes all motion and clears the interpolation streak (call order matters).
func teleport(new_position: Vector3) -> void:
	global_position = new_position
	move_velocity = Vector3.ZERO
	vertical_speed = 0.0
	velocity = Vector3.ZERO
	_was_on_floor = false
	reset_physics_interpolation()


## The nearest CameraRig above `node`, or null.
func _find_rig(node: Node) -> CameraRig:
	var current: Node = node.get_parent()
	while current != null:
		var rig := current as CameraRig
		if rig != null:
			return rig
		current = current.get_parent()
	return null


## True while a jump press is remembered.
func wants_jump() -> bool:
	return jump_buffer_timer > 0.0


## Spends the remembered press and the coyote window. Every jump calls this first.
func consume_jump() -> void:
	jump_buffer_timer = 0.0
	coyote_timer = 0.0


## True while a ground jump is still allowed after walking off a ledge.
func can_coyote_jump() -> bool:
	return coyote_timer > 0.0


## True when a dash may start: the cooldown has elapsed, and on the ground always, in the air only while
## the air dash of this airtime is unspent (D-12).
func can_dash() -> bool:
	if dash_cooldown_timer > 0.0:
		return false
	return is_grounded() or air_dash_available


## Called by the Dash state on enter: starts the cooldown, spends the air dash when airborne and remembers
## the direction (the long jump of a later plan reads it).
func start_dash(direction: Vector3, in_air: bool) -> void:
	dash_cooldown_timer = config.dash_cooldown
	if in_air:
		air_dash_available = false
	last_dash_direction = direction


## Called by Jump on enter for every ground jump (also coyote and buffered landing jumps). Returns the stage of
## this jump: 2 after Jump 1 and 3 after Jump 2 inside the open landing window, otherwise 1 (also after Jump 3,
## which starts a new chain, A8). The window closes; it reopens on landing.
func advance_chain_for_ground_jump() -> int:
	var stage: int = chain_stage + 1 if (chain_stage == 1 or chain_stage == 2) and chain_timer > 0.0 else 1
	chain_timer = 0.0
	_set_chain_stage(stage)
	return stage


## Called by LongJump on enter. Returns the chain stage the long jump spends (0..2) and resets the chain.
## Jump 3 counts as stage 2 here; the dash hop stack replaces this feed in a later step.
func take_chain_for_long_jump() -> int:
	var stage: int = mini(chain_stage, 2)
	chain_timer = 0.0
	_set_chain_stage(0)
	return stage


## A ground dash inside the open landing window keeps the stage and restarts the window (D-05).
func refresh_chain_window() -> void:
	if chain_stage > 0 and chain_timer > 0.0:
		chain_timer = config.chain_window


## A ground dash that ended on the ground keeps an open window alive at least through the long jump grace, so
## a jump pressed late in the grace still finds its chain stage.
func hold_chain_through_grace() -> void:
	if chain_stage > 0 and chain_timer > 0.0:
		chain_timer = maxf(chain_timer, config.dash_jump_grace)


func _set_chain_stage(stage: int) -> void:
	if stage == chain_stage:
		return
	chain_stage = stage
	EventBus.chain_stage_changed.emit(stage)


## Per-tick timers (coyote, buffer, dash cooldown, long jump grace, chain). Runs before the states, so every state
## sees the same timers. Polling just_pressed in the physics tick catches presses between two ticks.
func _tick_timers(delta: float) -> void:
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	dash_jump_grace_timer = maxf(dash_jump_grace_timer - delta, 0.0)
	_tick_chain(delta)
	if Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = config.jump_buffer_time


## The chain window counts down on the ground and resets the stage at 0. Standing still on the ground (below
## chain_reset_speed, outside a dash) resets it at once (D-07).
func _tick_chain(delta: float) -> void:
	if chain_stage == 0 or not is_grounded():
		return
	chain_timer = maxf(chain_timer - delta, 0.0)
	var standing: bool = horizontal_speed() < config.chain_reset_speed and state_machine.current.name != &"Dash"
	if chain_timer <= 0.0 or standing:
		chain_timer = 0.0
		_set_chain_stage(0)


func _integrate(delta: float) -> void:
	floor_max_angle = deg_to_rad(config.floor_max_angle_deg)
	var g: float = config.gravity() * gravity_scale
	if vertical_speed < 0.0:
		g *= config.fall_multiplier
	# Half-step gravity around the move keeps the jump height tick-rate independent.
	vertical_speed = maxf(vertical_speed - g * delta * 0.5, -config.terminal_speed)
	velocity = Vector3(move_velocity.x, vertical_speed, move_velocity.z)
	# Speed-scaled floor snap, held inside the D-13 band (A35).
	var snap: float = horizontal_speed() * delta * tan(floor_max_angle) + 0.1
	floor_snap_length = clampf(snap, config.snap_min, maxf(config.snap_min, config.snap_max))
	move_and_slide()
	vertical_speed = maxf(vertical_speed - g * delta * 0.5, -config.terminal_speed)
	_post_move()


func _post_move() -> void:
	var on_floor: bool = is_on_floor()
	if is_on_ceiling() and vertical_speed > 0.0:
		vertical_speed = 0.0
	if is_on_wall():
		var wall_normal: Vector3 = get_wall_normal()
		var into_wall: float = move_velocity.dot(wall_normal)
		if into_wall < 0.0:
			move_velocity -= wall_normal * into_wall
			move_velocity.y = 0.0
	if on_floor and not _was_on_floor:
		_land(maxf(-vertical_speed, 0.0))
	if _was_on_floor and not on_floor:
		_leave_floor()
	if on_floor:
		vertical_speed = 0.0
		_last_platform_velocity = get_platform_velocity()
	_was_on_floor = on_floor


func _land(impact_speed: float) -> void:
	air_dash_available = true
	coyote_timer = 0.0
	if chain_stage > 0:
		chain_timer = config.chain_window
	EventBus.landed.emit(global_position, impact_speed)


func _leave_floor() -> void:
	# Coyote time starts only when the body walked off (a jump take-off leaves with upward speed).
	if vertical_speed <= 0.0:
		coyote_timer = config.coyote_time
	move_velocity.x += _last_platform_velocity.x * config.platform_carry
	move_velocity.z += _last_platform_velocity.z * config.platform_carry
	air_speed_cap = maxf(config.run_speed, horizontal_speed())
