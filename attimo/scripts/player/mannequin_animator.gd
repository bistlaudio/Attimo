class_name MannequinAnimator
extends Node
## Presents FSM state on the Mannequin: maps the LOCAL StateMachine.state_changed signal to AnimationTree
## travel and the Locomotion blend. Animation shows state; it is not feedback in the D-10 sense.

@export var state_machine: StateMachine
@export var animation_tree: AnimationTree

const STATE_TO_ANIM: Dictionary[StringName, StringName] = {
	&"Idle": &"Locomotion",
	&"Run": &"Locomotion",
	&"Jump": &"Jump",
	&"Fall": &"Fall",
	&"Dash": &"Dash",
}

var _playback: AnimationNodeStateMachinePlayback


func _ready() -> void:
	_playback = animation_tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
	state_machine.state_changed.connect(_on_state_changed)


func _on_state_changed(from_state: StringName, to_state: StringName) -> void:
	animation_tree.set(&"parameters/Locomotion/blend_position", 1.0 if to_state == &"Run" else 0.0)
	var airborne: bool = from_state == &"Jump" or from_state == &"Fall"
	if to_state == &"Idle" and airborne:
		# Landing into Idle plays Land, which auto-advances to Locomotion. Landing into Run goes straight to Locomotion.
		_playback.travel(&"Land")
		return
	_playback.travel(STATE_TO_ANIM.get(to_state, &"Locomotion"))
