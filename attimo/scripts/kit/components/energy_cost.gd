class_name EnergyCost
extends Node
## EnergyCost component (Phase 05.1, KIT-01, D-14, D-37, D-39, ENRG-07): lets a kit object charge the arm energy over time. A child node of the block;
## the block calls `tick(player, delta, reason)` every physics tick while the paid thing goes on (a hold of E at the energy core, a fast escape from the
## attraction field) and `end_episode()` when it stops. Each interval it pays `steps` whole steps through ArmEnergy.try_spend (all or nothing).
## When the steps are missing, ArmEnergy.refuse fires once per episode (never every tick, T-05.1-55) and tick returns false. Exactly two users: the
## energy core and the attraction field. Time counts in real seconds (TimeFx.unscaled), so a slow world of a Loader hold does not stretch it.
## It only calls ArmEnergy; it never gives steps.

## Fired for every payment that went through, so a user can count payments while `tick` itself reports whether the episode is paid.
signal paid(steps: int)

## Added to the accumulator so a sum of 1/60 s ticks that lands a hair under the interval still pays (72 ticks of 1/60 are 1.2 s).
const EPSILON: float = 0.0001

## Whole steps paid per interval.
@export_range(1, 3, 1) var steps: int = 1
## Real seconds between two payments (never zero, the accumulator divides by nothing but a zero interval would pay every tick).
@export_range(0.1, 5.0, 0.05) var interval: float = 0.5
## False: the first payment comes after the first interval (the energy core). True: the first tick of an episode pays at once, so every started
## interval costs a step (the attraction field escape, a short dash must not be free).
@export var pay_on_start: bool = false

var _accumulated: float = 0.0
var _refused: bool = false
var _started: bool = false


## Counts `delta` and pays when an interval is full. Returns true while the episode is paid (including the ticks between two payments; `paid` fires for the payments), false when
## a payment failed. A failed payment refuses once per episode and is retried at the next interval, so energy that arrives later is still used.
func tick(player: PlayerController, delta: float, reason: StringName) -> bool:
	if player == null or not is_instance_valid(player) or player.arm_energy == null:
		return false
	if not _started:
		_started = true
		_accumulated = interval if pay_on_start else 0.0
		_refused = false
	_accumulated += TimeFx.unscaled(delta)
	if _accumulated + EPSILON < interval:
		return not _refused
	_accumulated = maxf(_accumulated - interval, 0.0)
	if player.arm_energy.try_spend(steps, reason):
		_refused = false
		paid.emit(steps)
		return true
	if not _refused:
		_refused = true
		player.arm_energy.refuse(reason, steps)
	return false


## Ends the paid thing: the next tick starts a new episode (the accumulator and the refusal latch are cleared).
func end_episode() -> void:
	_accumulated = 0.0
	_refused = false
	_started = false
