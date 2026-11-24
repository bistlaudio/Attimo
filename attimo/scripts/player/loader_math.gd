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
