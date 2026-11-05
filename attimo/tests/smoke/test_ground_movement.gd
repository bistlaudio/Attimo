extends RefCounted
## MOVE-01 tracer: camera-relative run with acceleration and skid, the floor snap band, and
## (later tasks) camera follow and a full jump. Every expectation derives from player.config.
## Actions are held with Input.action_press and always released before nodes are freed.

const Fixtures := preload("res://tests/fixtures.gd")

const SNAP_TOLERANCE: float = 1e-4


func run(tree: SceneTree, check: Callable) -> void:
	await _scenario_run_and_stop(tree, check)
	await _scenario_skid(tree, check)
	await _scenario_bare_camera(tree, check)
	await _scenario_camera_rig(tree, check)
	await _scenario_snap_band(tree, check)
	await _scenario_jump(tree, check)


func _tick() -> float:
	return 1.0 / float(Engine.physics_ticks_per_second)


func _spawn(tree: SceneTree, position: Vector3) -> Array[Node]:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, position)
	await Fixtures.wait_physics(tree, 5)
	return [floor_body, player]


func _free_all(tree: SceneTree, nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await tree.process_frame


# (a) accelerate perceptibly, reach run speed, stop on release (D-01).
func _scenario_run_and_stop(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3.ZERO)
	var player: PlayerController = nodes[1] as PlayerController
	var config: MovementConfig = player.config
	var dt: float = _tick()
	check.call(player.horizontal_speed() < 0.01 and player.is_grounded(), "(a) player rests on the floor before input")

	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 3)
	check.call(player.horizontal_speed() > 0.1 and player.horizontal_speed() < config.run_speed, "(a) after 3 ticks the speed is still below run_speed (%.2f)" % player.horizontal_speed())

	var accel_budget: int = int(ceil(config.run_speed / config.ground_accel / dt)) + 2
	var reached: int = await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - config.run_speed) < 0.05, accel_budget - 3)
	check.call(reached >= 0, "(a) run_speed reached within %d ticks of the press" % accel_budget)
	check.call(player.global_position.z < -0.5 and absf(player.global_position.x) < 0.05, "(a) the player moved toward -Z without a camera (z=%.2f)" % player.global_position.z)
	check.call(player.state_machine.current.name == &"Run", "(a) state is Run")

	Input.action_release(&"move_forward")
	var stop_budget: int = int(ceil(config.run_speed / config.ground_decel / dt)) + 2
	var stopped: int = await Fixtures.wait_until(tree, func() -> bool: return player.horizontal_speed() < 0.05, stop_budget)
	check.call(stopped >= 0, "(a) releasing brings the player to rest within %d ticks" % stop_budget)
	await Fixtures.wait_physics(tree, 3)
	check.call(player.state_machine.current.name == &"Idle", "(a) state is Idle after stopping")
	await _free_all(tree, nodes)


# (b) reversing brakes harder than releasing (skid, D-01).
func _scenario_skid(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3.ZERO)
	var player: PlayerController = nodes[1] as PlayerController
	var config: MovementConfig = player.config
	var dt: float = _tick()

	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - config.run_speed) < 0.05, 60)
	await Fixtures.wait_physics(tree, 2)
	var before: float = -player.move_velocity.z
	check.call(before > config.run_speed - 0.1, "(b) running toward -Z at full speed (%.2f)" % before)

	Input.action_release(&"move_forward")
	Input.action_press(&"move_back")
	await Fixtures.wait_physics(tree, 3)
	var drop: float = before - (-player.move_velocity.z)
	var expected: float = 0.9 * config.turn_decel * 3.0 * dt
	check.call(drop >= expected, "(b) skid: speed dropped %.2f in 3 ticks, at least %.2f" % [drop, expected])
	check.call(config.turn_decel > config.ground_decel, "(b) turn_decel is harder than ground_decel")

	Input.action_release(&"move_back")
	await _free_all(tree, nodes)


# (c) camera-relative through a bare Camera3D yawed by PI/2.
func _scenario_bare_camera(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3.ZERO)
	var player: PlayerController = nodes[1] as PlayerController
	var camera: Camera3D = Camera3D.new()
	camera.rotation.y = PI / 2.0
	tree.root.add_child(camera)
	camera.current = true
	await Fixtures.wait_process(tree, 2)
	nodes.append(camera)

	var start: Vector3 = player.global_position
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	var moved: Vector3 = player.global_position - start
	moved.y = 0.0
	var heading: float = moved.normalized().dot(Vector3(-1.0, 0.0, 0.0))
	check.call(moved.length() > 0.5 and heading > 0.95, "(c) bare camera yawed PI/2: move_forward heads along camera forward -X (dot %.3f)" % heading)

	Input.action_release(&"move_forward")
	await _free_all(tree, nodes)


# (d) camera-relative through a CameraRig (steering_yaw), rig follow, mouse look.
func _scenario_camera_rig(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3.ZERO)
	var player: PlayerController = nodes[1] as PlayerController
	var rig: CameraRig = Fixtures.spawn_camera_rig(tree.root, player)
	rig.yaw = PI / 2.0
	await Fixtures.wait_process(tree, 2)

	var start: Vector3 = player.global_position
	Input.action_press(&"move_forward")
	await Fixtures.wait_physics(tree, 30)
	var moved: Vector3 = player.global_position - start
	moved.y = 0.0
	var heading: float = moved.normalized().dot(Vector3(-1.0, 0.0, 0.0))
	check.call(moved.length() > 0.5 and heading > 0.95, "(d) rig yaw PI/2: move_forward steers along -X through steering_yaw (dot %.3f)" % heading)

	check.call(rig.top_level, "(d) the rig is top level")
	check.call(rig.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "(d) the rig has physics interpolation off")
	check.call(not player.is_ancestor_of(rig) and rig.get_parent() == player.get_parent(), "(d) the rig is a sibling of the player, not in its subtree")

	await Fixtures.wait_physics(tree, 60)
	await Fixtures.wait_process(tree, 2)
	var pivot: Vector3 = player.get_global_transform_interpolated().origin
	var gap: float = Vector2(rig.global_position.x - pivot.x, rig.global_position.z - pivot.z).length()
	check.call(gap < 1.0, "(d) after 1 s of running the rig trails the player by %.2f m (< 1.0)" % gap)

	var yaw_before: float = rig.yaw
	Fixtures.send_mouse_motion(Vector2(100.0, 0.0))
	await Fixtures.wait_process(tree, 2)
	var expected_delta: float = 100.0 * rig.base_sensitivity
	check.call(absf((yaw_before - rig.yaw) - expected_delta) < 1e-4, "(d) mouse motion of 100 px lowers yaw by %.4f (got %.4f)" % [expected_delta, yaw_before - rig.yaw])

	Input.action_release(&"move_forward")
	rig.queue_free()
	await _free_all(tree, nodes)


# (f) floor_snap_length stays inside the D-13 band up to dash speed (A35).
func _scenario_snap_band(tree: SceneTree, check: Callable) -> void:
	var nodes: Array[Node] = await _spawn(tree, Vector3(0.0, 0.0, 25.0))
	var player: PlayerController = nodes[1] as PlayerController
	var config: MovementConfig = player.config
	check.call(config.snap_min >= 0.3 and config.snap_max <= 0.5, "(f) default snap_min/snap_max sit inside the 0.3-0.5 band")

	Input.action_press(&"move_forward")
	await Fixtures.wait_until(tree, func() -> bool: return absf(player.horizontal_speed() - config.run_speed) < 0.05, 60)
	var in_band: bool = true
	var samples: int = 0
	for i: int in 20:
		await Fixtures.wait_physics(tree, 1)
		if player.is_grounded():
			samples += 1
			var snap: float = player.floor_snap_length
			if snap < 0.3 - SNAP_TOLERANCE or snap > 0.5 + SNAP_TOLERANCE:
				in_band = false
	check.call(samples > 10 and in_band, "(f) floor_snap_length stays in [0.3, 0.5] at run speed (%d grounded ticks)" % samples)

	# A duplicate config at dash speed: the raw formula is about 0.54 m, so it must clamp to snap_max.
	var fast: MovementConfig = config.duplicate() as MovementConfig
	fast.run_speed = config.dash_speed
	player.config = fast
	await Fixtures.wait_until(tree, func() -> bool: return player.horizontal_speed() > 21.0, 120)
	var clamped: bool = true
	var never_over: bool = true
	var fast_samples: int = 0
	for i: int in 15:
		await Fixtures.wait_physics(tree, 1)
		if player.is_grounded():
			fast_samples += 1
			if absf(player.floor_snap_length - fast.snap_max) > SNAP_TOLERANCE:
				clamped = false
			if player.floor_snap_length > fast.snap_max + SNAP_TOLERANCE:
				never_over = false
	check.call(player.horizontal_speed() > 21.0, "(f) the player reached dash speed (%.1f m/s)" % player.horizontal_speed())
	check.call(fast_samples > 8 and clamped, "(f) at dash speed floor_snap_length equals snap_max (%.3f)" % player.floor_snap_length)
	check.call(never_over, "(f) floor_snap_length never exceeds snap_max")
	check.call(config.run_speed < config.dash_speed, "(f) the shared config resource was not mutated (run_speed %.1f)" % config.run_speed)

	Input.action_release(&"move_forward")
	await _free_all(tree, nodes)


# (e) tracer: a held jump reaches jump_height, lands once, ends in Idle.
func _scenario_jump(tree: SceneTree, check: Callable) -> void:
	var bus: Node = tree.root.get_node("EventBus")
	var jumped: Array[int] = [0]
	var landed: Array[int] = [0]
	var impacts: Array[float] = []
	var on_jumped: Callable = func(_position: Vector3) -> void: jumped[0] += 1
	var on_landed: Callable = func(_position: Vector3, impact_speed: float) -> void:
		landed[0] += 1
		impacts.append(impact_speed)
	bus.connect(&"jumped", on_jumped)
	bus.connect(&"landed", on_landed)

	var nodes: Array[Node] = await _spawn(tree, Vector3.ZERO)
	var player: PlayerController = nodes[1] as PlayerController
	var config: MovementConfig = player.config
	check.call(landed[0] == 0 and jumped[0] == 0, "(e) no jumped or landed fact while standing")

	Input.action_press(&"jump")
	var max_y: float = 0.0
	var ticks: int = 0
	while landed[0] == 0 and ticks < 120:
		await Fixtures.wait_physics(tree, 1)
		max_y = maxf(max_y, player.global_position.y)
		ticks += 1
	await Fixtures.wait_physics(tree, 3)

	check.call(absf(max_y - config.jump_height) < 0.1, "(e) held jump apex %.3f m is within 0.1 of jump_height %.2f" % [max_y, config.jump_height])
	check.call(jumped[0] == 1, "(e) exactly one jumped fact (got %d)" % jumped[0])
	check.call(landed[0] == 1, "(e) exactly one landed fact (got %d)" % landed[0])
	check.call(impacts.size() == 1 and impacts[0] > 0.0, "(e) landed carries a real impact speed (%.2f m/s)" % (impacts[0] if impacts.size() > 0 else -1.0))
	check.call(player.state_machine.current.name == &"Idle", "(e) the player lands in Idle")
	check.call(absf(player.global_position.y) < 0.05, "(e) the player stands on the floor top (y=%.3f)" % player.global_position.y)

	bus.disconnect(&"jumped", on_jumped)
	bus.disconnect(&"landed", on_landed)
	Input.action_release(&"jump")
	await _free_all(tree, nodes)
