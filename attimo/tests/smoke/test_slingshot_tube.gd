extends RefCounted
## MECH-05 tube (D-06): the Capture state of the Rohrpost. The tube carries the player along its path and fires them out of the exit
## mouth. A blocked path or an over-long capture releases the player (no soft-lock, T-04.1-04). Mechanisms only call capture_along
## (D-06). The slingshot core moved to the Loader state in Phase 05.1 (test_slingshot_loader); the tube scenarios stay until plan
## 05.1-02 cuts the tube.

const Fixtures := preload("res://tests/fixtures.gd")

const TUBE_SCENE: String = "res://scenes/mechanisms/pneumatic_tube.tscn"
const SHIPPED_TPS: int = 60


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_tube(tree, check)
	await _scenario_tube_blocked(tree, check)
	await _scenario_bad_requests(tree, check)
	Engine.physics_ticks_per_second = SHIPPED_TPS


func _free(tree: SceneTree, nodes: Array) -> void:
	for node: Variant in nodes:
		if is_instance_valid(node):
			(node as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


func _make_tube(tree: SceneTree) -> Array:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var tube: PneumaticTube = (load(TUBE_SCENE) as PackedScene).instantiate() as PneumaticTube
	tube.source = source
	tree.root.add_child(tube)
	source.set_active(true)
	return [source, tube]


func _scenario_tube(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var parts: Array = _make_tube(tree)
	var tube: PneumaticTube = parts[1] as PneumaticTube
	var points: PackedVector3Array = tube.path_points()
	check.call(points.size() == 4, "the tube path has four points (%d)" % points.size())
	var exit_point: Vector3 = points[3]
	var exit_dir: Vector3 = (points[3] - points[2]).normalized()
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 4.0))
	await Fixtures.wait_physics(tree, 20)
	Input.action_press(&"move_forward")
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Capture", 90)
	Input.action_release(&"move_forward")
	check.call(waited >= 0, "walking into the mouth enters Capture (%d)" % waited)
	var closest: float = INF
	for i: int in 120:
		await tree.physics_frame
		closest = minf(closest, player.global_position.distance_to(exit_point))
		if player.state_machine.current.name != &"Capture":
			break
	check.call(closest <= 0.5, "the carried player reaches within 0.5 m of the exit point (%.2f)" % closest)
	await Fixtures.wait_physics(tree, 3)
	var flat: Vector3 = Vector3(player.move_velocity.x, 0.0, player.move_velocity.z)
	check.call(flat.normalized().dot(Vector3(exit_dir.x, 0.0, exit_dir.z).normalized()) > 0.95, "the exit points along the exit mouth direction (dot %.3f)" % flat.normalized().dot(Vector3(exit_dir.x, 0.0, exit_dir.z).normalized()))
	check.call(absf(flat.length() - tube.exit_speed) <= 0.1 * tube.exit_speed, "the exit speed is %.2f m/s (exit_speed %.1f, within 10 %%)" % [flat.length(), tube.exit_speed])
	await _free(tree, [floor_body, parts[0], tube, player])


func _scenario_tube_blocked(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var parts: Array = _make_tube(tree)
	var tube: PneumaticTube = parts[1] as PneumaticTube
	# A slab over the mouth stops the upward leg half a metre up (the player stands 2 m tall).
	var slab: StaticBody3D = Fixtures.spawn_box(tree.root, Vector3(4.0, 1.0, 4.0), Vector3(0.0, 3.0, 0.0))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 4.0))
	await Fixtures.wait_physics(tree, 20)
	Input.action_press(&"move_forward")
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Capture", 90)
	Input.action_release(&"move_forward")
	check.call(waited >= 0, "blocked tube: the mouth still captures (%d)" % waited)
	var released_in: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"Capture", 60)
	check.call(released_in >= 0 and released_in <= 60, "a blocked path releases the player within one second (%d ticks)" % released_in)
	check.call(player.gravity_scale == 1.0, "gravity_scale is 1.0 after the stuck release")
	await _free(tree, [floor_body, slab, parts[0], tube, player])


func _scenario_bad_requests(tree: SceneTree, check: Callable) -> void:
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root)
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 0.0, 0.0))
	await Fixtures.wait_physics(tree, 20)
	var good: PackedVector3Array = PackedVector3Array([Vector3(0.0, 6.0, 0.0), Vector3(0.0, 6.0, -6.0)])
	player.capture_along(PackedVector3Array(), 10.0, 0.0, Vector3.ZERO)
	check.call(player.state_machine.current.name != &"Capture", "an empty path is ignored")
	player.capture_along(PackedVector3Array([Vector3(NAN, 1.0, 0.0)]), 10.0, 0.0, Vector3.ZERO)
	check.call(player.state_machine.current.name != &"Capture", "a NAN point is ignored")
	player.capture_along(good, 0.0, 0.0, Vector3.ZERO)
	check.call(player.state_machine.current.name != &"Capture", "speed 0 is ignored")
	player.capture_along(good, 10.0, -1.0, Vector3.ZERO)
	check.call(player.state_machine.current.name != &"Capture", "a negative hold time is ignored")
	player.capture_along(good, 10.0, 0.0, Vector3(INF, 0.0, 0.0))
	check.call(player.state_machine.current.name != &"Capture", "a non-finite exit velocity is ignored")
	player.capture_along(good, 10.0, 0.0, Vector3(0.0, 0.0, -10.0))
	check.call(player.state_machine.current.name == &"Capture", "a valid request enters Capture")
	player.capture_along(PackedVector3Array([Vector3(5.0, 1.0, 5.0)]), 3.0, 0.0, Vector3.ZERO)
	check.call(player.capture_points == good and player.capture_speed == 10.0, "a request while already in Capture is ignored")
	var left: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name != &"Capture", 120)
	check.call(left >= 0, "the valid request ends (%d ticks)" % left)
	await _free(tree, [floor_body, player])
