class_name CatchLaunchConfig
extends Resource
## Config of the Catch & launch block (Phase 05.1, KIT-03, D-11): one profile enum instead of flags. FREE_AIM is the slingshot cage
## (the hold is the Loader's own: slow factor, cap, min push and control lock come from MovementConfig, never copied here). FIXED is
## the steam cannon (fixed direction and speed, short hold, no slow motion, no input; plan 05.1-02). Presets live in
## resources/kit/catch_launch/. Every divisor or timer field has a strictly positive minimum (T-02-02). A loaded preset is never
## written at runtime: the block duplicates it in _ready (D-12).

enum Profile { FREE_AIM, FIXED }

@export_group("Catch")
## FREE_AIM throws along the view like the Loader; FIXED throws along the barrel at fixed_speed.
@export var profile: Profile = Profile.FREE_AIM
## Catch radius in m: Rino is caught only when his chest point is this close to the core centre (D-54); raise it for a roomier cage.
## The trigger sphere is catch_radius + 0.5 (the capsule radius) so the overlap never misses the chest point.
@export_range(0.3, 6.0, 0.1) var catch_radius: float = 0.6
## Seconds after a throw before the block catches again (it also waits until the player has left the radius); raise it to stop
## quick re-catches.
@export_range(0.1, 5.0, 0.1) var rearm_time: float = 1.0

@export_group("Fixed")
## FIXED: seconds Rino is held in the barrel before the throw; raise it for a longer wind-up.
@export_range(0.05, 1.0, 0.01) var fixed_hold: float = 0.2
## FIXED: the throw speed in m/s; raise it for a longer, higher arc.
@export_range(1.0, 40.0, 0.5) var fixed_speed: float = 14.0
## FIXED: barrel pitch above the horizontal in degrees (the block's yaw gives the heading); raise it for a steeper, shorter arc.
@export_range(0.0, 89.0, 1.0) var fixed_pitch_deg: float = 45.0
## FIXED: distance in m from the block origin along the barrel to the mouth, where Rino is held and launched from.
@export_range(0.0, 4.0, 0.1) var muzzle_offset: float = 1.2

@export_group("Income")
## Steps given to the arm on a catch (D-43); 0 turns the income off.
@export_range(0, 3, 1) var income_steps: int = 1
## Real seconds before this element gives a step again; raise it to stop farming.
@export_range(0.5, 30.0, 0.5) var income_cooldown: float = 3.0
