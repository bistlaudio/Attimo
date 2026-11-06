class_name AirState
extends State
## Shared base of the airborne states (Jump, Fall, LongJump). physics_update applies air control and
## facing (D-02), takes a dash press, lands into Run, Idle or a buffered Jump, and decides a jump press in the
## air. Subclasses add their rules in _air_update.
##
## Jump decision rules (D-09; there is no air jump, MOVE-05), in order:
##   1. grounded, or airborne with coyote time left: ground jump (Jump)
##   2. otherwise the press stays in the jump buffer: landing inside the buffer window fires it as a ground
##      jump on the landing tick (no ground deceleration tick), later it expires with the buffer


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


## The state a remembered jump press leads to while airborne: Jump while coyote time is left, otherwise &""
## (the press stays buffered and either fires on the landing tick or expires).
func _airborne_jump_decision() -> StringName:
	if actor.wants_jump() and actor.can_coyote_jump():
		return &"Jump"
	return &""
