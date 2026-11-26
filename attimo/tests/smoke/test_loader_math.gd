extends RefCounted
## Plan 05.1-11 (ENRG-09, D-49, D-50): LoaderMath is the pure discharge math the release shares.
## discharge_speed(v, push, n, push_step, k, cap) = min(v + push + n * (push_step + k * v), cap); overflow(...) is what the cap cuts
## off; flight_distance(n, overflow, bases, gain) = bases[n] + overflow * gain. A non-finite input never speeds Rino up.
## discharge_velocity(direction, speed) scales the unit direction; a zero or non-finite direction gives ZERO. The old ballistic
## helpers are deleted (05.1-12); launch_reach and launch_apex size the Zone_Loader room.

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
	_check_removed(math_script, check)
	_check_launch(check)


## D-49 / 05.1-12: the old ballistic helpers and the legacy bridge are gone.
func _check_removed(math_script: GDScript, check: Callable) -> void:
	var names: Array[String] = []
	for method: Dictionary in math_script.get_script_method_list():
		names.append(str(method["name"]))
	for gone: String in ["trajectory", "flat_reach", "apex_height", "step", "legacy_speed"]:
		check.call(not names.has(gone), "LoaderMath has no %s any more" % gone)


## launch_reach and launch_apex: the landing reach and the apex of a straight line plus the ballistic tail (Zone_Loader sizing).
func _check_launch(check: Callable) -> void:
	var config: MovementConfig = load(CONFIG_PATH) as MovementConfig
	var up: Vector3 = Vector3.UP
	var apex: float = LoaderMath.launch_apex(10.0, up, 14.0, config.rise_gravity)
	check.call(absf(apex - (14.0 + 100.0 / (2.0 * config.rise_gravity))) < 0.01, "launch_apex straight up is the line plus v^2 / 2g (got %.2f)" % apex)
	check.call(LoaderMath.launch_reach(10.0, up, 14.0, config.rise_gravity, config.fall_gravity()) < 0.01, "launch_reach straight up lands where it started")
	var direction: Vector3 = Vector3(-cos(deg_to_rad(30.0)), sin(deg_to_rad(30.0)), 0.0)
	var reach: float = LoaderMath.launch_reach(6.0, direction, 6.0, config.rise_gravity, config.fall_gravity())
	check.call(reach > 6.0 * cos(deg_to_rad(30.0)) and reach < 9.0, "launch_reach of 6 m/s at 30 degrees is the line plus a short tail (got %.2f)" % reach)
	check.call(LoaderMath.launch_reach(NAN, direction, 6.0, 34.0, 44.0) == 0.0 and LoaderMath.launch_apex(10.0, Vector3(NAN, 1.0, 0.0), 6.0, 34.0) == 0.0, "non-finite inputs give 0")
