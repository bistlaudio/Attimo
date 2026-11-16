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

var _floor: StaticBody3D
var _player: PlayerController
var _rig: CameraRig
var _animator: MannequinAnimator
var _anim_tree: AnimationTree
var _library: AnimationLibrary


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	# The camera rig needs a tree that has finished starting up (it reads global transforms when it snaps).
	await Fixtures.wait_physics(tree, 2)
	_library = load(LIBRARY_PATH) as AnimationLibrary
	await _scenario_aim_layer(tree, check)


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
	_rig.queue_free()
	_player.queue_free()
	_floor.queue_free()
	await _player.tree_exited
	await Fixtures.wait_physics(tree, 1)
