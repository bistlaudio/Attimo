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
## Seconds left in which air control (steering in the air) is off, set by lock_air_control (a piston punch or a boost keeps its speed).
var air_control_lock_timer: float = 0.0
## True while the one air dash of this airtime is unspent. Landing refills it (D-12).
var air_dash_available: bool = true
## Direction of the last dash started, flattened and normalized.
var last_dash_direction: Vector3 = Vector3.ZERO
## Ground-jump chain stage: 0 none, 1 after Jump 1, 2 after Jump 2, 3 after Jump 3, the pirouette jump (D-05). Changes emit chain_stage_changed.
var chain_stage: int = 0
## Long-jump stack stage: 0 none, 1..3 the stage of the last long jump (dash hop) while the stack lives (D-05).
var long_jump_stage: int = 0
## Seconds left of the landing window in which the next ground jump advances the chain or the next ground dash
## keeps the long-jump stack. Counts down only while grounded and not dashing; at 0 both reset (D-07).
var combo_timer: float = 0.0
## Seconds left after a ground dash ended in which a jump still is a long jump (D-06).
var dash_jump_grace_timer: float = 0.0
## Seconds left of the blocked-dash twitch. ProceduralPose reads it; a refused dash press starts it.
var dash_twitch_timer: float = 0.0
## True while the Loader may start in the air: one use per airborne stretch (D-02). An airborne Loader press and a ground discharge
## that lifts off spend it; landing, refill_air_dash (boost ring, slingshot) give it back.
var loader_available: bool = true
## Seconds left before the next Loader press may start. A discharge without the bonus (empty arm) starts it at loader_redirect_cooldown.
var loader_cooldown_timer: float = 0.0

var _was_on_floor: bool = true
var _dash_block_frame: int = -1
var _last_platform_velocity: Vector3 = Vector3.ZERO
## Test-only switch: true leaves rotating platforms to the engine's own platform velocity (A2 measurement).
var debug_disable_custom_carry: bool = false
## Test and tool hook: a non-zero direction replaces the camera forward as the Loader discharge direction (the gym room tests aim
## without a mouse). ZERO keeps the camera.
var debug_loader_direction: Vector3 = Vector3.ZERO
## The mechanism root (has carry_velocity_at) of the carrying_platform body the last post-move stood on, or null.
var _floor_carrier: Node = null
var _floor_body: CollisionObject3D = null
## Our position in the local frame of _floor_body at the end of the last move.
var _carry_local: Vector3 = Vector3.ZERO
## The chord velocity applied on the last move, or ZERO. Used for the take-off momentum on a carrying platform.
var _carry_chord: Vector3 = Vector3.ZERO
var _carry_active: bool = false

## Continuous pushes recorded by push_toward this tick: direction, target speed, acceleration. Consumed in _physics_process.
var _push_directions: Array[Vector3] = []
var _push_targets: PackedFloat32Array = PackedFloat32Array()
var _push_accels: PackedFloat32Array = PackedFloat32Array()
## Smallest gravity factor requested this tick by request_gravity_scale (1.0 = none). Multiplies gravity_scale in _integrate and is
## cleared after every move, so leaving a zone needs no restore step.
var _zone_gravity_scale: float = 1.0

## Flat normal (y = 0, unit) of the last wall the move slid along, or ZERO before the first touch. Written in _post_move (MOVE-12).
var wall_normal: Vector3 = Vector3.ZERO
## The body of the last wall touched, or null. WallRun and WallJump ask it for its pad group through wall_surface.
var wall_collider: CollisionObject3D = null
## Seconds since the last wall touch (INF before the first). A touch inside config.wall_contact_grace still counts.
var wall_contact_age: float = INF
## The horizontal move_velocity of the last tick, read before the wall clamp took the into-wall part away (the approach speed, Pitfall 5).
var wall_pre_velocity: Vector3 = Vector3.ZERO
## Seconds left before the next wall-run may start. Every WallRun exit and every WallJump sets it to config.wall_run_cooldown.
var wall_run_cooldown_timer: float = 0.0
## The Capture request of capture_along: target points of the player origin, speed, hold time at the end and the exit velocity.
var capture_points: PackedVector3Array = PackedVector3Array()
var capture_speed: float = 0.0
var capture_hold: float = 0.0
var capture_exit_velocity: Vector3 = Vector3.ZERO

## A rotating platform never carries further than this per tick (a guard against a bad transform).
const MAX_CARRY_SHIFT: float = 2.0

@onready var visual_root: Node3D = $VisualRoot
@onready var state_machine: StateMachine = $StateMachine
## The single owner of the arm energy (the Loader bonus and, from plan 05-03, every other cost and income).
@onready var arm_energy: ArmEnergy = $ArmEnergy


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
	_apply_push_requests(delta)
	state_machine.physics_update(delta)
	_integrate(delta)


## True when the last post-move found the floor (true at spawn).
func is_grounded() -> bool:
	return _was_on_floor


## Horizontal speed in m/s.
func horizontal_speed() -> float:
	return Vector2(move_velocity.x, move_velocity.z).length()


## Movement input in world space, flattened, keeping the analog magnitude (<= 1).
## Camera-relative: a camera under a CameraRig steers through the rig's steering_yaw() (A40), any other current camera
## through its own yaw. Without a camera it falls back to world axes (W = -Z).
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


## The ground run target speed for `direction` (a world-space input direction): run_speed. There is one run speed; plan 05-03 adds the
## Moto Perpetuo factor here.
func ground_target_speed(_direction: Vector3) -> float:
	return config.run_speed


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


## Air control (D-02): toward direction * air_speed_cap with air_accel, toward zero with air_decel without input. Does nothing while
## air_control_lock_timer runs (lock_air_control).
func accelerate_air(direction: Vector3, delta: float) -> void:
	if air_control_lock_timer > 0.0:
		return
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


## Snaps the VisualRoot yaw toward `direction` without turning (Dash, LongJump and WallRun face their direction at once).
func face_now(direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	visual_root.rotation.y = atan2(direction.x, direction.z)


## Respawn after a fall (ENRG-01: always with one core): teleport() plus the arm back at its checkpoint energy. teleport() itself stays
## a pure test utility that leaves the energy alone.
func respawn(new_position: Vector3) -> void:
	teleport(new_position)
	arm_energy.reset_to_checkpoint()


## Places the body, zeroes all motion, hands the FSM to Fall and clears the interpolation streak (call order matters).
## The Fall hand-over ends a running Capture, WallRun or Dash through its exit() (gravity_scale restored), so a respawn
## does not keep steering, sliding or dashing (WR-02).
func teleport(new_position: Vector3) -> void:
	global_position = new_position
	velocity = Vector3.ZERO
	_was_on_floor = false
	if state_machine != null and state_machine.current != null:
		_enter_fall()
	# After the Fall hand-over: exit() hooks may touch the motion.
	move_velocity = Vector3.ZERO
	vertical_speed = 0.0
	reset_physics_interpolation()


## The CameraRig of the viewport's current camera, or null without one. The lookup for the hand and the Phase 4 beam:
## rig.aim_target_point() is the world point under the crosshair.
func camera_rig() -> CameraRig:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return null
	return _find_rig(camera)


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


## Why a dash is locked right now, or &"" when no lockout applies (quick 261120-dik, reduced by quick 261120-ef9, aim removed in
## phase 05). The one place both the ground and the air states ask. There is no lockout today; plan 05-03 adds the energy reason
## for an unaffordable air dash. The pirouette, the landing and the take-off never lock the dash (a dash hop on the landing tick
## works). The cooldown and the air dash charge are not lockouts.
func dash_locked_reason() -> StringName:
	return &""


## True when a dash may start: no lockout, the cooldown has elapsed, and on the ground always, in the air only while
## the air dash of this airtime is unspent (D-12).
func can_dash() -> bool:
	if dash_locked_reason() != &"":
		return false
	if dash_cooldown_timer > 0.0:
		return false
	return is_grounded() or air_dash_available


## The dash press check of the ground and the air states. True when a dash press this tick may start the Dash. A press
## refused by a lockout is consumed here, once: it emits EventBus.dash_blocked, starts the twitch and returns false. It spends
## no cooldown and no air dash charge and is not buffered (a press during a lockout never fires after it ends).
func dash_press_starts_dash() -> bool:
	if not Input.is_action_just_pressed(&"dash"):
		return false
	var reason: StringName = dash_locked_reason()
	if reason != &"":
		_block_dash(reason)
		return false
	return can_dash()


func _block_dash(reason: StringName) -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _dash_block_frame:
		return
	_dash_block_frame = frame
	dash_twitch_timer = config.dash_blocked_twitch_time
	EventBus.dash_blocked.emit(global_position, reason)


## The Loader press check of the ground and the air states, Dash and WallRun (D-01). True when a loader press this tick may start
## the Loader: the cooldown of an empty-arm redirect has elapsed, and Rino stands on the floor or the airborne use is still available
## (D-02). Capture never asks. Like the dash press it polls just_pressed, so the press is not buffered.
func loader_press_starts_loader() -> bool:
	if not Input.is_action_just_pressed(&"loader"):
		return false
	if loader_cooldown_timer > 0.0:
		return false
	return is_grounded() or loader_available


## The unit direction a Loader discharge (and its preview) goes: the forward of the current camera, up included (A8). Without a
## camera, or with a degenerate one, the facing of VisualRoot.
func loader_direction() -> Vector3:
	if debug_loader_direction.is_finite() and debug_loader_direction.length_squared() > 0.0001:
		return debug_loader_direction.normalized()
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var forward: Vector3 = -camera.global_basis.z
		if forward.is_finite() and forward.length_squared() > 0.0001:
			return forward.normalized()
	var facing: Vector3 = visual_root.global_basis.z
	facing.y = 0.0
	if not facing.is_finite() or facing.length_squared() < 0.0001:
		return Vector3.FORWARD
	return facing.normalized()


## True while the FSM is in the Loader state.
func loader_active() -> bool:
	return state_machine.current != null and state_machine.current.name == &"Loader"


## The Loader state node (its read-only helpers feed the presentation), or null without one.
func loader_state() -> LoaderState:
	return state_machine.get_node_or_null(^"Loader") as LoaderState


## Called by the Dash state on enter: starts the cooldown, spends the air dash when airborne and remembers
## the direction (the long jump of a later plan reads it).
func start_dash(direction: Vector3, in_air: bool) -> void:
	dash_cooldown_timer = config.dash_cooldown
	if in_air:
		air_dash_available = false
	last_dash_direction = direction


## One-shot launch (steam nozzle jump and cannon, D-20): sets the velocity along `direction` to exactly `speed` and keeps the
## sideways momentum (`keep_sideways` true), so height and distance repeat. With `keep_sideways` false the velocity becomes
## exactly direction * speed (a pad that decides the whole path). Leaves Dash, LongJump and Jump for Fall. The air dash and the
## landing chain are not touched. Mechanisms call this with call_deferred (never inside the physics flush). A bad vector is ignored.
func launch_along(direction: Vector3, speed: float, keep_sideways: bool = true) -> void:
	if not direction.is_finite() or not is_finite(speed) or direction.length_squared() < 0.0001:
		return
	var dir: Vector3 = direction.normalized()
	var v: Vector3 = Vector3(move_velocity.x, vertical_speed, move_velocity.z)
	if keep_sideways:
		v = v - dir * v.dot(dir) + dir * speed
	else:
		v = dir * speed
	move_velocity = Vector3(v.x, 0.0, v.z)
	vertical_speed = clampf(v.y, -config.terminal_speed, config.terminal_speed)
	coyote_timer = 0.0
	air_speed_cap = maxf(config.run_speed, horizontal_speed())
	_enter_fall()
	EventBus.launched.emit(global_position, dir, speed)


## One-shot boost (boost ring, bounce pad, D-06): raises the velocity component along `direction` to at least `min_speed` after
## adding `add` (`maxf(along + add, min_speed)`), so a boost never slows a faster player. The rest of the velocity is kept.
## Leaves Dash, LongJump and Jump for Fall, lifts the air cap to the new speed and emits EventBus.boosted. Mechanisms call this
## with call_deferred. A non-finite argument or a zero direction is ignored.
func boost_along(direction: Vector3, min_speed: float, add: float = 0.0) -> void:
	if not direction.is_finite() or not is_finite(min_speed) or not is_finite(add) or direction.length_squared() < 0.0001:
		return
	var dir: Vector3 = direction.normalized()
	var v: Vector3 = Vector3(move_velocity.x, vertical_speed, move_velocity.z)
	var along: float = v.dot(dir)
	var new_along: float = maxf(along + add, min_speed)
	v += dir * (new_along - along)
	move_velocity = Vector3(v.x, 0.0, v.z)
	vertical_speed = clampf(v.y, -config.terminal_speed, config.terminal_speed)
	coyote_timer = 0.0
	air_speed_cap = maxf(config.run_speed, horizontal_speed())
	_enter_fall()
	EventBus.boosted.emit(global_position, dir, new_along)


## Gives the air dash back (boost ring, D-06): the charge is available and the cooldown is gone, so a dash can start at once.
## The Loader use of this airtime comes back with it (D-02; the Loader itself never calls this, D-03). Emits EventBus.dash_refilled. Mechanisms call this with call_deferred.
func refill_air_dash() -> void:
	air_dash_available = true
	loader_available = true
	dash_cooldown_timer = 0.0
	EventBus.dash_refilled.emit(global_position)


## Switches air control off for `seconds` (a knock or a punch keeps its speed against steering). Several calls keep the longest
## time. Non-finite or negative seconds are ignored. Air control resumes by itself, no restore call is needed.
func lock_air_control(seconds: float) -> void:
	if not is_finite(seconds) or seconds < 0.0:
		return
	air_control_lock_timer = maxf(air_control_lock_timer, seconds)


## Continuous push (steam updraft and wall, D-20): moves the velocity component along `direction` toward `target_speed` by
## `accel` per second. Safe to call straight from a mechanism's _physics_process every tick: it only records a request that
## this controller applies in its own next _physics_process, so no outside code writes the velocity.
func push_toward(direction: Vector3, target_speed: float, accel: float) -> void:
	if not direction.is_finite() or not is_finite(target_speed) or not is_finite(accel):
		return
	if direction.length_squared() < 0.0001 or accel <= 0.0:
		return
	_push_directions.append(direction.normalized())
	_push_targets.append(target_speed)
	_push_accels.append(accel)


## Knock-back (pendulum, D-21): adds `impulse` to the velocity (the caller supplies the upward part), interrupts a dash and
## leaves the floor states for Fall. No damage. Mechanisms call this with call_deferred.
func knock_back(impulse: Vector3) -> void:
	if not impulse.is_finite():
		return
	move_velocity += Vector3(impulse.x, 0.0, impulse.z)
	vertical_speed = clampf(vertical_speed + impulse.y, -config.terminal_speed, config.terminal_speed)
	coyote_timer = 0.0
	air_speed_cap = maxf(air_speed_cap, horizontal_speed())
	_enter_fall()
	EventBus.knocked_back.emit(global_position, impulse)


## Gravity request of a zone (low gravity, D-06): scales gravity by `scale` (clamped to 0.05..1.0) for this tick only. Safe to call
## straight from a mechanism's _physics_process every tick; the smallest request of a tick wins. It never touches gravity_scale
## (the Dash state owns that field) and needs no restore: the factor is cleared after every move. A non-finite scale is ignored.
func request_gravity_scale(scale: float) -> void:
	if not is_finite(scale):
		return
	_zone_gravity_scale = minf(_zone_gravity_scale, clampf(scale, 0.05, 1.0))


## True while the last wall touched belongs to `group` (a pad group, D-09) and the touch is not older than config.wall_contact_grace.
func wall_surface(group: StringName) -> bool:
	if wall_collider == null or not is_instance_valid(wall_collider):
		return false
	return wall_contact_age <= config.wall_contact_grace and wall_collider.is_in_group(group)


## Flat unit direction along the last wall, signed toward the way the approach velocity went (the facing when the approach was
## almost head-on). ZERO without a wall.
func wall_tangent() -> Vector3:
	var tangent: Vector3 = Vector3.UP.cross(wall_normal)
	if tangent.length_squared() < 0.0001:
		return Vector3.ZERO
	tangent = tangent.normalized()
	var along: float = wall_pre_velocity.dot(tangent)
	if absf(along) < 0.1:
		var facing: Vector3 = visual_root.global_basis.z
		along = facing.dot(tangent)
	return tangent if along >= 0.0 else -tangent


## True when a wall-run may start now: airborne, on a wall-run pad, fast enough on approach (wall_pre_velocity) and not in the cooldown (MOVE-12).
func can_wall_run() -> bool:
	if is_grounded() or wall_run_cooldown_timer > 0.0 or not wall_surface(&"wall_run_surface"):
		return false
	var flat: Vector2 = Vector2(wall_pre_velocity.x, wall_pre_velocity.z)
	return flat.length() >= config.wall_run_min_speed


## True when a remembered jump press may become a wall-jump now: airborne, touching a wall-jump pad and not in the cooldown (D-09).
## A jump during WallRun is decided by the WallRun state itself.
func can_wall_jump() -> bool:
	if is_grounded() or wall_run_cooldown_timer > 0.0 or not wants_jump():
		return false
	return wall_surface(&"wall_jump_surface")


## Capture request (slingshot core, pneumatic tube, D-06): the Capture state carries the player origin through `points` at `speed`,
## holds `hold_time` at the last point and lets go with `exit_velocity`. Mechanisms call this with call_deferred. Empty or non-finite
## input, a non-positive speed and a request while already captured are ignored.
func capture_along(points: PackedVector3Array, speed: float, hold_time: float, exit_velocity: Vector3) -> void:
	if points.is_empty() or not is_finite(speed) or speed <= 0.0:
		return
	if not is_finite(hold_time) or hold_time < 0.0 or not exit_velocity.is_finite():
		return
	for point: Vector3 in points:
		if not point.is_finite():
			return
	if state_machine.current.name == &"Capture":
		return
	capture_points = points
	capture_speed = speed
	capture_hold = hold_time
	capture_exit_velocity = exit_velocity
	state_machine.transition_to(&"Capture")


func _enter_fall() -> void:
	if state_machine.current.name != &"Fall":
		state_machine.transition_to(&"Fall")


## Applies and clears the pushes recorded since the last tick (see push_toward). A push that lifts the player off the floor
## or out of a dash ends in Fall.
func _apply_push_requests(delta: float) -> void:
	if _push_directions.is_empty():
		return
	var lifted: bool = false
	for index: int in _push_directions.size():
		var dir: Vector3 = _push_directions[index]
		var v: Vector3 = Vector3(move_velocity.x, vertical_speed, move_velocity.z)
		var along: float = v.dot(dir)
		var next_along: float = move_toward(along, _push_targets[index], _push_accels[index] * delta)
		v += dir * (next_along - along)
		move_velocity = Vector3(v.x, 0.0, v.z)
		vertical_speed = maxf(v.y, -config.terminal_speed)
		if dir.y > 0.1 and next_along > along:
			lifted = true
	_push_directions.clear()
	_push_targets.clear()
	_push_accels.clear()
	# A push that made the player faster in the air raises the air cap, so air control does not drag it back to the old cap.
	if not is_grounded():
		air_speed_cap = maxf(air_speed_cap, horizontal_speed())
	if lifted:
		coyote_timer = 0.0
		var state_name: StringName = state_machine.current.name
		if state_name == &"Idle" or state_name == &"Run" or state_name == &"Dash":
			_enter_fall()


## Called by Jump on enter for every ground jump (also coyote and buffered landing jumps). Returns the stage of
## this jump: 2 after Jump 1 and 3 after Jump 2 inside the open landing window, otherwise 1 (also after Jump 3,
## which starts a new chain, A8). The window closes; it reopens on landing. A normal jump is a miss for the
## long-jump stack.
func advance_chain_for_ground_jump() -> int:
	var stage: int = chain_stage + 1 if (chain_stage == 1 or chain_stage == 2) and combo_timer > 0.0 else 1
	combo_timer = 0.0
	long_jump_stage = 0
	_set_chain_stage(stage)
	return stage


## Called by LongJump on enter. Returns the long-jump stage 1..3: one above the stack while it lives (a clean
## repeat), otherwise 1. The combo ends after stage 3: the stack is spent, so the next hop starts again at 1 (like
## the ground jump chain after Jump 3). Resets the ground-jump chain and closes the landing window; it reopens on landing.
func advance_long_jump_stage() -> int:
	var stage: int = long_jump_stage + 1 if long_jump_stage == 1 or long_jump_stage == 2 else 1
	long_jump_stage = stage
	combo_timer = 0.0
	_set_chain_stage(0)
	return stage


## A ground dash breaks the ground-jump chain and leaves the long-jump stack alone.
func on_ground_dash_started() -> void:
	_set_chain_stage(0)


## A ground dash that ended on the ground keeps an open stack window alive at least through the long jump grace,
## so a jump pressed late in the grace still finds its stage.
func hold_combo_through_grace() -> void:
	if long_jump_stage > 0 and combo_timer > 0.0:
		combo_timer = maxf(combo_timer, config.dash_jump_grace)


func _set_chain_stage(stage: int) -> void:
	if stage == chain_stage:
		return
	chain_stage = stage
	EventBus.chain_stage_changed.emit(stage)


## Per-tick timers (coyote, buffer, dash cooldown, long jump grace, blocked-dash twitch, landing window). Runs before the states, so every state
## sees the same timers. Polling just_pressed in the physics tick catches presses between two ticks.
func _tick_timers(delta: float) -> void:
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)
	dash_jump_grace_timer = maxf(dash_jump_grace_timer - delta, 0.0)
	dash_twitch_timer = maxf(dash_twitch_timer - delta, 0.0)
	loader_cooldown_timer = maxf(loader_cooldown_timer - delta, 0.0)
	air_control_lock_timer = maxf(air_control_lock_timer - delta, 0.0)
	wall_run_cooldown_timer = maxf(wall_run_cooldown_timer - delta, 0.0)
	_tick_combo(delta)
	if Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = config.jump_buffer_time


## The landing window counts down on the ground, not during a dash, and resets the chain and the long-jump stack
## at 0. Standing still on the ground (below combo_reset_speed, outside a dash) resets them at once (D-07).
func _tick_combo(delta: float) -> void:
	if chain_stage == 0 and long_jump_stage == 0:
		combo_timer = 0.0
		return
	if not is_grounded():
		return
	var dashing: bool = state_machine.current.name == &"Dash"
	if not dashing:
		combo_timer = maxf(combo_timer - delta, 0.0)
	var standing: bool = horizontal_speed() < config.combo_reset_speed and not dashing
	if combo_timer <= 0.0 or standing:
		combo_timer = 0.0
		long_jump_stage = 0
		_set_chain_stage(0)


func _integrate(delta: float) -> void:
	floor_max_angle = deg_to_rad(config.floor_max_angle_deg)
	var g: float = config.rise_gravity
	if vertical_speed < 0.0:
		g = config.fall_gravity()
	g *= gravity_scale * _zone_gravity_scale
	# Half-step gravity around the move keeps the jump height tick-rate independent.
	vertical_speed = maxf(vertical_speed - g * delta * 0.5, -config.terminal_speed)
	_attach_to_carrier(delta)
	velocity = Vector3(move_velocity.x, vertical_speed, move_velocity.z)
	# Speed-scaled floor snap, held inside the D-13 band (A35).
	var snap: float = horizontal_speed() * delta * tan(floor_max_angle) + 0.1
	floor_snap_length = clampf(snap, config.snap_min, maxf(config.snap_min, config.snap_max))
	if state_machine.current.name == &"Capture":
		# A captured body is carried along a path: the floor snap must not pull it back down.
		floor_snap_length = 0.0
	move_and_slide()
	vertical_speed = maxf(vertical_speed - g * delta * 0.5, -config.terminal_speed)
	_post_move(delta)
	_zone_gravity_scale = 1.0


func _post_move(delta: float) -> void:
	var on_floor: bool = is_on_floor()
	if is_on_ceiling() and vertical_speed > 0.0:
		vertical_speed = 0.0
	# Wall bookkeeping (MOVE-12) reads the approach velocity before the clamp below removes its into-wall part.
	wall_pre_velocity = move_velocity
	_track_wall_contact(delta)
	if is_on_wall():
		var hit_normal: Vector3 = get_wall_normal()
		var into_wall: float = move_velocity.dot(hit_normal)
		if into_wall < 0.0:
			move_velocity -= hit_normal * into_wall
			move_velocity.y = 0.0
	if on_floor and not _was_on_floor:
		_land(maxf(-vertical_speed, 0.0))
	if _was_on_floor and not on_floor:
		_leave_floor()
	if on_floor:
		vertical_speed = 0.0
		_last_platform_velocity = _carry_chord if _carry_active else get_platform_velocity()
		_floor_carrier = _find_floor_carrier()
		if _floor_body != null:
			_carry_local = _floor_body.global_transform.affine_inverse() * global_position
	else:
		_floor_carrier = null
	_was_on_floor = on_floor


## Remembers the last near-vertical surface the move slid along (flat normal and body) and how long ago it was touched.
func _track_wall_contact(delta: float) -> void:
	var touched: bool = false
	for index: int in get_slide_collision_count():
		var hit: KinematicCollision3D = get_slide_collision(index)
		var normal: Vector3 = hit.get_normal()
		if absf(normal.y) >= 0.1:
			continue
		var body: CollisionObject3D = hit.get_collider() as CollisionObject3D
		var flat: Vector3 = Vector3(normal.x, 0.0, normal.z)
		if body == null or flat.length_squared() < 0.0001:
			continue
		wall_normal = flat.normalized()
		wall_collider = body
		touched = true
	if touched:
		wall_contact_age = 0.0
	else:
		wall_contact_age += delta


func _land(impact_speed: float) -> void:
	air_dash_available = true
	loader_available = true
	coyote_timer = 0.0
	if chain_stage > 0 or long_jump_stage > 0:
		combo_timer = config.landing_window
	EventBus.landed.emit(global_position, impact_speed)


func _leave_floor() -> void:
	# Coyote time starts only when the body walked off (a jump take-off leaves with upward speed).
	if vertical_speed <= 0.0:
		coyote_timer = config.coyote_time
	move_velocity.x += _last_platform_velocity.x * config.platform_carry
	move_velocity.z += _last_platform_velocity.z * config.platform_carry
	air_speed_cap = maxf(config.run_speed, horizontal_speed())


## Rotating platforms (group carrying_platform), MECH-03: the rider is carried by reference frame, not by velocity. The engine
## would move it along the tangent of the platform point, which drifts outward on a circle, and a surface that moves through the
## rider's feet makes any velocity based carry double count its normal motion. So the engine carry is switched off for these
## floors (platform_floor_layers), and at the start of the tick the rider is placed at the same local point of the platform
## it stood on at the end of the last tick (the platform ticks after the player, so its body pose is the world the move sees).
## The own movement of this tick then happens on top. _carry_chord (carry_velocity_at) is only the take-off momentum.
func _attach_to_carrier(delta: float) -> void:
	_carry_chord = Vector3.ZERO
	_carry_active = false
	platform_floor_layers = 0xFFFFFFFF
	if debug_disable_custom_carry or not _was_on_floor or _floor_body == null or not is_instance_valid(_floor_body):
		return
	if _floor_carrier == null or not _floor_carrier.has_method(&"carry_velocity_at"):
		return
	var target: Vector3 = _floor_body.global_transform * _carry_local
	if not target.is_finite() or target.distance_to(global_position) > MAX_CARRY_SHIFT:
		return
	global_position = target
	_carry_active = true
	platform_floor_layers = 0
	var chord: Vector3 = _floor_carrier.call(&"carry_velocity_at", target, delta) as Vector3
	_carry_chord = chord if chord.is_finite() else Vector3.ZERO


## The mechanism root above the carrying_platform floor body of the last move, or null.
func _find_floor_carrier() -> Node:
	var floor_normal: Vector3 = get_floor_normal()
	for index: int in get_slide_collision_count():
		var hit: KinematicCollision3D = get_slide_collision(index)
		if hit.get_normal().dot(floor_normal) < 0.99:
			continue
		var collider: CollisionObject3D = hit.get_collider() as CollisionObject3D
		if collider != null and collider.is_in_group(&"carrying_platform"):
			_floor_body = collider
			return collider.get_parent()
	_floor_body = null
	return null
