extends State
## Idle: waits for input. Jump on the jump action, Run when a move direction is held.


func physics_update(_delta: float) -> StringName:
	if Input.is_action_just_pressed(&"jump"):
		return &"Jump"
	if actor.input_direction() != Vector3.ZERO:
		return &"Run"
	return &""
