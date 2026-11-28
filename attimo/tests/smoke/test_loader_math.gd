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
	_check_stage_table(check)
	_check_exit_speed(check)
	_check_shot_guards(check)
	_check_shot_reach(check)


## D-49 / 05.1-12: the old ballistic helpers and the legacy bridge are gone.
func _check_removed(math_script: GDScript, check: Callable) -> void:
	var names: Array[String] = []
	for method: Dictionary in math_script.get_script_method_list():
		names.append(str(method["name"]))
	for gone: String in ["trajectory", "flat_" + "reach", "apex_" + "height", "step", "legacy_" + "speed"]:
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


## Plan 05.2-01 (D-63, D-84): the stage speeds and shot times come from the config, the lookups clamp the stage.
func _check_stage_table(check: Callable) -> void:
	var config: MovementConfig = load(CONFIG_PATH) as MovementConfig
	var speeds: Array = [config.loader_stage_speed_1, config.loader_stage_speed_2, config.loader_stage_speed_3]
	var times: Array = [config.loader_shot_time_1, config.loader_shot_time_2, config.loader_shot_time_3]
	check.call(config.loader_stage_time > 0.0, "loader_stage_time is strictly positive (it divides)")
	check.call(config.loader_stage_speed_3 <= config.loader_max_speed, "stage 3 speed does not exceed the loader_max_speed cap")
	check.call(config.loader_stage_speed_1 < config.loader_stage_speed_2 and config.loader_stage_speed_2 <= config.loader_stage_speed_3, "the stage speeds rise with the stage")
	check.call(LoaderMath.stage_speed(1, speeds) == config.loader_stage_speed_1, "stage_speed(1) is stage 1")
	check.call(LoaderMath.stage_speed(3, speeds) == config.loader_stage_speed_3, "stage_speed(3) is stage 3")
	check.call(LoaderMath.stage_speed(0, speeds) == config.loader_stage_speed_1, "stage_speed(0) clamps to stage 1")
	check.call(LoaderMath.stage_speed(9, speeds) == config.loader_stage_speed_3, "stage_speed(9) clamps to stage 3")
	check.call(LoaderMath.stage_speed(2, []) == 0.0, "stage_speed of an empty array is 0")
	check.call(LoaderMath.stage_speed(2, [NAN, INF, -3.0]) == 0.0 and LoaderMath.stage_speed(3, [NAN, INF, -3.0]) == 0.0, "stage_speed of a non-finite or negative entry is 0")
	check.call(LoaderMath.shot_time(1, times) == config.loader_shot_time_1, "shot_time(1) is stage 1")
	check.call(LoaderMath.shot_time(3, times) == config.loader_shot_time_3, "shot_time(3) is stage 3")
	check.call(LoaderMath.shot_time(-4, times) == config.loader_shot_time_1 and LoaderMath.shot_time(7, times) == config.loader_shot_time_3, "shot_time clamps the stage")
	check.call(LoaderMath.shot_time(2, []) == 0.0, "shot_time of an empty array is 0")
	check.call(LoaderMath.shot_time(1, [NAN]) == 0.0, "shot_time of a non-finite entry is 0")


## D-63: exit speed = max(own, stage) then the cap; no addition, no k factor, no overflow.
func _check_exit_speed(check: Callable) -> void:
	check.call(absf(LoaderMath.exit_speed(21.0, 16.5, 22.0) - 21.0) < 1e-4, "exit_speed(21, 16.5, 22) is 21: own speed wins, nothing is added")
	check.call(absf(LoaderMath.exit_speed(30.0, 16.5, 22.0) - 22.0) < 1e-4, "exit_speed(30, 16.5, 22) is the cap 22")
	check.call(absf(LoaderMath.exit_speed(0.0, 20.0, 22.0) - 20.0) < 1e-4, "exit_speed(0, 20, 22) is the stage speed 20")
	check.call(absf(LoaderMath.exit_speed(8.5, 22.0, 22.0) - 22.0) < 1e-4, "exit_speed(8.5, 22, 22) is 22")
	check.call(absf(LoaderMath.exit_speed(NAN, 16.5, 22.0) - 16.5) < 1e-4, "a NAN own speed counts as 0")
	check.call(absf(LoaderMath.exit_speed(INF, 16.5, 22.0) - 16.5) < 1e-4, "an INF own speed counts as 0")
	check.call(absf(LoaderMath.exit_speed(5.0, NAN, 22.0) - 5.0) < 1e-4, "a NAN stage speed counts as 0")
	check.call(absf(LoaderMath.exit_speed(5.0, INF, 22.0) - 5.0) < 1e-4, "an INF stage speed counts as 0")
	check.call(LoaderMath.exit_speed(10.0, 16.5, NAN) == 0.0, "a NAN cap gives 0")
	check.call(LoaderMath.exit_speed(10.0, 16.5, INF) == 0.0, "an INF cap gives 0")
	check.call(LoaderMath.exit_speed(10.0, 16.5, 0.0) == 0.0 and LoaderMath.exit_speed(10.0, 16.5, -5.0) == 0.0, "a non-positive cap gives 0")
	check.call(LoaderMath.exit_speed(-6.0, 16.5, 22.0) >= 16.5, "a negative own speed never slows the stage speed")


## shot_reach / shot_apex guards: zero or non-finite direction, non-positive gravity, INF speed.
func _check_shot_guards(check: Callable) -> void:
	var dir: Vector3 = Vector3(1.0, 0.2, 0.0)
	check.call(LoaderMath.shot_reach(20.0, Vector3.ZERO, 0.5, 0.3, 34.0, 44.2) == 0.0, "shot_reach of a zero direction is 0")
	check.call(LoaderMath.shot_reach(20.0, Vector3(NAN, 0.0, 1.0), 0.5, 0.3, 34.0, 44.2) == 0.0, "shot_reach of a non-finite direction is 0")
	check.call(LoaderMath.shot_reach(20.0, dir, 0.5, 0.3, 0.0, 44.2) == 0.0 and LoaderMath.shot_reach(20.0, dir, 0.5, 0.3, 34.0, -1.0) == 0.0, "shot_reach of a non-positive gravity is 0")
	check.call(LoaderMath.shot_reach(NAN, dir, 0.5, 0.3, 34.0, 44.2) == 0.0, "shot_reach of a NAN speed is 0")
	check.call(is_finite(LoaderMath.shot_reach(INF, dir, 0.5, 0.3, 34.0, 44.2)), "shot_reach of an INF speed is finite")
	check.call(LoaderMath.shot_apex(20.0, Vector3.ZERO, 0.5, 0.3, 34.0, 44.2) == 0.0, "shot_apex of a zero direction is 0")
	check.call(LoaderMath.shot_apex(20.0, Vector3(0.0, INF, 1.0), 0.5, 0.3, 34.0, 44.2) == 0.0, "shot_apex of a non-finite direction is 0")
	check.call(LoaderMath.shot_apex(20.0, dir, 0.5, 0.3, -2.0, 44.2) == 0.0, "shot_apex of a non-positive gravity is 0")
	check.call(is_finite(LoaderMath.shot_apex(INF, dir, 0.5, 0.3, 34.0, 44.2)), "shot_apex of an INF speed is finite")
	check.call(is_finite(LoaderMath.shot_reach(20.0, dir, NAN, NAN, 34.0, 44.2)), "shot_reach of a NAN shot time and scale is finite")


## D-65 on paper: the config stage values reach about 8 / 12 / 16 m at 10 degrees (research simulation 8.1 / 11.8 / 15.5 m).
func _check_shot_reach(check: Callable) -> void:
	var config: MovementConfig = load(CONFIG_PATH) as MovementConfig
	var speeds: Array = [config.loader_stage_speed_1, config.loader_stage_speed_2, config.loader_stage_speed_3]
	var times: Array = [config.loader_shot_time_1, config.loader_shot_time_2, config.loader_shot_time_3]
	var dir: Vector3 = Vector3(cos(deg_to_rad(10.0)), sin(deg_to_rad(10.0)), 0.0)
	var targets: Array[float] = [8.0, 12.0, 16.0]
	var reaches: Array[float] = []
	for stage: int in [1, 2, 3]:
		var speed: float = LoaderMath.exit_speed(0.0, LoaderMath.stage_speed(stage, speeds), config.loader_max_speed)
		var reach: float = LoaderMath.shot_reach(speed, dir, LoaderMath.shot_time(stage, times), config.loader_shot_gravity_scale, config.rise_gravity, config.fall_gravity())
		reaches.append(reach)
		check.call(absf(reach - targets[stage - 1]) <= 1.0, "D-65: stage %d reach at 10 degrees is within 1 m of %s m (got %.2f)" % [stage, targets[stage - 1], reach])
	check.call(absf(reaches[0] - 8.1) <= 0.3, "stage 1 reach matches the research model 8.1 m within 0.3 m (got %.2f)" % reaches[0])
	check.call(reaches[0] < reaches[1] and reaches[1] < reaches[2], "the reach grows with the stage (%.2f < %.2f < %.2f)" % [reaches[0], reaches[1], reaches[2]])
	var speed_2: float = LoaderMath.stage_speed(2, speeds)
	var short_shot: float = LoaderMath.shot_reach(speed_2, dir, 0.2, config.loader_shot_gravity_scale, config.rise_gravity, config.fall_gravity())
	var long_shot: float = LoaderMath.shot_reach(speed_2, dir, 0.8, config.loader_shot_gravity_scale, config.rise_gravity, config.fall_gravity())
	check.call(short_shot < long_shot, "the reach grows with the shot time (%.2f < %.2f)" % [short_shot, long_shot])
	var apex_1: float = LoaderMath.shot_apex(LoaderMath.stage_speed(1, speeds), dir, LoaderMath.shot_time(1, times), config.loader_shot_gravity_scale, config.rise_gravity, config.fall_gravity())
	var apex_3: float = LoaderMath.shot_apex(LoaderMath.stage_speed(3, speeds), dir, LoaderMath.shot_time(3, times), config.loader_shot_gravity_scale, config.rise_gravity, config.fall_gravity())
	check.call(apex_1 > 0.0 and apex_3 > apex_1, "shot_apex is positive and grows with the stage (%.2f < %.2f)" % [apex_1, apex_3])
	var up_apex: float = LoaderMath.shot_apex(20.0, Vector3.UP, 0.5, config.loader_shot_gravity_scale, config.rise_gravity, config.fall_gravity())
	check.call(up_apex > 20.0 * 20.0 / (2.0 * config.rise_gravity), "a straight-up shot under 0.3x gravity climbs higher than the plain v^2 / 2g (got %.2f)" % up_apex)
