extends RefCounted
## Plan 05.1-11 (ENRG-09, D-49, D-50): LoaderMath is the pure discharge math the release shares.
## discharge_speed(v, push, n, push_step, k, cap) = min(v + push + n * (push_step + k * v), cap); overflow(...) is what the cap cuts
## off; flight_distance(n, overflow, bases, gain) = bases[n] + overflow * gain. A non-finite input never speeds Rino up.
## discharge_velocity(direction, speed) scales the unit direction; a zero or non-finite direction gives ZERO. The old ballistic
## helpers (step, trajectory, flat_reach) stay for the Zone_Loader builder until 05.1-12.

const MATH_PATH: String = "res://scripts/player/loader_math.gd"
const CONFIG_PATH: String = "res://resources/player/movement_default.tres"
## v, push, n, push_step, k, cap, expected speed, expected overflow.
const SPEED_TABLE: Array[Array] = [
	[0.0, 4.0, 1, 2.0, 0.1, 22.0, 6.0, 0.0],
	[0.0, 4.0, 2, 2.0, 0.1, 22.0, 8.0, 0.0],
	[0.0, 4.0, 3, 2.0, 0.1, 22.0, 10.0, 0.0],
	[8.5, 4.0, 1, 2.0, 0.1, 22.0, 15.35, 0.0],
	[8.5, 4.0, 2, 2.0, 0.1, 22.0, 18.2, 0.0],
	[8.5, 4.0, 3, 2.0, 0.1, 22.0, 21.05, 0.0],
	[16.0, 4.0, 3, 2.0, 0.1, 22.0, 22.0, 8.8],
	[30.0, 4.0, 1, 2.0, 0.1, 22.0, 22.0, 17.0],
	[NAN, 4.0, 1, 2.0, 0.1, 22.0, 6.0, 0.0],
	[INF, 4.0, 3, 2.0, 0.1, 22.0, 10.0, 0.0],
	[8.5, -5.0, 1, 2.0, 0.1, 22.0, 11.35, 0.0],
	[8.5, 4.0, 3, 2.0, 0.1, NAN, 0.0, 0.0],
]
## Flight distance bases of the three steps (D-50).
const BASES: Array[float] = [6.0, 10.0, 14.0]


func run(tree: SceneTree, check: Callable) -> void:
	var math_script: GDScript = load(MATH_PATH) as GDScript
	check.call(math_script != null, "loader_math.gd loads")
	if math_script == null:
		return
	for row: Array in SPEED_TABLE:
		var stored: float = row[0] as float
		var push: float = row[1] as float
		var steps: int = row[2] as int
		var push_step: float = row[3] as float
		var k: float = row[4] as float
		var cap: float = row[5] as float
		var expected: float = row[6] as float
		var expected_over: float = row[7] as float
		var got: float = math_script.call(&"discharge_speed", stored, push, steps, push_step, k, cap) as float
		check.call(is_finite(got) and absf(got - expected) < 1e-3, "discharge_speed(%s, %s, %s, %s, %s, %s) = %s (got %s)" % [stored, push, steps, push_step, k, cap, expected, got])
		var over: float = math_script.call(&"overflow", stored, push, steps, push_step, k, cap) as float
		check.call(is_finite(over) and absf(over - expected_over) < 1e-3, "overflow(%s, %s, %s, ...) = %s (got %s)" % [stored, push, steps, expected_over, over])
	var distance: float = math_script.call(&"flight_distance", 3, 8.8, BASES, 1.0) as float
	check.call(absf(distance - 22.8) < 1e-3, "flight_distance(3, 8.8, bases, 1.0) = 22.8 (got %s)" % distance)
	check.call(absf((math_script.call(&"flight_distance", 1, 0.0, BASES, 1.0) as float) - 6.0) < 1e-4, "flight_distance(1, 0) is 6 m")
	check.call(absf((math_script.call(&"flight_distance", 2, 5.0, BASES, 0.5) as float) - 12.5) < 1e-4, "flight_distance(2, 5, gain 0.5) is 12.5 m")
	check.call(is_finite(math_script.call(&"flight_distance", 3, NAN, BASES, INF) as float), "flight_distance of non-finite inputs is finite")
	check.call((math_script.call(&"flight_distance", 3, -4.0, BASES, 1.0) as float) >= 14.0, "a negative overflow never shortens the flight")
	var uncapped: float = math_script.call(&"discharge_speed_uncapped", 16.0, 4.0, 3, 2.0, 0.1) as float
	check.call(absf(uncapped - 30.8) < 1e-3, "discharge_speed_uncapped(16, 4, 3) = 30.8 (got %s)" % uncapped)
	var up: Vector3 = math_script.call(&"discharge_velocity", Vector3.UP * 3.0, 20.0) as Vector3
	check.call(up.is_equal_approx(Vector3(0.0, 20.0, 0.0)), "discharge_velocity(UP * 3, 20) is (0, 20, 0) (got %s)" % up)
	var zero: Vector3 = math_script.call(&"discharge_velocity", Vector3.ZERO, 20.0) as Vector3
	check.call(zero == Vector3.ZERO, "a zero direction gives ZERO (got %s)" % zero)
	var nan_direction: Vector3 = math_script.call(&"discharge_velocity", Vector3(NAN, 0.0, 1.0), 20.0) as Vector3
	check.call(nan_direction == Vector3.ZERO, "a non-finite direction gives ZERO (got %s)" % nan_direction)
	var inf_speed: Vector3 = math_script.call(&"discharge_velocity", Vector3.FORWARD, INF) as Vector3
	check.call(inf_speed == Vector3.ZERO, "a non-finite speed gives ZERO (got %s)" % inf_speed)
	await _check_trajectory(tree, check)


# Plan 05-02 (kept for the Zone_Loader builder until 05.1-12): step() mirrors PlayerController._integrate, trajectory() is bounded and finite-safe.
func _check_trajectory(_tree: SceneTree, check: Callable) -> void:
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
