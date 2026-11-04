extends State
## Idle: waits for input. Phase 1 only reacts to the jump action.


func physics_update(_delta: float) -> StringName:
	if Input.is_action_just_pressed(&"jump"):
		return &"Jump"
	return &""
