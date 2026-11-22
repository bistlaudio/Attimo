class_name Targeting
extends Node
## Aim assist of the hand (CAM-05, D-14). Stub: the selection arrives with plan 04-02 task 2.

enum State { NONE, VALID, VALID_BIG, INVALID }

signal target_changed(target: Interactable)

var target: Interactable = null
## A Targeting.State value (typed int: the global class State shadows the enum name in type positions).
var state: int = State.NONE
var target_angle_deg: float = 0.0


func update(_delta: float) -> void:
	pass
