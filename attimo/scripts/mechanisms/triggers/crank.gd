class_name Crank
extends SignalSource
## Uhrwerk-Kurbel (MECH-01, D-10, D-15): wound by holding near contact, ticks down and switches off at zero. Stub.

## Seconds of run time gained per second of hold.
@export var wind_ratio: float = 6.667
## Upper limit of the stored run time in seconds.
@export var max_time: float = 10.0

## Seconds of run time left.
var remaining: float = 0.0
