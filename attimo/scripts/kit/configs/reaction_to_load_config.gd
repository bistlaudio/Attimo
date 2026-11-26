class_name ReactionToLoadConfig
extends Resource
## Config of the Reaction to load block (Phase 05.1, KIT-01, KIT-02, D-11, D-53): how an object answers a Loader that flies into it.
## LOADER_FIELD is the turquoise Loader field: it never breaks, lets a Loader straight flight with at least min_steps paid steps glide
## through (once, with a brake and a ripple) and softly pushes everything else back. Later plans append the nature profiles. Presets
## live in resources/kit/reaction_to_load/. Timers and divisor-like fields have a strictly positive minimum (T-05.1-39). A loaded preset
## is never written at runtime: the block duplicates it in _ready (D-12).

enum Profile { LOADER_FIELD }

## Which reaction this is; the numbers below carry the behaviour.
@export var profile: Profile = Profile.LOADER_FIELD
@export_group("Field")
## Paid Loader steps a straight flight needs to pass; raise it so only a fuller Loader gets through.
@export_range(1, 3, 1) var min_steps: int = 2
## Share of the speed lost once on a pass (0.30 = 30 %); raise it for a harder brake.
@export_range(0.05, 0.9, 0.01) var brake: float = 0.30
## Speed in m/s of the soft push back for everything that does not pass; raise it for a firmer bounce.
@export_range(0.5, 20.0, 0.5) var push_back_speed: float = 4.0
## Real seconds the ripple cue shows after a pass.
@export_range(0.05, 2.0, 0.05) var ripple_time: float = 0.3
## Size of the field in m (width, height, thickness); the block origin is the middle of the foot.
@export var field_size: Vector3 = Vector3(6.0, 4.0, 0.5)
