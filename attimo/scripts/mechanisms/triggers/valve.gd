class_name Valve
extends SignalSource
## Handrad-Ventil (MECH-01, D-15): a heavy switch that only the big pulse moves (D-03). Every accepted hit toggles it
## and the wheel turns half a revolution. Stub, filled in by the GREEN step.

## Per-instance option: once on, the valve stays on.
@export var stays_on: bool = false
## Seconds the wheel takes for half a turn.
@export var turn_time: float = 0.6
