class_name EnergyCore
extends SignalSource
## Energiekern in a lantern (MECH-01, D-15): switches on at a shot and off by itself after core_duration. Stub.

## Seconds the core stays on after a hit.
@export var core_duration: float = 6.0

## Seconds left until the core switches off.
var remaining: float = 0.0
