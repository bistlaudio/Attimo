extends State
## Jump: timer-driven, no physics (D-09). Emits the jumped fact on enter, hands over to Fall after JUMP_TIME.

## Equals the Jump_Start clip length in seconds.
const JUMP_TIME: float = 0.6

var _timer: float = 0.0


func enter(_previous: StringName) -> void:
	_timer = 0.0
	EventBus.jumped.emit(actor.global_position)


func physics_update(delta: float) -> StringName:
	if Input.is_action_just_pressed(&"dash"):
		return &"Dash"
	actor.face(actor.input_direction(), delta)
	_timer += delta
	if _timer >= JUMP_TIME:
		return &"Fall"
	return &""
