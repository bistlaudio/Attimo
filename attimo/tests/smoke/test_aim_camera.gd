extends RefCounted
## CAM-02 / D-13 / D-14 / D-15: the aim camera. aim_changed eases the CameraRig to a tighter FOV and a fixed
## right-shoulder arm offset through the additive &"aim" sources (a camera kick stacks on top), and eases back and clears
## them. While aiming, mouse look is scaled by aim_sensitivity_factor, camera_recenter and auto-follow are ignored and
## the steering offset is zeroed, so steering_yaw() equals yaw. No shoulder swap action exists and Q stays unbound.
## Blend timing is tick-count based (Pitfall 12): the rig is stepped by hand with a fixed delta, never wall-clock.
## Actions are released and nodes freed at the end of each scenario.

const Fixtures := preload("res://tests/fixtures.gd")
const STEP: float = 1.0 / 60.0
const FOV_TOLERANCE: float = 0.01
const OFFSET_TOLERANCE: float = 0.001
const YAW_TOLERANCE: float = 0.00001
const RELEASE_BUDGET: int = 120
## SceneTree.physics_frame fires before the tick's _physics_process, so one full tick needs two awaited frames.
const TICK_FRAMES: int = 2

var _floor: StaticBody3D
var _player: PlayerController
var _rig: CameraRig


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	await _scenario_blend(tree, check)
	await _scenario_snap(tree, check)
	await _scenario_sensitivity(tree, check)
	await _scenario_recenter_and_follow(tree, check)
	await _scenario_no_swap(tree, check)


# (a2) the goggle snap: aim press adds a decaying jolt on the &"goggle_snap" sources that is gone after snap_time.
func _scenario_snap(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	_rig.snap_fov_punch = 4.0
	_rig.snap_shake_amplitude = 0.06
	Fixtures.send_action_event(&"aim", true)
	await Fixtures.wait_physics(tree, TICK_FRAMES)
	check.call(_rig._fov_sources.has(&"goggle_snap"), "(a2) aim press starts the goggle snap fov punch")
	check.call(_rig._offset_sources.has(&"goggle_snap"), "(a2) aim press starts the goggle snap shake")
	await Fixtures.wait_physics(tree, ceili(_rig.snap_time * 60.0) * TICK_FRAMES + TICK_FRAMES)
	check.call(not _rig._fov_sources.has(&"goggle_snap") and not _rig._offset_sources.has(&"goggle_snap"), "(a2) the goggle snap sources are cleared after snap_time")
	Fixtures.send_action_event(&"aim", false)
	await Fixtures.wait_physics(tree, TICK_FRAMES)


# (a) the blend: timing by tick count, full-weight FOV and offset, stacking with a kick, and the way back.
func _scenario_blend(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var steps_full: int = ceili(_rig.aim_blend_time * 60.0)
	check.call(_rig.aim_weight == 0.0, "(a) aim_weight is 0 before the hold")
	# This scenario measures the pure aim blend, so the goggle snap jolt (own test below) is off.
	_rig.snap_fov_punch = 0.0
	_rig.snap_shake_amplitude = 0.0
	# The rig stops processing before the hold, so only the hand-counted steps below move the blend.
	_rig.set_process(false)
	Fixtures.send_action_event(&"aim", true)
	await Fixtures.wait_physics(tree, TICK_FRAMES)
	check.call(_player.aiming, "(a) the player is aiming (the emitter of aim_changed)")
	for i: int in steps_full - 2:
		_rig._process(STEP)
	check.call(_rig.aim_weight > 0.0 and _rig.aim_weight < 1.0,
		"(a) after n - 2 = %d steps the weight is strictly between 0 and 1 (%.3f)" % [steps_full - 2, _rig.aim_weight])
	for i: int in 3:
		_rig._process(STEP)
	check.call(_rig.aim_weight == 1.0, "(a) after n + 1 steps the weight is 1 (%.3f)" % _rig.aim_weight)
	check.call(absf(_rig.camera.fov - (_rig.base_fov - _rig.aim_fov_delta)) < FOV_TOLERANCE,
		"(a) at full weight the fov is base_fov - aim_fov_delta (%.3f)" % _rig.camera.fov)
	check.call(absf(_rig.spring_arm.position.x - _rig.aim_shoulder_offset) < OFFSET_TOLERANCE,
		"(a) at full weight the arm sits aim_shoulder_offset to the right (%.4f)" % _rig.spring_arm.position.x)
	check.call(absf(_rig.spring_arm.position.y) < OFFSET_TOLERANCE and absf(_rig.spring_arm.position.z) < OFFSET_TOLERANCE,
		"(a) the shoulder offset is sideways only (%s)" % _rig.spring_arm.position)

	_rig.set_fov_offset(&"kick", -2.0)
	_rig._process(STEP)
	check.call(absf(_rig.camera.fov - (_rig.base_fov - _rig.aim_fov_delta - 2.0)) < FOV_TOLERANCE,
		"(a) a kick source stacks on the aim fov (%.3f)" % _rig.camera.fov)
	_rig.clear_fov_offset(&"kick")
	_rig.set_process(true)

	Fixtures.send_action_event(&"aim", false)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return _rig.aim_weight == 0.0, RELEASE_BUDGET)
	check.call(waited >= 0, "(a) the weight returns to 0 after release (waited %d)" % waited)
	await Fixtures.wait_process(tree, 2)
	check.call(absf(_rig.camera.fov - _rig.base_fov) < FOV_TOLERANCE, "(a) the fov is back at base_fov (%.3f)" % _rig.camera.fov)
	check.call(_rig.spring_arm.position == Vector3.ZERO, "(a) the arm is back at the pivot (%s)" % _rig.spring_arm.position)
	check.call(absf(_rig.get_fov_total() - _rig.base_fov) < FOV_TOLERANCE, "(a) get_fov_total is base_fov, the aim source is cleared")
	await _end(tree)


# (b) while aiming, a mouse motion turns the yaw by the scale including aim_sensitivity_factor.
func _scenario_sensitivity(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var plain_before: float = _rig.yaw
	Fixtures.send_mouse_motion(Vector2(100.0, 0.0))
	var plain: float = plain_before - _rig.yaw
	check.call(absf(plain - 100.0 * _rig.base_sensitivity * _rig.settings.sensitivity) < YAW_TOLERANCE,
		"(b) without aim 100 px turn the yaw by the plain scale (%.6f)" % plain)
	Fixtures.send_action_event(&"aim", true)
	await Fixtures.wait_physics(tree, TICK_FRAMES)
	_rig.set_process(false)
	for i: int in ceili(_rig.aim_blend_time * 60.0) + 2:
		_rig._process(STEP)
	check.call(_rig.aim_weight == 1.0, "(b) the aim weight is 1 before the motion")
	var before: float = _rig.yaw
	Fixtures.send_mouse_motion(Vector2(100.0, 0.0))
	var turned: float = before - _rig.yaw
	var expected: float = 100.0 * _rig.base_sensitivity * _rig.settings.sensitivity * _rig.aim_sensitivity_factor
	check.call(absf(turned - expected) < YAW_TOLERANCE,
		"(b) 100 px while aiming turn the yaw by the scaled amount (%.6f, expected %.6f)" % [turned, expected])
	_rig.set_process(true)
	await _end(tree)


# (c) recenter and auto-follow are off while aiming, and the steering offset is zeroed on enter.
func _scenario_recenter_and_follow(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	_rig.yaw = 1.0
	_rig._auto_offset = 0.4
	check.call(not is_equal_approx(_rig.steering_yaw(), _rig.yaw), "(c) the steering offset is non-zero before aim")
	Fixtures.send_action_event(&"aim", true)
	await Fixtures.wait_physics(tree, TICK_FRAMES)
	await Fixtures.wait_process(tree, 1)
	check.call(is_equal_approx(_rig.steering_yaw(), _rig.yaw),
		"(c) right after aim enter steering_yaw equals yaw (%.4f vs %.4f)" % [_rig.steering_yaw(), _rig.yaw])
	var yaw_before: float = _rig.yaw
	Fixtures.send_action_event(&"camera_recenter", true)
	Fixtures.send_action_event(&"camera_recenter", false)
	await Fixtures.wait_process(tree, 20)
	check.call(is_equal_approx(_rig.yaw, yaw_before), "(c) camera_recenter while aiming leaves the yaw unchanged (%.4f)" % _rig.yaw)
	_rig.recenter()
	await Fixtures.wait_process(tree, 20)
	check.call(is_equal_approx(_rig.yaw, yaw_before), "(c) recenter() while aiming does nothing (%.4f)" % _rig.yaw)

	# Auto-follow forced on: running sideways would swing a free camera, but not an aiming one.
	var follow_settings: CameraSettings = CameraSettings.new()
	follow_settings.auto_follow_mode = "on"
	_rig.apply_settings(follow_settings)
	check.call(_rig.auto_follow_active(), "(c) auto-follow is configured on")
	_rig.time_since_look = 10.0
	Input.action_press(&"move_right")
	var followed: bool = false
	for i: int in 120:
		await Fixtures.wait_process(tree, 1)
		_rig.time_since_look = 10.0
		if not is_equal_approx(_rig.yaw, yaw_before):
			followed = true
	Input.action_release(&"move_right")
	check.call(not followed, "(c) auto-follow does not turn the camera over 120 frames of strafing while aiming (yaw %.4f)" % _rig.yaw)
	check.call(is_equal_approx(_rig.steering_yaw(), _rig.yaw), "(c) steering_yaw still equals yaw after the strafe")
	await _end(tree)


# (d) no shoulder swap: no aim_shoulder_swap action exists and Q stays unbound (03-01 checkpoint item 2).
func _scenario_no_swap(_tree: SceneTree, check: Callable) -> void:
	check.call(not InputMap.has_action(&"aim_shoulder_swap"), "(d) no aim_shoulder_swap action exists")
	var q_bound: bool = false
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null and (key.physical_keycode == KEY_Q or key.keycode == KEY_Q):
				q_bound = true
	check.call(not q_bound, "(d) Q is bound to no game action")


func _begin(tree: SceneTree) -> void:
	_floor = Fixtures.spawn_floor(tree.root)
	_player = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.5, 0.0))
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	await Fixtures.wait_physics(tree, 5)
	await Fixtures.wait_process(tree, 2)


func _end(tree: SceneTree) -> void:
	Fixtures.send_action_event(&"aim", false)
	for action: StringName in [&"move_left", &"move_right", &"move_forward", &"move_back", &"dash", &"jump"]:
		Input.action_release(action)
	await Fixtures.wait_physics(tree, 2)
	if is_instance_valid(_rig):
		_rig.set_process(true)
		_rig.queue_free()
	_player.queue_free()
	_floor.queue_free()
	await Fixtures.wait_physics(tree, 2)
