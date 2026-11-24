class_name ArmEnergy
extends Node
## The single owner of the arm energy (checklist item 12: one owner with spend and gain APIs). Only this class writes `value`;
## states, modules and mechanisms ask can_afford and try_spend and learn the outcome from the EventBus facts, which carry numbers
## and never node references. Child of the Player.
##
## Plan 05-01 ships the minimal API the Loader bonus needs: can_afford, try_spend, reset_to, reset_to_checkpoint. Plan 05-03
## extends this class with drain (partial spends: the wall run per tick, the shot charge), gain (income, clamped to MAX_ENERGY),
## core_fill and is_moto (Moto Perpetuo with hysteresis), plus the energy_gained, energy_refused and moto_changed facts.

## Energy of one core, the respawn value and the Loader bonus cost.
const CORE_SIZE: float = 25.0
## Number of cores on the arm.
const CORE_COUNT: int = 4
## Most energy the arm holds (CORE_COUNT cores).
const MAX_ENERGY: float = 100.0

## Current energy, 0 .. MAX_ENERGY. Starts as one core (the respawn value).
var value: float = CORE_SIZE


## True when `amount` can be paid in full. A non-finite or negative amount cannot.
func can_afford(amount: float) -> bool:
	return is_finite(amount) and amount >= 0.0 and value >= amount


## Pays `amount` all or nothing. On success emits EventBus.energy_spent(amount, reason) and energy_changed(value) and returns true;
## on failure nothing changes, nothing is emitted and false comes back (the caller decides what the refusal looks like).
func try_spend(amount: float, reason: StringName) -> bool:
	if not can_afford(amount):
		return false
	value = clampf(value - amount, 0.0, MAX_ENERGY)
	EventBus.energy_spent.emit(amount, reason)
	EventBus.energy_changed.emit(value)
	return true


## Sets the energy to `new_value` (clamped to 0 .. MAX_ENERGY; a non-finite value is ignored) and emits energy_changed.
func reset_to(new_value: float) -> void:
	if not is_finite(new_value):
		return
	value = clampf(new_value, 0.0, MAX_ENERGY)
	EventBus.energy_changed.emit(value)


## Respawn and checkpoint rule: exactly one core.
func reset_to_checkpoint() -> void:
	reset_to(CORE_SIZE)
