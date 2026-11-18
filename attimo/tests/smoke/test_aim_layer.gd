extends RefCounted
## MOVE-09 / CAM-02 (D-09, D-11, D-12): the clip side of aim mode. The Aim layer is the UAL spell hand (quick 261118-qi3:
## Enter, Hold, Exit and a Shoot OneShot; the KayKit Ranged_1H_Aiming is the fallback of a dropped clip) on the upper
## body while the legs keep their locomotion clip, aim strafes and walks backwards through one BlendSpace2D, the clip
## playback speed follows the movement, and aimed dashes play the directional Dodge clips. Tree parameters are read
## through the MannequinAnimator constants, never a path literal. Scenarios that count animation time run the tree in
## manual mode and advance it once per physics frame (Pitfall 12).

const Fixtures := preload("res://tests/fixtures.gd")
## The animation node of the unaimed ground dash: Slide only while Dash.SLIDE_PRESENTATION is on (off since 2026-11-18).
const UNAIMED_DASH: StringName = &"Slide" if preload("res://scripts/player/states/dash.gd").SLIDE_PRESENTATION else &"Dash"
const SHIPPED_TPS: int = 60
const LIBRARY_PATH: String = "res://assets/animations/rig_medium/rig_medium_library.res"
const SKEL: String = "Rig_Medium/Skeleton3D:"
const SKELETON_PATH: String = "VisualRoot/Mannequin/Rig_Medium/Skeleton3D"
const AIM_BLEND_FRAMES: int = 60
const HOLD_POSE_TOLERANCE_DEG: float = 3.0
const SPELL_CLIPS: Dictionary[StringName, StringName] = {
	&"Enter": &"UAL_Spell_Simple_Enter", &"Hold": &"UAL_Spell_Simple_Idle_Loop", &"Exit": &"UAL_Spell_Simple_Exit", &"ShootClip": &"UAL_Spell_Simple_Shoot",
}
const P_SHOOT_ACTIVE: StringName = &"parameters/Shoot/active"
const HAND_BONE: StringName = &"upperarm.l"
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
	await _scenario_spell_hand(tree, check)
	await _scenario_strafe(tree, check)
	await _scenario_not_aiming(tree, check)
	await _scenario_clip_scale(tree, check)
	await _scenario_dash_scale(tree, check)
	await _scenario_aim_dash_choice(tree, check)
	await _scenario_air_dash_directional(tree, check)


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
	check.call(not machine_root.has_node(&"AimClip"), "(a4) the old AimClip node is gone")
	var shoot: AnimationNodeOneShot = machine_root.get_node(&"Shoot") as AnimationNodeOneShot
	check.call(shoot != null and is_equal_approx(shoot.fadein_time, 0.05) and is_equal_approx(shoot.fadeout_time, 0.1), "(a4) the tree has a Shoot OneShot with fade 0.05 in and 0.1 out")
	var aim_machine: AnimationNodeStateMachine = machine_root.get_node(&"AimMachine") as AnimationNodeStateMachine
	check.call(aim_machine != null, "(a4) the tree has the AimMachine state machine")
	check.call(_input_of(machine_root, &"Shoot", 0) == &"AimMachine" and _input_of(machine_root, &"Shoot", 1) == &"ShootClip", "(a4) the Shoot OneShot takes the AimMachine (input 0) and the ShootClip (input 1)")
	check.call(_input_of(machine_root, &"Aim", 1) == &"Shoot", "(a4) the Aim layer's input 1 is the Shoot node")
	var dropped: Array[StringName] = _dropped_list()
	for node_name: StringName in SPELL_CLIPS:
		var holder: AnimationNodeAnimation = null
		if node_name == &"ShootClip":
			holder = machine_root.get_node(&"ShootClip") as AnimationNodeAnimation
		elif aim_machine != null:
			holder = aim_machine.get_node(node_name) as AnimationNodeAnimation
		var ual: StringName = SPELL_CLIPS[node_name]
		var expected_clip: StringName = _fallback_of(ual) if dropped.has(ual) else ual
		check.call(holder != null and holder.animation == expected_clip, "(a4) the %s node plays %s" % [node_name, expected_clip])
		if holder != null and not dropped.has(ual):
			var wants_loop: bool = node_name == &"Hold"
			check.call(_library.get_animation(ual).loop_mode == (Animation.LOOP_LINEAR if wants_loop else Animation.LOOP_NONE), "(a4) %s %s" % [ual, "loops" if wants_loop else "does not loop"])

	check.call(is_zero_approx(float(_anim_tree.get(MannequinAnimator.P_AIM))), "(a5) the aim weight is 0 before aiming")
	Input.action_press(&"aim")
	var blended: int = await Fixtures.wait_until(tree, func() -> bool: return is_equal_approx(float(_anim_tree.get(MannequinAnimator.P_AIM)), 1.0), AIM_BLEND_FRAMES)
	check.call(blended >= 0, "(a5) holding aim brings %s to 1.0 within %d frames (took %d)" % [MannequinAnimator.P_AIM, AIM_BLEND_FRAMES, blended])
	var expected_frames: int = ceili(_player.config.aim_layer_blend_time * float(SHIPPED_TPS))
	check.call(blended >= 0 and blended <= expected_frames + 3, "(a5) the blend takes about aim_layer_blend_time (%d frames, took %d)" % [expected_frames, blended])

	# The left upper arm (the right arm belongs to AimPoseModifier) shows the Hold clip once the Enter clip has handed over.
	var machine_playback: AnimationNodeStateMachinePlayback = _anim_tree.get(MannequinAnimator.P_AIM_PLAYBACK) as AnimationNodeStateMachinePlayback
	var in_hold: int = await Fixtures.wait_until(tree, func() -> bool: return machine_playback.get_current_node() == &"Hold", AIM_BLEND_FRAMES)
	check.call(in_hold >= 0, "(a6) the spell hand reaches Hold after Enter (took %d frames)" % in_hold)
	await Fixtures.wait_physics(tree, 12)
	var previous_mode: AnimationMixer.AnimationCallbackModeProcess = _anim_tree.callback_mode_process
	_anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for i: int in 10:
		_anim_tree.advance(1.0 / float(SHIPPED_TPS))
	var skeleton: Skeleton3D = _player.get_node(SKELETON_PATH) as Skeleton3D
	check.call(skeleton != null, "(a6) the Mannequin skeleton is reachable")
	if skeleton != null and aim_machine != null:
		var arm_bone: int = skeleton.find_bone(HAND_BONE)
		var hold_node: AnimationNodeAnimation = aim_machine.get_node(&"Hold") as AnimationNodeAnimation
		var hold_clip: Animation = _library.get_animation(hold_node.animation)
		var arm_track: int = hold_clip.find_track(NodePath(SKEL + String(HAND_BONE)), Animation.TYPE_ROTATION_3D)
		check.call(arm_bone >= 0 and arm_track >= 0, "(a6) %s exists on the skeleton and in the Hold clip" % HAND_BONE)
		if arm_bone >= 0 and arm_track >= 0:
			var position: float = machine_playback.get_current_play_position()
			var window_start: float = hold_node.start_offset if hold_node.use_custom_timeline else 0.0
			var expected: Quaternion = hold_clip.rotation_track_interpolate(arm_track, window_start + position)
			var shown: Quaternion = skeleton.get_bone_pose_rotation(arm_bone)
			var error_deg: float = rad_to_deg(shown.angle_to(expected))
			check.call(error_deg < HOLD_POSE_TOLERANCE_DEG, "(a6) %s shows the Hold pose at %.2f s (%.2f deg from the clip)" % [HAND_BONE, position, error_deg])
	_anim_tree.callback_mode_process = previous_mode

	Input.action_release(&"aim")
	var released: int = await Fixtures.wait_until(tree, func() -> bool: return is_zero_approx(float(_anim_tree.get(MannequinAnimator.P_AIM))), AIM_BLEND_FRAMES)
	check.call(released >= 0, "(a7) releasing aim brings the aim weight back to 0 (took %d frames)" % released)
	await _end(tree)


# The spell hand: Enter on the press frame, Hold, a Shoot OneShot while aiming only, Exit on the release.
func _scenario_spell_hand(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	var machine: AnimationNodeStateMachinePlayback = _anim_tree.get(MannequinAnimator.P_AIM_PLAYBACK) as AnimationNodeStateMachinePlayback
	check.call(machine != null, "(h1) the tree exposes the AimMachine playback")
	if machine == null:
		await _end(tree)
		return
	# use_hand outside aim fires nothing.
	await Fixtures.tap_action(tree, &"use_hand")
	await Fixtures.wait_process(tree, 2)
	check.call(not bool(_anim_tree.get(P_SHOOT_ACTIVE)), "(h2) use_hand without aim does not fire the Shoot OneShot")

	Input.action_press(&"aim")
	await Fixtures.wait_physics(tree, 2)
	await Fixtures.wait_process(tree, 2)
	check.call(machine.get_current_node() == &"Enter", "(h3) an aim press starts the spell hand at Enter within 2 physics frames (node %s)" % machine.get_current_node())
	check.call(machine.get_current_play_position() < 4.0 / float(SHIPPED_TPS) + 0.02, "(h3) Enter has just started (position %.3f s)" % machine.get_current_play_position())
	var enter_length: float = _clip_length(&"Enter")
	var reached: int = await Fixtures.wait_until(tree, func() -> bool: return machine.get_current_node() == &"Hold", int(ceil(enter_length * float(SHIPPED_TPS))) + 20)
	check.call(reached >= 0, "(h4) Enter hands over to Hold after the Enter clip (%d frames, clip %.2f s)" % [reached, enter_length])
	await Fixtures.wait_physics(tree, 30)
	check.call(machine.get_current_node() == &"Hold", "(h4) holding aim stays in Hold (node %s)" % machine.get_current_node())

	await Fixtures.tap_action(tree, &"use_hand")
	await Fixtures.wait_process(tree, 2)
	check.call(bool(_anim_tree.get(P_SHOOT_ACTIVE)), "(h5) use_hand while aiming fires the Shoot OneShot")
	var shot_done: int = await Fixtures.wait_until(tree, func() -> bool: return not bool(_anim_tree.get(P_SHOOT_ACTIVE)), 90)
	check.call(shot_done >= 0, "(h5) the Shoot OneShot ends on its own (%d frames)" % shot_done)
	check.call(machine.get_current_node() == &"Hold", "(h5) the hand is still in Hold after the shot")

	Input.action_release(&"aim")
	await Fixtures.wait_physics(tree, 2)
	await Fixtures.wait_process(tree, 2)
	check.call(machine.get_current_node() == &"Exit", "(h6) an aim release travels to Exit within 2 physics frames (node %s)" % machine.get_current_node())
	var exit_length: float = _clip_length(&"Exit")
	var half_frames: int = int(floor(exit_length * 0.5 * float(SHIPPED_TPS)))
	await Fixtures.wait_physics(tree, half_frames)
	var layer_during_exit: float = float(_anim_tree.get(MannequinAnimator.P_AIM))
	check.call(layer_during_exit > 0.99, "(h6) the layer stays up while Exit plays (%.2f at %.2f s)" % [layer_during_exit, exit_length * 0.5])
	var faded: int = await Fixtures.wait_until(tree, func() -> bool: return is_zero_approx(float(_anim_tree.get(MannequinAnimator.P_AIM))), 60)
	var limit_frames: int = int(ceil((exit_length + _player.config.aim_layer_blend_time) * float(SHIPPED_TPS))) + 4
	check.call(faded >= 0 and faded + half_frames + 4 <= limit_frames, "(h6) the layer reaches 0 within Exit length plus aim_layer_blend_time (%d + %d frames, limit %d)" % [half_frames + 4, faded, limit_frames])
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
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.tap_action(tree, &"dash")
	var entry: int = _find(&"Run", &"Dash")
	check.call(entry >= 0, "(e1) Run -> Dash was recorded (calls %s)" % [_names()])
	if entry >= 0:
		var expected: float = MannequinAnimator.SLIDE_PLAYBACK_SCALE if UNAIMED_DASH == &"Slide" else _library.get_animation(&"Dodge_Forward").length / config.dash_time
		check.call(_calls[entry]["travel"] == UNAIMED_DASH, "(e1) the unaimed ground dash travels to its node inside the call (got %s)" % _calls[entry]["travel"])
		check.call(absf(float(_calls[entry]["scale"]) - expected) < SCALE_TOLERANCE, "(e1) the unaimed ground dash plays the Slide window at the fixed slide scale: scale %.3f on the entry frame, expected %.3f" % [_calls[entry]["scale"], expected])
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


# D-12: an aimed ground dash plays the Dodge clip of its direction relative to the facing; an unaimed one is Slide (DEV-04).
func _scenario_aim_dash_choice(tree: SceneTree, check: Callable) -> void:
	await _aim_dash_case(tree, check, true, &"move_right", &"DashRight", &"Dodge_Right", "(f1)")
	await _aim_dash_case(tree, check, true, &"move_left", &"DashLeft", &"Dodge_Left", "(f2)")
	await _aim_dash_case(tree, check, true, &"move_back", &"DashBack", &"Dodge_Backward", "(f3)")
	await _aim_dash_case(tree, check, true, &"move_forward", &"Dash", &"Dodge_Forward", "(f4)")
	await _aim_dash_case(tree, check, true, &"", &"Dash", &"Dodge_Forward", "(f5)")
	await _aim_dash_case(tree, check, false, &"move_right", UNAIMED_DASH, &"Running_Slide" if UNAIMED_DASH == &"Slide" else &"Dodge_Forward", "(f6)")


func _aim_dash_case(tree: SceneTree, check: Callable, aiming: bool, move: StringName, expected_node: StringName, clip: StringName, label: String) -> void:
	await _begin(tree)
	_record()
	var how: String = "%s%s" % ["aiming, " if aiming else "", String(move) if move != &"" else "no input"]
	if aiming:
		Input.action_press(&"aim")
		await Fixtures.wait_physics(tree, 12)
	if move != &"":
		Input.action_press(move)
		await Fixtures.wait_physics(tree, 6)
	await Fixtures.tap_action(tree, &"dash")
	var dash_call: int = _find_to(&"Dash")
	check.call(dash_call >= 0, "%s a dash was recorded (%s; calls %s)" % [label, how, _names()])
	if dash_call >= 0:
		var entry: Dictionary = _calls[dash_call]
		check.call(entry["travel"] == expected_node, "%s %s: last_travel is %s inside the Dash call (got %s)" % [label, how, expected_node, entry["travel"]])
		check.call(entry["travel_frame"] == entry["frame"], "%s %s: last_travel_frame %d equals the physics frame %d of the call" % [label, how, entry["travel_frame"], entry["frame"]])
		var clip_length: float = _slide_window() if expected_node == &"Slide" else _library.get_animation(clip).length
		var expected_scale: float = MannequinAnimator.SLIDE_PLAYBACK_SCALE if expected_node == &"Slide" else clip_length / _player.config.dash_time
		check.call(absf(float(entry["scale"]) - expected_scale) < SCALE_TOLERANCE, "%s %s: the ground dash scale is %s length / dash_time = %.3f (got %.3f)" % [label, how, clip, expected_scale, entry["scale"]])
		await Fixtures.wait_process(tree, 2)
		var visible: StringName = Fixtures.playback(_player).get_current_node()
		check.call(visible == expected_node, "%s %s: the playback is on %s within 2 process frames (got %s)" % [label, how, expected_node, visible])
	await _end(tree)


# DEV-02 with a directional node: the air dash holds DashRight past the Dash exit and landing travels on its frame.
func _scenario_air_dash_directional(tree: SceneTree, check: Callable) -> void:
	await _begin(tree)
	_record()
	Input.action_press(&"aim")
	await Fixtures.wait_physics(tree, 12)
	await Fixtures.tap_action(tree, &"jump")
	await Fixtures.wait_physics(tree, 4)
	Input.action_press(&"move_right")
	await Fixtures.tap_action(tree, &"dash")
	var exited: int = await Fixtures.wait_until(tree, func() -> bool: return _find(&"Dash", &"Fall") >= 0, 30)
	check.call(exited >= 0, "(g1) the aimed air dash exits into Fall (calls %s)" % [_names()])
	var exit_call: int = _find(&"Dash", &"Fall")
	if exit_call >= 0:
		check.call(_calls[exit_call]["holding"] == true, "(g1) air_dash_holding is true inside the Dash -> Fall call")
		check.call(_calls[exit_call]["travel"] == &"DashRight", "(g1) the playback stays on DashRight through the Dash -> Fall call (got %s)" % _calls[exit_call]["travel"])
		check.call(absf(float(_calls[exit_call]["scale"]) - 1.0) < HOLD_SCALE_TOLERANCE, "(g1) the held DashRight plays at 1x (got %.3f)" % _calls[exit_call]["scale"])
	await Fixtures.wait_process(tree, 2)
	if _find_from(&"Fall") < 0:
		var held: StringName = Fixtures.playback(_player).get_current_node()
		check.call(held == &"DashRight", "(g2) two process frames after the exit the tree is still on DashRight (got %s)" % held)
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return _find_from(&"Fall") >= 0, 120)
	check.call(landed >= 0, "(g3) the aimed air dash jump ends on the floor (calls %s)" % [_names()])
	var land_call: int = _find_from(&"Fall")
	if land_call >= 0:
		var land: Dictionary = _calls[land_call]
		check.call(land["holding"] == false, "(g3) air_dash_holding is false inside the landing call")
		check.call(land["travel"] == &"Locomotion" and land["travel_frame"] == land["frame"], "(g3) landing travels to Locomotion on the landing frame (travel %s at %d, call at %d)" % [land["travel"], land["travel_frame"], land["frame"]])
	await _end(tree)


## Length in seconds the AimMachine node plays (its window, or the whole clip).
func _clip_length(node_name: StringName) -> float:
	var root: AnimationNodeBlendTree = _anim_tree.tree_root as AnimationNodeBlendTree
	var machine: AnimationNodeStateMachine = root.get_node(&"AimMachine") as AnimationNodeStateMachine
	var node: AnimationNodeAnimation = machine.get_node(node_name) as AnimationNodeAnimation
	return node.timeline_length if node.use_custom_timeline else _library.get_animation(node.animation).length


## The node wired to input `index` of `node_name` in a BlendTree, or &"". The tree stores its connections as the flat
## array node_connections of (receiving node, input index, sending node) triples (the layout of connect_node()).
func _input_of(root: AnimationNodeBlendTree, node_name: StringName, index: int) -> StringName:
	var raw: Array = root.get(&"node_connections") as Array
	for position: int in range(0, raw.size() - 2, 3):
		if raw[position] == node_name and int(raw[position + 1]) == index:
			return raw[position + 2]
	return &""


## The documented drop list of tools/build_animation_library.gd.
func _dropped_list() -> Array[StringName]:
	var script: GDScript = load("res://tools/build_animation_library.gd") as GDScript
	var result: Array[StringName] = []
	for entry: Variant in script.get_script_constant_map().get("UAL_DROPPED", []):
		result.append(StringName(entry))
	return result


## The FALLBACK clip of tools/build_mannequin_tree.gd for a UAL clip.
func _fallback_of(ual_clip: StringName) -> StringName:
	var script: GDScript = load("res://tools/build_mannequin_tree.gd") as GDScript
	var table: Dictionary = script.get_script_constant_map().get("FALLBACK", {})
	return StringName(table.get(ual_clip, &""))


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


## Index of the first recorded call into `to_state`, or -1.
func _find_to(to_state: StringName) -> int:
	for i: int in _calls.size():
		if _calls[i]["to"] == to_state:
			return i
	return -1


## Index of the first recorded call out of `from_state`, or -1.
func _find_from(from_state: StringName) -> int:
	for i: int in _calls.size():
		if _calls[i]["from"] == from_state:
			return i
	return -1


func _names() -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in _calls:
		names.append("%s->%s" % [entry["from"], entry["to"]])
	return names


## The part of the Slide window that plays in dash_time: the drop ("drop_length" metadata, 2026-11-18), else the window.
func _slide_window() -> float:
	var root: AnimationNodeBlendTree = _animator.animation_tree.tree_root as AnimationNodeBlendTree
	var machine: AnimationNodeStateMachine = root.get_node(&"StateMachine") as AnimationNodeStateMachine
	var node: AnimationNodeAnimation = machine.get_node(&"Slide") as AnimationNodeAnimation
	return float(node.get_meta(&"drop_length", node.timeline_length))
