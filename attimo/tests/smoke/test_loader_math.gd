extends RefCounted
## Plan 05-01 (HAND-04): LoaderMath is the pure discharge math the release (and later the preview) shares.
## discharge_speed(stored, min_push, bonus, cap) = min(max(stored, min_push) + bonus, cap); a non-finite stored speed counts
## as 0 and a negative bonus as 0. discharge_velocity(direction, speed) scales the unit direction; a zero or non-finite
## direction gives ZERO.

const Fixtures := preload("res://tests/fixtures.gd")

const MATH_PATH: String = "res://scripts/player/loader_math.gd"
const CONFIG_PATH: String = "res://resources/player/movement_default.tres"
const LANDING_TOLERANCE: float = 0.5
## stored, min_push, bonus, cap, expected.
const SPEED_TABLE: Array[Array] = [
	[0.0, 12.0, 0.0, 22.0, 12.0],
	[8.5, 12.0, 8.0, 22.0, 20.0],
	[14.0, 12.0, 8.0, 22.0, 22.0],
	[18.0, 12.0, 8.0, 22.0, 22.0],
	[30.0, 12.0, 0.0, 22.0, 22.0],
	[NAN, 12.0, 0.0, 22.0, 12.0],
	[INF, 12.0, 8.0, 22.0, 20.0],
	[8.5, 12.0, -5.0, 22.0, 12.0],
]


func run(tree: SceneTree, check: Callable) -> void:
	var math_script: GDScript = load(MATH_PATH) as GDScript
	check.call(math_script != null, "loader_math.gd loads")
	if math_script == null:
		return
	for row: Array in SPEED_TABLE:
		var stored: float = row[0] as float
		var min_push: float = row[1] as float
		var bonus: float = row[2] as float
		var cap: float = row[3] as float
		var expected: float = row[4] as float
		var got: float = math_script.call(&"discharge_speed", stored, min_push, bonus, cap) as float
		check.call(absf(got - expected) < 1e-4, "discharge_speed(%s, %s, %s, %s) = %s (got %s)" % [stored, min_push, bonus, cap, expected, got])
	var up: Vector3 = math_script.call(&"discharge_velocity", Vector3.UP * 3.0, 20.0) as Vector3
	check.call(up.is_equal_approx(Vector3(0.0, 20.0, 0.0)), "discharge_velocity(UP * 3, 20) is (0, 20, 0) (got %s)" % up)
	var zero: Vector3 = math_script.call(&"discharge_velocity", Vector3.ZERO, 20.0) as Vector3
	check.call(zero == Vector3.ZERO, "a zero direction gives ZERO (got %s)" % zero)
	var nan_direction: Vector3 = math_script.call(&"discharge_velocity", Vector3(NAN, 0.0, 1.0), 20.0) as Vector3
	check.call(nan_direction == Vector3.ZERO, "a non-finite direction gives ZERO (got %s)" % nan_direction)
	var inf_speed: Vector3 = math_script.call(&"discharge_velocity", Vector3.FORWARD, INF) as Vector3
	check.call(inf_speed == Vector3.ZERO, "a non-finite speed gives ZERO (got %s)" % inf_speed)
	await _check_trajectory(tree, check)


# Plan 05-02: step() mirrors PlayerController._integrate, trajectory() is bounded and finite-safe, and the predicted landing of a
# no-input discharge matches the real one.
func _check_trajectory(tree: SceneTree, check: Callable) -> void:
	var config: MovementConfig = load(CONFIG_PATH) as MovementConfig
	var dt: float = 1.0 / 60.0
	# One rising step: half gravity (rise) before and after, the position moves with the mid-step velocity.
	var rising: PackedVector3Array = LoaderMath.step(Vector3.ZERO, Vector3(3.0, 10.0, 0.0), config, dt)
	var mid: float = 10.0 - config.rise_gravity * dt * 0.5
	check.call(is_equal_approx(rising[0].y, mid * dt) and is_equal_approx(rising[0].x, 3.0 * dt), "step moves with the half-step velocity (got %s)" % rising[0])
	check.call(is_equal_approx(rising[1].y, 10.0 - config.rise_gravity * dt) and is_equal_approx(rising[1].x, 3.0), "step ends with a full gravity step and a constant horizontal speed (got %s)" % rising[1])
	# Falling uses fall gravity; the terminal speed clamps.
	var falling: PackedVector3Array = LoaderMath.step(Vector3.ZERO, Vector3(0.0, -1.0, 0.0), config, dt)
	check.call(is_equal_approx(falling[1].y, -1.0 - config.fall_gravity() * dt), "step uses the fall gravity below zero vertical speed (got %.3f)" % falling[1].y)
	var clamped: PackedVector3Array = LoaderMath.step(Vector3.ZERO, Vector3(0.0, -config.terminal_speed, 0.0), config, dt)
	check.call(is_equal_approx(clamped[1].y, -config.terminal_speed), "step clamps at the terminal speed (got %.3f)" % clamped[1].y)

	var points: PackedVector3Array = LoaderMath.trajectory(Vector3(0.0, 5.0, 0.0), Vector3(8.0, 4.0, 0.0), config, 0.025, 60, null, 0)
	check.call(points.size() == 60, "trajectory returns exactly max_points points without a space (got %d)" % points.size())
	var constant: bool = true
	for index: int in range(1, points.size()):
		constant = constant and is_equal_approx(points[index].x - points[index - 1].x, 8.0 * 0.025)
	check.call(constant, "the horizontal velocity of the path is constant")
	check.call(LoaderMath.trajectory(Vector3(NAN, 0.0, 0.0), Vector3.ONE, config, 0.025, 60, null, 0).is_empty(), "a non-finite origin gives an empty path")
	check.call(LoaderMath.trajectory(Vector3.ZERO, Vector3(INF, 0.0, 0.0), config, 0.025, 60, null, 0).is_empty(), "a non-finite velocity gives an empty path")
	check.call(LoaderMath.trajectory(Vector3.ZERO, Vector3.ONE, config, 0.025, 0, null, 0).is_empty(), "max_points 0 gives an empty path")
	check.call(LoaderMath.trajectory(Vector3.ZERO, Vector3.ONE, config, 0.025, 9999, null, 0).size() == 9999, "the bound is the caller's max_points")
	var reach: float = LoaderMath.flat_reach(Vector3(10.0, 6.0, 0.0), config)
	check.call(reach > 3.0 and reach < 3.6, "flat_reach of a (10, 6) discharge is about 3.3 m (got %.2f)" % reach)
	check.call(LoaderMath.flat_reach(Vector3(NAN, 1.0, 0.0), config) == 0.0, "flat_reach of a non-finite velocity is 0")

	# Live: released at 6 m height, no input; the real landing is within 0.5 m of the predicted floor hit.
	await tree.process_frame
	var floor_body: StaticBody3D = Fixtures.spawn_floor(tree.root, Vector3(80.0, 1.0, 80.0))
	var player: PlayerController = Fixtures.spawn_player(tree.root, Vector3(0.0, 6.0, 0.0))
	await tree.process_frame
	Fixtures.set_energy(player, 25.0)
	player.debug_loader_direction = Vector3(0.8, 0.3, 0.2)
	await Fixtures.wait_physics(tree, 2)
	Input.action_press(&"loader")
	var entered: int = await Fixtures.wait_until(tree, func() -> bool: return player.loader_active(), 6)
	check.call(entered >= 0, "the air press enters the Loader")
	await Fixtures.wait_physics(tree, 10)
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var predicted: Vector3 = Vector3.ZERO
	var released_at: Vector3 = Vector3.ZERO
	Input.action_release(&"loader")
	# The Loader state writes the velocity on the release tick; predict from that moment's position and velocity.
	await Fixtures.wait_until(tree, func() -> bool: return not player.loader_active(), 6)
	released_at = player.global_position
	var velocity: Vector3 = Vector3(player.move_velocity.x, player.vertical_speed, player.move_velocity.z)
	var path: PackedVector3Array = LoaderMath.trajectory(released_at, velocity, config, dt, 400, space, PhysicsLayers.WORLD)
	predicted = path[path.size() - 1] if not path.is_empty() else Vector3.INF
	await Fixtures.wait_until(tree, func() -> bool: return player.is_on_floor(), 240)
	var landed: Vector2 = Vector2(player.global_position.x, player.global_position.z)
	var expected: Vector2 = Vector2(predicted.x, predicted.z)
	check.call(player.is_on_floor() and landed.distance_to(expected) <= LANDING_TOLERANCE, "the real landing %s is within %.1f m of the predicted %s (off by %.2f)" % [landed, LANDING_TOLERANCE, expected, landed.distance_to(expected)])
	Input.action_release(&"loader")
	Fixtures.restore_time()
	player.queue_free()
	await player.tree_exited
	floor_body.queue_free()
	await tree.process_frame
