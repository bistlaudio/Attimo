extends RefCounted
## FOUND-05 / FEEL-01 on real physics: WASD runs the player toward the camera-relative input and faces it, every
## jump ends in a real fall that emits `landed` exactly once with an impact speed above 0.

const Fixtures := preload("res://tests/fixtures.gd")

var _bus: Node
var _landed: Array[Array] = []
var _transitions: Array[Array] = []
var _floor: StaticBody3D
var _on_landed: Callable
var _on_transition: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	await _scenario_idle(tree, check)
	await _scenario_run_and_facing(tree, check)
	await _scenario_jump_fall_land(tree, check)
	await _scenario_jump_while_running(tree, check)


func _scenario_idle(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	var playback: AnimationNodeStateMachinePlayback = _playback(player)
	await Fixtures.wait_physics(tree, 20)
	check.call(_landed.size() == 0, "(a) no landed fact without a jump (got %d)" % _landed.size())
	check.call(player.state_machine.current.name == &"Idle", "(a) state is Idle")
	check.call(playback.get_current_node() == &"Locomotion", "(a) tree is in Locomotion")
	await _end(player, check, "(a)")


func _scenario_run_and_facing(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	var playback: AnimationNodeStateMachinePlayback = _playback(player)
	var animation_tree: AnimationTree = _animation_tree(player)
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	check.call(player.state_machine.current.name == &"Run", "(b) holding move_forward enters Run (got %s)" % player.state_machine.current.name)
	check.call(player.global_position.z < -0.5, "(b) the player moved toward -Z (z %.3f)" % player.global_position.z)
	var yaw_error: float = absf(angle_difference(player.visual_root.rotation.y, PI))
	check.call(yaw_error < 0.2, "(b) VisualRoot faces -Z (yaw %.3f, error %.3f)" % [player.visual_root.rotation.y, yaw_error])
	check.call(playback.get_current_node() == &"Locomotion", "(b) tree is in Locomotion")
	check.call(is_equal_approx(float(animation_tree.get(&"parameters/Locomotion/blend_position")), 1.0), "(b) Locomotion blend is 1.0 while running")
	Input.action_release(&"move_forward")
	var stopped: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Idle", 60)
	check.call(stopped >= 0, "(b) releasing returns to Idle (got %s)" % player.state_machine.current.name)
	await Fixtures.wait_physics(tree, 2)
	check.call(is_zero_approx(float(animation_tree.get(&"parameters/Locomotion/blend_position"))), "(b) Locomotion blend back to 0.0")
	await _end(player, check, "(b)")


func _scenario_jump_fall_land(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	var playback: AnimationNodeStateMachinePlayback = _playback(player)
	await Fixtures.tap_action(tree, &"jump")
	var seen: Dictionary[StringName, bool] = {}
	var landed_in: int = -1
	for i: int in 120:
		await tree.physics_frame
		seen[playback.get_current_node()] = true
		if not _landed.is_empty() and player.state_machine.current.name == &"Idle":
			landed_in = i
			break
	check.call(landed_in >= 0, "(c) the jump lands in Idle within 120 ticks")
	check.call(_has_transition(&"Idle", &"Jump"), "(c) transition Idle -> Jump recorded")
	check.call(_has_transition(&"Jump", &"Fall"), "(c) transition Jump -> Fall recorded")
	check.call(_has_transition(&"Fall", &"Idle"), "(c) transition Fall -> Idle recorded")
	check.call(_landed.size() == 1, "(c) exactly one landed fact (got %d)" % _landed.size())
	if _landed.size() == 1:
		check.call(float(_landed[0][1]) > 0.0, "(c) landed impact_speed is above 0 (got %.2f)" % float(_landed[0][1]))
	for i: int in 60:
		if playback.get_current_node() == &"Locomotion" and seen.has(&"Land"):
			break
		await tree.physics_frame
		seen[playback.get_current_node()] = true
	check.call(seen.has(&"Land"), "(c) tree passed through Land (seen %s)" % [seen.keys()])
	check.call(playback.get_current_node() == &"Locomotion", "(c) tree back in Locomotion (got %s)" % playback.get_current_node())
	await _end(player, check, "(c)")


func _scenario_jump_while_running(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	var playback: AnimationNodeStateMachinePlayback = _playback(player)
	var animation_tree: AnimationTree = _animation_tree(player)
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 5)
	var z_before_jump: float = player.global_position.z
	await Fixtures.tap_action(tree, &"jump")
	# Still airborne a few ticks later: the body keeps moving toward -Z in the air.
	await Fixtures.wait_physics(tree, 10)
	check.call(not player.is_grounded(), "(d) the player is airborne ten ticks after the jump")
	var z_in_air: float = player.global_position.z
	check.call(z_in_air < z_before_jump - 0.5, "(d) the player keeps moving toward -Z in the air (z %.3f -> %.3f)" % [z_before_jump, z_in_air])
	var landed_in: int = await Fixtures.wait_until(tree, func() -> bool: return not _landed.is_empty(), 120)
	check.call(landed_in >= 0, "(d) the jump lands within 120 ticks")
	await Fixtures.wait_physics(tree, 3)
	check.call(_has_transition(&"Fall", &"Run"), "(d) landing with input held goes Fall -> Run")
	check.call(_landed.size() == 1, "(d) exactly one landed fact (got %d)" % _landed.size())
	if _landed.size() == 1:
		check.call(float(_landed[0][1]) > 0.0, "(d) landed impact_speed is above 0 (got %.2f)" % float(_landed[0][1]))
	check.call(player.state_machine.current.name == &"Run", "(d) state is Run (got %s)" % player.state_machine.current.name)
	check.call(playback.get_current_node() == &"Locomotion", "(d) tree is in Locomotion (got %s)" % playback.get_current_node())
	check.call(is_equal_approx(float(animation_tree.get(&"parameters/Locomotion/blend_position")), 1.0), "(d) Locomotion blend is 1.0")
	Input.action_release(&"move_forward")
	await _end(player, check, "(d)")


func _begin(tree: SceneTree) -> PlayerController:
	_landed = []
	_transitions = []
	_on_landed = func(position: Vector3, impact_speed: float) -> void: _landed.append([position, impact_speed])
	_on_transition = func(from_state: StringName, to_state: StringName) -> void: _transitions.append([from_state, to_state])
	_bus.connect(&"landed", _on_landed)
	_bus.connect(&"movement_state_changed", _on_transition)
	_floor = Fixtures.spawn_floor(tree.root)
	return Fixtures.spawn_player(tree.root, Vector3.ZERO)


## Every scenario ends by freeing its player and floor and disconnecting the recorders.
func _end(player: PlayerController, _check: Callable, _label: String) -> void:
	_bus.disconnect(&"landed", _on_landed)
	_bus.disconnect(&"movement_state_changed", _on_transition)
	# The lambdas capture self; drop them so this RefCounted test object is not kept alive by a cycle.
	_on_landed = Callable()
	_on_transition = Callable()
	player.queue_free()
	_floor.queue_free()
	await player.tree_exited


func _has_transition(from_state: StringName, to_state: StringName) -> bool:
	for t: Array in _transitions:
		if t[0] == from_state and t[1] == to_state:
			return true
	return false


func _animation_tree(player: PlayerController) -> AnimationTree:
	return player.get_node("VisualRoot/Mannequin/AnimationTree") as AnimationTree


func _playback(player: PlayerController) -> AnimationNodeStateMachinePlayback:
	return _animation_tree(player).get(&"parameters/playback") as AnimationNodeStateMachinePlayback
