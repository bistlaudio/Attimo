extends RefCounted
## MOVE-09 / ROADMAP criterion 4: the animation never makes control wait for a clip. Every travelling state change
## travels the tree on the same physics frame (inside the state_changed call), a landing never locks control, and
## the one deliberate presentation delay, the air-dash pose hold (DEV-02), never delays the FSM, steering or landing.
## A recorder connected after the scene is ready runs after the animator's handler and stores what the animator
## shows inside each state_changed call. Tick counts come from physics frames, never from wall clock.

const Fixtures := preload("res://tests/fixtures.gd")
const SHIPPED_TPS: int = 60

var _calls: Array[Dictionary] = []
var _recorder: Callable
var _machine: StateMachine


func run(tree: SceneTree, check: Callable) -> void:
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_air_dash_hold(tree, check)


# Tracer path: air dash -> Dash exits into Fall -> the Dodge node is held -> landing travels on the landing frame.
func _scenario_air_dash_hold(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3.ZERO)
	# The scene is ready after the first frame; the recorder joins after the animator's own connection.
	await Fixtures.wait_physics(tree, 2)
	var animator: MannequinAnimator = player.get_node("MannequinAnimator") as MannequinAnimator
	_record(player, animator)
	await Fixtures.wait_physics(tree, 3)
	await Fixtures.tap_action(tree, &"jump")
	await Fixtures.wait_physics(tree, 4)
	await Fixtures.tap_action(tree, &"dash")
	var exited: int = await Fixtures.wait_until(tree, func() -> bool: return _find(&"Dash", &"Fall") >= 0, 30)
	check.call(exited >= 0, "(1) the dash exit was recorded within 30 ticks")
	await Fixtures.wait_process(tree, 2)
	if _find(&"Fall", &"Idle") < 0:
		check.call(Fixtures.playback(player).get_current_node() == &"Dash", "(1) two process frames after the exit the tree is still on the dash node (got %s)" % Fixtures.playback(player).get_current_node())
	var landed: int = await Fixtures.wait_until(tree, func() -> bool: return _find(&"Fall", &"Idle") >= 0, 120)
	check.call(landed >= 0, "(1) the air dash jump ends in Idle (calls %s)" % [_names()])
	var exit_call: int = _find(&"Dash", &"Fall")
	check.call(exit_call >= 0, "(1) the air dash exits into Fall")
	if exit_call >= 0:
		var entry: Dictionary = _calls[exit_call]
		check.call(entry["holding"] == true, "(1) air_dash_holding is true inside the Dash -> Fall call")
		check.call(entry["travel"] == &"Dash", "(1) last_travel is still the dash node inside the Dash -> Fall call (got %s)" % entry["travel"])
	var land_call: int = _find(&"Fall", &"Idle")
	if land_call >= 0:
		var land: Dictionary = _calls[land_call]
		check.call(land["holding"] == false, "(1) air_dash_holding is false inside the landing call")
		check.call(land["travel"] == &"Locomotion", "(1) the landing travels to Locomotion inside its call (got %s)" % land["travel"])
		check.call(land["travel_frame"] == land["frame"], "(1) last_travel_frame %d equals the landing frame %d" % [land["travel_frame"], land["frame"]])
		var active: int = await Fixtures.wait_until(tree, func() -> bool: return Fixtures.land_active(player), 10)
		check.call(active >= 0, "(1) landing into Idle fires the Land overlay")
	await _release_all(tree)
	_stop_recording()
	player.queue_free()
	floor_body.queue_free()
	await player.tree_exited


## Records every state_changed call: from, to, the animator's view and the physics frame, all read inside the call.
func _record(player: PlayerController, animator: MannequinAnimator) -> void:
	_calls = []
	_machine = player.state_machine
	_recorder = func(from_state: StringName, to_state: StringName) -> void:
		_calls.append({
			"from": from_state,
			"to": to_state,
			"travel": animator.last_travel,
			"travel_frame": animator.last_travel_frame,
			"holding": animator.air_dash_holding,
			"frame": Engine.get_physics_frames(),
		})
	_machine.state_changed.connect(_recorder)


func _stop_recording() -> void:
	if _machine != null and _machine.state_changed.is_connected(_recorder):
		_machine.state_changed.disconnect(_recorder)
	# The lambda captures self; drop it so this RefCounted test object is not kept alive by a cycle.
	_recorder = Callable()
	_machine = null


## Index of the first recorded call from -> to, or -1.
func _find(from_state: StringName, to_state: StringName, start: int = 0) -> int:
	for i: int in range(start, _calls.size()):
		if _calls[i]["from"] == from_state and _calls[i]["to"] == to_state:
			return i
	return -1


func _names() -> Array[String]:
	var names: Array[String] = []
	for entry: Dictionary in _calls:
		names.append("%s->%s" % [entry["from"], entry["to"]])
	return names


func _release_all(tree: SceneTree) -> void:
	for action: StringName in [&"jump", &"dash", &"move_forward", &"move_left", &"move_right", &"move_back"]:
		Input.action_release(action)
		Fixtures.send_action_event(action, false)
	await Fixtures.wait_physics(tree, 1)
