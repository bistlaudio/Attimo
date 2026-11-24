class_name CameraRig
extends Node3D
## Hand-built follow camera (D-14 centered framing, D-18). Scene layout:
## CameraRig (yaw) > Pitch > SpringArm3D > Camera3D.
## The rig is a top-level SIBLING of its target, never a child: it runs in _process, reads the
## interpolated target transform and has physics interpolation switched off, so it stays smooth at
## any tick rate. FOV and arm-origin offsets are additive per-source channels (D-18): later phases
## (aim, camera kick) register a source by name and the rig sums them.
##
## Framing (quick 261118-qbt, DEV-05): the view is centered behind the character and looks at a pivot slightly above the
## shoulders, 3.6 m out, so the standing character reads in the lower part of the screen. The follow is tight and the rig
## locks onto the player: after the exponential damping the rig is clamped to max_follow_lag horizontally and
## max_vertical_lag vertically from the anchor, so running, dashing, jumping and long jumping never let the character
## drift out of frame. This replaces the Phase 2 D-15 airborne hold band ("no fixed hard lock") at the developer request
## of 2026-11-18; the damping still smooths the small lags below the clamps.
##
## Auto-follow (D-16) converges instead of circling (A40). Movement input is camera-relative, so a camera that
## rotated with a held A/D key would rotate the key's world direction too and never settle. The follow term is
## therefore the angle e from camera forward to the player's heading, and steering_yaw() (read by
## PlayerController.input_direction()) excludes every rotation the follow adds (`_auto_offset`). A held key keeps
## its world heading while the camera swings behind it, e shrinks into the dead zone and the swing stops. The
## offset is dropped (steering re-based to the current view) when the move input goes between neutral and held or
## turns by more than steer_rebase_angle. Mouse look changes yaw only, so it turns the steering with it.
## Straight runs (e about 0) and runs toward the camera (|e| above auto_follow_max_angle) are left alone.
##
## Aim target (quick 261118-qbt): aim_target_point() is the world point under the screen-centre crosshair. A perspective
## Camera3D without h/v offset has its centre ray at the camera position along the camera -Z, so no viewport query is
## needed. The ray starts level with the character (aim_ray_start), so geometry between the lens and the character is
## never the target, hits crosshair_ray_mask and falls back to the point at crosshair_ray_length. The arm solver
## (AimPoseModifier through MannequinAnimator) and the Phase 4 beam read it (aim_direction_from).
##
## Auto-follow mode (A41, CameraSettings.auto_follow_mode): "on" always follows, "off" never, "auto" only while
## the last input event came from a joypad. `_input` records the device and never consumes the event.

## The node to follow (the Player).
@export var target: Node3D
## Tests set this to false: a headless run cannot capture the mouse.
@export var require_mouse_capture: bool = true
## Height of the follow pivot above the target origin in m: slightly above the shoulder joint (1.107 m on the Mannequin),
## the point the view centre looks at. Measured 2026-11-18; the plan rule (shoulder + 0.2 m) gives 1.3 m, 1.4 m keeps
## the standing character in the lower part of the screen.
@export var pivot_height: float = 1.3
## Horizontal follow rate in 1/s (exponential damping). Softened 2026-11-18 (developer: the hard lock felt odd).
@export var follow_rate: float = 16.0
## Vertical follow rate in 1/s (exponential damping of the vertical lock, max_vertical_lag clamps what is left).
@export var vertical_follow_rate: float = 8.0
## Most the rig may trail the anchor horizontally in m (dashes and long jumps run at 14-22 m/s). A loose clamp, so the
## damping does the work and the clamp only catches dashes.
@export var max_follow_lag: float = 1.0
## Most the rig may differ from the anchor height in m, so a jump keeps head and feet inside the vertical view.
@export var max_vertical_lag: float = 0.6

@export_group("Zoom")
## Closest and farthest arm length in m that zoom_by() can choose (the F2 panel and tests; the mouse wheel no longer zooms,
## it switches hand modules, D-26). The scene's SpringArm3D spring_length is the start distance.
@export var zoom_min: float = 2.5
@export var zoom_max: float = 7.0
## Metres per zoom_by() step in the old wheel notch size.
@export var zoom_step: float = 0.5
## Rate in 1/s at which the arm eases to the chosen zoom distance.
@export var zoom_rate: float = 12.0
@export_group("")
## Radians of rotation per pixel of mouse motion (no delta scaling, no smoothing).
@export var base_sensitivity: float = 0.0022
## Lowest pitch in rad (negative looks down from above).
@export var pitch_min: float = -1.2
## Highest pitch in rad (looking up at high platforms).
@export var pitch_max: float = 0.75
## Field of view in degrees with no FOV source registered.
@export var base_fov: float = 78.0
## Rate in 1/s at which the arm lengthens again after a wall pull-in. Pulling in is instant.
@export var arm_extend_rate: float = 8.0

## Player camera settings (sensitivity, invert-Y, auto-follow mode). Loaded from user://settings.cfg in _ready.
var settings: CameraSettings

## Process priority of the rig: lower runs first, so every _process reader of the camera (arm solver) sees this frame's view.
const PROCESS_PRIORITY: int = -100

## Input device families tracked for the auto-follow mode (A41).
enum InputDevice { KEYBOARD_MOUSE, JOYPAD }

## Seconds without look input before auto-follow may act (D-16 "about 1 s").
@export var auto_follow_delay: float = 1.0
## Maximum auto-follow swing speed in rad/s.
@export var auto_follow_rate: float = 1.4
## Swing speed in 1/s per rad of heading error, below the rate cap.
@export var auto_follow_gain: float = 3.0
## Heading errors in rad smaller than this are left alone.
@export var auto_follow_dead_zone: float = 0.03
## Headings in rad further from the camera forward than this (toward the camera) are left alone.
@export var auto_follow_max_angle: float = 2.0
## Horizontal target speed in m/s below which auto-follow does not act.
@export var auto_follow_min_speed: float = 1.0
## Change in rad of the move input direction that re-bases steering.
@export var steer_rebase_angle: float = 0.35
## Seconds a recenter (camera_recenter, D-17) takes to turn the camera behind the character.
@export var recenter_time: float = 0.15

@export_group("Aim")
## Degrees the field of view narrows at full aim weight (D-14).
@export_range(0.0, 30.0, 0.5) var aim_fov_delta: float = 12.0
## Metres the camera arm moves to the right shoulder at full aim weight, along Pitch-local X (D-13). There is one
## fixed shoulder: no swap.
@export_range(0.0, 1.5, 0.05) var aim_shoulder_offset: float = 1.1
## DEBUG: permanent over-the-shoulder offset outside aim (Pitch-local, x right, y up), so the crosshair is not behind the
## character. Aim blends x from here to aim_shoulder_offset. Set to zero for the centered framing (D-14).
@export var base_shoulder_offset: Vector3 = Vector3(0.6, 0.35, 0.0)
## Seconds a full aim blend takes, in and out (D-14). The 0.01 minimum keeps the blend rate finite.
@export_range(0.01, 1.0, 0.01) var aim_blend_time: float = 0.18
## Factor on the look sensitivity while aiming, scaled in with the aim weight (D-15).
@export_range(0.1, 1.5, 0.05) var aim_sensitivity_factor: float = 0.8
## Goggle snap: a short decaying jolt when aim starts. Amplitude in m (arm offset), FOV punch in degrees (widens, then
## settles) and duration in seconds. Set the amplitude and the punch to zero to switch it off.
@export_range(0.0, 0.3, 0.005) var snap_shake_amplitude: float = 0.06
@export_range(0.0, 10.0, 0.1) var snap_fov_punch: float = 4.0
@export_range(0.05, 1.0, 0.01) var snap_time: float = 0.22
@export_group("")

@export_group("Crosshair ray")
## Length in m of the ray from the camera through the screen-centre crosshair; the end point is the aim target when
## nothing is hit.
@export var crosshair_ray_length: float = 100.0
## Physics layers the crosshair ray hits: World now, Phase 4 may add the Interactable and Enemy bits.
@export_flags_3d_physics var crosshair_ray_mask: int = PhysicsLayers.WORLD
@export_group("")

## Yaw in rad, rotation about Y.
var yaw: float = 0.0
## Pitch in rad, rotation about X (negative lifts the camera above the target).
var pitch: float = -0.22

## Seconds since the last look input (mouse motion; gamepad stick in Phase 13).
var time_since_look: float = 0.0
## The device family of the last input event (A41).
var last_input_device: InputDevice = InputDevice.KEYBOARD_MOUSE

## Whether the last aim_target_point() query hit something (false: the point is the ray end). Read-only for others.
var last_aim_hit: bool = false
## The collider of the last hit, null without a hit.
var last_aim_collider: Object = null
## The point the last aim_target_point() query returned.
var last_aim_point: Vector3 = Vector3.ZERO

## Eased aim blend, 0 (no aim) to 1 (full aim). Read-only for other code; driven by EventBus.aim_changed.
var aim_weight: float = 0.0

## Aim blend goal: 1.0 while aim is held, else 0.0.
var _aim_target: float = 0.0
## Linear blend progress before smoothstep.
var _aim_linear: float = 0.0
## True while the &"aim" FOV and offset sources are registered by this rig.
var _aim_sources_written: bool = false
var _snap_left: float = 0.0

## Rotation added by auto-follow since steering was last re-based (A40).
var _auto_offset: float = 0.0
## Move input vector at the last steering re-base (ZERO while neutral).
var _steer_reference: Vector2 = Vector2.ZERO
## True while a recenter runs; mouse look cancels it.
var _recentering: bool = false
var _recenter_start_yaw: float = 0.0
var _recenter_target_yaw: float = 0.0
var _recenter_elapsed: float = 0.0
## Target origin of the previous frame, for targets that are not CharacterBody3D.
var _last_target_origin: Vector3 = Vector3.ZERO

## FOV contributions in degrees by source name.
var _fov_sources: Dictionary[StringName, float] = {}
## Arm origin contributions in Pitch-local space by source name.
var _offset_sources: Dictionary[StringName, Vector3] = {}
## The arm length in m the player chose with the mouse wheel (starts at the scene's spring_length).
var zoom_distance: float = 4.5
## Longest arm in m before the wall cast: eases toward zoom_distance.
var _max_arm_length: float = 4.5
## Arm length in m after the last wall cast.
var _arm_length: float = 3.6
## World mask the arm casts against. The SpringArm3D node's own mask is zeroed (see _ready).
var _arm_mask: int = 0
var _arm_query: PhysicsShapeQueryParameters3D

@onready var pitch_node: Node3D = $Pitch
@onready var spring_arm: SpringArm3D = $Pitch/SpringArm3D
@onready var camera: Camera3D = $Pitch/SpringArm3D/Camera3D


func _ready() -> void:
	# Run before the Player's MannequinAnimator and AnimationTree: they read aim_target_point() (camera transform) in
	# _process, and _process order is tree order, so at the default priority the arm aimed at last frame's camera.
	# Safe: the rig reads the interpolated target transform, which does not depend on _process order (WR-01).
	process_priority = PROCESS_PRIORITY
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# SpringArm3D only casts on physics ticks, so at low tick rates the lens clips walls (A3, measured at
	# 10 TPS). The rig casts every frame itself and sets the node's own mask to 0 so the two never disagree.
	_max_arm_length = spring_arm.spring_length
	zoom_distance = _max_arm_length
	_arm_length = _max_arm_length
	_arm_mask = spring_arm.collision_mask
	spring_arm.collision_mask = 0
	settings = CameraSettings.load_from()
	snap_to_target()
	EventBus.aim_changed.connect(_on_aim_changed)
	if require_mouse_capture and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and require_mouse_capture:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Records the last used device family for the auto-follow mode (A41). _input, not _unhandled_input, so a UI
## control that consumes events cannot hide a device change. Never consumes the event.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		last_input_device = InputDevice.JOYPAD
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= 0.2:
			last_input_device = InputDevice.JOYPAD
	elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		last_input_device = InputDevice.KEYBOARD_MOUSE


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if require_mouse_capture and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		if motion.relative != Vector2.ZERO:
			notify_look_activity()
		var scale: float = base_sensitivity * settings.sensitivity * lerpf(1.0, aim_sensitivity_factor, aim_weight)
		var vertical: float = motion.relative.y * scale
		if settings.invert_y:
			vertical = -vertical
		yaw -= motion.relative.x * scale
		pitch = clampf(pitch - vertical, pitch_min, pitch_max)
		return
	if event.is_action_pressed(&"camera_recenter") and _aim_target <= 0.0 and (not require_mouse_capture or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		recenter()
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
	# Real time: the world may run in slow motion (the Loader hold, TimeFx), the free camera must not (Pitfall 2).
	var real: float = TimeFx.unscaled(delta)
	time_since_look += real
	_update_steering_latch()
	_advance_recenter(real)
	_apply_auto_follow(real)
	var anchor: Vector3 = target.get_global_transform_interpolated().origin + Vector3.UP * pivot_height
	var horizontal_weight: float = 1.0 - exp(-follow_rate * real)
	var vertical_weight: float = 1.0 - exp(-vertical_follow_rate * real)
	var current: Vector3 = global_position
	current.x = lerpf(current.x, anchor.x, horizontal_weight)
	current.z = lerpf(current.z, anchor.z, horizontal_weight)
	current.y = lerpf(current.y, anchor.y, vertical_weight)
	# The lock: whatever the damping leaves is clamped, so the player stays framed through dashes and jumps.
	var lag: Vector2 = Vector2(current.x - anchor.x, current.z - anchor.z)
	if lag.length() > max_follow_lag:
		lag = lag.normalized() * max_follow_lag
		current.x = anchor.x + lag.x
		current.z = anchor.z + lag.y
	current.y = clampf(current.y, anchor.y - max_vertical_lag, anchor.y + max_vertical_lag)
	global_position = current
	pitch = clampf(pitch, pitch_min, pitch_max)
	rotation.y = yaw
	pitch_node.rotation.x = pitch
	_update_aim(real)
	_update_snap(real)
	_max_arm_length = lerpf(_max_arm_length, zoom_distance, 1.0 - exp(-zoom_rate * real))
	spring_arm.position = base_shoulder_offset + _offset_total()
	camera.fov = get_fov_total()
	_update_arm(real)


## Moves the chosen zoom distance by `amount` m (negative is closer), clamped to zoom_min .. zoom_max.
func zoom_by(amount: float) -> void:
	zoom_distance = clampf(zoom_distance + amount, zoom_min, zoom_max)


## Eases aim_weight toward the aim goal and writes it through the additive &"aim" sources (D-14), so a camera
## kick still stacks on top. While aim was never active the sources are left alone (tests set them by hand).
func _update_aim(delta: float) -> void:
	_aim_linear = move_toward(_aim_linear, _aim_target, delta / maxf(aim_blend_time, 0.01))
	aim_weight = smoothstep(0.0, 1.0, _aim_linear)
	if aim_weight > 0.0:
		set_fov_offset(&"aim", -aim_fov_delta * aim_weight)
		set_offset(&"aim", Vector3(maxf(aim_shoulder_offset - base_shoulder_offset.x, 0.0) * aim_weight, 0.0, 0.0))
		_aim_sources_written = true
	elif _aim_sources_written:
		clear_fov_offset(&"aim")
		clear_offset(&"aim")
		_aim_sources_written = false


## Decaying jolt on the &"goggle_snap" sources, cleared when it ends. Stacks with aim and any other kick.
func _update_snap(delta: float) -> void:
	if _snap_left <= 0.0:
		return
	_snap_left = maxf(_snap_left - delta, 0.0)
	if _snap_left <= 0.0:
		clear_offset(&"goggle_snap")
		clear_fov_offset(&"goggle_snap")
		return
	var decay: float = _snap_left / maxf(snap_time, 0.01)
	decay *= decay
	var phase: float = (snap_time - _snap_left) * 80.0
	set_offset(&"goggle_snap", Vector3(sin(phase * 1.3), cos(phase * 1.7) * 0.7, 0.0) * snap_shake_amplitude * decay)
	set_fov_offset(&"goggle_snap", snap_fov_punch * decay)


## On aim enter the steering offset is dropped and a running recenter stops, so steering_yaw() equals yaw (Pitfall 9).
func _on_aim_changed(active: bool) -> void:
	_aim_target = 1.0 if active else 0.0
	if active:
		_auto_offset = 0.0
		_recentering = false
		_snap_left = snap_time


## Where the crosshair ray starts: the camera `origin` pushed along `forward` to the plane through `pivot` (level with
## the character), never behind the lens. A pivot behind the lens gives `origin`.
static func aim_ray_start(origin: Vector3, forward: Vector3, pivot: Vector3) -> Vector3:
	return origin + forward * maxf((pivot - origin).dot(forward), 0.0)


## The world point under the screen-centre crosshair: the first hit of the centre ray on crosshair_ray_mask, else the ray
## end (camera position + camera forward * crosshair_ray_length). Updates last_aim_hit, last_aim_collider and
## last_aim_point. Queries the physics space on demand, one ray per call.
func aim_target_point() -> Vector3:
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z.normalized()
	var end: Vector3 = origin + forward * crosshair_ray_length
	var point: Vector3 = end
	last_aim_hit = false
	last_aim_collider = null
	if is_inside_tree():
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(aim_ray_start(origin, forward, global_position), end, crosshair_ray_mask)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and (hit["position"] as Vector3).is_finite():
			point = hit["position"] as Vector3
			last_aim_hit = true
			last_aim_collider = hit["collider"] as Object
	if not point.is_finite():
		point = end
	last_aim_point = point
	return point


## The raw first hit of the centre crosshair ray on `mask`, up to `length` metres: the ray starts level with the character
## (aim_ray_start), so geometry between lens and character is never hit. Empty when nothing is hit or the hit is not finite.
## Areas are not hit. One ray per call.
func aim_ray(mask: int, length: float) -> Dictionary:
	if not is_inside_tree() or camera == null:
		return {}
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z.normalized()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(aim_ray_start(origin, forward, global_position), origin + forward * length, mask)
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (hit["position"] as Vector3).is_finite():
		return {}
	return hit


## Unit direction from `origin` (the hand, the shoulder) to the aim target point; the camera forward when the target is
## closer than 1 mm. The Phase 4 beam fires along this from the hand.
func aim_direction_from(origin: Vector3) -> Vector3:
	var offset: Vector3 = aim_target_point() - origin
	if offset.length() < 0.001:
		return -camera.global_basis.z.normalized()
	return offset.normalized()


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


## Replaces the camera settings (the F2 panel and tests call this). null falls back to defaults.
func apply_settings(new_settings: CameraSettings) -> void:
	settings = new_settings if new_settings != null else CameraSettings.new()


## Places the rig on the target pivot with no smoothing (spawn, teleport).
func snap_to_target() -> void:
	if target != null:
		global_position = target.get_global_transform_interpolated().origin + Vector3.UP * pivot_height
		_last_target_origin = target.get_global_transform_interpolated().origin
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


## The yaw that camera-relative movement input uses: the camera yaw without the rotation auto-follow added
## since the move input last changed (A40). Mouse look is included, so the player turns with the view.
func steering_yaw() -> float:
	return yaw - _auto_offset


## Marks look input (mouse now, gamepad stick in Phase 13): auto-follow waits auto_follow_delay again.
func notify_look_activity() -> void:
	time_since_look = 0.0
	_recentering = false


## Turns the camera behind the character's facing within recenter_time (D-17, A29). The rotation is added to the
## steering offset like auto-follow's, so a held direction keeps its heading. Mouse look cancels it.
func recenter() -> void:
	if target == null or _aim_target > 0.0:
		return
	var facing: Vector2 = Vector2.ZERO
	var visual: Node3D = target.get(&"visual_root") as Node3D
	if visual != null:
		facing = Vector2(visual.global_basis.z.x, visual.global_basis.z.z)
	var body := target as CharacterBody3D
	if facing.length_squared() < 0.0001 and body != null:
		facing = Vector2(body.velocity.x, body.velocity.z)
	if facing.length_squared() < 0.0001:
		return
	_recenter_start_yaw = yaw
	_recenter_target_yaw = atan2(-facing.x, -facing.y)
	_recenter_elapsed = 0.0
	_recentering = true


func _advance_recenter(delta: float) -> void:
	if not _recentering:
		return
	_recenter_elapsed += delta
	var weight: float = clampf(_recenter_elapsed / maxf(recenter_time, 0.001), 0.0, 1.0)
	var new_yaw: float = lerp_angle(_recenter_start_yaw, _recenter_target_yaw, weight)
	_auto_offset += new_yaw - yaw
	yaw = new_yaw
	if weight >= 1.0:
		_recentering = false


## Whether auto-follow may act: "on" always, "off" never, "auto" only after joypad input (A41).
func auto_follow_active() -> bool:
	match settings.auto_follow_mode:
		"on":
			return true
		"off":
			return false
	return last_input_device == InputDevice.JOYPAD


## Drops the auto-follow rotation from steering when the move input goes between neutral and held, or turns by
## more than steer_rebase_angle: the new direction is then relative to the view on screen (A40).
func _update_steering_latch() -> void:
	var move: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var deflected: bool = move.length() >= 0.1
	var was_deflected: bool = _steer_reference.length() >= 0.1
	if deflected != was_deflected or (deflected and absf(move.angle_to(_steer_reference)) > steer_rebase_angle):
		_auto_offset = 0.0
		_steer_reference = move if deflected else Vector2.ZERO


## Horizontal heading of the target in m/s: the CharacterBody3D velocity, else the interpolated position delta.
func _target_heading(delta: float) -> Vector2:
	var origin: Vector3 = target.get_global_transform_interpolated().origin
	var heading: Vector2 = Vector2.ZERO
	var body := target as CharacterBody3D
	if body != null:
		heading = Vector2(body.velocity.x, body.velocity.z)
	elif delta > 0.0:
		heading = Vector2(origin.x - _last_target_origin.x, origin.z - _last_target_origin.z) / delta
	_last_target_origin = origin
	return heading


## Swings the camera toward the player's heading (D-16). Step = gain * error capped at the rate; every step is
## added to the yaw and to _auto_offset, so the held key keeps its world heading and the error converges to 0.
func _apply_auto_follow(delta: float) -> void:
	var heading: Vector2 = _target_heading(delta)
	if _aim_target > 0.0 or _recentering or not auto_follow_active() or time_since_look <= auto_follow_delay:
		return
	if heading.length() <= auto_follow_min_speed:
		return
	var error: float = angle_difference(yaw, atan2(-heading.x, -heading.y))
	var magnitude: float = absf(error)
	if magnitude < auto_follow_dead_zone or magnitude > auto_follow_max_angle:
		return
	var speed: float = clampf(magnitude * auto_follow_gain, 0.0, auto_follow_rate)
	var step: float = signf(error) * minf(speed * delta, magnitude)
	yaw += step
	_auto_offset += step
