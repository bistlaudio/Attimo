class_name CameraRig
extends Node3D
## Hand-built follow camera (D-14 centered framing, D-18). Scene layout:
## CameraRig (yaw) > Pitch > SpringArm3D > Camera3D.
## The rig is a top-level SIBLING of its target, never a child: it runs in _process, reads the
## interpolated target transform and has physics interpolation switched off, so it stays smooth at
## any tick rate. Later plans add additive FOV and offset sources, auto-follow and recenter.

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

## Yaw in rad, rotation about Y.
var yaw: float = 0.0
## Pitch in rad, rotation about X (negative lifts the camera above the target).
var pitch: float = -0.3

@onready var pitch_node: Node3D = $Pitch
@onready var spring_arm: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
	current.y = lerpf(current.y, anchor.y, vertical_weight)
	global_position = current
	rotation.y = yaw
	pitch_node.rotation.x = pitch


## Places the rig on the target pivot with no smoothing (spawn, teleport).
func snap_to_target() -> void:
	if target != null:
		global_position = target.get_global_transform_interpolated().origin + Vector3.UP * pivot_height
	rotation.y = yaw
	if pitch_node != null:
		pitch_node.rotation.x = pitch


## The yaw that camera-relative movement input uses. Here it is simply the camera yaw; 02-10
## excludes auto-follow and recenter rotation from it until the move input changes (A40).
func steering_yaw() -> float:
	return yaw
