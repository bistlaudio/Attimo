class_name SignalSource
extends Node3D
## Base of triggers and logic nodes: a boolean signal that mechanisms listen to (MECH-01). A mechanism connects to
## active_changed and never asks who the source is.

signal active_changed(active: bool)

var is_active: bool = false


func _ready() -> void:
	add_to_group(&"mechanism")


## Sets the signal. Emits active_changed only when the value changed.
func set_active(value: bool) -> void:
	if value == is_active:
		return
	is_active = value
	active_changed.emit(value)


## Virtual: back to the load state (inactive). Called by the reset sweep.
func reset() -> void:
	set_active(false)
