class_name ImpulseConfig
extends Resource
## Config of the Impulse block (Phase 05.1, KIT-01, D-10, D-11): a one-shot kick for the player through PlayerController request APIs
## only. One enum says which kick: BOOST (a ring in the air: speed along its axis, gives the air dash back, the air-dash counterpart),
## PAD (a plate on the floor: a short forward boost while grounded, the dash-hop counterpart) and BOUNCE (a raised pad that throws the
## player back up with the drop height). There is no refill flag: BOOST always refills the air dash, PAD and BOUNCE never. Presets live
## in resources/kit/impulse/. Timers have strictly positive minimums (T-05.1-48). A loaded preset is never written at runtime: the block
## duplicates it in _ready (D-12).

enum Profile { BOOST, PAD, BOUNCE }

@export_group("Shape")
## Which kick: BOOST along the axis, PAD forward on the ground, BOUNCE up from the pad top.
@export var profile: Profile = Profile.BOOST
## Size in m. BOOST: the trigger box centred on the block (x along the axis, so keep x at 1 m or more against tunnelling). PAD: the
## trigger box from the floor up, x and z centred. BOUNCE: the pad body (top face at size.y).
@export var size: Vector3 = Vector3(1.2, 3.0, 3.0)
## BOOST axis / PAD forward in the block's local space (turns with the node); normalized at use.
@export var direction: Vector3 = Vector3.RIGHT

@export_group("Kick")
## BOOST and PAD: the speed along the direction in m/s the kick lifts the player to (it never slows a faster one). BOUNCE: the lowest
## bounce speed (a hop onto the pad) in m/s.
@export_range(1.0, 40.0, 0.5) var speed: float = 20.0
## BOOST and PAD: m/s added to the speed along the direction before the floor above is applied.
@export_range(0.0, 20.0, 0.5) var add: float = 0.0
## Seconds after a kick before the block accepts the next one (one crossing counts once).
@export_range(0.05, 5.0, 0.05) var rearm_time: float = 0.3
## BOUNCE: share of the drop height that comes back (1.0 = back to the drop height).
@export_range(0.1, 2.0, 0.05) var restitution: float = 1.0
## BOUNCE: the highest bounce speed in m/s (the amplified speed is clamped to it too).
@export_range(1.0, 40.0, 0.5) var max_speed: float = 30.0

@export_group("Income")
## Steps given to the arm per use (D-43); 0 turns it off.
@export_range(0, 3, 1) var income_steps: int = 0
## Real seconds before this block gives a step again; raise it to stop farming.
@export_range(0.5, 30.0, 0.5) var income_cooldown: float = 3.0
