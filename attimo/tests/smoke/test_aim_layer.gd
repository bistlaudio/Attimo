extends RefCounted
## MOVE-09 / CAM-02 (D-09, D-11, D-12): the clip side of aim mode. The Aim layer holds Ranged_1H_Aiming on the upper
## body while the legs keep their locomotion clip, aim strafes and walks backwards through one BlendSpace2D, the clip
## playback speed follows the movement, and aimed dashes play the directional Dodge clips. Tree parameters are read
## through the MannequinAnimator constants, never a path literal. Scenarios that count animation time run the tree in
## manual mode and advance it once per physics frame (Pitfall 12).

const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60
const LIBRARY_PATH: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const SKEL: String = "Rig_Medium/Skeleton3D:"
const SKELETON_PATH: String = "VisualRoot/Mannequin/Rig_Medium/Skeleton3D"
const AIM_BLEND_FRAMES: int = 60
const HOLD_POSE_TOLERANCE_DEG: float = 3.0
const HOLD_SAMPLE_TIME: float = 0.6
const SETTLE_FRAMES: int = 30
const STRAFE_FRAMES: int = 90
const STRAFE_BLEND_MIN: float = 0.8
const STRAFE_ROOT_YAW_MIN_DEG: float = 40.0
const SCALE_TOLERANCE: float = 0.01
const RUN_SCALE_TOLERANCE: float = 0.05
const RUN_FRAMES: int = 120
const HOLD_SCALE_TOLERANCE: float = 0.001

var _floor: StaticBody3D
var _player: PlayerController
var _rig: CameraRig
var _animator: MannequinAnimator
var _anim_tree: AnimationTree
var _library: AnimationLibrary
var _calls: Array[Dictionary] = []
var _recorder: Callable
var _machine: StateMachine


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	# The camera rig needs a tree that has finished starting up (it reads global transforms when it snaps).
	await Fixtures.wait_physics(tree, 2)
	_library = load(LIBRARY_PATH) as AnimationLibrary
	await _scenario_aim_layer(tree, check)
	await _scenario_strafe(tree, check)
	await _scenario_not_aiming(tree, check)
	await _scenario_clip_scale(tree, check)
	await _scenario_dash_scale(tree, check)


# Tracer: hold aim -> animator aim weight -> filtered Aim layer shows the held pose on the upper body.
func _scenario_aim_layer(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var machine_root: AnimationNodeBlendTree = _anim_tree.tree_root as AnimationNodeBlendTree
	var aim_node: AnimationNodeBlend2 = machine_root.get_node(&"Aim") as AnimationNodeBlend2
	check.call(aim_node != null and aim_node.filter_enabled, "(a1) the tree has an Aim Blend2 with the filter enabled")
	if aim_node != null:
		for bone: String in ["upperarm.r", "upperarm.l", "spine", "chest", "head", "hand.r", "lowerarm.l"]:
			check.call(aim_node.is_path_filtered(NodePath(SKEL + bone)), "(a2) the Aim filter takes over %s" % bone)
		for bone: String in ["hips", "root", "upperleg.l", "upperleg.r"]:
			check.call(not aim_node.is_path_filtered(NodePath(SKEL + bone)), "(a3) the Aim filter leaves %s to locomotion (legs and strafe yaw)" % bone)
	var aim_clip: AnimationNodeAnimation = machine_root.get_node(&"AimClip") as AnimationNodeAnimation
	check.call(aim_clip != null and aim_clip.animation == &"Ranged_1H_Aiming", "(a4) the AimClip node plays Ranged_1H_Aiming")
	if aim_clip != null:
		check.call(aim_clip.loop_mode == Animation.LOOP_NONE, "(a4) the AimClip never loops (Pitfall 4)")
		check.call(aim_clip.use_custom_timeline and is_equal_approx(aim_clip.start_offset, 0.6) and is_equal_approx(aim_clip.timeline_length, 0.4), "(a4) the AimClip timeline is the hold from 0.6 s, length 0.4 s (got %.2f, %.2f)" % [aim_clip.start_offset, aim_clip.timeline_length])

	check.call(is_zero_approx(float(_anim_tree.get(MannequinAnimator.P_AIM))), "(a5) the aim weight is 0 before aiming")
	Input.action_press(&"aim")
	var blended: int = await Fixtures.wait_until(tree, func() -> bool: return is_equal_approx(float(_anim_tree.get(MannequinAnimator.P_AIM)), 1.0), AIM_BLEND_FRAMES)
	check.call(blended >= 0, "(a5) holding aim brings %s to 1.0 within %d frames (took %d)" % [MannequinAnimator.P_AIM, AIM_BLEND_FRAMES, blended])
	var expected_frames: int = ceili(_player.config.aim_layer_blend_time * float(SHIPPED_TPS))
	check.call(blended >= 0 and blended <= expected_frames + 3, "(a5) the blend takes about aim_layer_blend_time (%d frames, took %d)" % [expected_frames, blended])

	# The upper arm shows the held pose and the pelvis does not.
	var previous_mode: AnimationMixer.AnimationCallbackModeProcess = _anim_tree.callback_mode_process
	_anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for i: int in 10:
		_anim_tree.advance(1.0 / float(SHIPPED_TPS))
	var skeleton: Skeleton3D = _player.get_node(SKELETON_PATH) as Skeleton3D
	check.call(skeleton != null, "(a6) the Mannequin skeleton is reachable")
	if skeleton != null:
		var arm_bone: int = skeleton.find_bone(&"upperarm.r")
		var arm_track: int = _aim_animation().find_track(NodePath(SKEL + "upperarm.r"), Animation.TYPE_ROTATION_3D)
		check.call(arm_bone >= 0 and arm_track >= 0, "(a6) upperarm.r exists on the skeleton and in the aim clip")
		if arm_bone >= 0 and arm_track >= 0:
			var expected: Quaternion = _aim_animation().rotation_track_interpolate(arm_track, HOLD_SAMPLE_TIME)
			var shown: Quaternion = skeleton.get_bone_pose_rotation(arm_bone)
			var error_deg: float = rad_to_deg(shown.angle_to(expected))
			check.call(error_deg < HOLD_POSE_TOLERANCE_DEG, "(a6) upperarm.r shows the held aim pose (%.2f deg from the clip at 0.6 s)" % error_deg)
	_anim_tree.callback_mode_process = previous_mode

	Input.action_release(&"aim")
	var released: int = await Fixtures.wait_until(tree, func() -> bool: return is_zero_approx(float(_anim_tree.get(MannequinAnimator.P_AIM))), AIM_BLEND_FRAMES)
	check.call(released >= 0, "(a7) releasing aim brings the aim weight back to 0 (took %d frames)" % released)
	await _end(tree)


# D-09: in aim, moving sideways or backwards relative to the facing blends the strafe and backward clips.
func _scenario_strafe(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	Input.action_press(&"aim")
	Input.action_press(&"move_right")
	var right: int = await Fixtures.wait_until(tree, func() -> bool: return Fixtures.locomotion_blend(_player).x > STRAFE_BLEND_MIN, STRAFE_FRAMES)
	check.call(right >= 0, "(b1) aiming with move_right drives the blend x above %.1f within %d frames (got %s)" % [STRAFE_BLEND_MIN, STRAFE_FRAMES, Fixtures.locomotion_blend(_player)])
	# The strafe clip carries its direction in the root bone yaw (Pitfall 3); the pose is read in manual mode.
	var previous_mode: AnimationMixer.AnimationCallbackModeProcess = _anim_tree.callback_mode_process
	_anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for i: int in 10:
		await tree.physics_frame
		_anim_tree.advance(1.0 / float(SHIPPED_TPS))
	var skeleton: Skeleton3D = _player.get_node(SKELETON_PATH) as Skeleton3D
	var root_bone: int = skeleton.find_bone(&"root")
	check.call(root_bone >= 0, "(b2) the skeleton has the root bone")
	if root_bone >= 0:
		var yaw: float = rad_to_deg(skeleton.get_bone_pose_rotation(root_bone).get_euler(EULER_ORDER_YXZ).y)
		check.call(absf(yaw) > STRAFE_ROOT_YAW_MIN_DEG, "(b2) the strafe right clip turns the root bone by more than %.0f deg (got %.1f)" % [STRAFE_ROOT_YAW_MIN_DEG, yaw])
	_anim_tree.callback_mode_process = previous_mode
	Input.action_release(&"move_right")
	Input.action_press(&"move_left")
	var left: int = await Fixtures.wait_until(tree, func() -> bool: return Fixtures.locomotion_blend(_player).x < -STRAFE_BLEND_MIN, STRAFE_FRAMES * 2)
	check.call(left >= 0, "(b3) aiming with move_left drives the blend x below -%.1f (got %s)" % [STRAFE_BLEND_MIN, Fixtures.locomotion_blend(_player)])
	Input.action_release(&"move_left")
	Input.action_press(&"move_back")
	var back: int = await Fixtures.wait_until(tree, func() -> bool: return Fixtures.locomotion_blend(_player).y < -STRAFE_BLEND_MIN, STRAFE_FRAMES * 2)
	check.call(back >= 0, "(b4) aiming with move_back drives the blend y below -%.1f (got %s)" % [STRAFE_BLEND_MIN, Fixtures.locomotion_blend(_player)])
	Input.action_release(&"move_back")
	Input.action_press(&"move_forward")
	var forward: int = await Fixtures.wait_until(tree, func() -> bool: return Fixtures.locomotion_blend(_player).y > STRAFE_BLEND_MIN, STRAFE_FRAMES * 2)
	check.call(forward >= 0, "(b5) aiming with move_forward reaches the full run blend although the aim run is slower than run_speed (got %s)" % Fixtures.locomotion_blend(_player))
	await _end(tree)


# D-09: outside aim the strafe axis is forced to 0, whatever direction the camera-relative input has.
func _scenario_not_aiming(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	Input.action_press(&"move_right")
	await Fixtures.wait_physics(tree, 40)
	var blend: Vector2 = Fixtures.locomotion_blend(_player)
	check.call(not _player.aiming and _player.horizontal_speed() > 1.0, "(c1) the player runs sideways to the camera without aiming (speed %.2f)" % _player.horizontal_speed())
	check.call(blend.x == 0.0, "(c1) outside aim the strafe axis is exactly 0 (got %s)" % blend)
	check.call(blend.y > 0.5, "(c1) outside aim the forward weight follows the speed (got %.2f)" % blend.y)
	await _end(tree)


# Pitfall 6: Running_A plays faster with ground speed, up to run_anim_max_scale; idle plays at 1x.
func _scenario_clip_scale(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var config: MovementConfig = _player.config
	check.call(is_equal_approx(float(_anim_tree.get(MannequinAnimator.P_TIME_SCALE)), 1.0), "(d1) idle plays at 1x (got %s)" % _anim_tree.get(MannequinAnimator.P_TIME_SCALE))
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return _player.horizontal_speed() > config.run_speed - 0.01, RUN_FRAMES)
	await Fixtures.wait_physics(tree, 2)
	var expected: float = clampf(config.run_speed / config.run_anim_ref_speed, 1.0, config.run_anim_max_scale)
	var shown: float = float(_anim_tree.get(MannequinAnimator.P_TIME_SCALE))
	check.call(absf(shown - expected) < RUN_SCALE_TOLERANCE, "(d2) full speed plays Running_A at %.2fx (got %.2f)" % [expected, shown])
	check.call(is_finite(_animator.clip_scale()) and _animator.clip_scale() >= 1.0, "(d3) clip_scale() is finite and at least 1.0 (got %s)" % _animator.clip_scale())
	# A zero reference speed is clamped by the animator, so the scale stays finite and inside its band (T-03-11).
	var saved_ref: float = config.run_anim_ref_speed
	config.run_anim_ref_speed = 0.0
	var clamped: float = _animator.clip_scale()
	config.run_anim_ref_speed = saved_ref
	check.call(is_finite(clamped) and clamped <= config.run_anim_max_scale + 0.0001, "(d3) a zero reference speed still gives a finite scale within the band (got %s)" % clamped)
	await _end(tree)


# Pitfall 6: a ground dash plays its Dodge clip in exactly dash_time, an air dash and its pose hold play at 1x.
func _scenario_dash_scale(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	_record()
	var config: MovementConfig = _player.config
	var dodge_length: float = _library.get_animation(&"Dodge_Forward").length
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.tap_action(tree, &"dash")
	var entry: int = _find(&"Run", &"Dash")
	check.call(entry >= 0, "(e1) Run -> Dash was recorded (calls %s)" % [_names()])
	if entry >= 0:
		var expected: float = dodge_length / config.dash_time
		check.call(absf(float(_calls[entry]["scale"]) - expected) < SCALE_TOLERANCE, "(e1) the ground dash plays Dodge_Forward in dash_time: scale %.3f on the entry frame, expected %.3f" % [_calls[entry]["scale"], expected])
	Input.action_release(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return _player.is_grounded() and _player.state_machine.current.name == &"Idle", 120)
	await Fixtures.wait_physics(tree, 40)
	_calls.clear()
	# Air dash from a low tap jump: scale 1 on entry and on every frame of the hold (DEV-02).
	await Fixtures.tap_action(tree, &"jump")
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"dash")
	var samples: int = 0
	var hold_samples: int = 0
	var worst_hold_deviation: float = 0.0
	for i: int in 90:
		await tree.physics_frame
		if _animator.last_travel == &"Dash":
			samples += 1
			var deviation: float = absf(_animator.clip_scale() - 1.0)
			worst_hold_deviation = maxf(worst_hold_deviation, deviation)
			if _animator.air_dash_holding:
				hold_samples += 1
	var air_entry: int = _find(&"Jump", &"Dash")
	check.call(air_entry >= 0, "(e2) Jump -> Dash was recorded for the air dash (calls %s)" % [_names()])
	if air_entry >= 0:
		check.call(absf(float(_calls[air_entry]["scale"]) - 1.0) < HOLD_SCALE_TOLERANCE, "(e2) an air dash plays at 1x on the entry frame (got %.3f)" % _calls[air_entry]["scale"])
	check.call(hold_samples > 0 and worst_hold_deviation < HOLD_SCALE_TOLERANCE, "(e2) the scale stays 1.0 on every frame of the dash and its pose hold (%d frames, %d in the hold, worst deviation %.4f)" % [samples, hold_samples, worst_hold_deviation])
	await _end(tree)


func _aim_animation() -> Animation:
	return _library.get_animation(&"Ranged_1H_Aiming")


## Spawns floor, player and a camera rig (aim needs a camera frame) and waits until the scene has settled.
func _begin(tree: SceneTree) -> void:
	_floor = Fixtures.spawn_floor(tree.root)
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	await Fixtures.wait_physics(tree, SETTLE_FRAMES)
	_animator = _player.get_node("MannequinAnimator") as MannequinAnimator
	_anim_tree = Fixtures.animation_tree(_player)


## Releases every action and frees the scenario's nodes.
func _end(tree: SceneTree) -> void:
	for action: StringName in [&"aim", &"jump", &"dash", &"move_forward", &"move_left", &"move_right", &"move_back"]:
		Input.action_release(action)
		Fixtures.send_action_event(action, false)
	_stop_recording()
	_rig.queue_free()
	_player.queue_free()
	_floor.queue_free()
	await _player.tree_exited
	await Fixtures.wait_physics(tree, 1)


## Records every state_changed call after the animator's own handler: from, to, the animator's view and the scale
## written to the tree, all read inside the call.
func _record() -> void:
	_calls = []
	_machine = _player.state_machine
	var animator: MannequinAnimator = _animator
	var anim_tree: AnimationTree = _anim_tree
	_recorder = func(from_state: StringName, to_state: StringName) -> void:
		_calls.append({
			"from": from_state,
			"to": to_state,
			"travel": animator.last_travel,
			"travel_frame": animator.last_travel_frame,
			"holding": animator.air_dash_holding,
			"scale": float(anim_tree.get(MannequinAnimator.P_TIME_SCALE)),
			"frame": Engine.get_physics_frames(),
		})
	_machine.state_changed.connect(_recorder)


func _stop_recording() -> void:
	if _machine != null and _machine.state_changed.is_connected(_recorder):
		_machine.state_changed.disconnect(_recorder)
	_recorder = Callable()
	_machine = null


## Index of the first recorded call from -> to, or -1.
func _find(from_state: StringName, to_state: StringName) -> int:
	for i: int in _calls.size():
		if _calls[i]["from"] == from_state and _calls[i]["to"] == to_state:
			return i
	return -1


func _names() -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in _calls:
		names.append("%s->%s" % [entry["from"], entry["to"]])
	return names
