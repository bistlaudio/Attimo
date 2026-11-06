extends AirState
## Jump: launches with the speed of config.jump_height_for_stage(stage) and emits the jumped fact on enter.
## The stage comes from the ground chain (D-05): Jump 1, Jump 2 and Jump 3, the salto. The salto is physics
## only (the highest ground jump); its flip animation is Phase 3 (MOVE-09).
## A released button cuts the rise (variable height); hands over to Fall at the apex.
## Gravity and the heavier fall come from the controller.


func enter(_previous: StringName) -> void:
	actor.consume_jump()
	# Jump 2 and Jump 3 only raise the maximum height; the release cut below still applies (D-04).
	var stage: int = actor.advance_chain_for_ground_jump()
	var height: float = actor.config.jump_height_for_stage(stage)
	actor.vertical_speed = actor.config.jump_speed(height)
	# A buffered press that was released before this tick gives the tap height at every tick rate.
	apply_jump_cut()
	EventBus.jumped.emit(actor.global_position)


func _air_update(_delta: float) -> StringName:
	apply_jump_cut()
	if actor.vertical_speed <= 0.0:
		return &"Fall"
	return &""
