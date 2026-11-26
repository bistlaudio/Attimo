class_name TriggerConfig
extends Resource
## Config of the Trigger block (Phase 05.1, KIT-01, D-13, D-21, D-47): one profile enum. CHARGE_GATE is a check volume that is active
## while the player stands inside with at least `threshold` steps; it never spends them. Plan 05.1-18 appends ENERGY_CORE. Presets live
## in resources/kit/trigger/. A loaded preset is never written at runtime: the block duplicates it in _ready (D-12).

enum Profile { CHARGE_GATE }

## Which trigger: CHARGE_GATE checks the steps of a player standing in its volume.
@export var profile: Profile = Profile.CHARGE_GATE
## CHARGE_GATE: steps the clock must show for the gate to switch (start value 6, F2). Raise it for a harder gate; the turquoise marks follow.
@export_range(1, 12, 1) var threshold: int = 6
## CHARGE_GATE: size in m of the check volume (an archway: x wide, y high, z deep), standing on the floor at the node.
@export var size: Vector3 = Vector3(4.0, 4.0, 2.5)
