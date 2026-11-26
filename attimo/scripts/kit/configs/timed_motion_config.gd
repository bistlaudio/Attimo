class_name TimedMotionConfig
extends Resource
## Config of the Timed motion block (Phase 05.1, KIT-01, D-07, D-09, D-11): one profile enum plus one timing enum instead of flags.
## SWEEP is the clock-hand platform (a hand pivoted at one end that sweeps back and forth about the block's local X axis), TILT the
## tilting platform (a square plate pivoted in its centre that rocks about local X), HINGE the drawbridge (a deck hinged at one end that
## folds from raised to flat while its receiver is on, plan 05.1-17). Later plans append GATE, PATH, LOOP, EXTEND, SWING and STAMP. ALWAYS_ON runs from _ready with no receiver (D-07); SWITCHED runs only while a child Receiver is on
## (plan 05.1-14). The values are the tuned ones of the old rotating platform, folded unchanged (D-09). Presets live in
## resources/kit/timed_motion/. Divisor fields have a strictly positive minimum (T-05.1-13). A loaded preset is never written at
## runtime: the block duplicates it in _ready (D-12).

enum Profile { SWEEP, TILT, HINGE }
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

@export_group("Deck")
## SWEEP and HINGE: length in m from the pivot (along local +Z); longer hands dip further, so the station pivot must stand higher.
@export_range(1.0, 16.0, 0.5) var hand_length: float = 8.0
## SWEEP and HINGE: width in m.
@export_range(0.5, 8.0, 0.5) var hand_width: float = 2.5
## TILT: edge length in m of the square plate.
@export_range(1.0, 16.0, 0.5) var plate_size: float = 8.0
## Deck thickness in m (the top face passes through the pivot).
@export_range(0.1, 2.0, 0.05) var plate_thickness: float = 0.5
