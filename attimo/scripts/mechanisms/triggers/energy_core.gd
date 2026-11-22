class_name EnergyCore
extends SignalSource
## Energiekern in a lantern (MECH-01, D-15): switches on at a shot and off by itself after core_duration. A new hit
## restarts the time. A ring of pips around the lantern shows the time left (a visible built-in timer).

## Seconds the core stays on after a hit.
@export var core_duration: float = 6.0

## Seconds left until the core switches off.
var remaining: float = 0.0

@onready var _interactable: Interactable = $Interactable
@onready var _pips: Array[Node] = $Lantern/TimerRing.get_children()


func _ready() -> void:
	super._ready()
	_interactable.triggered.connect(_on_triggered)
	_show_pips()


func _physics_process(delta: float) -> void:
	if remaining <= 0.0:
		return
	remaining = maxf(remaining - delta, 0.0)
	if remaining <= 0.0:
		set_active(false)
	_show_pips()


func reset() -> void:
	remaining = 0.0
	super.reset()
	_show_pips()


func _on_triggered(_hit: PulseHit) -> void:
	remaining = core_duration
	set_active(true)
	_show_pips()


func _show_pips() -> void:
	var fraction: float = clampf(remaining / maxf(core_duration, 0.01), 0.0, 1.0)
	var visible_count: int = ceili(fraction * float(_pips.size()))
	for i: int in _pips.size():
		(_pips[i] as Node3D).visible = i < visible_count
