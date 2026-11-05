class_name CameraRig
extends Node3D
## Hand-built follow camera (D-14 centered framing, D-18). Scene layout:
## CameraRig (yaw) > Pitch > SpringArm3D > Camera3D.
## The rig is a top-level SIBLING of its target, never a child: it runs in _process, reads the
## interpolated target transform and has physics interpolation switched off, so it stays smooth at
## any tick rate. FOV and arm-origin offsets are additive per-source channels (D-18): later phases
## (aim, camera kick) register a source by name and the rig sums them. Auto-follow and recenter come later.

## The node to follow (the Player).
@export var target: Node3D
## Tests set this to false: a headless run cannot capture the mouse.
@export var require_mouse_capture: bool = true
## Height of the follow pivot above the target origin in m.
@export var pivot_height: float = 1.6
## Horizontal follow rate in 1/s (exponential damping).
@export var follow_rate: float = 14.0
## Vertical follow rate in 1/s (slower, so jumps do not bob the camera).
@export var vertical_follow_rate: float = 6.0
## Radians of rotation per pixel of mouse motion (no delta scaling, no smoothing).
@export var base_sensitivity: float = 0.0022
## Lowest pitch in rad (negative looks down from above).
@export var pitch_min: float = -1.2
## Highest pitch in rad.
@export var pitch_max: float = 0.6
## Field of view in degrees with no FOV source registered.
@export var base_fov: float = 75.0
## Rate in 1/s at which the arm lengthens again after a wall pull-in. Pulling in is instant.
@export var arm_extend_rate: float = 8.0
## Airborne vertical band in m (D-15): the camera holds the last grounded height until the target
## rises more than this above it.
@export var air_rise_band: float = 2.5

## Yaw in rad, rotation about Y.
var yaw: float = 0.0
## Pitch in rad, rotation about X (negative lifts the camera above the target).
var pitch: float = -0.3

## FOV contributions in degrees by source name.
var _fov_sources: Dictionary[StringName, float] = {}
## Arm origin contributions in Pitch-local space by source name.
var _offset_sources: Dictionary[StringName, Vector3] = {}
## Anchor height (target origin y + pivot_height) at the last grounded moment.
var _grounded_height: float = 0.0
## Longest arm in m, the SpringArm3D spring_length of the scene.
var _max_arm_length: float = 5.0
## Arm length in m after the last wall cast.
var _arm_length: float = 5.0
## World mask the arm casts against. The SpringArm3D node's own mask is zeroed (see _ready).
var _arm_mask: int = 0
var _arm_query: PhysicsShapeQueryParameters3D

@onready var pitch_node: Node3D = $Pitch
@onready var spring_arm: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# SpringArm3D only casts on physics ticks, so at low tick rates the lens clips walls (A3, measured at
	# 10 TPS). The rig casts every frame itself and sets the node's own mask to 0 so the two never disagree.
	_max_arm_length = spring_arm.spring_length
	_arm_length = _max_arm_length
	_arm_mask = spring_arm.collision_mask
	spring_arm.collision_mask = 0
	snap_to_target()
	if require_mouse_capture and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and require_mouse_capture:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if require_mouse_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		yaw -= motion.relative.x * base_sensitivity
		pitch = clampf(pitch - motion.relative.y * base_sensitivity, pitch_min, pitch_max)
		return
	if event.is_action_pressed(&"pause") and require_mouse_capture:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed and require_mouse_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if target == null:
		return
	var anchor: Vector3 = target.get_global_transform_interpolated().origin + Vector3.UP * pivot_height
	var horizontal_weight: float = 1.0 - exp(-follow_rate * delta)
	var vertical_weight: float = 1.0 - exp(-vertical_follow_rate * delta)
	var current: Vector3 = global_position
	current.x = lerpf(current.x, anchor.x, horizontal_weight)
	current.z = lerpf(current.z, anchor.z, horizontal_weight)
	current.y = lerpf(current.y, _vertical_goal(anchor.y), vertical_weight)
	global_position = current
	pitch = clampf(pitch, pitch_min, pitch_max)
	rotation.y = yaw
	pitch_node.rotation.x = pitch
	spring_arm.position = _offset_total()
	camera.fov = get_fov_total()
	_update_arm(delta)


## The World mask the arm casts against. The SpringArm3D node's own mask is 0 because the rig casts.
func arm_collision_mask() -> int:
	return _arm_mask


## Per-frame wall safety. Sphere cast along the arm after rotation and offsets: pull in instantly, extend eased.
func _update_arm(delta: float) -> void:
	var goal: float = _max_arm_length
	if spring_arm.shape != null:
		if _arm_query == null:
			_arm_query = PhysicsShapeQueryParameters3D.new()
		var arm_transform: Transform3D = spring_arm.global_transform
		_arm_query.shape = spring_arm.shape
		_arm_query.transform = Transform3D(Basis.IDENTITY, arm_transform.origin)
		_arm_query.motion = arm_transform.basis.z.normalized() * _max_arm_length
		_arm_query.collision_mask = _arm_mask
		var fractions: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(_arm_query)
		if fractions.size() >= 2 and fractions[0] < 1.0:
			goal = maxf(_max_arm_length * fractions[0] - spring_arm.margin, 0.0)
	if goal < _arm_length:
		_arm_length = goal
	else:
		_arm_length = lerpf(_arm_length, goal, 1.0 - exp(-arm_extend_rate * delta))
	spring_arm.spring_length = _arm_length
	camera.position = Vector3(0.0, 0.0, _arm_length)


## The height the rig approaches (D-15). Grounded: the target itself. Airborne: the last grounded height,
## unless the target rose more than air_rise_band above it (then it trails by the band) or fell below it
## (then falls are followed).
func _vertical_goal(anchor_y: float) -> float:
	if _target_grounded():
		_grounded_height = anchor_y
		return anchor_y
	if anchor_y - _grounded_height > air_rise_band:
		return anchor_y - air_rise_band
	if anchor_y < _grounded_height:
		return anchor_y
	return _grounded_height


## Targets without is_grounded() count as always grounded.
func _target_grounded() -> bool:
	if not target.has_method(&"is_grounded"):
		return true
	return bool(target.call(&"is_grounded"))


## Places the rig on the target pivot with no smoothing (spawn, teleport).
func snap_to_target() -> void:
	if target != null:
		global_position = target.get_global_transform_interpolated().origin + Vector3.UP * pivot_height
		_grounded_height = global_position.y
	rotation.y = yaw
	if pitch_node != null:
		pitch_node.rotation.x = pitch


## Adds or replaces the FOV contribution of `source` in degrees (positive widens).
func set_fov_offset(source: StringName, degrees: float) -> void:
	_fov_sources[source] = degrees


## Removes the FOV contribution of `source`; other sources stay.
func clear_fov_offset(source: StringName) -> void:
	_fov_sources.erase(source)


## Base FOV plus all sources, clamped to a valid projection (1..179 degrees).
func get_fov_total() -> float:
	var total: float = base_fov
	var keys: Array = _fov_sources.keys()
	keys.sort()
	for key: StringName in keys:
		total += _fov_sources[key]
	return clampf(total, 1.0, 179.0)


## Adds or replaces the arm origin offset of `source`, in Pitch-local space. The cast origin moves with
## it, so wall collision accounts for the offset.
func set_offset(source: StringName, offset: Vector3) -> void:
	_offset_sources[source] = offset


## Removes the arm origin offset of `source`; other sources stay.
func clear_offset(source: StringName) -> void:
	_offset_sources.erase(source)


func _offset_total() -> Vector3:
	var total: Vector3 = Vector3.ZERO
	var keys: Array = _offset_sources.keys()
	keys.sort()
	for key: StringName in keys:
		total += _offset_sources[key]
	return total


## The yaw that camera-relative movement input uses. Here it is simply the camera yaw; 02-10
## excludes auto-follow and recenter rotation from it until the move input changes (A40).
func steering_yaw() -> float:
	return yaw
