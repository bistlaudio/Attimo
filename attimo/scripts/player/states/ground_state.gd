class_name GroundState
extends State
## Shared base of the grounded states (Idle, Run, later Sprint). physics_update runs the common
## transitions first (left the floor, dash, jump or the long jump inside the dash grace), then the subclass hook _ground_update.


func physics_update(delta: float) -> StringName:
	if not actor.is_grounded():
		return &"Fall"
	if Input.is_action_just_pressed(&"dash") and actor.can_dash():
		return &"Dash"
	if actor.wants_jump():
		# Just after a ground dash a jump is still the long jump (D-06).
		if actor.dash_jump_grace_timer > 0.0:
			return &"LongJump"
		return &"Jump"
	return _ground_update(delta)


## Override in subclasses. Return a state name to transition, or &"" to stay.
func _ground_update(_delta: float) -> StringName:
	return &""
