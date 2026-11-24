extends RefCounted
## Plan 05-01 (HAND-04): LoaderMath is the pure discharge math the release (and later the preview) shares.
## discharge_speed(stored, min_push, bonus, cap) = min(max(stored, min_push) + bonus, cap); a non-finite stored speed counts
## as 0 and a negative bonus as 0. discharge_velocity(direction, speed) scales the unit direction; a zero or non-finite
## direction gives ZERO.

const MATH_PATH: String = "res://scripts/player/loader_math.gd"
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


func run(_tree: SceneTree, check: Callable) -> void:
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
