class_name PlayerController
extends CharacterBody3D
## Phase 1 scaffold. The body NEVER moves in Phase 1 (D-09, Option A): no velocity, no gravity,
## no floor checks. States are timer-driven and only emit facts on the EventBus.
## Phase 2 adds velocity, gravity and the single kinematic move call in _physics_process here.

@onready var visual_root: Node3D = $VisualRoot
@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	state_machine.setup(self)


func _physics_process(delta: float) -> void:
	state_machine.physics_update(delta)
