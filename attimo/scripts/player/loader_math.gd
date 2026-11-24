class_name LoaderMath
extends RefCounted
## The pure Loader discharge math (HAND-04, GAME-DESIGN 6.8). Static functions only, no node access: the release (LoaderState) and
## the trajectory preview of plan 05-02 call the same functions, so what the preview promises is what the release does. The
## slingshot core may adopt them later (the catch-and-launch shares code with the Loader).


## The speed of a discharge in m/s: max(stored, min_push) + bonus, capped at `cap`. A non-finite stored speed counts as 0, a
## negative or non-finite bonus or min_push as 0, a non-finite or negative cap gives 0, so a bad value can never speed Rino up.
static func discharge_speed(stored_speed: float, min_push: float, bonus: float, cap: float) -> float:
	if not is_finite(cap) or cap <= 0.0:
		return 0.0
	var stored: float = maxf(stored_speed, 0.0) if is_finite(stored_speed) else 0.0
	var push: float = maxf(min_push, 0.0) if is_finite(min_push) else 0.0
	var extra: float = maxf(bonus, 0.0) if is_finite(bonus) else 0.0
	return minf(maxf(stored, push) + extra, cap)


## The discharge velocity: the unit `direction` times `speed`. A zero or non-finite direction or a non-finite speed gives ZERO.
static func discharge_velocity(direction: Vector3, speed: float) -> Vector3:
	if not direction.is_finite() or not is_finite(speed) or direction.length_squared() < 0.000001:
		return Vector3.ZERO
	return direction.normalized() * speed


## One physics step of a free flight, in the exact gravity order of PlayerController._integrate: gravity is chosen once per step
## (rise gravity while the vertical speed is >= 0, fall gravity below), a half step is applied before and after the move, and the
## vertical speed is clamped to the terminal speed. Returns [new_position, new_velocity]. Horizontal velocity stays constant (the
## controller has no air drag while the stick is neutral: air_decel is 0), so this is the no-input path.
static func step(position: Vector3, velocity: Vector3, config: MovementConfig, dt: float) -> PackedVector3Array:
	var gravity: float = config.rise_gravity
	if velocity.y < 0.0:
		gravity = config.fall_gravity()
	var vertical: float = maxf(velocity.y - gravity * dt * 0.5, -config.terminal_speed)
	var moved: Vector3 = position + Vector3(velocity.x, vertical, velocity.z) * dt
	vertical = maxf(vertical - gravity * dt * 0.5, -config.terminal_speed)
	return PackedVector3Array([moved, Vector3(velocity.x, vertical, velocity.z)])


## The no-input flight path as points: points[0] is `origin`, then one point per `dt` step, at most `max_points` in total. With a
## `space` the path stops at the first World hit (a ray between two points on `mask`): the hit point is the last point. A null
## space never truncates. A non-finite origin, velocity or step, or max_points < 1, gives an empty array (T-05-04: bounded work).
static func trajectory(origin: Vector3, velocity: Vector3, config: MovementConfig, dt: float, max_points: int, space: PhysicsDirectSpaceState3D, mask: int) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	if not origin.is_finite() or not velocity.is_finite() or not is_finite(dt) or dt <= 0.0 or max_points < 1 or config == null:
		return points
	points.append(origin)
	var position: Vector3 = origin
	var current: Vector3 = velocity
	while points.size() < max_points:
		var stepped: PackedVector3Array = step(position, current, config, dt)
		if space != null:
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(position, stepped[0], mask)
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty():
				points.append(hit["position"] as Vector3)
				break
		position = stepped[0]
		current = stepped[1]
		points.append(position)
	return points


## The horizontal distance a free flight with `velocity` covers until it comes back down to `drop` m below its start (the no-input
## landing of the discharge on a floor `drop` m lower; 0 = same height). Steps with LoaderMath.step at `dt` and interpolates the
## crossing. The gym room builder sizes its gap from this and the room test recomputes it, so both always agree. Returns 0 for a
## non-finite input or when the flight never comes back down within a bounded number of steps.
static func flat_reach(velocity: Vector3, config: MovementConfig, dt: float = 1.0 / 240.0, drop: float = 0.0) -> float:
	if not velocity.is_finite() or not is_finite(dt) or dt <= 0.0 or config == null:
		return 0.0
	var position: Vector3 = Vector3.ZERO
	var current: Vector3 = velocity
	for _i: int in 4000:
		var stepped: PackedVector3Array = step(position, current, config, dt)
		if position.y + drop > 0.0 and stepped[0].y + drop <= 0.0:
			var span: float = position.y - stepped[0].y
			var share: float = 0.0 if span <= 0.0 else clampf((position.y + drop) / span, 0.0, 1.0)
			var crossing: Vector3 = position.lerp(stepped[0], share)
			return Vector2(crossing.x, crossing.z).length()
		position = stepped[0]
		current = stepped[1]
	return 0.0


## The apex height in m of a straight-up discharge at `speed` under rise gravity: v^2 / (2 g).
static func apex_height(speed: float, config: MovementConfig) -> float:
	if not is_finite(speed) or config == null:
		return 0.0
	return speed * speed / (2.0 * maxf(config.rise_gravity, 0.001))
