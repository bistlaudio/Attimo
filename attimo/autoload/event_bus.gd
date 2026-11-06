extends Node
## Gameplay FACTS only. No state, no logic.
## Gameplay code emits; juice, audio and debug tooling connect (D-10, D-11).

signal jumped(position: Vector3)
signal landed(position: Vector3, impact_speed: float)
signal dash_started(position: Vector3, direction: Vector3, in_air: bool)
signal movement_state_changed(from_state: StringName, to_state: StringName)
## Emitted by the LongJump state on enter. `stage` is the long-jump stage: 1 first dash hop, 2, 3 top of the stack.
signal long_jumped(position: Vector3, stage: int)
## Emitted by PlayerController when the ground-jump chain stage changes: 1..3 for Jump 1, 2, 3 (salto), 0 on reset.
signal chain_stage_changed(stage: int)
