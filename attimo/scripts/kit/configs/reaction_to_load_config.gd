class_name ReactionToLoadConfig
extends Resource
## Config of the Reaction to load block (Phase 05.1, KIT-01, KIT-02, D-11, D-53): how an object answers a Loader that flies into it.
## LOADER_FIELD is the turquoise Loader field: it never breaks, lets a Loader straight flight with at least min_steps paid steps glide
## through (once, with a brake and a ripple) and softly pushes everything else back. The nature profiles (plan 05.1-21, D-11, D-27) are
## appended: CRUMBLE (crumbling platform, collapse strip), SINK (sinking debris), TIP (tipping trunk), DROP (falling debris, proximity) and
## BITE (snap bloom, proximity). Nature never helps: no profile touches energy. Presets
## live in resources/kit/reaction_to_load/. Timers and divisor-like fields have a strictly positive minimum (T-05.1-39). A loaded preset
## is never written at runtime: the block duplicates it in _ready (D-12).

enum Profile { LOADER_FIELD, CRUMBLE, SINK, TIP, DROP, BITE }

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
@export_group("Deck")
## Size in m of a deck (CRUMBLE, SINK, TIP): width, thickness, length. A CRUMBLE strip puts `segments` of them in a row along -Z.
@export var deck_size: Vector3 = Vector3(4.0, 0.5, 4.0)
@export_group("Crumble")
## Seconds the deck shakes after the first step before it falls away (the old crumbling platform: 0.6).
@export_range(0.1, 3.0, 0.05) var delay: float = 0.6
## Seconds the deck falls (collision already off) before it is gone.
@export_range(0.1, 3.0, 0.05) var fall_time: float = 0.5
## Seconds a CRUMBLE deck or DROP debris stays gone (counted from gone / landed) before it respawns; CRUMBLE only once nobody stands in it.
@export_range(0.5, 10.0, 0.1) var respawn_time: float = 3.0
## Number of decks in the row (1 = a platform, 6 = the collapse strip).
@export_range(1, 12, 1) var segments: int = 1
## Strip only (segments above 1): seconds after a segment was first touched before its own delay starts.
@export_range(0.05, 2.0, 0.05) var segment_delay: float = 0.35
@export_group("Sink")
## How deep in m the deck sinks under a rider.
@export_range(0.1, 4.0, 0.1) var sink_depth: float = 1.2
## Sink speed in m/s while somebody stands on it.
@export_range(0.1, 3.0, 0.05) var sink_speed: float = 0.6
## Rise speed in m/s once the deck is empty.
@export_range(0.1, 3.0, 0.05) var rise_speed: float = 0.4
@export_group("Tip")
## How far the trunk tips in degrees; the block keeps it below the player's floor angle.
@export_range(1.0, 45.0, 0.5) var tip_angle_deg: float = 25.0
## Seconds the tip takes.
@export_range(0.1, 3.0, 0.05) var tip_time: float = 0.6
## Seconds the return takes once the trunk is empty.
@export_range(0.2, 6.0, 0.1) var return_time: float = 2.0
@export_group("Proximity")
## Radius in m of the sensor that wakes DROP and BITE.
@export_range(0.5, 10.0, 0.1) var trigger_radius: float = 3.0
## DROP: height in m the debris hangs and falls from.
@export_range(0.5, 20.0, 0.5) var drop_height: float = 6.0
## BITE: seconds from waking to the bite.
@export_range(0.1, 3.0, 0.05) var windup: float = 0.6
## BITE: seconds after a bite before the next windup may start.
@export_range(0.1, 6.0, 0.1) var cooldown: float = 1.5
