class_name MovementConfig
extends Resource
## The one tunable movement resource (MOVE-10, D-23). Every movement number lives here.
## Gravity and all jump speeds are derived from design numbers, so editing a height never
## changes the fall feel. Every divisor field has a strictly positive minimum (T-02-02).

@export_group("Ground")
## The one run speed in m/s (there is no separate fast run; extra speed comes from the dash).
@export_range(1.0, 20.0, 0.1) var run_speed: float = 8.5
## Ground acceleration toward run speed in m/s^2.
@export_range(5.0, 200.0, 1.0) var ground_accel: float = 70.0
## Braking when input is released in m/s^2.
@export_range(5.0, 200.0, 1.0) var ground_decel: float = 55.0
## Braking when input opposes the current velocity in m/s^2 (the skid).
@export_range(5.0, 300.0, 1.0) var turn_decel: float = 90.0
## Facing turn rate in 1/s (VisualRoot yaw lerp).
@export_range(1.0, 40.0, 0.5) var turn_rate: float = 14.0

@export_group("Air")
## Air acceleration toward the air speed cap in m/s^2 (D-02: near-full air control).
@export_range(5.0, 200.0, 1.0) var air_accel: float = 35.0
## Air braking without input in m/s^2 (0 keeps momentum).
@export_range(0.0, 200.0, 1.0) var air_decel: float = 0.0

@export_group("Jump")
## Height of the reference jump in m. With reference_apex_time it defines gravity.
@export_range(0.5, 6.0, 0.05) var reference_jump_height: float = 2.5
## Seconds to the apex of the reference jump.
@export_range(0.15, 1.0, 0.01) var reference_apex_time: float = 0.42
## Full-hold height of the first ground jump in m.
@export_range(0.5, 6.0, 0.05) var jump_height: float = 2.0
## Full-hold height of a chained second ground jump in m.
@export_range(0.5, 6.0, 0.05) var chain_jump_height: float = 2.6
## Tap height in m (release cuts the rise to this height).
@export_range(0.1, 3.0, 0.05) var jump_min_height: float = 0.8
## Full-hold height of the double jump in m.
@export_range(0.5, 6.0, 0.05) var double_jump_height: float = 2.0
## Gravity multiplier while falling (D-04).
@export_range(1.0, 3.0, 0.05) var fall_multiplier: float = 1.7
## Maximum fall speed in m/s.
@export_range(5.0, 80.0, 1.0) var terminal_speed: float = 40.0
## Seconds after leaving a ledge in which a ground jump is still allowed.
@export_range(0.0, 0.3, 0.01) var coyote_time: float = 0.1
## Seconds a jump press is remembered before landing.
@export_range(0.0, 0.3, 0.01) var jump_buffer_time: float = 0.12

@export_group("Dash")
## Dash speed in m/s.
@export_range(5.0, 60.0, 0.5) var dash_speed: float = 22.0
## Dash duration in seconds.
@export_range(0.05, 1.0, 0.01) var dash_time: float = 0.18
## Seconds before the next dash may start.
@export_range(0.0, 2.0, 0.05) var dash_cooldown: float = 0.4
## How much of the dash speed carries out of the dash (0 = run speed, 1 = dash speed).
@export_range(0.0, 1.0, 0.05) var dash_carry: float = 0.5
## Upper bound of the horizontal speed leaving a dash in m/s.
@export_range(1.0, 40.0, 0.5) var dash_exit_cap: float = 12.0
## Gravity scale during an air dash (0 = flat dash).
@export_range(0.0, 1.0, 0.05) var air_dash_gravity_scale: float = 0.0

@export_group("Chain and long jump")
## Seconds after landing in which the next ground jump advances the chain.
@export_range(0.05, 1.5, 0.01) var chain_window: float = 0.35
## Seconds after a dash in which a jump still counts as a long jump.
@export_range(0.0, 0.5, 0.01) var dash_jump_grace: float = 0.15
## Ground speed under which the chain resets in m/s.
@export_range(0.0, 5.0, 0.1) var chain_reset_speed: float = 0.5
## Long jump height at chain stage 0 in m.
@export_range(0.1, 6.0, 0.05) var long_jump_height_small: float = 1.0
## Long jump height at chain stage 1 in m.
@export_range(0.1, 6.0, 0.05) var long_jump_height_mid: float = 1.2
## Long jump height at chain stage 2 in m.
@export_range(0.1, 6.0, 0.05) var long_jump_height_max: float = 1.4
## Minimum take-off speed of the stage 0 long jump in m/s.
@export_range(1.0, 40.0, 0.5) var long_jump_speed_small: float = 14.0
## Minimum take-off speed of the stage 1 long jump in m/s.
@export_range(1.0, 40.0, 0.5) var long_jump_speed_mid: float = 15.0
## Minimum take-off speed of the stage 2 long jump in m/s.
@export_range(1.0, 40.0, 0.5) var long_jump_speed_max: float = 17.0
## Hard upper bound of any long-jump take-off speed in m/s (D-06). The carried dash speed is clamped to it.
@export_range(1.0, 60.0, 0.5) var long_jump_speed_cap: float = 22.0

@export_group("Floor and platforms")
## Lower bound of the speed-scaled floor snap length in m (D-13 band, A35).
@export_range(0.3, 0.5, 0.01) var snap_min: float = 0.3
## Upper bound of the speed-scaled floor snap length in m (D-13 band, A35).
@export_range(0.3, 0.5, 0.01) var snap_max: float = 0.5
## Steepest walkable floor angle in degrees.
@export_range(30.0, 60.0, 1.0) var floor_max_angle_deg: float = 50.0
## Share of the platform's horizontal velocity that carries over when leaving it.
@export_range(0.0, 1.5, 0.05) var platform_carry: float = 1.0


## Gravity in m/s^2, derived from the reference jump: g = 2 * H / T^2.
func gravity() -> float:
	return 2.0 * reference_jump_height / (reference_apex_time * reference_apex_time)


## Take-off speed in m/s that reaches `height` under gravity(): v = sqrt(2 * g * h).
func jump_speed(height: float) -> float:
	return sqrt(2.0 * gravity() * maxf(height, 0.0))


## Rising speed a released jump is cut down to (tap height).
func cut_speed() -> float:
	return jump_speed(jump_min_height)


## Long jump height for a chain stage 0, 1 or 2 (clamped).
func long_jump_height(stage: int) -> float:
	match clampi(stage, 0, 2):
		0:
			return long_jump_height_small
		1:
			return long_jump_height_mid
		_:
			return long_jump_height_max


## Minimum long jump take-off speed for a chain stage 0, 1 or 2 (clamped).
func long_jump_speed(stage: int) -> float:
	match clampi(stage, 0, 2):
		0:
			return long_jump_speed_small
		1:
			return long_jump_speed_mid
		_:
			return long_jump_speed_max
