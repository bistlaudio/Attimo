class_name LoaderMath
extends RefCounted
## The pure Loader discharge math (HAND-04, ENRG-09, D-49, D-50; staged table D-63..D-65 since Phase 05.2). Static functions only, no node access: the release (LoaderState)
## and the metrics tool call the same functions. The slingshot cage (Catch & launch, Phase 05.1) throws through the same LoaderState
## discharge as a free 2-step flight, so it uses them too. launch_reach and launch_apex size the Zone_Loader room from the straight line
## plus the ballistic tail after it (D-59).


## Clamps one formula input: a non-finite value counts as 0, a negative one as 0.
static func _pos(value: float) -> float:
	return maxf(value, 0.0) if is_finite(value) else 0.0


## The ticks per second of the shot simulation: the physics tick of the game (project default 60), so the numbers match PlayerController.
const SHOT_DT: float = 1.0 / 60.0
## Hard stop of the shot simulation in ticks (10 s), so a bad input can never loop long.
const SHOT_MAX_TICKS: int = 600


## The stage table lookup of D-63: the entry of `stage` (clamped into 1..speeds.size()) as a speed in m/s. An empty array gives 0,
## a non-finite or negative entry counts as 0.
static func stage_speed(stage: int, speeds: Array) -> float:
	if speeds.is_empty():
		return 0.0
	return _pos(float(speeds[clampi(stage, 1, speeds.size()) - 1]))


## The shot-phase length of D-64 in seconds for `stage` (clamped into 1..times.size()). An empty array gives 0, a non-finite or negative
## entry counts as 0.
static func shot_time(stage: int, times: Array) -> float:
	if times.is_empty():
		return 0.0
	return _pos(float(times[clampi(stage, 1, times.size()) - 1]))


## The exit speed of a staged discharge in m/s (D-63): the faster of the own speed and the stage speed, capped. No addition, no k factor,
## no overflow. A non-finite input counts as 0; a non-finite or non-positive cap gives 0.
static func exit_speed(own_speed: float, stage_speed_value: float, cap: float) -> float:
	if not is_finite(cap) or cap <= 0.0:
		return 0.0
	return minf(maxf(_pos(own_speed), _pos(stage_speed_value)), cap)


## Runs the shot simulation in the exact order of PlayerController._integrate and returns [reach, apex]: gravity is picked from the sign
## of the vertical speed BEFORE the move (rise_g at vy >= 0, fall_g below), scaled by `shot_scale` while the elapsed time is under
## `shot_seconds`, half a step before and half after the move. No air control, no terminal clamp, launch from floor height. The reach is
## the horizontal distance in m at the tick the height is back at the launch height (or after SHOT_MAX_TICKS), the apex the highest
## height in m above the launch point. Both 0 for a non-finite or zero direction, a non-finite speed or a non-positive gravity.
static func _simulate_shot(speed: float, direction: Vector3, shot_seconds: float, shot_scale: float, rise_g: float, fall_g: float, dt: float) -> Array[float]:
	if not direction.is_finite() or direction.length_squared() < 0.000001 or not is_finite(speed):
		return [0.0, 0.0]
	if not is_finite(rise_g) or rise_g <= 0.0 or not is_finite(fall_g) or fall_g <= 0.0 or not is_finite(dt) or dt <= 0.0:
		return [0.0, 0.0]
	var unit: Vector3 = direction.normalized()
	var across: float = _pos(speed) * Vector2(unit.x, unit.z).length()
	var vy: float = _pos(speed) * unit.y
	var gravity_factor: float = _pos(shot_scale)
	var limit: float = _pos(shot_seconds) - 0.000001
	var x: float = 0.0
	var y: float = 0.0
	var apex: float = 0.0
	var t: float = 0.0
	for tick: int in SHOT_MAX_TICKS:
		var g: float = rise_g if vy >= 0.0 else fall_g
		if t < limit:
			g *= gravity_factor
		vy -= g * dt * 0.5
		x += across * dt
		y += vy * dt
		vy -= g * dt * 0.5
		t += dt
		apex = maxf(apex, y)
		if y <= 0.0 and tick > 1:
			break
	return [x, apex]


## The horizontal distance in m a staged discharge covers until it is back at the launch height (D-65): `speed` along `direction`, the
## shot phase of `shot_seconds` s at `shot_scale` x gravity, then normal gravity. The same function sizes the rooms, the metrics and the tests.
static func shot_reach(speed: float, direction: Vector3, shot_seconds: float, shot_scale: float, rise_g: float, fall_g: float, dt: float = SHOT_DT) -> float:
	return _simulate_shot(speed, direction, shot_seconds, shot_scale, rise_g, fall_g, dt)[0]


## The highest height in m above the launch point of a staged discharge (D-65, D-70), same simulation as shot_reach.
static func shot_apex(speed: float, direction: Vector3, shot_seconds: float, shot_scale: float, rise_g: float, fall_g: float, dt: float = SHOT_DT) -> float:
	return _simulate_shot(speed, direction, shot_seconds, shot_scale, rise_g, fall_g, dt)[1]


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


## The discharge velocity: the unit `direction` times `speed`. A zero or non-finite direction or a non-finite speed gives ZERO.
static func discharge_velocity(direction: Vector3, speed: float) -> Vector3:
	if not direction.is_finite() or not is_finite(speed) or direction.length_squared() < 0.000001:
		return Vector3.ZERO
	return direction.normalized() * speed


## The height in m above the launch point of the highest point of a discharge: the straight line of `distance` m along `direction`
## (gravity-free, D-50), then the ballistic tail with the speed `speed` along `direction` under rise gravity. 0 for a non-finite input.
static func launch_apex(speed: float, direction: Vector3, distance: float, rise_g: float) -> float:
	if not direction.is_finite() or direction.length_squared() < 0.000001 or not is_finite(speed) or not is_finite(distance) or not is_finite(rise_g) or rise_g <= 0.0:
		return 0.0
	var unit: Vector3 = direction.normalized()
	var height: float = _pos(distance) * unit.y
	var vertical: float = _pos(speed) * unit.y
	return maxf(height + (vertical * vertical / (2.0 * rise_g) if vertical > 0.0 else 0.0), 0.0)


## The horizontal distance in m from the launch point to where a discharge comes back down to the launch height: the straight line of
## `distance` m (gravity-free), then the ballistic tail (rise gravity going up, fall gravity going down, no air control, no terminal
## clamp). A launch that never rises above its start returns the horizontal part of the line. 0 for a non-finite input.
static func launch_reach(speed: float, direction: Vector3, distance: float, rise_g: float, fall_g: float) -> float:
	if not direction.is_finite() or direction.length_squared() < 0.000001 or not is_finite(speed) or not is_finite(distance):
		return 0.0
	if not is_finite(rise_g) or rise_g <= 0.0 or not is_finite(fall_g) or fall_g <= 0.0:
		return 0.0
	var unit: Vector3 = direction.normalized()
	var line: float = _pos(distance)
	var flat: float = line * Vector2(unit.x, unit.z).length()
	var height: float = line * unit.y
	var vertical: float = _pos(speed) * unit.y
	var across: float = _pos(speed) * Vector2(unit.x, unit.z).length()
	var top: float = height + (vertical * vertical / (2.0 * rise_g) if vertical > 0.0 else 0.0)
	if top <= 0.0:
		return flat
	var time_up: float = maxf(vertical, 0.0) / rise_g
	var time_down: float = sqrt(2.0 * top / fall_g)
	if vertical < 0.0:
		# Already falling when the line ends: the time to reach the launch height from `height` at the downward speed.
		time_down = (vertical + sqrt(vertical * vertical + 2.0 * fall_g * height)) / fall_g
	return flat + across * (time_up + maxf(time_down, 0.0))
