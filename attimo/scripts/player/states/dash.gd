extends State
## Dash: Dodge_Forward plays in place, no speed and no displacement (D-09). Phase 2 adds dash speed,
## the air-dash limit and the cooldown (MOVE-06/07). Emits the dash_started fact once on enter.

## Equals the Dodge_Forward clip length in seconds (a D-09 demo timing).
const DASH_TIME: float = 0.4

var _timer: float = 0.0
var _in_air: bool = false


func enter(previous: StringName) -> void:
	_timer = 0.0
	var direction: Vector3 = actor.input_direction()
	if direction == Vector3.ZERO:
		direction = actor.visual_root.global_basis.z
		direction.y = 0.0
	direction = direction.normalized()
	# A dodge snaps its facing instead of turning toward it.
	actor.visual_root.rotation.y = atan2(direction.x, direction.z)
	# Airborne is a state fact in Phase 1: no floor check exists (D-09).
	_in_air = previous == &"Jump" or previous == &"Fall"
	EventBus.dash_started.emit(actor.global_position, direction, _in_air)


func physics_update(delta: float) -> StringName:
	_timer += delta
	if _timer >= DASH_TIME:
		if _in_air:
			# The airborne stretch finishes through Fall, which emits landed.
			return &"Fall"
		if actor.input_direction() != Vector3.ZERO:
			return &"Run"
		return &"Idle"
	return &""
