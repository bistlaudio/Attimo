class_name MannequinAnimator
extends Node
## Presents FSM state on the Mannequin: maps the LOCAL StateMachine.state_changed signal to AnimationTree
## travel and the Locomotion blend. Animation shows state; it is not feedback in the D-10 sense.

@export var state_machine: StateMachine
@export var animation_tree: AnimationTree

const STATE_TO_ANIM: Dictionary[StringName, StringName] = {
	&"Idle": &"Locomotion",
	&"Run": &"Locomotion",
	&"Sprint": &"Locomotion",
	&"Jump": &"Jump",
	&"DoubleJump": &"Jump",
	&"LongJump": &"Jump",
	&"Fall": &"Fall",
	&"Dash": &"Dash",
}

## States that count as airborne for the landing check (Landing into Idle plays Land).
const AIRBORNE_STATES: Array[StringName] = [&"Jump", &"Fall", &"DoubleJump", &"LongJump"]
## States that blend Locomotion to its run end (blend_position 1.0).
const RUNNING_STATES: Array[StringName] = [&"Run", &"Sprint"]

var _playback: AnimationNodeStateMachinePlayback


func _ready() -> void:
	_playback = animation_tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
	state_machine.state_changed.connect(_on_state_changed)


func _on_state_changed(from_state: StringName, to_state: StringName) -> void:
	animation_tree.set(&"parameters/Locomotion/blend_position", 1.0 if RUNNING_STATES.has(to_state) else 0.0)
	if to_state == &"Idle" and AIRBORNE_STATES.has(from_state):
		# Landing into Idle plays Land, which auto-advances to Locomotion. Landing into Run goes straight to Locomotion.
		_playback.travel(&"Land")
		return
	_playback.travel(STATE_TO_ANIM.get(to_state, &"Locomotion"))
