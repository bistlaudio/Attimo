extends State
## Jump: timer-driven, no physics (D-09). Emits the jumped fact on enter, returns to Idle after JUMP_TIME.
## Plan 01-03 hands the end of this state to a Fall state.

## Equals the Jump_Start clip length in seconds.
const JUMP_TIME: float = 0.6

var _timer: float = 0.0


func enter(_previous: StringName) -> void:
	_timer = 0.0
	EventBus.jumped.emit(actor.global_position)


func physics_update(delta: float) -> StringName:
	_timer += delta
	if _timer >= JUMP_TIME:
		return &"Idle"
	return &""
