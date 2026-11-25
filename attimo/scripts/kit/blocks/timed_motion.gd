class_name TimedMotion
extends KitBlock
## Timed motion block (Phase 05.1, KIT-01, D-07, D-09, D-11): a deck that moves on its own clock. Profiles (TimedMotionConfig.Profile):
## SWEEP is the clock-hand platform, a hand pivoted at one end that sweeps back and forth about the block's local X axis; TILT is the
## tilting platform, a plate pivoted in its centre that rocks about local X. Both swing as limit * sin(phase), clamped 10 degrees
## below the player's floor angle, so a rider never inverts and never slides off by physics. ALWAYS_ON runs from _ready (D-07),
## SWITCHED runs while a child Receiver is on (plan 05.1-14).
##
## Carry contract (folded unchanged from the old rotating platform, D-09): the Body is an AnimatableBody3D in the group
## carrying_platform with sync_to_physics off, a direct child of this node. PlayerController carries the rider by reference frame
## (it re-places the rider at the same local point of the deck every tick), which needs the block to tick AFTER the player: physics
## priority 100. carry_velocity_at() is the chord of one tick, used for the take-off momentum (horizontal and, since 05.1-04,
## vertical). The block never writes the player's motion (D-17).
##
## Station rule (D-07, research reproduction 3): the lowest deck point over a full sweep must stay FLOOR_CLEARANCE above the
## surrounding floor top, or floor snap lands the rider on the static floor and the carry is lost. Stand the block at
## min_pivot_height(config, floor_top) or higher; lowest_deck_y gives the lowest deck point for any pivot height.

## Physics priority: after the player (priority 0), so the player's move sees the pose the body has in the world.
const TICK_AFTER_PLAYER: int = 100
## Floor angle assumed when no player is in the tree yet.
const FALLBACK_FLOOR_ANGLE_DEG: float = 50.0
## The swing stays this many degrees below the floor angle.
const FLOOR_ANGLE_MARGIN_DEG: float = 10.0
## The lowest deck point over a full sweep stays at least this far in m above the surrounding floor top.
const FLOOR_CLEARANCE: float = 0.3

## The block's config; the instance works on its own copy (D-12).
@export var config: TimedMotionConfig

var _speed_factor: float = 0.0
var _angle: float = 0.0
var _phase: float = 0.0
var _omega: float = 0.0
## The angular velocity of the next tick (what a rider moving before this block ticks must follow).
var _carry_omega: float = 0.0
var _axis_local: Vector3 = Vector3.RIGHT
var _rest_offset: Vector3 = Vector3.ZERO
var _limit_rad: float = 0.0
var _limit_from_player: bool = false

@onready var _body: AnimatableBody3D = $Body
@onready var _shape_node: CollisionShape3D = $Body/CollisionShape3D
@onready var _mesh_node: MeshInstance3D = get_node_or_null(^"Body/Mesh") as MeshInstance3D


func _ready() -> void:
	if config == null:
		config = TimedMotionConfig.new()
	config = own_config(config) as TimedMotionConfig
	_body.sync_to_physics = false
	_body.collision_layer = PhysicsLayers.WORLD
	_body.collision_mask = 0
	_body.add_to_group(&"carrying_platform")
	_build_shape()
	_resolve_limit()
	_apply()
	process_physics_priority = TICK_AFTER_PLAYER


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


## The deck's reach in m from the pivot: the hand length (SWEEP) or half the plate (TILT).
static func deck_reach(motion: TimedMotionConfig) -> float:
	if motion.profile == TimedMotionConfig.Profile.SWEEP:
		return motion.hand_length
	return motion.plate_size * 0.5


## The configured swing limit in degrees (the runtime floor-angle clamp can only lower it).
static func limit_deg(motion: TimedMotionConfig) -> float:
	if motion.profile == TimedMotionConfig.Profile.SWEEP:
		return motion.sweep_limit_deg
	return motion.tilt_limit_deg


## How far in m the deck reaches below the pivot over a full sweep (reach * sin(limit) + thickness, a safe upper bound).
static func deck_drop(motion: TimedMotionConfig) -> float:
	return deck_reach(motion) * sin(deg_to_rad(limit_deg(motion))) + motion.plate_thickness


## The lowest deck point (world y) over a full sweep for a block whose pivot stands at `pivot_y`.
static func lowest_deck_y(motion: TimedMotionConfig, pivot_y: float) -> float:
	return pivot_y - deck_drop(motion)


## The lowest pivot height that keeps the whole sweep FLOOR_CLEARANCE above a floor whose top is at `floor_top`.
static func min_pivot_height(motion: TimedMotionConfig, floor_top: float) -> float:
	return floor_top + FLOOR_CLEARANCE + deck_drop(motion)


## The world-space displacement per second (chord) of the deck point under `point` over one tick of length `delta`.
## Built from the rotation of the last tick (the rider's world); Vector3.ZERO for a bad delta.
func carry_velocity_at(point: Vector3, delta: float) -> Vector3:
	if delta <= 0.0 or not is_finite(delta) or not point.is_finite():
		return Vector3.ZERO
	var relative: Vector3 = point - global_position
	var axis: Vector3 = (global_basis * _axis_local).normalized()
	return (Basis(axis, _carry_omega * delta) * relative - relative) / delta


## Current angular velocity in rad/s about the deck axis (signed).
func angular_velocity() -> float:
	return _omega


## Current rotation angle in radians about the deck axis.
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


## The speed target: 1 while running. ALWAYS_ON always runs (D-07); SWITCHED runs while a child Receiver (plan 05.1-14) is on.
func _target() -> float:
	if config.timing == TimedMotionConfig.Timing.ALWAYS_ON:
		return 1.0
	var receiver: Node = get_node_or_null(^"Receiver")
	if receiver != null and receiver.has_method(&"is_on") and bool(receiver.call(&"is_on")):
		return 1.0
	return 0.0


## The state after one more tick of `delta`: x = speed factor, y = phase, z = angle. Pure, nothing is stored.
func _next_state(delta: float) -> Vector3:
	var factor: float = move_toward(_speed_factor, _target(), delta / maxf(config.ramp_time, 0.01))
	var phase: float = wrapf(_phase + _phase_rate() * factor * delta, -PI, PI)
	return Vector3(factor, phase, _limit_rad * sin(phase))


func _phase_rate() -> float:
	return config.angular_speed / maxf(_limit_rad, 0.01)


## The swing never exceeds floor_max_angle - 10 degrees.
func _resolve_limit() -> void:
	var cap: float = FALLBACK_FLOOR_ANGLE_DEG
	var player: PlayerController = get_tree().get_first_node_in_group(&"player") as PlayerController if is_inside_tree() else null
	if player != null and player.config != null:
		cap = player.config.floor_max_angle_deg
		_limit_from_player = true
	_limit_rad = deg_to_rad(minf(limit_deg(config), cap - FLOOR_ANGLE_MARGIN_DEG))


## Shape and mesh of this instance's profile. Fresh resources, the scene's are shared between instances. The top face passes
## through the pivot (the shape sits half its thickness below the body origin).
func _build_shape() -> void:
	var thickness: float = config.plate_thickness
	var size: Vector3 = Vector3(config.plate_size, thickness, config.plate_size)
	_rest_offset = Vector3.ZERO
	if config.profile == TimedMotionConfig.Profile.SWEEP:
		size = Vector3(config.hand_width, thickness, config.hand_length)
		_rest_offset = Vector3(0.0, 0.0, config.hand_length * 0.5)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	_shape_node.shape = box
	_shape_node.position = Vector3(0.0, -thickness * 0.5, 0.0)
	if _mesh_node != null:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		_mesh_node.mesh = mesh
		_mesh_node.position = Vector3(0.0, -thickness * 0.5, 0.0)


func _apply() -> void:
	var rotation_basis: Basis = Basis(_axis_local, _angle)
	_body.transform = Transform3D(rotation_basis, rotation_basis * _rest_offset)
