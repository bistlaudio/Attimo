class_name SignalSource
extends Node3D
## Base of triggers and logic nodes: a boolean signal that mechanisms listen to (MECH-01). A mechanism connects to
## active_changed and never asks who the source is.

signal active_changed(active: bool)

## Per-instance option: a plain SignalSource that is on from the start and after every reset (an always-on driver, e.g. a pendulum).
@export var start_active: bool = false

var is_active: bool = false


func _ready() -> void:
	add_to_group(&"mechanism")
	if start_active:
		set_active(true)


## The shared material pass (D-07b). Hooked on NOTIFICATION_READY, which reaches this base class even when a subclass
## overrides _ready without calling super.
func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		MechanismLook.apply(self)


## Sets the signal. Emits active_changed only when the value changed.
func set_active(value: bool) -> void:
	if value == is_active:
		return
	is_active = value
	active_changed.emit(value)


## Virtual: back to the load state (start_active, off by default). Called by the reset sweep.
func reset() -> void:
	set_active(start_active)
