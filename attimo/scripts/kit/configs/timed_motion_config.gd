class_name TimedMotionConfig
extends Resource
## Config of the Timed motion block (Phase 05.1, KIT-01, D-07, D-09, D-11): one profile enum plus one timing enum instead of flags.
## SWEEP is the clock-hand platform (a hand pivoted at one end that sweeps back and forth about the block's local X axis), TILT the
## tilting platform (a square plate pivoted in its centre that rocks about local X), HINGE the drawbridge (a deck hinged at one end that
## folds from raised to flat while its receiver is on, plan 05.1-17), PATH (plan 05.1-19) moves level decks along a polyline in the block's local space:
## it loops when the first and last point are equal (the paternoster) and ping-pongs with a pause at each end otherwise (the rail cart); STEPS (plan
## 05.1-19) are decks that extend from and retract into a wall along local Z in a phase-shifted sine (the piston steps). Later plans append GATE, LOOP, SWING and STAMP. ALWAYS_ON runs from _ready with no receiver (D-07); SWITCHED runs only while a child Receiver is on
## (plan 05.1-14). The values are the tuned ones of the old rotating platform, folded unchanged (D-09). Presets live in
## resources/kit/timed_motion/. Divisor fields have a strictly positive minimum (T-05.1-13). A loaded preset is never written at
## runtime: the block duplicates it in _ready (D-12).

enum Profile { SWEEP, TILT, HINGE, PATH, STEPS }
enum Timing { ALWAYS_ON, SWITCHED }

## SWEEP swings a hand pivoted at one end; TILT rocks a plate pivoted in its centre; HINGE folds a deck hinged at one end down and up.
@export var profile: Profile = Profile.SWEEP
## ALWAYS_ON runs from the start; SWITCHED runs while the child Receiver is on (eased start and stop).
@export var timing: Timing = Timing.ALWAYS_ON

@export_group("Motion")
## Peak angular speed in rad/s; raise it for a faster swing (the deck tip moves at reach * angular_speed).
@export_range(0.1, 6.0, 0.1) var angular_speed: float = 1.0
## Seconds a start or stop takes; raise it for a softer start.
@export_range(0.05, 2.0, 0.05) var ramp_time: float = 0.3
## SWEEP: the hand swings within +- this angle in degrees (always clamped 10 degrees below the player's floor angle).
@export_range(5.0, 80.0, 1.0) var sweep_limit_deg: float = 35.0
## TILT: the plate rocks within +- this angle in degrees (same clamp).
@export_range(5.0, 80.0, 1.0) var tilt_limit_deg: float = 30.0
## HINGE: the deck stands this many degrees up when raised and lies flat (0) when lowered. Not clamped by the floor angle.
@export_range(5.0, 120.0, 1.0) var hinge_angle_deg: float = 90.0
## HINGE: seconds the deck takes to fold from raised to flat and back (eased). Raise it for a slower bridge.
@export_range(0.2, 5.0, 0.05) var hinge_time: float = 1.2

@export_group("Path")
## PATH: the route in the block's local space (the deck top centre). First point equal to the last: a closed loop; otherwise back and forth.
@export var path_points: PackedVector3Array = PackedVector3Array()
## PATH: travel speed in m/s along the route.
@export_range(0.1, 12.0, 0.1) var path_speed: float = 1.5
## PATH ping-pong: seconds the deck waits at each end point (0 for none).
@export_range(0.0, 10.0, 0.1) var path_pause: float = 0.8
## PATH: how many decks ride the route, spread evenly over a loop (use 1 for a ping-pong).
@export_range(1, 8, 1) var path_deck_count: int = 1

@export_group("Steps")
## STEPS: how many step decks stand in a row along local +X.
@export_range(1, 8, 1) var step_count: int = 4
## STEPS: how far in m a step reaches out of the wall (along local +Z) at full extension.
@export_range(0.1, 6.0, 0.1) var step_extend: float = 2.0
## STEPS: seconds one extend and retract cycle takes.
@export_range(0.2, 20.0, 0.1) var step_period: float = 3.0
## STEPS: seconds a step is behind its western neighbour in the cycle (a rhythm that climbs).
@export_range(0.0, 10.0, 0.05) var step_phase: float = 0.75
## STEPS: distance in m between two steps along local X.
@export_range(0.5, 8.0, 0.1) var step_pitch: float = 3.0
## STEPS: height in m each step stands above its western neighbour.
@export_range(0.0, 3.0, 0.1) var step_rise: float = 1.0

@export_group("Deck")
## SWEEP and HINGE: length in m from the pivot (along local +Z); longer hands dip further, so the station pivot must stand higher.
@export_range(1.0, 16.0, 0.5) var hand_length: float = 8.0
## SWEEP and HINGE: width in m.
@export_range(0.5, 8.0, 0.5) var hand_width: float = 2.5
## TILT, PATH and STEPS: edge length in m of the square plate (the cabin, the cart deck or the step plate).
@export_range(1.0, 16.0, 0.5) var plate_size: float = 8.0
## Deck thickness in m (the top face passes through the pivot).
@export_range(0.1, 2.0, 0.05) var plate_thickness: float = 0.5
