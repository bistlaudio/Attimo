extends RefCounted
## HAND-02 / D-08, D-09, D-10: interact next to an Interactable that accepts near contact stretches the arm, holds
## while E is held and releases with it. It works while aiming, and it never starts strafe or backward locomotion.

const Fixtures := preload("res://tests/fixtures.gd")

const LEVER_SCENE: String = "res://scenes/mechanisms/lever.tscn"
const SHIPPED_TPS: int = 60
const AIM_SETTLE_FRAMES: int = 180

var _nodes: Array[Node] = []
var _player: PlayerController
var _rig: CameraRig
var _hand: HandController
var _contacts: Array[bool] = []
var _triggered_near: int = 0
var _bus: Node


func run(tree: SceneTree, check: Callable) -> void:
	# The runner calls us from _initialize, before the root is inside the tree.
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	_bus = tree.root.get_node("EventBus")
	await _scenario_toggle(tree, check)
	await _scenario_out_of_reach(tree, check)
	await _scenario_not_accepting(tree, check)
	await _scenario_hold(tree, check)
	await _scenario_aiming(tree, check)
	await _scenario_no_strafe(tree, check)


func _on_contact(active: bool, _point: Vector3) -> void:
	_contacts.append(active)


func _on_triggered(_node: Node, kind: int) -> void:
	if kind == int(PulseHit.Kind.NEAR):
		_triggered_near += 1


func _begin(tree: SceneTree, aim: bool) -> void:
	_contacts.clear()
	_triggered_near = 0
	_nodes.clear()
	_nodes.append(Fixtures.spawn_floor(tree.root, Vector3(200.0, 1.0, 200.0)))
	_player = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	_nodes.append(_player)
	_rig = Fixtures.spawn_camera_rig(tree.root, _player)
	_nodes.append(_rig)
	_rig.pitch = 0.0
	_hand = _player.get_node("HandController") as HandController
	_bus.connect(&"near_contact_changed", _on_contact)
	_bus.connect(&"interactable_triggered", _on_triggered)
	await Fixtures.wait_physics(tree, 6)
	await Fixtures.wait_process(tree, 3)
	if aim:
		Input.action_press(&"aim")
		var frames: int = 0
		while _rig.aim_weight < 0.999 and frames < AIM_SETTLE_FRAMES:
			await tree.process_frame
			frames += 1
		await Fixtures.wait_physics(tree, 3)


func _end(tree: SceneTree) -> void:
	for action: StringName in [&"aim", &"interact", &"use_hand", &"move_back", &"move_left"]:
		Input.action_release(action)
	if _bus.is_connected(&"near_contact_changed", _on_contact):
		_bus.disconnect(&"near_contact_changed", _on_contact)
	if _bus.is_connected(&"interactable_triggered", _on_triggered):
		_bus.disconnect(&"interactable_triggered", _on_triggered)
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame
	await tree.process_frame


func _lever(tree: SceneTree, position: Vector3) -> Lever:
	var lever: Lever = Fixtures.spawn_scene(tree.root, LEVER_SCENE, position) as Lever
	_nodes.append(lever)
	return lever


func _scenario_toggle(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	var lever: Lever = _lever(tree, Vector3(0.0, 0.0, 1.5))
	await Fixtures.wait_physics(tree, 3)
	Input.action_press(&"interact")
	await Fixtures.wait_physics(tree, 6)
	check.call(lever.is_active, "(1) interact next to the lever toggles it on")
	check.call(_hand.arm_out, "(1) the arm is out while E is held")
	check.call(_contacts == [true], "(1) near_contact_changed(true) fired once (%s)" % str(_contacts))
	check.call(_triggered_near == 1, "(1) interactable_triggered(NEAR) fired once (%d)" % _triggered_near)
	Input.action_release(&"interact")
	await Fixtures.wait_physics(tree, 40)
	check.call(_contacts == [true, false], "(1) releasing E fires near_contact_changed(false) (%s)" % str(_contacts))
	check.call(not _hand.arm_out, "(1) the arm is back after the release")
	await _end(tree)


func _scenario_out_of_reach(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	var lever: Lever = _lever(tree, Vector3(0.0, 0.0, 4.0))
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.tap_action(tree, &"interact", 4)
	await Fixtures.wait_physics(tree, 4)
	check.call(not lever.is_active and _contacts.is_empty(), "(2) a lever 4 m away does nothing")
	check.call(not _hand.arm_out, "(2) the arm stays in")
	await _end(tree)


func _scenario_not_accepting(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	var lever: Lever = _lever(tree, Vector3(0.0, 0.0, 1.5))
	(lever.get_node("Interactable") as Interactable).accepts_near = false
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.tap_action(tree, &"interact", 4)
	await Fixtures.wait_physics(tree, 4)
	check.call(not lever.is_active and _contacts.is_empty(), "(3) an Interactable that does not accept near contact does nothing")
	await _end(tree)


func _scenario_hold(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	var lever: Lever = _lever(tree, Vector3(0.0, 0.0, 1.5))
	var held: Array[int] = [0]
	(lever.get_node("Interactable") as Interactable).near_held.connect(func(_delta: float) -> void: held[0] += 1)
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.hold_action(tree, &"interact", 0.5)
	await Fixtures.wait_physics(tree, 3)
	check.call(held[0] >= 26 and held[0] <= 32, "(4) holding interact 0.5 s emits near_held about 30 times (%d)" % held[0])
	await _end(tree)


func _scenario_aiming(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, true)
	var lever: Lever = _lever(tree, Vector3(0.0, 0.0, 1.5))
	await Fixtures.wait_physics(tree, 3)
	Input.action_press(&"interact")
	await Fixtures.wait_physics(tree, 6)
	check.call(lever.is_active, "(5) near contact works while aiming")
	Input.action_release(&"interact")
	await _end(tree)


## Near contact without aim raises the arm layer but never enters strafe or backward locomotion.
func _scenario_no_strafe(tree: SceneTree, check: Callable) -> void:
	await _begin(tree, false)
	var lever: Lever = _lever(tree, Vector3(0.0, 0.0, 1.5))
	var animator: MannequinAnimator = _player.get_node("MannequinAnimator") as MannequinAnimator
	var machine: AnimationNodeStateMachinePlayback = Fixtures.animation_tree(_player).get(MannequinAnimator.P_AIM_PLAYBACK) as AnimationNodeStateMachinePlayback
	await Fixtures.wait_physics(tree, 3)
	Input.action_press(&"interact")
	Input.action_press(&"move_back")
	Input.action_press(&"move_left")
	var max_layer: float = 0.0
	var entered: bool = false
	var strafe: bool = false
	var backward: bool = false
	for i: int in 30:
		await tree.physics_frame
		await tree.process_frame
		max_layer = maxf(max_layer, animator.layer_weight)
		if machine != null and machine.get_current_node() == &"Enter":
			entered = true
		var blend: Vector2 = Fixtures.locomotion_blend(_player)
		if not is_zero_approx(blend.x):
			strafe = true
		if blend.y < -0.001:
			backward = true
	check.call(lever.is_active, "(6) the near press toggled the lever")
	check.call(max_layer > 0.0, "(6) the arm layer rises during near contact (%.2f)" % max_layer)
	check.call(not entered, "(6) the AimMachine is never started at Enter")
	check.call(not strafe and not backward, "(6) no strafe or backward blend (strafe %s, backward %s)" % [str(strafe), str(backward)])
	check.call(not _player.aiming, "(6) the player is not aiming")
	await _end(tree)
