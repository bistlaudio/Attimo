class_name GroundState
extends State
## Shared base of the grounded states (Idle, Run, later Sprint). physics_update runs the common
## transitions first (left the floor, dash, jump), then the subclass hook _ground_update.


func physics_update(delta: float) -> StringName:
	if not actor.is_grounded():
		return &"Fall"
	if Input.is_action_just_pressed(&"dash"):
		return &"Dash"
	if actor.wants_jump():
		return &"Jump"
	return _ground_update(delta)


## Override in subclasses. Return a state name to transition, or &"" to stay.
func _ground_update(_delta: float) -> StringName:
	return &""
