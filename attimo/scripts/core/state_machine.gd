class_name StateMachine
extends Node
## Node-based state machine. States are child nodes extending State.
## Emits a LOCAL state_changed signal (animator) and the global EventBus fact movement_state_changed.

signal state_changed(from_state: StringName, to_state: StringName)

@export var initial_state: StringName = &"Idle"

var current: State
var _states: Dictionary[StringName, State] = {}


func setup(actor: PlayerController) -> void:
	for child: Node in get_children():
		var state := child as State
		if state == null:
			continue
		state.actor = actor
		_states[state.name] = state
	assert(_states.has(initial_state), "initial_state missing: %s" % initial_state)
	current = _states[initial_state]
	current.enter(&"")
	state_changed.emit(&"", current.name)
	EventBus.movement_state_changed.emit(&"", current.name)


func physics_update(delta: float) -> void:
	var next: StringName = current.physics_update(delta)
	if next != &"" and next != current.name:
		transition_to(next)


func transition_to(next: StringName) -> void:
	assert(_states.has(next), "unknown state: %s" % next)
	var previous: StringName = current.name
	current.exit()
	current = _states[next]
	current.enter(previous)
	state_changed.emit(previous, next)
	EventBus.movement_state_changed.emit(previous, next)
