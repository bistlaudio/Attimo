class_name Lever
extends SignalSource
## Lever trigger (MECH-01): toggles on every accepted hit, a small pulse or near contact (D-15, D-17). With stays_on it
## stays on after the first hit. The handle rotation is presentation only.

const HANDLE_ANGLE: float = deg_to_rad(35.0)
const HANDLE_SPEED: float = 8.0

## Per-instance option: once on, the lever stays on.
@export var stays_on: bool = false

@onready var _interactable: Interactable = $Interactable
@onready var _handle: Node3D = $Handle


func _ready() -> void:
	super._ready()
	_interactable.triggered.connect(_on_triggered)
	_interactable.near_started.connect(_toggle)
	_handle.rotation.x = _target_angle()


func _physics_process(delta: float) -> void:
	_handle.rotation.x = move_toward(_handle.rotation.x, _target_angle(), HANDLE_SPEED * delta)


func reset() -> void:
	super.reset()
	_handle.rotation.x = _target_angle()


func _on_triggered(_hit: PulseHit) -> void:
	_toggle()


func _toggle() -> void:
	if stays_on and is_active:
		return
	set_active(not is_active)


func _target_angle() -> float:
	return HANDLE_ANGLE if is_active else -HANDLE_ANGLE
