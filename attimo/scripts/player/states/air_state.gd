class_name AirState
extends State
## Shared base of the airborne states (Jump, Fall, later DoubleJump and LongJump). physics_update
## applies air control and facing (D-02), takes a dash press, lands into Run, Idle or a buffered Jump,
## and decides a jump press in the air. Subclasses add their rules in _air_update.
##
## Jump decision rules (D-08 / D-09), in order:
##   1. grounded, or airborne with coyote time left: ground jump (Jump)
##   2. airborne, falling and about to land within the buffer window: keep the press, the jump fires
##      as a ground jump on the landing tick with no ground deceleration tick
##   3. otherwise, with the air jump unspent: the double jump
##   4. otherwise the press expires with the buffer


func physics_update(delta: float) -> StringName:
	var direction: Vector3 = actor.input_direction()
	actor.face(direction, delta)
	actor.accelerate_air(direction, delta)
	if Input.is_action_just_pressed(&"dash") and actor.can_dash():
		return &"Dash"
	if actor.is_grounded() and actor.vertical_speed <= 0.0:
		if actor.wants_jump():
			return &"Jump"
		if direction != Vector3.ZERO:
			return &"Run"
		return &"Idle"
	var jump_state: StringName = _airborne_jump_decision()
	if jump_state != &"":
		return jump_state
	return _air_update(delta)


## Override in subclasses. Return a state name to transition, or &"" to stay.
func _air_update(_delta: float) -> StringName:
	return &""


## Variable jump height (D-04): a released button cuts the rise down to the tap speed.
## Every rising state calls this, so chain stages and long jumps only change the maximum.
func apply_jump_cut() -> void:
	if Input.is_action_pressed(&"jump"):
		return
	var cut: float = actor.config.cut_speed()
	if actor.vertical_speed > cut:
		actor.vertical_speed = cut


## The state a remembered jump press leads to while airborne, or &"" to keep it buffered or let it expire.
func _airborne_jump_decision() -> StringName:
	if not actor.wants_jump():
		return &""
	if actor.can_coyote_jump():
		return &"Jump"
	if actor.vertical_speed <= 0.0 and actor.will_land_within(actor.config.jump_buffer_time):
		return &""
	if actor.air_jump_available:
		return &"DoubleJump"
	return &""
