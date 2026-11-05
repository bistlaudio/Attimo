class_name AirState
extends State
## Shared base of the airborne states (Jump, Fall, later DoubleJump and LongJump). physics_update
## applies air control and facing (D-02), takes a dash press, and lands into Run or Idle once the
## floor is reached and the body is no longer rising. Subclasses add their rules in _air_update.


func physics_update(delta: float) -> StringName:
	var direction: Vector3 = actor.input_direction()
	actor.face(direction, delta)
	actor.accelerate_air(direction, delta)
	if Input.is_action_just_pressed(&"dash"):
		return &"Dash"
	if actor.is_grounded() and actor.vertical_speed <= 0.0:
		if direction != Vector3.ZERO:
			return &"Run"
		return &"Idle"
	return _air_update(delta)


## Override in subclasses. Return a state name to transition, or &"" to stay.
func _air_update(_delta: float) -> StringName:
	return &""
