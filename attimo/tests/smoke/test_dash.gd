extends RefCounted
## MOVE-06 / MOVE-07 / FEEL-01: the real dash. A ground and an air dash are fixed velocity bursts
## (dash_speed for dash_time) with a cooldown, one air dash per airtime, an exit carry, a hand-off into a jump
## and no tunnelling through thin walls. Every expectation derives from player.config. Scenarios that need other
## numbers duplicate the config first (the shared resource is never mutated). Actions are released and the tick
## rate is restored to 60 before nodes are freed.

const Fixtures := preload("res://tests/fixtures.gd")
const TREE_TRAVEL_TICKS: int = 15
const SLOPE_SCENE: String = "res://scenes/proto/primitive_slope.tscn"
const SHIPPED_TPS: int = 60
const SNAP_TOLERANCE: float = 1e-4

var _bus: Node
var _dashes: Array[Array] = []
var _landed: Array[Array] = []
var _jumps: Array[int] = []
var _floor: StaticBody3D
var _on_dash: Callable
var _on_landed: Callable
var _on_jump: Callable


func run(tree: SceneTree, check: Callable) -> void:
	_bus = tree.root.get_node("EventBus")
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_grounded_run_dash(tree, check)
	await _scenario_idle_dash(tree, check)
	await _scenario_ground_distance_and_carry(tree, check)
	await _scenario_cooldown(tree, check)
	await _scenario_air_dash(tree, check)
	await _scenario_air_dash_then_jump_press(tree, check)
	await _scenario_air_exit_and_steering(tree, check)
	await _scenario_ground_dash_jump(tree, check)
	Engine.physics_ticks_per_second = 10
	await _scenario_tunnelling(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_tunnelling(tree, check)
	await _scenario_slope_dash(tree, check)


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
	var back: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Run", 40)
	check.call(back >= 0, "(1) back in Run after the dash with move_forward held (got %s)" % player.state_machine.current.name)
	check.call(_dashes.size() == 1, "(1) still exactly one dash_started (got %d)" % _dashes.size())
	Input.action_release(&"move_forward")
	await _end(player)


func _scenario_idle_dash(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	# A non-trivial facing, so the "VisualRoot forward" fallback is not just the default +Z.
	player.visual_root.rotation.y = 1.0
	var forward: Vector3 = player.visual_root.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	await Fixtures.wait_physics(tree, 5)
	var stats: Dictionary = await _dash_stats(tree, player)
	check.call(_dashes.size() == 1, "(2) exactly one dash_started (got %d)" % _dashes.size())
	if _dashes.size() == 1:
		check.call(_dashes[0][1].dot(forward) > 0.95, "(2) direction follows the VisualRoot forward axis (got %s, expected %s)" % [_dashes[0][1], forward])
		check.call(_dashes[0][2] == false, "(2) in_air is false from Idle")
	var moved: Vector3 = (stats["end"] as Vector3) - (stats["start"] as Vector3)
	moved.y = 0.0
	check.call(moved.length() > 1.0 and moved.normalized().dot(forward) > 0.95, "(2) the body travels %.2f m along the facing, not in place" % moved.length())
	var idle: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Idle", 40)
	check.call(idle >= 0, "(2) Idle after the dash without input (got %s)" % player.state_machine.current.name)
	await _end(player)


# A ground dash covers dash_speed * dash_time and carries a bounded speed out of it.
func _scenario_ground_distance_and_carry(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree, Vector3(0.0, 0.0, 25.0))
	var config: MovementConfig = player.config
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - config.run_speed) < 0.05, 60)
	var stats: Dictionary = await _dash_stats(tree, player)
	var flat: Vector3 = (stats["end"] as Vector3) - (stats["start"] as Vector3)
	flat.y = 0.0
	var expected: float = config.dash_speed * config.dash_time
	var tolerance: float = config.dash_speed / 60.0 + 0.1
	check.call(stats["started"], "(3) the dash press starts a dash")
	check.call(absf(flat.length() - expected) <= tolerance, "(3) dash travel %.2f m is within %.2f of dash_speed * dash_time = %.2f" % [flat.length(), tolerance, expected])
	var exit_speed: float = stats["exit_speed"]
	check.call(exit_speed >= config.run_speed and exit_speed <= config.dash_exit_cap + 0.01, "(3) exit speed %.2f is between run_speed %.1f and dash_exit_cap %.1f" % [exit_speed, config.run_speed, config.dash_exit_cap])
	check.call(stats["exit_state"] == &"Run", "(3) the dash hands over to Run with the direction held (got %s)" % stats["exit_state"])
	Input.action_release(&"move_forward")
	await _end(player)


# A second dash inside dash_cooldown is refused; after it the dash works again.
func _scenario_cooldown(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	var config: MovementConfig = player.config
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	await Fixtures.wait_physics(tree, 5)
	var started: int = 0
	Input.action_press(&"dash")
	started = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 6)
	Input.action_release(&"dash")
	check.call(started >= 0 and _dashes.size() == 1, "(4) the first dash starts (dash_started %d)" % _dashes.size())
	var half: int = int(round(config.dash_cooldown * 0.5 / dt))
	await Fixtures.wait_physics(tree, half)
	await Fixtures.tap_action(tree, &"dash")
	await Fixtures.wait_physics(tree, 2)
	check.call(_dashes.size() == 1, "(4) a press at half the cooldown (%.2f s) produces no dash_started (got %d)" % [config.dash_cooldown * 0.5, _dashes.size()])
	var full: int = int(ceil(config.dash_cooldown / dt)) + 3
	await Fixtures.wait_physics(tree, maxi(full - half - 4, 0))
	await Fixtures.tap_action(tree, &"dash")
	await Fixtures.wait_physics(tree, 2)
	check.call(_dashes.size() == 2, "(4) a press after the cooldown (%.2f s) dashes again (got %d)" % [config.dash_cooldown, _dashes.size()])
	await _end(player)


# One air dash per airtime: altitude hold, refusal of a second one, landing refills it (D-12).
func _scenario_air_dash(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	# Cooldown 0 so only the per-airtime flag can refuse the second dash.
	player.config = player.config.duplicate() as MovementConfig
	player.config.dash_cooldown = 0.0
	await Fixtures.wait_physics(tree, 5)
	# The jump is held: a released button cuts the rise (D-04) and would end the airtime early.
	_hold_jump()
	await Fixtures.wait_physics(tree, 8)
	check.call(player.state_machine.current.name == &"Jump", "(5) still in Jump before the dash (got %s)" % player.state_machine.current.name)
	var stats: Dictionary = await _dash_stats(tree, player)
	check.call(_dashes.size() == 1, "(5) exactly one dash_started (got %d)" % _dashes.size())
	if _dashes.size() == 1:
		check.call(_dashes[0][2] == true, "(5) in_air is true from Jump")
	check.call(_landed.size() == 0, "(5) no landed fact yet")
	var held: float = absf((stats["end"] as Vector3).y - (stats["start"] as Vector3).y)
	check.call(stats["started"] and held < 0.05, "(5) the air dash holds altitude (%.3f m vertical change, limit 0.05)" % held)
	check.call(stats["exit_state"] == &"Fall", "(5) Fall after the air dash (got %s)" % stats["exit_state"])
	check.call(not player.is_grounded(), "(5) still airborne for the second press")
	await Fixtures.tap_action(tree, &"dash")
	await Fixtures.wait_physics(tree, 2)
	check.call(_dashes.size() == 1, "(5) a second air dash in the same airtime is refused (got %d dash_started)" % _dashes.size())
	var settled: int = await Fixtures.wait_until(tree, func() -> bool: return _landed.size() == 1 and player.state_machine.current.name == &"Idle", 90)
	check.call(settled >= 0, "(5) the jump ends with exactly one landed fact and Idle within 90 ticks (landed %d, state %s)" % [_landed.size(), player.state_machine.current.name])
	# Landing refills the air dash: the next jump can dash in the air again.
	_release_jump()
	await Fixtures.wait_physics(tree, 4)
	_hold_jump()
	await Fixtures.wait_physics(tree, 8)
	await _dash_stats(tree, player)
	var airborne_dashes: int = 0
	for entry: Array in _dashes:
		if entry[2] == true:
			airborne_dashes += 1
	check.call(airborne_dashes == 2, "(5) landing refills the air dash: a second airtime dashes again (airborne dash_started %d)" % airborne_dashes)
	_release_jump()
	await _end(player)


# U2: jump -> air dash -> jump press. There is no air jump: one airborne dash_started, no rise, no second jumped.
func _scenario_air_dash_then_jump_press(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree)
	await Fixtures.wait_physics(tree, 5)
	_hold_jump()
	await Fixtures.wait_physics(tree, 8)
	await Fixtures.tap_action(tree, &"dash")
	var in_dash: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 4)
	check.call(in_dash >= 0, "(6) the air dash is running before the second jump press")
	_release_jump()
	_hold_jump()
	var rose: bool = false
	for i: int in 20:
		await Fixtures.wait_physics(tree, 1)
		rose = rose or player.vertical_speed > 0.0
	check.call(not rose, "(6) a jump press during and after the air dash adds no rise")
	check.call(_airborne_dashes() == 1, "(6) jump -> air dash -> jump press: exactly one airborne dash_started (got %d)" % _airborne_dashes())
	check.call(_jumps.size() == 1, "(6) and no second jumped fact (got %d)" % _jumps.size())
	_release_jump()
	await _end(player)


# The exit carry of an air dash is bounded and the air control keeps steering.
func _scenario_air_exit_and_steering(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree, Vector3(0.0, 0.0, 25.0))
	var config: MovementConfig = player.config
	await Fixtures.wait_physics(tree, 5)
	Input.action_press(&"move_forward")
	_hold_jump()
	await Fixtures.wait_physics(tree, 8)
	var stats: Dictionary = await _dash_stats(tree, player)
	var exit_speed: float = stats["exit_speed"]
	check.call(stats["exit_state"] == &"Fall", "(7) the air dash ends in Fall (got %s)" % stats["exit_state"])
	check.call(exit_speed >= config.run_speed and exit_speed <= config.dash_exit_cap + 0.01, "(7) first tick after the air dash: speed %.2f between run_speed %.1f and dash_exit_cap %.1f" % [exit_speed, config.run_speed, config.dash_exit_cap])
	Input.action_release(&"move_forward")
	Input.action_press(&"move_right")
	await Fixtures.wait_physics(tree, 6)
	check.call(player.move_velocity.x > 2.0, "(7) holding a direction after the dash still steers (x speed %.2f)" % player.move_velocity.x)
	Input.action_release(&"move_right")
	_release_jump()
	await _end(player)


# A jump pressed during a ground dash leaves Dash on that tick into a rising jump (MOVE-07).
func _scenario_ground_dash_jump(tree: SceneTree, check: Callable) -> void:
	var player: PlayerController = _begin(tree, Vector3(0.0, 0.0, 25.0))
	var config: MovementConfig = player.config
	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - config.run_speed) < 0.05, 60)
	await Fixtures.tap_action(tree, &"dash")
	var in_dash: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Dash", 4)
	check.call(in_dash >= 0, "(8) the ground dash is running")
	_hold_jump()
	var jumped: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name in [&"Jump", &"LongJump"], 8)
	check.call(jumped >= 0, "(8) a jump press during the dash leaves Dash into a jump, the long jump (state %s)" % player.state_machine.current.name)
	check.call(player.vertical_speed > 0.0, "(8) the jump is rising (vertical speed %.2f)" % player.vertical_speed)
	check.call(player.horizontal_speed() >= config.run_speed, "(8) the jump keeps at least run speed (%.2f m/s)" % player.horizontal_speed())
	_release_jump()
	Input.action_release(&"move_forward")
	await _end(player)


# A 60 m/s dash into a 0.1 m wall never ends on the far side, whatever the tick rate (D-11).
func _scenario_tunnelling(tree: SceneTree, check: Callable) -> void:
	var tps: int = Engine.physics_ticks_per_second
	var label: String = "%d TPS" % tps
	var player: PlayerController = _begin(tree)
	player.config = player.config.duplicate() as MovementConfig
	player.config.dash_speed = 60.0
	# The wall is 0.1 m thick across the dash path: near face z = -4.95, far face z = -5.05.
	var wall: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(10.0, 4.0, 0.1), Vector3(0.0, 2.0, -5.0))
	await Fixtures.wait_physics(tree, 5)
	Input.action_press(&"move_forward")
	Input.action_press(&"dash")
	var lowest_z: float = player.global_position.z
	var ticks: int = int(ceil(1.5 * float(tps)))
	for i: int in ticks:
		await Fixtures.wait_physics(tree, 1)
		if i == 1:
			# Only the dash may carry the player to the wall: the direction is read on the dash tick.
			Input.action_release(&"dash")
			Input.action_release(&"move_forward")
		lowest_z = minf(lowest_z, player.global_position.z)
	Input.action_release(&"dash")
	Input.action_release(&"move_forward")
	check.call(_dashes.size() == 1, "(9) %s: the dash started (dash_started %d)" % [label, _dashes.size()])
	check.call(lowest_z > -5.05, "(9) %s: a 60 m/s dash never reaches the far face of the wall (lowest z %.3f, far face -5.05)" % [label, lowest_z])
	check.call(lowest_z < -3.5, "(9) %s: the dash did reach the wall (lowest z %.3f)" % [label, lowest_z])
	wall.queue_free()
	await _end(player)


# D-13 / A35: a ground dash down a 45 degree slope stays grounded and inside the snap band.
func _scenario_slope_dash(tree: SceneTree, check: Callable) -> void:
	_dashes = []
	_landed = []
	_connect_recorders()
	_floor = Fixtures.spawn_floor(tree.root, Vector3(80, 1, 40))
	var slope: StaticBody3D = (load(SLOPE_SCENE) as PackedScene).instantiate() as StaticBody3D
	tree.root.add_child(slope)
	# The slope rises toward -X and is 4 m high; the plateau behind it tops out at y 4.
	var plateau: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(8, 4, 4), Vector3(-6.0, 2.0, 0.0))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(-2.5, 4.0, 0.0))
	await Fixtures.wait_physics(tree, 8)
	check.call(player.is_grounded() and absf(player.global_position.y - 4.0) < 0.05, "(10) the player stands on the plateau 0.5 m before the slope edge (y %.3f)" % player.global_position.y)
	Input.action_press(&"move_right")
	var stats: Dictionary = await _dash_stats(tree, player)
	Input.action_release(&"move_right")
	print("DIAG [test_dash] slope dash: started=%s ticks=%d airborne=%d max_height=%.3f end=%s snap_samples=%d" % [stats["started"], stats["ticks"], stats["airborne"], stats["max_height"], stats["end"], stats["snap_samples"]])
	check.call(stats["started"] and (stats["end"] as Vector3).y < 3.0, "(10) the dash carries the player down the slope (end y %.2f)" % (stats["end"] as Vector3).y)
	check.call(stats["airborne"] == 0, "(10) 0 airborne ticks while in Dash on the slope (got %d)" % stats["airborne"])
	check.call(stats["max_height"] <= 0.3, "(10) never more than 0.3 m above the surface below (%.3f)" % stats["max_height"])
	check.call(stats["snap_ok"] and stats["snap_samples"] > 5, "(10) floor_snap_length stays within [0.3, 0.5] on every grounded tick (%d samples)" % stats["snap_samples"])
	slope.queue_free()
	plateau.queue_free()
	await _end(player)


## Number of recorded dashes that started in the air.
func _airborne_dashes() -> int:
	var count: int = 0
	for entry: Array in _dashes:
		if entry[2] == true:
			count += 1
	return count


func _hold_jump() -> void:
	Fixtures.send_action_event(&"jump", true)


func _release_jump() -> void:
	Fixtures.send_action_event(&"jump", false)


## Presses dash for two ticks (a key tap) and samples every tick of the Dash stretch. Returns
## {started, ticks (Dash ticks after the first), start, end (positions), airborne (Dash samples off the floor),
##  max_height (above the surface below), snap_ok / snap_samples (floor_snap_length band on grounded samples),
##  exit_speed / exit_state (horizontal speed and state on the first sample after Dash)}.
func _dash_stats(tree: SceneTree, player: PlayerController, max_ticks: int = 90) -> Dictionary:
	var stats: Dictionary = {"started": false, "ticks": 0, "start": player.global_position, "end": player.global_position, "airborne": 0, "max_height": 0.0, "snap_ok": true, "snap_samples": 0, "exit_speed": -1.0, "exit_state": &""}
	Input.action_press(&"dash")
	for i: int in max_ticks:
		await Fixtures.wait_physics(tree, 1)
		if i == 1:
			Input.action_release(&"dash")
		var in_dash: bool = player.state_machine.current.name == &"Dash"
		if in_dash:
			if not stats["started"]:
				stats["started"] = true
				stats["start"] = player.global_position
			else:
				stats["ticks"] += 1
			stats["end"] = player.global_position
			var surface: float = _surface_below(player)
			if surface > -INF:
				stats["max_height"] = maxf(stats["max_height"], player.global_position.y - surface)
			if player.is_grounded():
				stats["snap_samples"] += 1
				var snap: float = player.floor_snap_length
				if snap < 0.3 - SNAP_TOLERANCE or snap > 0.5 + SNAP_TOLERANCE:
					stats["snap_ok"] = false
			else:
				stats["airborne"] += 1
		elif stats["started"]:
			stats["exit_speed"] = player.horizontal_speed()
			stats["exit_state"] = player.state_machine.current.name
			break
	Input.action_release(&"dash")
	return stats


## Height of the surface straight below the player (World mask), or -INF without one.
func _surface_below(player: PlayerController) -> float:
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var from: Vector3 = player.global_position + Vector3.UP * 0.5
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0, PhysicsLayers.WORLD)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return -INF
	return (hit["position"] as Vector3).y


func _connect_recorders() -> void:
	_jumps = []
	_on_dash = func(position: Vector3, direction: Vector3, in_air: bool) -> void: _dashes.append([position, direction, in_air])
	_on_landed = func(position: Vector3, impact_speed: float) -> void: _landed.append([position, impact_speed])
	_on_jump = func(_position: Vector3) -> void: _jumps.append(Engine.get_physics_frames())
	_bus.connect(&"dash_started", _on_dash)
	_bus.connect(&"landed", _on_landed)
	_bus.connect(&"jumped", _on_jump)


func _begin(tree: SceneTree, position: Vector3 = Vector3.ZERO) -> PlayerController:
	_dashes = []
	_landed = []
	_connect_recorders()
	_floor = Fixtures.spawn_floor(tree.root)
	return Fixtures.spawn_player(tree.root, position)


## Every scenario ends by disconnecting the recorders and freeing its player and floor.
func _end(player: PlayerController) -> void:
	_bus.disconnect(&"dash_started", _on_dash)
	_bus.disconnect(&"landed", _on_landed)
	_bus.disconnect(&"jumped", _on_jump)
	# The lambdas capture self; drop them so this RefCounted test object is not kept alive by a cycle.
	_on_dash = Callable()
	_on_landed = Callable()
	_on_jump = Callable()
	player.queue_free()
	_floor.queue_free()
	await player.tree_exited


func _playback(player: PlayerController) -> AnimationNodeStateMachinePlayback:
	var animation_tree: AnimationTree = player.get_node("VisualRoot/Mannequin/AnimationTree") as AnimationTree
	return animation_tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
