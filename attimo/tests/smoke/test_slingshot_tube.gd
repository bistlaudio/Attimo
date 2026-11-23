extends RefCounted
## MECH-04 C and the MECH-05 tube (D-06, D-10): the Capture state shared by the Schleuderkern and the Rohrpost. The core catches the
## player, pulls them to its centre and ejects them through the point mirror of the entry offset (exit pitch never below
## min_exit_pitch_deg, exit speed clamped); the tube carries them along its path and fires them out of the exit mouth. A blocked
## path or an over-long capture releases the player (no soft-lock, T-04.1-04). Mechanisms only call capture_along (D-06).

const Fixtures := preload("res://tests/fixtures.gd")

const CORE_SCENE: String = "res://scenes/mechanisms/slingshot_core.tscn"
const TUBE_SCENE: String = "res://scenes/mechanisms/pneumatic_tube.tscn"
const SHIPPED_TPS: int = 60
const CENTRE: Vector3 = Vector3(0.0, 5.0, 0.0)


func run(tree: SceneTree, check: Callable) -> void:
	await tree.process_frame
	Engine.physics_ticks_per_second = SHIPPED_TPS
	await _scenario_core_directions(tree, check)
	await _scenario_core_rearm(tree, check)
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


func _make_core(tree: SceneTree) -> Array:
	var source: SignalSource = SignalSource.new()
	tree.root.add_child(source)
	var core: SlingshotCore = (load(CORE_SCENE) as PackedScene).instantiate() as SlingshotCore
	core.source = source
	core.position = CENTRE
	tree.root.add_child(core)
	source.set_active(true)
	return [source, core]


## Launches a player whose body centre starts at CENTRE + offset toward the core and returns the exit velocity of the capture release
## (ZERO when it never entered Capture or never released). `released` collects every capture_released velocity.
func _fly_into_core(tree: SceneTree, player: PlayerController, offset: Vector3, released: Array) -> Vector3:
	player.teleport(CENTRE + offset - Vector3.UP)
	player.air_dash_available = false
	player.launch_along(-offset, 10.0, false)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Capture", 30)
	if waited < 0:
		return Vector3.ZERO
	released.clear()
	await Fixtures.wait_until(tree, func() -> bool: return not released.is_empty(), 120)
	return released[0] as Vector3 if not released.is_empty() else Vector3.ZERO


func _scenario_core_directions(tree: SceneTree, check: Callable) -> void:
	var released: Array = []
	var on_released: Callable = func(_p: Vector3, v: Vector3) -> void: released.append(v)
	EventBus.capture_released.connect(on_released)
	var parts: Array = _make_core(tree)
	var core: SlingshotCore = parts[1] as SlingshotCore
	var player: PlayerController = Fixtures.spawn_player(tree.root, CENTRE + Vector3(-3.0, -1.0, 0.0) + Vector3(0.0, 0.0, 30.0))
	await Fixtures.wait_physics(tree, 3)

	var exit_a: Vector3 = await _fly_into_core(tree, player, Vector3(-3.0, 1.0, 0.0), released)
	check.call(exit_a != Vector3.ZERO, "a player flying at the core is captured and released")
	var want_a: Vector3 = Vector3(3.0, -1.0, 0.0).normalized()
	check.call(exit_a.normalized().dot(want_a) > 0.97, "entry from upper left leaves to lower right (dot %.3f)" % exit_a.normalized().dot(want_a))
	check.call(exit_a.length() >= core.min_exit_speed - 0.01 and exit_a.length() <= core.max_exit_speed + 0.01, "exit speed %.2f lies in [%.1f, %.1f]" % [exit_a.length(), core.min_exit_speed, core.max_exit_speed])
	check.call(player.air_dash_available, "the air dash is back after the release")
	check.call(player.state_machine.current.name == &"Fall", "the release hands over to Fall (%s)" % player.state_machine.current.name)
	check.call(player.gravity_scale == 1.0, "gravity_scale is 1.0 after the capture")

	await Fixtures.wait_physics(tree, 90)
	var exit_b: Vector3 = await _fly_into_core(tree, player, Vector3(0.0, 0.5, 3.0), released)
	var want_b: Vector3 = Vector3(0.0, -0.5, -3.0).normalized()
	check.call(exit_b != Vector3.ZERO and exit_b.normalized().dot(want_b) > 0.97, "a second entry angle gives the mirrored second direction (dot %.3f)" % exit_b.normalized().dot(want_b))

	await Fixtures.wait_physics(tree, 90)
	var exit_c: Vector3 = await _fly_into_core(tree, player, Vector3(0.0, 3.0, -1.0), released)
	var pitch: float = rad_to_deg(asin(clampf(exit_c.y / maxf(exit_c.length(), 0.001), -1.0, 1.0)))
	check.call(exit_c != Vector3.ZERO and absf(pitch - core.min_exit_pitch_deg) < 1.5, "entry from straight above clamps the exit pitch to %.1f degrees (%.2f)" % [core.min_exit_pitch_deg, pitch])
	check.call(exit_c.z > 0.0 and absf(exit_c.x) < 0.5, "and keeps the heading +z (%.2f, %.2f)" % [exit_c.x, exit_c.z])
	EventBus.capture_released.disconnect(on_released)
	await _free(tree, [parts[0], core, player])


func _scenario_core_rearm(tree: SceneTree, check: Callable) -> void:
	var released: Array = []
	var on_released: Callable = func(_p: Vector3, v: Vector3) -> void: released.append(v)
	EventBus.capture_released.connect(on_released)
	var parts: Array = _make_core(tree)
	var core: SlingshotCore = parts[1] as SlingshotCore
	var player: PlayerController = Fixtures.spawn_player(tree.root, CENTRE + Vector3(0.0, 0.0, 40.0))
	await Fixtures.wait_physics(tree, 3)
	var first: Vector3 = await _fly_into_core(tree, player, Vector3(-3.0, 1.0, 0.0), released)
	check.call(first != Vector3.ZERO, "rearm scenario: the first capture works")
	await Fixtures.wait_physics(tree, 3)
	# 0.05 s after the release, fly in again: the core is still disarmed.
	player.teleport(CENTRE + Vector3(-3.0, 0.0, 0.0))
	player.launch_along(Vector3(3.0, -1.0, 0.0), 10.0, false)
	var again: bool = false
	for i: int in 40:
		await tree.physics_frame
		if player.state_machine.current.name == &"Capture":
			again = true
	check.call(not again, "no second capture by the same core within 1.0 s after the release")
	player.teleport(CENTRE + Vector3(0.0, 0.0, 40.0))
	await Fixtures.wait_physics(tree, 60)
	player.teleport(CENTRE + Vector3(-3.0, 0.0, 0.0))
	player.launch_along(Vector3(3.0, -1.0, 0.0), 10.0, false)
	var waited: int = await Fixtures.wait_until(tree, func() -> bool: return player.state_machine.current.name == &"Capture", 30)
	check.call(waited >= 0, "after the rearm time the core catches again (%d)" % waited)
	EventBus.capture_released.disconnect(on_released)
	await _free(tree, [parts[0], core, player])


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
