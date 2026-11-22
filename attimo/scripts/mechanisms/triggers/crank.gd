class_name Crank
extends SignalSource
## Uhrwerk-Kurbel (MECH-01, D-10, D-15): accepts near contact only. Holding E winds it up (wind_ratio seconds of run time
## per second held, up to max_time), then it ticks down visibly and switches off at zero. Handle and dial are
## presentation only.

const SPIN_HELD: float = 8.0
const SPIN_IDLE: float = -2.0

## Seconds of run time gained per second of hold.
@export var wind_ratio: float = 6.667
## Upper limit of the stored run time in seconds.
@export var max_time: float = 10.0

## Seconds of run time left.
var remaining: float = 0.0

var _wound_this_tick: bool = false

@onready var _interactable: Interactable = $Interactable
@onready var _handle: Node3D = $Handle
@onready var _needle: Node3D = $Dial/Needle


func _ready() -> void:
	super._ready()
	_interactable.near_held.connect(_on_near_held)
	_apply_dial()


func _physics_process(delta: float) -> void:
	if _wound_this_tick:
		_wound_this_tick = false
		_handle.rotation.z += SPIN_HELD * delta
	elif remaining > 0.0:
		remaining = maxf(remaining - delta, 0.0)
		_handle.rotation.z += SPIN_IDLE * delta
		if remaining <= 0.0:
			set_active(false)
	_apply_dial()


func reset() -> void:
	remaining = 0.0
	_wound_this_tick = false
	super.reset()
	_apply_dial()


func _on_near_held(delta: float) -> void:
	_wound_this_tick = true
	remaining = minf(remaining + delta * wind_ratio, max_time)
	set_active(remaining > 0.0)


## The needle sweeps from +90 degrees (empty) to -90 degrees (full).
func _apply_dial() -> void:
	var fraction: float = clampf(remaining / maxf(max_time, 0.01), 0.0, 1.0)
	_needle.rotation.z = lerpf(PI * 0.5, -PI * 0.5, fraction)
