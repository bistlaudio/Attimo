class_name Conveyor
extends Mechanism
## Foerderband (MECH-03, D-16, D-18): a belt that moves whatever stands on it through the Belt body's constant_linear_velocity
## (bodies get the same surface velocity, so the belt pushes objects as well as the player). RUN_WHILE_ON runs while the signal
## is on, REVERSE_ON_SIGNAL always runs and the signal reverses it. The speed eases over ramp_time, so a rider is never
## launched when the belt starts, stops or reverses (Pitfall 3). Jumping off keeps the belt speed as momentum (engine
## platform velocity, MOVE-08).

## Local direction of the belt surface motion.
@export var direction: Vector3 = Vector3(0.0, 0.0, -1.0)
## Surface speed in m/s.
@export_range(0.5, 8.0, 0.1) var speed: float = 3.0
## Seconds a start, stop or reversal takes.
@export_range(0.0, 1.0, 0.05) var ramp_time: float = 0.25

## Distance between two slats; the slats scroll with the belt so the motion is readable.
const SLAT_SPACING: float = 1.0

var _current: float = 0.0
var _scroll: float = 0.0

@onready var _belt: StaticBody3D = $Belt
@onready var _slats: Node3D = $Belt/Slats


func _physics_process(delta: float) -> void:
	var target: float = 0.0
	match behaviour:
		Behaviour.RUN_WHILE_ON:
			target = speed if signal_on else 0.0
		Behaviour.REVERSE_ON_SIGNAL:
			target = -speed if signal_on else speed
	_current = move_toward(_current, target, speed / maxf(ramp_time, 0.01) * delta)
	var axis: Vector3 = direction.normalized()
	_belt.constant_linear_velocity = (global_basis * axis) * _current
	_scroll = fposmod(_scroll + _current * delta, SLAT_SPACING)
	_slats.position = axis * _scroll


## Current signed belt speed in m/s along `direction`.
func current_speed() -> float:
	return _current


func reset() -> void:
	super.reset()
	_current = 0.0
	_scroll = 0.0
	_belt.constant_linear_velocity = Vector3.ZERO
	_slats.position = Vector3.ZERO
