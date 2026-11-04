extends RefCounted
## FOUND-05 / FOUND-04: the Mannequin under VisualRoot idles and the AnimationTree follows the FSM in place (D-09).

const Fixtures := preload("res://tests/fixtures.gd")
const POSE_CHANGE_EPSILON: float = 0.001


func run(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 10)

	var animation_tree := player.get_node_or_null("VisualRoot/Mannequin/AnimationTree") as AnimationTree
	check.call(animation_tree != null, "VisualRoot/Mannequin/AnimationTree exists")
	if animation_tree == null:
		player.queue_free()
		return
	check.call(animation_tree.active, "AnimationTree is active")
	check.call(player.visual_root.position == Vector3.ZERO, "VisualRoot sits at the Player origin")
	check.call(player.visual_root.get_node_or_null("Mannequin") != null, "Mannequin is a child of VisualRoot")

	var playback := animation_tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
	check.call(playback != null, "playback is reachable at parameters/playback")
	if playback == null:
		player.queue_free()
		return
	check.call(playback.get_current_node() == &"Locomotion", "starts in Locomotion (got %s)" % playback.get_current_node())
	check.call(is_zero_approx(float(animation_tree.get(&"parameters/Locomotion/blend_position"))), "blend_position is 0.0 (idle)")

	# Idle clip plays and keeps looping past one clip length (Idle_A is 1.067 s).
	var skeleton: Skeleton3D = _find_skeleton(player.visual_root)
	check.call(skeleton != null, "Skeleton3D found under the Mannequin")
	if skeleton == null:
		player.queue_free()
		return
	var pose_a: Array[Quaternion] = _record_pose(skeleton)
	await Fixtures.wait_physics(tree, 20)
	check.call(_max_pose_delta(skeleton, pose_a) > POSE_CHANGE_EPSILON, "bone poses change after 20 frames (clip plays)")
	await Fixtures.wait_physics(tree, 90)
	var pose_b: Array[Quaternion] = _record_pose(skeleton)
	await Fixtures.wait_physics(tree, 20)
	check.call(playback.get_current_node() == &"Locomotion", "still Locomotion after 1.5 s")
	check.call(_max_pose_delta(skeleton, pose_b) > POSE_CHANGE_EPSILON, "bone poses still change past one clip length (Idle_A loops)")

	# Space -> Jump_Start.
	await Fixtures.tap_action(tree, &"jump", 2)
	var reached_jump: bool = playback.get_current_node() == &"Jump"
	for i: int in 3:
		if reached_jump:
			break
		await tree.physics_frame
		reached_jump = playback.get_current_node() == &"Jump"
	check.call(reached_jump, "jump press travels the tree to Jump (got %s)" % playback.get_current_node())

	# Timer-driven jump ends in Idle; the tree plays Land and returns to Locomotion.
	var seen: Dictionary[StringName, bool] = {}
	var fsm_idle_again: bool = false
	var back_in_locomotion: bool = false
	for i: int in 150:
		await tree.physics_frame
		var node: StringName = playback.get_current_node()
		seen[node] = true
		if player.state_machine.current.name == &"Idle":
			fsm_idle_again = true
		if fsm_idle_again and node == &"Locomotion":
			back_in_locomotion = true
			break
	check.call(fsm_idle_again, "FSM reports Idle again after the jump")
	check.call(seen.has(&"Land"), "tree played Land on the way back (seen %s)" % [seen.keys()])
	check.call(back_in_locomotion, "tree returned to Locomotion within 90 frames of the FSM landing")

	check.call(player.global_position == Vector3.ZERO, "D-09: Player did not move")

	player.queue_free()
	await tree.process_frame


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null


func _record_pose(skeleton: Skeleton3D) -> Array[Quaternion]:
	var pose: Array[Quaternion] = []
	for bone: int in skeleton.get_bone_count():
		pose.append(skeleton.get_bone_pose_rotation(bone))
	return pose


func _max_pose_delta(skeleton: Skeleton3D, reference: Array[Quaternion]) -> float:
	var biggest: float = 0.0
	for bone: int in skeleton.get_bone_count():
		biggest = maxf(biggest, skeleton.get_bone_pose_rotation(bone).angle_to(reference[bone]))
	return biggest
