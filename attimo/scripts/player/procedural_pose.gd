class_name ProceduralPose
extends Node
## Code-driven body motion the animation kit has no clip for (MOVE-09): the forward lean of a ground dash (D-01), that eases back
## to upright when the dash hands over to a long jump, the twitch of a refused dash press (quick 261120-dik), and the single pirouette of Jump 3 and of long jump
## stage 3 (D-05, D-07). An air dash adds no lean (D-02), and neither does a ground dash shown as the
## retargeted Running_Slide (DEV-04), whose own pose would clash with a body pitch about the hip pivot (the extended lead
## foot would sink into the floor). The held long-jump stretch lean of D-04 was dropped after the
## Phase 3 gym check: at 60 degrees the body lay almost horizontal in the air (quick task 261118-okz). It is presentation only: it reads the FSM and the player, writes
## nothing back and never delays any input.
##
## The pose is written on the Mannequin child of VisualRoot, not on VisualRoot itself (DEV-01, confirmed by the
## developer on 2026-11-14). PlayerController.face(), Dash, LongJump and CameraRig.recenter() read VisualRoot's yaw as
## the facing, so a lean or a spin there would corrupt them. The Mannequin transform is a rotation about the pivot
## p = (0, pose_pivot_height, 0), so the body tilts and turns about its hips and not about its feet. It is written in
## _physics_process only (the Player is interpolated, so a write in _process would jitter or be ignored).
## Easing is hand-written with move_toward.
##
## Lean: the angle eases toward a target per state (ground dash: dash_lean_deg, otherwise 0) at dash_lean_deg per
## lean_in_time when it grows and per lean_out_time when it shrinks. It always eases from where it is, so Dash into
## LongJump (the dash hop) eases the lean back to upright with no pop and the long jump itself stays upright.
##
## Pirouette: a spin of one full turn about the vertical axis. A closed-loop rate (the remaining angle over the
## predicted time to touchdown minus pirouette_lead_time) finishes it just before landing, also after a released
## (cut) jump. DEV-03 (approved by the developer on 2026-11-15, an amendment of D-05 and D-07, aim part removed in phase 05):
## a Loader press, an air dash or the landing during a running pirouette puts the spin into finish mode: the remaining angle
## is completed in pirouette_finish_time, forward, never snapped back.

## A spin this close to a full turn in radians counts as complete (about one degree).
const SPIN_DONE_EPSILON: float = 0.02
## Smallest divisor of the spin rate in seconds (T-03-10: the closed loop never divides by a vanishing time).
const MIN_SPIN_TIME: float = 0.05
## Smallest twitch duration in seconds (the half sine never divides by a vanishing time).
const MIN_TWITCH_TIME: float = 0.01
## Smallest lean in degrees the ease rate is scaled by, so a dash_lean_deg of 0 never gives a zero rate.
const MIN_LEAN_REFERENCE_DEG: float = 1.0
## Smallest distance in m the head bone keeps from the wall face during a wall-run (05.1-03, D-06). The wall-run roll lean is clamped
## to the largest angle that keeps it, from the head bone's rest height above the pose pivot and the capsule-to-wall distance
## (collision radius plus the contact skin), so the clamp is geometric and adds no tuning number. MovementConfig.wall_run_lean_deg
## stays the upper bound (unattended decision 2: the value is not changed, the clamp is pose only).
const WALL_RUN_HEAD_CLEARANCE: float = 0.45

@export var player: PlayerController
@export var mannequin: Node3D
## True: the spin turns about the tilted body axis (a corkscrew). False: the tilted body spins about the vertical axis
## (a tilted top). Judged in the gym check (research A4).
@export var spin_about_body_axis: bool = true
## True: the pirouette turns clockwise seen from above (Claude's discretion, D-07).
@export var pirouette_clockwise: bool = true
## Longest time in seconds a full pirouette may take; 0 is off (the spin spreads over the whole flight, the developer
## kept that speed on 2026-11-18). Above 0 the spin turns at least TAU per
## this time, so on a long airtime it finishes early instead of stretching over the whole flight.
@export_range(0.0, 1.5, 0.05) var pirouette_max_time: float = 0.0

## Current forward lean in radians, 0 upright. Read-only for others.
var lean_angle: float = 0.0
## Axis of the lean in VisualRoot space (unit length).
var lean_axis: Vector3 = Vector3.RIGHT
## Current blocked-dash twitch in radians, 0 at rest (quick 261120-dik). A refused dash press kicks the body forward by
## dash_blocked_twitch_deg and back inside dash_blocked_twitch_time (a half sine), on top of lean_angle. Read-only for others.
var twitch_angle: float = 0.0
## Current spin angle in radians, 0 to TAU. Read-only for others.
var spin_angle: float = 0.0
## True while a pirouette runs. Read-only for others.
var spinning: bool = false

var _machine: StateMachine
var _written_identity: bool = true
var _takeoff_y: float = 0.0
var _finishing: bool = false
var _finish_rate: float = 0.0
## World axis of the wall-run roll lean while it is set or still easing out, else ZERO.
var _wall_axis: Vector3 = Vector3.ZERO
## Head bone rest height in m above the VisualRoot origin, NAN when the bone is missing (then the shipped lean is used, T-05.1-09).
var _head_height: float = NAN
## Distance in m from the capsule axis to the wall face while the capsule touches it (radius plus safe_margin).
var _wall_gap: float = NAN


func _ready() -> void:
	# The Player's own state_machine reference is set after its children are ready, so find the node.
	_machine = player.get_node(^"StateMachine") as StateMachine
	_machine.state_changed.connect(_on_state_changed)
	_measure_head_clearance()


## Reads the head bone's rest height and the capsule-to-wall distance once (no per-tick search). The Mannequin is still identity here,
## so its scale is part of the height. A missing skeleton or bone logs once and leaves the wall-run lean unclamped (T-05.1-09).
func _measure_head_clearance() -> void:
	var shape_node: CollisionShape3D = player.get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	var capsule: CapsuleShape3D = shape_node.shape as CapsuleShape3D if shape_node != null else null
	if capsule != null:
		_wall_gap = capsule.radius + player.safe_margin
	var skeletons: Array[Node] = mannequin.find_children("*", "Skeleton3D", true, false) if mannequin != null else []
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	var bone: int = skeleton.find_bone("head") if skeleton != null else -1
	if bone < 0:
		push_warning("ProceduralPose: no head bone found, the wall-run lean is not clamped by head clearance")
		return
	var head: Vector3 = skeleton.global_transform * skeleton.get_bone_global_rest(bone).origin
	# The Player's @onready visual_root is set after its children are ready, so read the node.
	var visual: Node3D = player.get_node(^"VisualRoot") as Node3D
	_head_height = (visual.global_transform.affine_inverse() * head).y


## Starts the pirouette of Jump 3 and of long jump stage 3. The stage was set by the state's enter, which runs before the signal.
func _on_state_changed(_from_state: StringName, to_state: StringName) -> void:
	var pirouette_jump: bool = (to_state == &"Jump" and player.chain_stage == 3) or (to_state == &"LongJump" and player.long_jump_stage == 3)
	if pirouette_jump:
		spinning = true
		spin_angle = 0.0
		_finishing = false
		_takeoff_y = player.global_position.y


## Eases the lean, runs the spin and writes the Mannequin transform.
func _physics_process(delta: float) -> void:
	var config: MovementConfig = player.config
	var target: float = deg_to_rad(_lean_target_deg(config))
	var full: float = deg_to_rad(maxf(config.dash_lean_deg, MIN_LEAN_REFERENCE_DEG))
	var time: float = config.lean_in_time if target > lean_angle else config.lean_out_time
	lean_angle = move_toward(lean_angle, target, full / time * delta)
	twitch_angle = _twitch_for(config)
	_update_axis()
	_tick_spin(delta, config)
	if not is_finite(lean_angle) or not is_finite(spin_angle) or not is_finite(twitch_angle):
		lean_angle = 0.0
		twitch_angle = 0.0
		spin_angle = 0.0
		spinning = false
	_write(config)


## The Mannequin rotation for the current lean and spin: the spin about the vertical axis, nested inside the lean (a
## corkscrew about the body axis) or around it (a tilted top), see spin_about_body_axis.
func pose_basis() -> Basis:
	var lean: Basis = Basis(lean_axis, total_lean())
	var turn_sign: float = -1.0 if pirouette_clockwise else 1.0
	var spin: Basis = Basis(Vector3.UP, turn_sign * spin_angle)
	if spin_about_body_axis:
		return lean * spin
	return spin * lean


## The lean written to the body: the eased lean plus the blocked-dash twitch.
func total_lean() -> float:
	return lean_angle + twitch_angle


## The twitch kick of this tick: a half sine over the controller's twitch timer, exactly 0 when it has run out.
func _twitch_for(config: MovementConfig) -> float:
	if player.dash_twitch_timer <= 0.0:
		return 0.0
	var duration: float = maxf(config.dash_blocked_twitch_time, MIN_TWITCH_TIME)
	var progress: float = clampf(1.0 - player.dash_twitch_timer / duration, 0.0, 1.0)
	return deg_to_rad(config.dash_blocked_twitch_deg) * sin(PI * progress)


## Lean target in degrees for the current state: an aimed ground dash leans forward and a wall-run rolls toward the wall (head
## clearance clamp, 05.1-03). An air dash, the unaimed ground dash (the slide), the long jump that follows a dash and everything else
## are upright (D-02, DEV-04).
func _lean_target_deg(config: MovementConfig) -> float:
	if _machine.current.name == &"WallRun":
		return wall_run_lean_limit_deg(config)
	if _machine.current.name != &"Dash" or bool(_machine.current.get(&"in_air")) or bool(_machine.current.get(&"slide")):
		return 0.0
	return config.dash_lean_deg


## The wall-run roll lean in degrees: wall_run_lean_deg, clamped to the largest lean that keeps the head bone
## WALL_RUN_HEAD_CLEARANCE from the wall face. A lean about the pivot moves the head toward the wall by (head height above the pivot)
## x sin(lean), so the limit is asin((wall gap - clearance) / arm), its argument clamped to [-1, 1] (T-05.1-08). Without the bone
## data, or with the head at or below the pivot, the shipped lean is used.
func wall_run_lean_limit_deg(config: MovementConfig) -> float:
	var shipped: float = config.wall_run_lean_deg
	if not is_finite(_head_height) or not is_finite(_wall_gap):
		return shipped
	var arm: float = _head_height - config.pose_pivot_height
	if arm <= 0.0:
		return shipped
	var ratio: float = clampf((_wall_gap - WALL_RUN_HEAD_CLEARANCE) / arm, -1.0, 1.0)
	var limit: float = rad_to_deg(asin(ratio))
	if not is_finite(limit):
		return 0.0
	return clampf(shipped, 0.0, maxf(limit, 0.0))


## True while the running state is a Dash that started in the air.
func _air_dash_running() -> bool:
	return _machine.current.name == &"Dash" and bool(_machine.current.get(&"in_air"))


## Keeps lean_axis on up x travel direction, expressed in VisualRoot space. With no direction the last axis is kept
## while the lean eases out, and the facing is used once upright.
func _update_axis() -> void:
	# Wall-run roll lean (MOVE-12): the axis wall normal x up tilts the body toward the wall. The world axis is kept while the lean
	# eases out, so the recovery rolls back about the same axis even after the facing or the velocity changed.
	if _machine.current.name == &"WallRun":
		_wall_axis = player.wall_normal.cross(Vector3.UP)
	elif lean_angle == 0.0 or _machine.current.name == &"Dash":
		# A dash wants its own forward lean; keeping the wall axis would lean the whole dash sideways (WR-06).
		_wall_axis = Vector3.ZERO
	if _wall_axis.length_squared() > 0.0001:
		var wall_local: Vector3 = player.visual_root.global_basis.orthonormalized().inverse() * _wall_axis
		if wall_local.length_squared() > 0.0001:
			lean_axis = wall_local.normalized()
		return
	var direction: Vector3 = Vector3.ZERO
	if _machine.current.name == &"Dash":
		direction = _machine.current.get(&"direction") as Vector3
	else:
		direction = Vector3(player.move_velocity.x, 0.0, player.move_velocity.z)
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		if total_lean() != 0.0:
			return
		direction = player.visual_root.global_basis.z
		direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var world_axis: Vector3 = Vector3.UP.cross(direction.normalized())
	var local_axis: Vector3 = player.visual_root.global_basis.orthonormalized().inverse() * world_axis
	if local_axis.length_squared() > 0.0001:
		lean_axis = local_axis.normalized()


## Advances a running pirouette by one tick: the closed-loop rate in flight, the fixed finish rate in finish mode.
func _tick_spin(delta: float, config: MovementConfig) -> void:
	if not spinning:
		return
	var remaining: float = TAU - spin_angle
	if not _finishing and (player.is_grounded() or player.loader_active() or _air_dash_running()):
		_begin_finish(remaining, config)
	var rate: float = _finish_rate
	if not _finishing:
		var time_left: float = _time_to_touchdown(config)
		if is_finite(time_left):
			rate = remaining / maxf(time_left - config.pirouette_lead_time, MIN_SPIN_TIME)
			if pirouette_max_time > 0.0:
				rate = maxf(rate, TAU / maxf(pirouette_max_time, MIN_SPIN_TIME))
		else:
			_begin_finish(remaining, config)
			rate = _finish_rate
	spin_angle += rate * delta
	if spin_angle >= TAU - SPIN_DONE_EPSILON:
		spinning = false
		spin_angle = 0.0
		_finishing = false


## Finish mode (DEV-03): the remaining angle is completed at a fixed rate over pirouette_finish_time.
func _begin_finish(remaining: float, config: MovementConfig) -> void:
	_finishing = true
	_finish_rate = remaining / config.pirouette_finish_time


## Seconds until the body is back at the take-off height, from the vertical speed, the height above take-off (not
## below 0) and the gravities. NAN when the prediction is not usable.
func _time_to_touchdown(config: MovementConfig) -> float:
	var height: float = maxf(player.global_position.y - _takeoff_y, 0.0)
	var speed: float = player.vertical_speed
	var fall_gravity: float = config.fall_gravity()
	if fall_gravity <= 0.0:
		return NAN
	if speed > 0.0:
		var rise_gravity: float = config.rise_gravity * player.gravity_scale
		if rise_gravity <= 0.0:
			return NAN
		var apex: float = height + speed * speed / (2.0 * rise_gravity)
		return speed / rise_gravity + sqrt(2.0 * apex / fall_gravity)
	return (-absf(speed) + sqrt(speed * speed + 2.0 * fall_gravity * height)) / fall_gravity


## Writes the Mannequin transform: exactly identity when upright, otherwise a rotation about the pivot point.
func _write(config: MovementConfig) -> void:
	if total_lean() == 0.0 and not spinning:
		if not _written_identity:
			mannequin.transform = Transform3D.IDENTITY
			_written_identity = true
		return
	var pose: Basis = pose_basis()
	var pivot: Vector3 = Vector3(0.0, config.pose_pivot_height, 0.0)
	mannequin.transform = Transform3D(pose, pivot - pose * pivot)
	_written_identity = false
