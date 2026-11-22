class_name LogicTimer
extends SignalSource
## Timer node (MECH-02, D-23): a rising edge of its source switches it on for hold_time, then it switches off. Invisible
## in game. A missing source keeps it off with one warning (T-04-07).

@export var source: SignalSource
## Seconds it stays on after a rising edge.
@export var hold_time: float = 3.0
## When true a new edge while on restarts the time; otherwise the running time is kept.
@export var retriggerable: bool = true

var _left: float = 0.0


func _ready() -> void:
	super._ready()
	if source == null:
		push_warning("LogicTimer %s has no source" % name)
		return
	source.active_changed.connect(_on_source_changed)
	if source.is_active:
		_start()


func _physics_process(delta: float) -> void:
	if not is_active:
		return
	_left -= delta
	if _left <= 0.0:
		set_active(false)


func reset() -> void:
	_left = 0.0
	super.reset()


func _on_source_changed(active: bool) -> void:
	if active:
		_start()


func _start() -> void:
	if is_active and not retriggerable:
		return
	_left = hold_time
	set_active(true)
