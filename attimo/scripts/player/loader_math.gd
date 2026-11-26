class_name LoaderMath
extends RefCounted
## The pure Loader discharge math (HAND-04, ENRG-09, D-49, D-50). Static functions only, no node access: the release (LoaderState)
## and the metrics tool call the same functions. The slingshot cage (Catch & launch, Phase 05.1) throws through the same LoaderState
## discharge as a free 2-step flight, so it uses them too. launch_reach and launch_apex size the Zone_Loader room from the straight line
## plus the ballistic tail after it (D-59).


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
