class_name ForceVolumeConfig
extends Resource
## Config of the Force volume block (Phase 05.1, KIT-01, D-10, D-11): a box volume that acts on the player through PlayerController request
## APIs only. Two enums instead of flags: Profile says what the volume does (DIRECTIONAL pushes or launches along `direction`, DRAG slows the
## run; RADIAL and GRAVITY are appended by later plans), Timing says when (CONTINUOUS is always on, PULSED cycles off / on). Presets live in
## resources/kit/force_volume/. Timers and divisors have strictly positive minimums (T-05.1-45). A loaded preset is never written at
## runtime: the block duplicates it in _ready (D-12).

enum Profile { DIRECTIONAL, DRAG }
enum Timing { CONTINUOUS, PULSED }

@export_group("Shape")
## What the volume does: DIRECTIONAL pushes along `direction`, DRAG slows the run to `move_scale`.
@export var profile: Profile = Profile.DIRECTIONAL
## Always on, or a rhythm of `pulse_off` seconds off and `pulse_on` seconds on (the cycle starts off).
@export var timing: Timing = Timing.CONTINUOUS
## Volume size in m: x and z centred on the block, y from the block origin up (each axis is held at 0.5 m or more).
@export var size: Vector3 = Vector3(3.0, 4.0, 3.0)
## Push direction in the block's local space (it turns with the node); normalized at use. Up for a column, -Z for a stream.
@export var direction: Vector3 = Vector3.UP

@export_group("Push")
## DIRECTIONAL: target speed in m/s along the direction; raise it for a stronger lift or wind. It must beat the state's own restoring
## rate to be felt: the run restores at ground_accel (70), so a gust against the route needs an accel above that.
@export_range(0.0, 40.0, 0.1) var strength: float = 6.0
## DIRECTIONAL: acceleration toward the target speed in m/s2; an updraft must beat the rise gravity (34) to lift.
@export_range(1.0, 200.0, 1.0) var accel: float = 60.0
## PULSED: seconds the volume acts per cycle.
@export_range(0.1, 10.0, 0.05) var pulse_on: float = 1.0
## PULSED: seconds the volume rests per cycle (a geyser charges during it).
@export_range(0.1, 10.0, 0.05) var pulse_off: float = 1.0
## PULSED burst: the launch speed in m/s along the direction, once per pulse and player (0 = push only).
@export_range(0.0, 40.0, 0.5) var launch_speed: float = 0.0

@export_group("Drag")
## DRAG: share of the run speed and acceleration that is left inside the volume (0.2 .. 1.0).
@export_range(0.2, 1.0, 0.01) var move_scale: float = 0.5

@export_group("Income")
## Steps given to the arm per use (D-43): on entering a CONTINUOUS volume or on a PULSED burst that launches; 0 turns it off.
@export_range(0, 3, 1) var income_steps: int = 0
## Real seconds before this block gives a step again; raise it to stop farming.
@export_range(0.5, 30.0, 0.5) var income_cooldown: float = 3.0
