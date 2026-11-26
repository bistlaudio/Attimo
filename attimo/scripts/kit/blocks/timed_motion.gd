class_name TimedMotion
extends KitBlock
## Timed motion block (Phase 05.1, KIT-01, D-07, D-09, D-11): a deck that moves on its own clock. Profiles (TimedMotionConfig.Profile):
## SWEEP is the clock-hand platform, a hand pivoted at one end that sweeps back and forth about the block's local X axis; TILT is the
## tilting platform, a plate pivoted in its centre that rocks about local X. Both swing as limit * sin(phase), clamped 10 degrees
## below the player's floor angle, so a rider never inverts and never slides off by physics. ALWAYS_ON runs from _ready (D-07),
## SWITCHED runs while a child Receiver is on (plan 05.1-17).
## HINGE (plan 05.1-17, the drawbridge) is the third profile: a deck hinged at its +Z-pointing end that folds from raised
## (-hinge_angle_deg about local X, the +Z tip up) to flat while the Receiver is on and back when it is off, eased over hinge_time. It
## has no sin phase and no floor-angle clamp; the 0..1 fold progress lives in _speed_factor and drives _angle, _omega and
## _carry_omega, so the carry contract below holds unchanged.
##
## PATH and STEPS (plan 05.1-19) only translate: every deck is an AnimatableBody3D child of this node that follows the same carry contract.
## PATH moves path_deck_count level decks along config.path_points at path_speed (a closed route loops, an open one ping-pongs with
## path_pause at the ends); STEPS puts step_count decks in a row along local X that each reach out of a wall along local +Z by
## step_extension(i) = step_extend * (1 - cos(2 pi (t + step_phase * i) / step_period)) / 2. carry_velocity_at() then answers with the
## chord of the deck nearest to the point (decks() lists them, body() is deck 0).
##
## SWING and STAMP (plan 05.1-20) are the obstacles. SWING rotates the Body about local Z (the pendulum: `swing_amplitude_deg * sin(phase)`,
## the arm hangs below the node origin, the pivot); STAMP translates the one Body along `stamp_axis` through a cycle of `stamp_period`
## (wait with a shudder telegraph, a fast stamp out, `stamp_hold`, a slower return). Both use the scene's own shapes and meshes (no plate is
## built) and a DamagePush child watching a hit area under the Body; the carry contract below holds unchanged (a rider on a piston wall top is carried).
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
## STAMP telegraph: the sideways shudder amplitude in m.
const STAMP_SHUDDER: float = 0.03

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
## PATH and STEPS: all decks (deck 0 is the scene's Body), the local displacement per second of the last tick of each, and the clocks.
var _decks: Array[AnimatableBody3D] = []
var _deck_velocity: PackedVector3Array = PackedVector3Array()
var _path_offset: float = 0.0
var _path_dir: float = 1.0
var _pause_left: float = 0.0
var _clock: float = 0.0

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
	if config.profile == TimedMotionConfig.Profile.SWING:
		_axis_local = Vector3.BACK
	_build_shape()
	_build_decks()
	_resolve_limit()
	_angle = _rest_angle()
	_apply()
	process_physics_priority = TICK_AFTER_PLAYER


func _physics_process(delta: float) -> void:
	if translates():
		_tick_translating(delta)
		return
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
	if motion.profile == TimedMotionConfig.Profile.SWEEP or motion.profile == TimedMotionConfig.Profile.HINGE:
		return motion.hand_length
	return motion.plate_size * 0.5


## The configured swing limit in degrees (the runtime floor-angle clamp can only lower it).
static func limit_deg(motion: TimedMotionConfig) -> float:
	if motion.profile == TimedMotionConfig.Profile.SWEEP:
		return motion.sweep_limit_deg
	if motion.profile == TimedMotionConfig.Profile.HINGE:
		return motion.hinge_angle_deg
	return motion.tilt_limit_deg


## How far in m the deck reaches below the pivot over a full sweep (reach * sin(limit) + thickness, a safe upper bound).
static func deck_drop(motion: TimedMotionConfig) -> float:
	if motion.profile == TimedMotionConfig.Profile.HINGE:
		# The raised deck stands up, the flat deck lies with its top at the hinge: only the thickness reaches below.
		return motion.plate_thickness
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
	if translates():
		var index: int = _nearest_deck(point)
		return global_basis * _deck_velocity[index] if index >= 0 else Vector3.ZERO
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


## True for the profiles that only translate their decks (PATH, STEPS, STAMP).
func translates() -> bool:
	return config != null and (config.profile == TimedMotionConfig.Profile.PATH or config.profile == TimedMotionConfig.Profile.STEPS or config.profile == TimedMotionConfig.Profile.STAMP)


## True for the profiles whose shapes and meshes the look scene authors (the obstacles SWING and STAMP): no plate is built for them.
func authored_shape() -> bool:
	return config != null and (config.profile == TimedMotionConfig.Profile.SWING or config.profile == TimedMotionConfig.Profile.STAMP)


## STAMP: how far in m the body is out along its axis right now (0 .. stamp_distance), from the cycle clock.
func stamp_extension() -> float:
	return config.stamp_distance * _stamp_fraction()


## STAMP: the extension fraction 0..1 at the current clock: rest during the wait, linear out, hold, linear return.
func _stamp_fraction() -> float:
	var out_time: float = maxf(config.stamp_out_time, 0.01)
	var return_time: float = maxf(config.stamp_return_time, 0.01)
	var wait: float = maxf(config.stamp_period - out_time - config.stamp_hold - return_time, 0.0)
	var t: float = fposmod(_clock, maxf(config.stamp_period, out_time + config.stamp_hold + return_time))
	if t < wait:
		return 0.0
	t -= wait
	if t < out_time:
		return t / out_time
	t -= out_time
	if t < config.stamp_hold:
		return 1.0
	t -= config.stamp_hold
	return clampf(1.0 - t / return_time, 0.0, 1.0)


## STAMP: a small sideways shudder in the last `stamp_telegraph` seconds of the wait (the warning that the stamp comes).
func _stamp_shudder() -> Vector3:
	var out_time: float = maxf(config.stamp_out_time, 0.01)
	var wait: float = maxf(config.stamp_period - out_time - config.stamp_hold - maxf(config.stamp_return_time, 0.01), 0.0)
	var t: float = fposmod(_clock, maxf(config.stamp_period, 0.5))
	if config.stamp_telegraph <= 0.0 or t >= wait or t < wait - config.stamp_telegraph:
		return Vector3.ZERO
	var axis: Vector3 = config.stamp_axis.normalized()
	var side: Vector3 = axis.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
	return side * STAMP_SHUDDER * sin(t * 90.0)


## PATH and STEPS: all deck bodies in order (deck 0 is body()).
func decks() -> Array[AnimatableBody3D]:
	return _decks


## STEPS: how far in m step `index` reaches out of the wall right now (0 retracted .. step_extend).
func step_extension(index: int) -> float:
	var cycle: float = (_clock + config.step_phase * float(index)) / maxf(config.step_period, 0.2)
	return config.step_extend * 0.5 * (1.0 - cos(TAU * cycle))


## PATH: the length of the route in m (the closing leg of a loop is part of the points).
func path_length() -> float:
	var length: float = 0.0
	for index: int in range(1, config.path_points.size()):
		length += config.path_points[index - 1].distance_to(config.path_points[index])
	return length


## PATH: a closed route (first and last point equal) loops; an open one ping-pongs.
func path_loops() -> bool:
	var points: PackedVector3Array = config.path_points
	return points.size() >= 3 and points[0].is_equal_approx(points[points.size() - 1])


## PATH: the local point at `distance` m along the route (wrapped on a loop, clamped otherwise).
func path_point(distance: float) -> Vector3:
	var points: PackedVector3Array = config.path_points
	if points.is_empty():
		return Vector3.ZERO
	var length: float = path_length()
	if length <= 0.0001:
		return points[0]
	var travelled: float = fposmod(distance, length) if path_loops() else clampf(distance, 0.0, length)
	for index: int in range(1, points.size()):
		var leg: float = points[index - 1].distance_to(points[index])
		if travelled <= leg or index == points.size() - 1:
			return points[index - 1].lerp(points[index], clampf(travelled / maxf(leg, 0.0001), 0.0, 1.0))
		travelled -= leg
	return points[points.size() - 1]


## The physics body (the thing the player stands on).
func body() -> AnimatableBody3D:
	return _body


func reset() -> void:
	super.reset()
	_path_offset = 0.0
	_path_dir = 1.0
	_pause_left = 0.0
	_clock = 0.0
	_speed_factor = 0.0
	_angle = 0.0
	_phase = 0.0
	_omega = 0.0
	_carry_omega = 0.0
	_angle = _rest_angle()
	_apply()
	for deck: AnimatableBody3D in _decks:
		deck.reset_physics_interpolation()
	_body.reset_physics_interpolation()
	_deck_velocity.fill(Vector3.ZERO)


## The speed target: 1 while running. ALWAYS_ON always runs (D-07); SWITCHED runs while a child Receiver (plan 05.1-17) is on.
func _target() -> float:
	if config.timing == TimedMotionConfig.Timing.ALWAYS_ON:
		return 1.0
	var receiver: Node = get_node_or_null(^"Receiver")
	if receiver != null and receiver.has_method(&"is_on") and bool(receiver.call(&"is_on")):
		return 1.0
	return 0.0


## The local position of every deck: along the route (PATH) or out of the wall (STEPS). A deck's node origin is its top face centre.
func _place_decks() -> void:
	var count: int = _decks.size()
	for index: int in count:
		var at: Vector3 = Vector3.ZERO
		if config.profile == TimedMotionConfig.Profile.STAMP:
			at = config.stamp_axis.normalized() * stamp_extension() + _stamp_shudder()
		elif config.profile == TimedMotionConfig.Profile.STEPS:
			var depth: float = step_extension(index) - config.plate_size * 0.5
			at = Vector3(config.step_pitch * float(index), config.step_rise * float(index), depth)
		else:
			at = path_point(_path_offset + path_length() / float(count) * float(index) if path_loops() else _path_offset)
		_decks[index].transform = Transform3D(Basis.IDENTITY, at)


## The state after one more tick of `delta`: x = speed factor, y = phase, z = angle. Pure, nothing is stored.
func _next_state(delta: float) -> Vector3:
	if config.profile == TimedMotionConfig.Profile.HINGE:
		var progress: float = move_toward(_speed_factor, _target(), delta / maxf(config.hinge_time, 0.05))
		return Vector3(progress, _phase, _hinge_angle(progress))
	var factor: float = move_toward(_speed_factor, _target(), delta / maxf(config.ramp_time, 0.01))
	if config.profile == TimedMotionConfig.Profile.SWING:
		var swing_phase: float = wrapf(_phase + TAU / maxf(config.swing_period, 0.1) * factor * delta, -PI, PI)
		return Vector3(factor, swing_phase, deg_to_rad(config.swing_amplitude_deg) * sin(swing_phase))
	var phase: float = wrapf(_phase + _phase_rate() * factor * delta, -PI, PI)
	return Vector3(factor, phase, _limit_rad * sin(phase))


## The HINGE angle for a fold progress 0 (raised) .. 1 (flat), eased with smoothstep. Negative: +Z up under Basis(RIGHT, angle).
func _hinge_angle(progress: float) -> float:
	return -deg_to_rad(config.hinge_angle_deg) * (1.0 - smoothstep(0.0, 1.0, progress))


## The angle at rest: the raised deck for HINGE, 0 for the swings.
func _rest_angle() -> float:
	if config.profile == TimedMotionConfig.Profile.HINGE:
		return _hinge_angle(0.0)
	return 0.0


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
	if authored_shape():
		return
	var thickness: float = config.plate_thickness
	var size: Vector3 = Vector3(config.plate_size, thickness, config.plate_size)
	_rest_offset = Vector3.ZERO
	if config.profile == TimedMotionConfig.Profile.SWEEP or config.profile == TimedMotionConfig.Profile.HINGE:
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


## PATH and STEPS tick: the speed factor eases the start, the route or the step clock advances, the decks are placed and each
## deck's displacement per second is kept for the carry.
func _tick_translating(delta: float) -> void:
	var factor: float = move_toward(_speed_factor, _target(), delta / maxf(config.ramp_time, 0.01))
	_speed_factor = factor
	if config.profile == TimedMotionConfig.Profile.STEPS or config.profile == TimedMotionConfig.Profile.STAMP:
		_clock += delta * factor
	else:
		_advance_path(delta, factor)
	var before: PackedVector3Array = PackedVector3Array()
	for deck: AnimatableBody3D in _decks:
		before.append(deck.position)
	_apply()
	for index: int in _decks.size():
		_deck_velocity[index] = (_decks[index].position - before[index]) / maxf(delta, 0.0001)


func _advance_path(delta: float, factor: float) -> void:
	var length: float = path_length()
	if length <= 0.0001:
		return
	var step: float = config.path_speed * factor * delta
	if path_loops():
		_path_offset = fposmod(_path_offset + step, length)
		return
	if _pause_left > 0.0:
		_pause_left = maxf(_pause_left - delta, 0.0)
		return
	_path_offset += _path_dir * step
	if _path_offset >= length:
		_path_offset = length
		_path_dir = -1.0
		_pause_left = config.path_pause
	elif _path_offset <= 0.0:
		_path_offset = 0.0
		_path_dir = 1.0
		_pause_left = config.path_pause


## The index of the deck whose box lies nearest to the world `point` (the one the rider stands on), or -1 without decks.
func _nearest_deck(point: Vector3) -> int:
	var best: int = -1
	var best_distance: float = INF
	var half: Vector3 = Vector3(config.plate_size, config.plate_thickness, config.plate_size) * 0.5
	for index: int in _decks.size():
		var local: Vector3 = _decks[index].global_transform.affine_inverse() * point
		local.y += config.plate_thickness * 0.5
		var outside: Vector3 = Vector3(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0), maxf(absf(local.z) - half.z, 0.0))
		if outside.length_squared() < best_distance:
			best_distance = outside.length_squared()
			best = index
	return best


## PATH and STEPS: one body per deck. Deck 0 is the scene's Body, the others are copies of it (same shape, mesh and look children).
func _build_decks() -> void:
	_decks.clear()
	_decks.append(_body)
	if not translates():
		_deck_velocity = PackedVector3Array([Vector3.ZERO])
		return
	var count: int = config.step_count if config.profile == TimedMotionConfig.Profile.STEPS else config.path_deck_count
	if config.profile == TimedMotionConfig.Profile.STAMP:
		count = 1
	for index: int in range(1, maxi(count, 1)):
		var deck: AnimatableBody3D = _body.duplicate() as AnimatableBody3D
		deck.name = "Deck%d" % index
		add_child(deck)
		_decks.append(deck)
	_deck_velocity.resize(_decks.size())
	_deck_velocity.fill(Vector3.ZERO)


func _apply() -> void:
	if translates():
		_place_decks()
		return
	var rotation_basis: Basis = Basis(_axis_local, _angle)
	_body.transform = Transform3D(rotation_basis, rotation_basis * _rest_offset)
