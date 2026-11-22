class_name LiftPlatform
extends Mechanism
## Hub-Plattform (MECH-03, D-16, D-18): a platform that travels from point A to point B while the signal is on and back
## while it is off. Stub of plan 04-04 task 2, the body follows in task 3.

enum Look { PISTON, CHAIN }

@export var point_a: Vector3 = Vector3.ZERO
@export var point_b: Vector3 = Vector3(0.0, 4.0, 0.0)
@export_range(0.1, 8.0, 0.1) var speed: float = 2.0
@export_range(0.0, 1.0, 0.05) var ease_time: float = 0.15
@export var look: Look = Look.PISTON
