class_name Mechanism
extends Node3D
## Base of signal-driven mechanisms. Stub, filled in Task 3.

enum Behaviour { RUN_WHILE_ON, REVERSE_ON_SIGNAL }

@export var source: SignalSource
@export var behaviour: Behaviour = Behaviour.RUN_WHILE_ON

var signal_on: bool = false


func set_signal(_on: bool) -> void:
	pass


func reset() -> void:
	pass
