extends AirState
## Jump: launches with the speed of config.jump_height and emits the jumped fact on enter.
## Hands over to Fall at the apex. Gravity and the heavier fall come from the controller.


func enter(_previous: StringName) -> void:
	actor.vertical_speed = actor.config.jump_speed(actor.config.jump_height)
	EventBus.jumped.emit(actor.global_position)


func _air_update(_delta: float) -> StringName:
	if actor.vertical_speed <= 0.0:
		return &"Fall"
	return &""
