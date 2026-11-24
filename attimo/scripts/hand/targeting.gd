class_name Targeting
extends Node
## Aim assist of the hand (CAM-05, D-14, D-19). It is always on (there is no aim hold since phase 05) and picks the Interactable
## the pulse will hit: the one under the crosshair, else the best one inside hand_assist_angle with line of sight. The current
## target is kept with hysteresis, so it does not flicker between two close neighbours. It never rotates the camera and never
## slows the mouse (the sticky aim slowdown is gone).
## It reports the reticle State, the target and the glow stage (TARGET on the target, AIM on the rest). It is created by
## the HandController, which calls update() every physics tick before it decides a shot.

enum State { NONE, VALID, VALID_BIG, INVALID }

signal target_changed(target: Interactable)

## Pulse rate of the brightest glow stage in Hz and its relative swing (D-12).
const TARGET_PULSE_HZ: float = 1.5
const TARGET_PULSE_SWING: float = 0.15
## Extra ray length behind the big range, so a far crosshair hit still reads INVALID instead of nothing.
const RAY_MARGIN: float = 10.0

## The selected Interactable, or null. Only valid targets are held.
var target: Interactable = null
## A Targeting.State value (typed int: the global class State shadows the enum name in type positions).
var state: int = State.NONE
## Angle in degrees between the crosshair and the target (0 for an exact hit).
var target_angle_deg: float = 0.0

var _controller: HandController = null
var _player: PlayerController = null
var _lost_time: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_controller = get_parent() as HandController
	if _controller != null:
		_player = _controller.get_parent() as PlayerController


## Runs one selection step. Called from HandController._physics_process every tick.
func update(delta: float) -> void:
	if _controller == null or _player == null:
		return
	var rig: CameraRig = _player.camera_rig()
	if rig == null or rig.camera == null:
		_release_target()
		state = State.NONE
		return
	_select(rig, delta)


func _process(delta: float) -> void:
	# One target at a time, so animating the shared brightest material is safe (D-12).
	_time += delta
	var material: StandardMaterial3D = Interactable.GLOW_TARGET_MATERIAL
	var pulse: float = 1.0 + TARGET_PULSE_SWING * sin(_time * TAU * TARGET_PULSE_HZ) if target != null else 1.0
	material.emission_energy_multiplier = Interactable.GLOW_TARGET_ENERGY * pulse


func _select(rig: CameraRig, delta: float) -> void:
	var camera: Camera3D = rig.camera
	var camera_position: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z.normalized()
	var origin: Vector3 = _player.global_position
	var assist: float = _controller.hand_assist_angle

	var exact: Interactable = null
	var hit: Dictionary = rig.aim_ray(PhysicsLayers.WORLD | PhysicsLayers.INTERACTABLE, _controller.hand_big_range + RAY_MARGIN)
	if not hit.is_empty():
		exact = Interactable.from_collider(hit["collider"] as Object)

	# Best candidate: the exact crosshair hit (angle 0) when it is valid, else the nearest valid one inside the cone.
	var best: Interactable = null
	var best_angle: float = INF
	if exact != null and _state_for(exact, origin) != State.INVALID:
		best = exact
		best_angle = 0.0
	else:
		for node: Node in get_tree().get_nodes_in_group(&"interactable"):
			var candidate: Interactable = node as Interactable
			if candidate == null or not candidate.accepts_shot or not candidate.is_inside_tree():
				continue
			var point: Vector3 = candidate.target_point()
			if origin.distance_to(point) > _controller.hand_big_range:
				continue
			var angle: float = _angle_deg(forward, point - camera_position)
			if angle > assist or angle >= best_angle:
				continue
			if _state_for(candidate, origin) == State.INVALID or not _line_of_sight(rig, candidate):
				continue
			best = candidate
			best_angle = angle

	var current: Interactable = target if is_instance_valid(target) else null
	if current != null:
		var current_angle: float = _angle_deg(forward, current.target_point() - camera_position)
		var keeps: bool = current_angle <= assist * _controller.hand_assist_hold_factor and _state_for(current, origin) != State.INVALID and _line_of_sight(rig, current)
		if keeps:
			_lost_time = 0.0
			target_angle_deg = current_angle
			if best != null and best != current and best_angle < current_angle - _controller.hand_assist_switch_margin:
				_set_target(best)
				target_angle_deg = best_angle
		else:
			_lost_time += delta
			if _lost_time >= _controller.hand_assist_drop_delay:
				_set_target(best)
				target_angle_deg = best_angle if best != null else 0.0
				_lost_time = 0.0
	else:
		_lost_time = 0.0
		if best != null:
			_set_target(best)
			target_angle_deg = best_angle
		else:
			_set_target(null)
			target_angle_deg = 0.0

	if target != null:
		state = _state_for(target, origin)
	elif exact != null:
		state = State.INVALID
	else:
		state = State.NONE


## The reticle state `candidate` would show for the equipped module and the player position (D-03, D-06, HAND-02).
func _state_for(candidate: Interactable, origin: Vector3) -> int:
	if _controller.active_def == null or not candidate.accepts_module(_controller.active_def.id):
		return State.INVALID
	var distance: float = origin.distance_to(candidate.target_point())
	if not is_finite(distance):
		return State.INVALID
	if candidate.can_accept(PulseHit.Kind.SHOT, PulseHit.Size.SMALL) and distance <= _controller.hand_small_range:
		return State.VALID
	if candidate.can_accept(PulseHit.Kind.SHOT, PulseHit.Size.BIG) and distance <= _controller.hand_big_range:
		return State.VALID_BIG
	return State.INVALID


## True when a ray from the crosshair line start to the target point reaches it: nothing in the way, or the first hit
## belongs to the same Interactable.
func _line_of_sight(rig: CameraRig, candidate: Interactable) -> bool:
	var camera: Camera3D = rig.camera
	var forward: Vector3 = -camera.global_basis.z.normalized()
	var start: Vector3 = CameraRig.aim_ray_start(camera.global_position, forward, rig.global_position)
	var point: Vector3 = candidate.target_point()
	if not point.is_finite() or start.distance_squared_to(point) < 0.000001:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, point, PhysicsLayers.WORLD | PhysicsLayers.INTERACTABLE)
	query.collide_with_areas = false
	var result: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return Interactable.from_collider(result["collider"] as Object) == candidate


func _set_target(next: Interactable) -> void:
	var previous: Interactable = target if is_instance_valid(target) else null
	if previous == next:
		target = next
		return
	if previous != null:
		previous.set_glow_stage(Interactable.GlowStage.AIM)
	target = next
	if next != null:
		next.set_glow_stage(Interactable.GlowStage.TARGET)
	target_changed.emit(next)


## Drops the target when the rig is gone: the old one falls back to the idle glow.
func _release_target() -> void:
	_lost_time = 0.0
	target_angle_deg = 0.0
	if target == null:
		return
	var previous: Interactable = target if is_instance_valid(target) else null
	target = null
	if previous != null:
		previous.set_glow_stage(Interactable.GlowStage.IDLE)
	target_changed.emit(null)


## Angle in degrees between the unit vector `forward` and `to`; INF for a zero-length or non-finite direction (T-04-05).
func _angle_deg(forward: Vector3, to: Vector3) -> float:
	if not to.is_finite() or to.length_squared() < 0.000001:
		return INF
	return rad_to_deg(acos(clampf(forward.dot(to.normalized()), -1.0, 1.0)))
