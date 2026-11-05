extends RefCounted
## MOVE-06 groundwork / FEEL-01: dash plays Dodge_Forward from grounded and airborne states on a real floor and emits
## `dash_started` exactly once (direction, in_air). Plan 02-09 extends this file with the real dash scenarios.

const Fixtures := preload("res://tests/fixtures.gd")
const TREE_TRAVEL_TICKS: int = 15

var _bus: Node
var _dashes: Array[Array] = []
var _landed: Array[Array] = []
var _floor: StaticBody3D
var _on_dash: Callable
var _on_landed: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	await _scenario_grounded_run_dash(tree, check)
	await _scenario_idle_dash(tree, check)
	await _scenario_air_dash(tree, check)


func _scenario_grounded_run_dash(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	var playback: AnimationNodeStateMachinePlayback = _playback(player)
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 5)
	await Fixtures.tap_action(tree, &"dash")
	check.call(player.state_machine.current.name == &"Dash", "(1) dash press enters Dash (got %s)" % player.state_machine.current.name)
	# The tree follows the FSM after its 0.1 s crossfade, so allow a few ticks (the FSM state is the truth).
	var reached_dash: int = await Fixtures.wait_until(tree, func() -> bool: return playback.get_current_node() == &"Dash", TREE_TRAVEL_TICKS)
	check.call(reached_dash >= 0, "(1) tree travels to Dash within %d ticks (got %s)" % [TREE_TRAVEL_TICKS, playback.get_current_node()])
	check.call(_dashes.size() == 1, "(1) exactly one dash_started (got %d)" % _dashes.size())
	if _dashes.size() == 1:
		check.call(_dashes[0][1].dot(Vector3(0, 0, -1)) > 0.95, "(1) direction points to -Z (got %s)" % _dashes[0][1])
		check.call(_dashes[0][2] == false, "(1) in_air is false from Run")
	await Fixtures.wait_physics(tree, 30)
	check.call(player.state_machine.current.name == &"Run", "(1) back in Run after DASH_TIME with move_forward held (got %s)" % player.state_machine.current.name)
	check.call(_dashes.size() == 1, "(1) still exactly one dash_started (got %d)" % _dashes.size())
	Input.action_release(&"move_forward")
	await _end(player, check, "(1)")


func _scenario_idle_dash(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	# A non-trivial facing, so the "VisualRoot forward" fallback is not just the default +Z.
	player.visual_root.rotation.y = 1.0
	var forward: Vector3 = player.visual_root.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	await Fixtures.wait_physics(tree, 5)
	await Fixtures.tap_action(tree, &"dash")
	check.call(_dashes.size() == 1, "(2) exactly one dash_started (got %d)" % _dashes.size())
	if _dashes.size() == 1:
		check.call(_dashes[0][1].dot(forward) > 0.95, "(2) direction follows the VisualRoot forward axis (got %s, expected %s)" % [_dashes[0][1], forward])
		check.call(_dashes[0][2] == false, "(2) in_air is false from Idle")
	await Fixtures.wait_physics(tree, 30)
	check.call(player.state_machine.current.name == &"Idle", "(2) Idle after DASH_TIME (got %s)" % player.state_machine.current.name)
	await _end(player, check, "(2)")


func _scenario_air_dash(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	await Fixtures.wait_physics(tree, 5)
	# The jump is held: a released button cuts the rise (D-04) and would end the airtime early.
	Input.action_press(&"jump")
	await Fixtures.wait_physics(tree, 8)
	check.call(player.state_machine.current.name == &"Jump", "(3) still in Jump before the dash (got %s)" % player.state_machine.current.name)
	await Fixtures.tap_action(tree, &"dash")
	check.call(_dashes.size() == 1, "(3) exactly one dash_started (got %d)" % _dashes.size())
	if _dashes.size() == 1:
		check.call(_dashes[0][2] == true, "(3) in_air is true from Jump")
	check.call(_landed.size() == 0, "(3) no landed fact yet")
	await Fixtures.wait_physics(tree, 26)
	check.call(player.state_machine.current.name == &"Fall", "(3) Fall after DASH_TIME (got %s)" % player.state_machine.current.name)
	var settled: int = await Fixtures.wait_until(tree, func() -> bool: return _landed.size() == 1 and player.state_machine.current.name == &"Idle", 90)
	check.call(settled >= 0, "(3) the jump ends with exactly one landed fact and Idle within 90 ticks (landed %d, state %s)" % [_landed.size(), player.state_machine.current.name])
	Input.action_release(&"jump")
	await _end(player, check, "(3)")


func _begin(tree: SceneTree) -> PlayerController:
	_dashes = []
	_landed = []
	_on_dash = func(position: Vector3, direction: Vector3, in_air: bool) -> void: _dashes.append([position, direction, in_air])
	_on_landed = func(position: Vector3, impact_speed: float) -> void: _landed.append([position, impact_speed])
	_bus.connect(&"dash_started", _on_dash)
	_bus.connect(&"landed", _on_landed)
	_floor = Fixtures.spawn_floor(tree.root)
	return Fixtures.spawn_player(tree.root, Vector3.ZERO)


## Every scenario ends by disconnecting the recorders and freeing its player and floor.
func _end(player: PlayerController, _check: Callable, _label: String) -> void:
	_bus.disconnect(&"dash_started", _on_dash)
	_bus.disconnect(&"landed", _on_landed)
	# The lambdas capture self; drop them so this RefCounted test object is not kept alive by a cycle.
	_on_dash = Callable()
	_on_landed = Callable()
	player.queue_free()
	_floor.queue_free()
	await player.tree_exited


func _playback(player: PlayerController) -> AnimationNodeStateMachinePlayback:
	var animation_tree: AnimationTree = player.get_node("VisualRoot/Mannequin/AnimationTree") as AnimationTree
	return animation_tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
