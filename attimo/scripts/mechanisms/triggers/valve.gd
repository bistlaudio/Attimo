class_name Valve
extends SignalSource
## Handrad-Ventil (MECH-01, D-15): a heavy switch worked by near contact (hold E beside it; the shot is gone, D-45). Every contact toggles it
## and the wheel turns half a revolution. The wheel turn is presentation only.

## Per-instance option: once on, the valve stays on.
@export var stays_on: bool = false
## Seconds the wheel takes for half a turn.
@export var turn_time: float = 0.6

var _half_turns: int = 0

@onready var _interactable: Interactable = $Interactable
@onready var _wheel: Node3D = $Wheel


func _ready() -> void:
	super._ready()
	_interactable.near_started.connect(_toggle)


func _physics_process(delta: float) -> void:
	var speed: float = PI / maxf(turn_time, 0.05)
	_wheel.rotation.z = move_toward(_wheel.rotation.z, PI * float(_half_turns), speed * delta)


func reset() -> void:
	super.reset()
	_half_turns = 0
	_wheel.rotation.z = 0.0


func _toggle() -> void:
	if stays_on and is_active:
		return
	_half_turns += 1
	set_active(not is_active)
