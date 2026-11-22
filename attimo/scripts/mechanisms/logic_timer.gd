class_name LogicTimer
extends SignalSource
## Timer node (MECH-02, D-23): a rising edge of its source switches it on for hold_time. Invisible in game. Stub.

@export var source: SignalSource
## Seconds it stays on after a rising edge.
@export var hold_time: float = 3.0
## When true a new edge while on restarts the time.
@export var retriggerable: bool = true
