extends RefCounted
## FOUND-05 / FOUND-04: the Mannequin under VisualRoot idles on a floor and the AnimationTree follows the FSM
## through a real jump and landing.

const Fixtures := preload("res://tests/fixtures.gd")
const POSE_CHANGE_EPSILON: float = 0.001
const REST_BLEND_MAX: float = 0.05
const RUN_BLEND_MIN: float = 0.8
const RUN_BLEND_FRAMES: int = 90
const REST_BLEND_FRAMES: int = 120
const LAND_ACTIVE_FRAMES: int = 30


func run(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	await Fixtures.wait_physics(tree, 10)

	var animation_tree := player.get_node_or_null("VisualRoot/Mannequin/AnimationTree") as AnimationTree
	check.call(animation_tree != null, "VisualRoot/Mannequin/AnimationTree exists")
	if animation_tree == null:
		player.queue_free()
		floor_body.queue_free()
		return
	check.call(animation_tree.active, "AnimationTree is active")
	check.call(player.visual_root.position == Vector3.ZERO, "VisualRoot sits at the Player origin")
	check.call(player.visual_root.get_node_or_null("Mannequin") != null, "Mannequin is a child of VisualRoot")

	_check_tree_shape(animation_tree, check)
	var playback := animation_tree.get(MannequinAnimator.P_PLAYBACK) as AnimationNodeStateMachinePlayback
	check.call(playback != null, "playback is reachable at %s" % MannequinAnimator.P_PLAYBACK)
	if playback == null:
		player.queue_free()
		floor_body.queue_free()
		return
	check.call(playback.get_current_node() == &"Locomotion", "starts in Locomotion (got %s)" % playback.get_current_node())
	var rest_blend: Vector2 = animation_tree.get(MannequinAnimator.P_LOCOMOTION) as Vector2
	check.call(rest_blend.length() < REST_BLEND_MAX, "locomotion blend is near zero at rest (got %s)" % rest_blend)

	# Idle clip plays and keeps looping past one clip length (Idle_A is 1.067 s).
	var skeleton: Skeleton3D = _find_skeleton(player.visual_root)
	check.call(skeleton != null, "Skeleton3D found under the Mannequin")
	if skeleton == null:
		player.queue_free()
		floor_body.queue_free()
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
	# Held through the rise: a released button cuts the jump (D-04) and the descent would be too short to see Fall.
	Input.action_press(&"jump")
	await Fixtures.wait_physics(tree, 2)
	var reached_jump: bool = playback.get_current_node() == &"Jump"
	for i: int in 3:
		if reached_jump:
			break
		await tree.physics_frame
		reached_jump = playback.get_current_node() == &"Jump"
	check.call(reached_jump, "jump press travels the tree to Jump (got %s)" % playback.get_current_node())

	# A real jump ends in Idle on the floor; the landing fires the Land overlay (AIRBORNE_STATES path). No Land state.
	var seen: Dictionary[StringName, bool] = {}
	var fsm_idle_again: bool = false
	for i: int in 240:
		await tree.physics_frame
		seen[playback.get_current_node()] = true
		if player.state_machine.current.name == &"Idle" and seen.has(&"Jump"):
			fsm_idle_again = true
			break
	Input.action_release(&"jump")
	check.call(fsm_idle_again, "FSM reports Idle again after the jump")
	check.call(seen.has(&"Fall"), "tree passed through Fall on the way down (seen %s)" % [seen.keys()])
	var land_seen: int = await Fixtures.wait_until(tree, func() -> bool: return bool(animation_tree.get(MannequinAnimator.P_LAND_ACTIVE)), LAND_ACTIVE_FRAMES)
	check.call(land_seen >= 0, "landing into Idle sets %s true" % MannequinAnimator.P_LAND_ACTIVE)
	check.call(playback.get_current_node() == &"Locomotion", "after the jump the tree is back in Locomotion (got %s)" % playback.get_current_node())
	check.call(absf(player.global_position.y) < 0.05 and is_zero_approx(player.global_position.x), "Player stands where it jumped from (%s)" % player.global_position)

	# Idle -> Run -> Idle on the 2D blend: run weight rises while a move input is held and falls again on release.
	Input.action_press(&"move_forward")
	var ran: int = await Fixtures.wait_until(tree, func() -> bool: return (animation_tree.get(MannequinAnimator.P_LOCOMOTION) as Vector2).y > RUN_BLEND_MIN, RUN_BLEND_FRAMES)
	check.call(ran >= 0, "holding move_forward lifts the run blend above %.1f within %d frames" % [RUN_BLEND_MIN, RUN_BLEND_FRAMES])
	Input.action_release(&"move_forward")
	var rested: int = await Fixtures.wait_until(tree, func() -> bool: return (animation_tree.get(MannequinAnimator.P_LOCOMOTION) as Vector2).length() < REST_BLEND_MAX, REST_BLEND_FRAMES)
	check.call(rested >= 0, "releasing move_forward returns the blend below %.2f within %d frames" % [REST_BLEND_MAX, REST_BLEND_FRAMES])

	player.queue_free()
	floor_body.queue_free()
	await tree.process_frame


## The root is a BlendTree whose state machine has no Land state and only immediate, enabled edges between states.
func _check_tree_shape(animation_tree: AnimationTree, check: Callable) -> void:
	var root := animation_tree.tree_root as AnimationNodeBlendTree
	check.call(root != null, "tree root is an AnimationNodeBlendTree")
	if root == null:
		return
	var machine := root.get_node(&"StateMachine") as AnimationNodeStateMachine
	check.call(machine != null, "BlendTree has a StateMachine node")
	if machine == null:
		return
	check.call(not machine.has_node(&"Land"), "state machine has no Land state (Land is a OneShot overlay)")
	check.call(root.has_node(&"Land") and root.get_node(&"Land") is AnimationNodeOneShot, "BlendTree has the Land OneShot")
	var bad_edges: Array[String] = []
	var checked: int = 0
	for i: int in machine.get_transition_count():
		if machine.get_transition_from(i) == &"Start":
			continue
		checked += 1
		var edge: AnimationNodeStateMachineTransition = machine.get_transition(i)
		if edge.advance_mode != AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED or edge.switch_mode != AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE:
			bad_edges.append("%s->%s" % [machine.get_transition_from(i), machine.get_transition_to(i)])
	check.call(checked > 0 and bad_edges.is_empty(), "every state edge is ENABLED + SWITCH_MODE_IMMEDIATE, Jump -> Fall included (%d checked, bad: %s)" % [checked, bad_edges])


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
