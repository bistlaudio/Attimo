extends State
## Fall: timer-driven, no physics (D-09). When FALL_TIME has passed the landing phase (Jump_Land) is reached:
## emit the landed fact exactly once, then go to Run (input held) or Idle. Phase 2 replaces the timer with floor contact.

## Short Jump_Idle hold in seconds, a D-09 demo timing.
const FALL_TIME: float = 0.3

var _timer: float = 0.0


func enter(_previous: StringName) -> void:
	_timer = 0.0


func physics_update(delta: float) -> StringName:
	if Input.is_action_just_pressed(&"dash"):
		return &"Dash"
	var direction: Vector3 = actor.input_direction()
	actor.face(direction, delta)
	_timer += delta
	if _timer >= FALL_TIME:
		# impact_speed is 0.0: Phase 1 has no vertical motion. The signal shape is final; Phase 2 supplies the value.
		EventBus.landed.emit(actor.global_position, 0.0)
		if direction != Vector3.ZERO:
			return &"Run"
		return &"Idle"
	return &""
