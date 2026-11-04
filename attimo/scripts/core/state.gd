class_name State
extends Node
## Base class for node-based states. Return a state name from physics_update() to request a transition.

var actor: PlayerController


func enter(_previous: StringName) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> StringName:
	return &""
