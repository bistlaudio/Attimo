extends AirState
## Jump: launches with the speed of config.jump_height and emits the jumped fact on enter.
## A released button cuts the rise (variable height); hands over to Fall at the apex.
## Gravity and the heavier fall come from the controller.


func enter(_previous: StringName) -> void:
	actor.consume_jump()
	actor.vertical_speed = actor.config.jump_speed(actor.config.jump_height)
	# A buffered press that was released before this tick gives the tap height at every tick rate.
	apply_jump_cut()
	EventBus.jumped.emit(actor.global_position)


func _air_update(_delta: float) -> StringName:
	apply_jump_cut()
	if actor.vertical_speed <= 0.0:
		return &"Fall"
	return &""
