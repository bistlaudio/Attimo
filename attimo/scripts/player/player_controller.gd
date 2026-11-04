class_name PlayerController
extends CharacterBody3D
## Phase 1 scaffold. The body NEVER moves in Phase 1 (D-09, Option A): no velocity, no gravity,
## no floor checks. States are timer-driven and only emit facts on the EventBus.
## Phase 2 adds velocity, gravity and the single kinematic move call in _physics_process here.

## Facing turn rate (per second) used by lerp_angle. Rotates VisualRoot only.
const TURN_SPEED: float = 14.0

@onready var visual_root: Node3D = $VisualRoot
@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	state_machine.setup(self)


func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)


## Movement input in world axes (Phase 1 has a static camera, A14): W = -Z, away from the camera.
## Phase 2 makes this camera-relative.
func input_direction() -> Vector3:
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	return Vector3(input.x, 0.0, input.y)


## Turns VisualRoot toward `direction` (the Mannequin faces +Z). Needs no velocity (D-09).
## Called from state physics_update so the rotation happens inside the physics tick (Pitfall 13).
func face(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(direction.x, direction.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_yaw, minf(TURN_SPEED * delta, 1.0))
