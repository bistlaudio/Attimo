class_name LoaderMath
extends RefCounted
## The pure Loader discharge math (HAND-04, ENRG-09, D-49, D-50). Static functions only, no node access: the release (LoaderState)
## and the metrics tool call the same functions. The slingshot cage (Catch & launch, Phase 05.1) throws through the same LoaderState
## discharge as a free 2-step flight, so it uses them too. step, trajectory, flat_reach and apex_height are the old ballistic helpers
## that only the Zone_Loader builder reads (deleted in 05.1-12).


## Clamps one formula input: a non-finite value counts as 0, a negative one as 0.
static func _pos(value: float) -> float:
	return maxf(value, 0.0) if is_finite(value) else 0.0


## The raw discharge speed of D-49 in m/s, before the cap: v + push + n * (push_step + k * v), v = the stored speed at the freeze.
## A non-finite or negative input counts as 0, so a bad value can never speed Rino up.
static func discharge_speed_uncapped(stored_speed: float, push: float, steps: int, push_step: float, k: float) -> float:
	var v: float = _pos(stored_speed)
	return v + _pos(push) + float(maxi(steps, 0)) * (_pos(push_step) + _pos(k) * v)


## The speed of a discharge in m/s (D-49): the raw formula capped at `cap`. A non-finite or non-positive cap gives 0.
static func discharge_speed(stored_speed: float, push: float, steps: int, push_step: float, k: float, cap: float) -> float:
	if not is_finite(cap) or cap <= 0.0:
		return 0.0
	return minf(discharge_speed_uncapped(stored_speed, push, steps, push_step, k), cap)


## The speed the cap cuts off, in m/s (D-49): it turns into extra straight-flight distance. 0 for an invalid cap.
static func overflow(stored_speed: float, push: float, steps: int, push_step: float, k: float, cap: float) -> float:
	if not is_finite(cap) or cap <= 0.0:
		return 0.0
	return maxf(discharge_speed_uncapped(stored_speed, push, steps, push_step, k) - cap, 0.0)


## The straight-flight distance in m (D-50): the base of `steps` (bases[steps - 1], clamped into the array) plus overflow * gain.
## Non-finite or negative inputs count as 0, and the result is always finite.
static func flight_distance(steps: int, overflow_speed: float, bases: Array, gain: float) -> float:
	if bases.is_empty():
		return 0.0
	var base: float = _pos(float(bases[clampi(steps, 1, bases.size()) - 1]))
	return base + _pos(overflow_speed) * _pos(gain)


## The whole straight reach of one discharge in m: base distance plus the overflow rule, for the metrics and the room sizing.
static func straight_reach(stored_speed: float, steps: int, push: float, push_step: float, k: float, cap: float, bases: Array, gain: float) -> float:
	return flight_distance(steps, overflow(stored_speed, push, steps, push_step, k, cap), bases, gain)


## The pre-D-49 discharge speed max(stored, min_push) + bonus capped at `cap`. Zone_Loader builder and its room test only, deleted in 05.1-12.
static func legacy_speed(stored_speed: float, min_push: float, bonus: float, cap: float) -> float:
	if not is_finite(cap) or cap <= 0.0:
		return 0.0
	return minf(maxf(_pos(stored_speed), _pos(min_push)) + _pos(bonus), cap)


## The discharge velocity: the unit `direction` times `speed`. A zero or non-finite direction or a non-finite speed gives ZERO.
static func discharge_velocity(direction: Vector3, speed: float) -> Vector3:
	if not direction.is_finite() or not is_finite(speed) or direction.length_squared() < 0.000001:
		return Vector3.ZERO
	return direction.normalized() * speed


## One physics step of a free flight, in the exact gravity order of PlayerController._integrate: gravity is chosen once per step
## (rise gravity while the vertical speed is >= 0, fall gravity below), a half step is applied before and after the move, and the
## vertical speed is clamped to the terminal speed. Returns [new_position, new_velocity]. Horizontal velocity stays constant (the
## controller has no air drag while the stick is neutral: air_decel is 0), so this is the no-input path.
## Zone_Loader builder only, deleted in 05.1-12.
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
## Zone_Loader builder only, deleted in 05.1-12.
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
## Zone_Loader builder only, deleted in 05.1-12.
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
## Zone_Loader builder only, deleted in 05.1-12.
static func apex_height(speed: float, config: MovementConfig) -> float:
	if not is_finite(speed) or config == null:
		return 0.0
	return speed * speed / (2.0 * maxf(config.rise_gravity, 0.001))
