class_name LiftPlatform
extends Mechanism
## Hub-Plattform (MECH-03, D-16, D-18): a platform that travels from point A to point B while the signal is on and back to A
## while it is off. The speed eases in and out over ease_time, so a rider is never launched (D-22); the engine carries the
## rider with the body's velocity like any linear platform. The look is a piston column or two chains (D-16).
## The Body sits on the World layer and is not one of the gym test platforms.

enum Look { PISTON, CHAIN }

## Local offset of the lower stop (relative to this node).
@export var point_a: Vector3 = Vector3.ZERO
## Local offset of the upper stop.
@export var point_b: Vector3 = Vector3(0.0, 4.0, 0.0)
## Travel speed in m/s.
@export_range(0.1, 8.0, 0.1) var speed: float = 2.0
## Seconds a start or a stop takes.
@export_range(0.0, 1.0, 0.05) var ease_time: float = 0.15
@export var look: Look = Look.PISTON

var _progress: float = 0.0
var _velocity: float = 0.0

@onready var _body: AnimatableBody3D = $Body
@onready var _piston: Node3D = $Body/Piston
@onready var _chains: Node3D = $Body/Chains


func _ready() -> void:
	_body.sync_to_physics = true
	_piston.visible = look == Look.PISTON
	_chains.visible = look == Look.CHAIN
	_apply()
	super._ready()


func _physics_process(delta: float) -> void:
	var length: float = (point_b - point_a).length()
	if length < 0.01:
		return
	var goal: float = 1.0 if signal_on else 0.0
	var remaining: float = absf(goal - _progress) * length
	if remaining < 0.002:
		_progress = goal
		_velocity = 0.0
	else:
		var ease_seconds: float = maxf(ease_time, 0.01)
		var target: float = minf(speed, remaining / ease_seconds) * signf(goal - _progress)
		_velocity = move_toward(_velocity, target, speed / ease_seconds * delta)
		_progress = clampf(_progress + _velocity * delta / length, 0.0, 1.0)
	_apply()


## Progress along the path, 0 at A and 1 at B.
func progress() -> float:
	return _progress


func reset() -> void:
	super.reset()
	_progress = 0.0
	_velocity = 0.0
	_apply()
	_body.reset_physics_interpolation()


func _apply() -> void:
	_body.position = point_a.lerp(point_b, _progress)
