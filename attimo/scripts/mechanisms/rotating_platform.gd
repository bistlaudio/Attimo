class_name RotatingPlatform
extends Mechanism
## Dreh-Plattform (MECH-03, D-16, D-22): a platform that turns about a pivot at its own origin. LYING is a gear that rotates
## continuously about the world Y axis, STANDING is a clock hand pivoted at one end that sweeps back and forth, TILTING is a
## plate pivoted in the centre that oscillates. Both bounded modes are clamped below the player's floor angle so a rider never
## inverts and never slides off by physics. The Body is an AnimatableBody3D. PlayerController carries the rider by reference frame
## (it re-places the rider at the same local point every tick), which needs this platform to tick AFTER the player: the
## physics priority below is 100. carry_velocity_at() is the chord of one tick, used for the take-off momentum.
## Rotation runs in the physics tick only. Behaviour: RUN_WHILE_ON runs while the signal is on, REVERSE_ON_SIGNAL always runs
## and the signal reverses the direction (D-18). Starts, stops and reversals are eased over ramp_time (D-22).

enum AxisMode { LYING, STANDING, TILTING }

## Size of the gear (LYING) and the tilt plate (TILTING), a square in metres.
const PLATE_SIZE: float = 8.0
const PLATE_THICKNESS: float = 0.5
## The clock hand: length from the pivot, width.
const HAND_LENGTH: float = 8.0
const HAND_WIDTH: float = 2.5
## Physics priority: after the player (priority 0), so the player's move sees the pose the body has in the world.
const TICK_AFTER_PLAYER: int = 100
## Floor angle assumed when no player is in the tree yet.
const FALLBACK_FLOOR_ANGLE_DEG: float = 50.0
## The bounded modes stay this many degrees below the floor angle.
const FLOOR_ANGLE_MARGIN_DEG: float = 10.0

@export var axis_mode: AxisMode = AxisMode.LYING
## Peak angular speed in rad/s (the constant speed of LYING).
@export_range(0.1, 6.0, 0.1) var angular_speed: float = 1.0
## Seconds a start, stop or reversal takes.
@export_range(0.0, 2.0, 0.05) var ramp_time: float = 0.3
## STANDING: the hand sweeps within +- this angle in degrees.
@export_range(5.0, 80.0, 1.0) var sweep_limit_deg: float = 35.0
## TILTING: the plate oscillates within +- this angle in degrees.
@export_range(5.0, 80.0, 1.0) var tilt_limit_deg: float = 30.0

var _speed_factor: float = 0.0
var _angle: float = 0.0
var _phase: float = 0.0
var _omega: float = 0.0
## The angular velocity of the next tick (what a rider moving before this platform ticks must follow).
var _carry_omega: float = 0.0
var _axis_local: Vector3 = Vector3.UP
var _rest_offset: Vector3 = Vector3.ZERO
var _limit_rad: float = 0.0
var _limit_from_player: bool = false

@onready var _body: AnimatableBody3D = $Body
@onready var _shape_node: CollisionShape3D = $Body/CollisionShape3D
@onready var _mesh_node: MeshInstance3D = $Body/Mesh


func _ready() -> void:
	_body.sync_to_physics = false
	_body.add_to_group(&"carrying_platform")
	_axis_local = Vector3.UP if axis_mode == AxisMode.LYING else Vector3.RIGHT
	_build_shape()
	_resolve_limit()
	_apply()
	process_physics_priority = TICK_AFTER_PLAYER
	super._ready()


func _physics_process(delta: float) -> void:
	if not _limit_from_player:
		_resolve_limit()
	var next: Vector3 = _next_state(delta)
	_speed_factor = next.x
	_phase = next.y
	var previous_angle: float = _angle
	_angle = next.z
	_omega = angle_difference(previous_angle, _angle) / maxf(delta, 0.0001)
	_apply()
	_carry_omega = _omega


## The world-space displacement per second (chord) of the platform point under `point` over one tick of length `delta`.
## Built from the rotation of the last tick (the rider's world); Vector3.ZERO for a bad delta.
func carry_velocity_at(point: Vector3, delta: float) -> Vector3:
	if delta <= 0.0 or not is_finite(delta) or not point.is_finite():
		return Vector3.ZERO
	var relative: Vector3 = point - global_position
	var axis: Vector3 = (global_basis * _axis_local).normalized()
	return (Basis(axis, _carry_omega * delta) * relative - relative) / delta


## Current angular velocity in rad/s about the platform axis (signed).
func angular_velocity() -> float:
	return _omega


## Current rotation angle in radians about the platform axis.
func current_angle() -> float:
	return _angle


## The pivot in world space.
func pivot_position() -> Vector3:
	return global_position


## The physics body (the thing the player stands on).
func body() -> AnimatableBody3D:
	return _body


func reset() -> void:
	super.reset()
	_speed_factor = 0.0
	_angle = 0.0
	_phase = 0.0
	_omega = 0.0
	_carry_omega = 0.0
	_apply()
	_body.reset_physics_interpolation()


## The state after one more tick of `delta`: x = speed factor, y = phase (bounded modes), z = angle. Pure, nothing is stored.
func _next_state(delta: float) -> Vector3:
	var target: float = 0.0
	match behaviour:
		Behaviour.RUN_WHILE_ON:
			target = 1.0 if signal_on else 0.0
		Behaviour.REVERSE_ON_SIGNAL:
			target = -1.0 if signal_on else 1.0
	var factor: float = move_toward(_speed_factor, target, delta / maxf(ramp_time, 0.01))
	if axis_mode == AxisMode.LYING:
		return Vector3(factor, _phase, wrapf(_angle + angular_speed * factor * delta, -PI, PI))
	var phase: float = wrapf(_phase + _phase_rate() * factor * delta, -PI, PI)
	return Vector3(factor, phase, _limit_rad * sin(phase))


func _phase_rate() -> float:
	return angular_speed / maxf(_limit_rad, 0.01)


## The bounded modes never exceed floor_max_angle - 10 degrees (D-22).
func _resolve_limit() -> void:
	var cap: float = FALLBACK_FLOOR_ANGLE_DEG
	var player: PlayerController = get_tree().get_first_node_in_group(&"player") as PlayerController if is_inside_tree() else null
	if player != null and player.config != null:
		cap = player.config.floor_max_angle_deg
		_limit_from_player = true
	var wanted: float = sweep_limit_deg if axis_mode == AxisMode.STANDING else tilt_limit_deg
	_limit_rad = deg_to_rad(minf(wanted, cap - FLOOR_ANGLE_MARGIN_DEG))


## Shape and mesh of this instance's mode. Fresh resources, the scene's are shared between instances.
func _build_shape() -> void:
	var size: Vector3 = Vector3(PLATE_SIZE, PLATE_THICKNESS, PLATE_SIZE)
	_rest_offset = Vector3.ZERO
	if axis_mode == AxisMode.STANDING:
		size = Vector3(HAND_WIDTH, PLATE_THICKNESS, HAND_LENGTH)
		_rest_offset = Vector3(0.0, 0.0, HAND_LENGTH * 0.5)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	_shape_node.shape = box
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_mesh_node.mesh = mesh


func _apply() -> void:
	var rotation_basis: Basis = Basis(_axis_local, _angle)
	_body.transform = Transform3D(rotation_basis, rotation_basis * _rest_offset)
