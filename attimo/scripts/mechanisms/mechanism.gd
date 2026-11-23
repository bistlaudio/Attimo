class_name Mechanism
extends Node3D
## Base of signal-driven mechanisms. `source` is an exported ref wired by the room builder. RUN_WHILE_ON runs while the
## signal is on and stops when it goes off, REVERSE_ON_SIGNAL reverses direction on every signal edge (D-18).

enum Behaviour { RUN_WHILE_ON, REVERSE_ON_SIGNAL }

@export var source: SignalSource
@export var behaviour: Behaviour = Behaviour.RUN_WHILE_ON

var signal_on: bool = false


func _ready() -> void:
	add_to_group(&"mechanism")
	if source != null:
		source.active_changed.connect(set_signal)
		set_signal(source.is_active)


## The shared material pass (D-07b). Hooked on NOTIFICATION_READY, which reaches this base class even when a subclass
## overrides _ready without calling super.
func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		MechanismLook.apply(self)


## Applies the signal. Does nothing when it did not change; otherwise calls _on_signal and announces the fact.
func set_signal(on: bool) -> void:
	if on == signal_on:
		return
	signal_on = on
	_on_signal(on)
	EventBus.mechanism_changed.emit(self, on)


## Virtual: react to a signal change.
func _on_signal(_on: bool) -> void:
	pass


## Virtual: back to the load state.
func reset() -> void:
	signal_on = false
