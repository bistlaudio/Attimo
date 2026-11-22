class_name Conveyor
extends Mechanism
## Foerderband (MECH-03, D-16, D-18): a belt that moves what stands on it through constant_linear_velocity. Stub of plan
## 04-04 task 2, the body follows in task 4.

@export var direction: Vector3 = Vector3(0.0, 0.0, -1.0)
@export_range(0.5, 8.0, 0.1) var speed: float = 3.0
@export_range(0.0, 1.0, 0.05) var ramp_time: float = 0.25
