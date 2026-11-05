extends AirState
## DoubleJump: the one air jump of an airtime (D-07, D-08). Sets the rise to the speed of
## config.double_jump_height (set, not added; A19), keeps the horizontal momentum, and obeys the release
## cut like every jump (D-04). Emits the double_jumped fact on enter. Landing refills the air jump.


func enter(_previous: StringName) -> void:
	actor.consume_jump()
	actor.air_jump_available = false
	actor.vertical_speed = actor.config.jump_speed(actor.config.double_jump_height)
	apply_jump_cut()
	EventBus.double_jumped.emit(actor.global_position)


func _air_update(_delta: float) -> StringName:
	apply_jump_cut()
	if actor.vertical_speed <= 0.0:
		return &"Fall"
	return &""
