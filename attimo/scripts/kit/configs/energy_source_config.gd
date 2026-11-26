class_name EnergySourceConfig
extends Resource
## Config of the Energy source block (Phase 05.1, KIT-01, D-10, D-11, D-42): how many whole steps the source holds, how fast the
## Extractor drains it and when it refills. Presets live in resources/kit/energy_source/: the capsule (3 steps, quick) and the broken
## machine (5 steps, about 2 s). Timers have strictly positive minimums (T-05.1-29). A loaded preset is never written at runtime: the
## block duplicates it in _ready (D-12).

enum Profile { CAPSULE, MACHINE }

## Which source this is; the capsule is small and quick, the machine large and slow. The numbers below carry the behaviour.
@export var profile: Profile = Profile.CAPSULE
## Whole steps the source holds when full.
@export_range(1, 12, 1) var amount: int = 3
## Seconds between two steps while the Extractor drains it.
@export_range(0.05, 2.0, 0.05) var step_interval: float = 0.15
## Seconds after the last step until it refills; 0 never refills (D-08).
@export_range(0.0, 120.0, 0.5) var respawn_time: float = 0.0
