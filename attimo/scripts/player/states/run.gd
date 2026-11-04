extends State
## Run: Running_A plays in place (Locomotion blend 1.0 by the animator). Only facing changes (D-09).


func physics_update(delta: float) -> StringName:
	var direction: Vector3 = actor.input_direction()
	actor.face(direction, delta)
	if Input.is_action_just_pressed(&"dash"):
		return &"Dash"
	if Input.is_action_just_pressed(&"jump"):
		return &"Jump"
	if direction == Vector3.ZERO:
		return &"Idle"
	return &""
