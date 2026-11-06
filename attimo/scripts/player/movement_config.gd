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
## Full-hold height of Jump 2 of the ground chain in m.
@export_range(0.5, 6.0, 0.05) var jump_2_height: float = 2.6
## Full-hold height of Jump 3 (the salto, the highest ground jump) in m.
@export_range(0.5, 6.0, 0.05) var jump_3_height: float = 3.4
## Tap height in m (release cuts the rise to this height).
@export_range(0.1, 3.0, 0.05) var jump_min_height: float = 0.8
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
## Horizontal speed leaving a dash in m/s; never below run speed.
@export_range(5.0, 22.0, 0.5) var dash_exit_speed: float = 12.0
## Gravity scale during an air dash (0 = flat dash).
@export_range(0.0, 1.0, 0.05) var air_dash_gravity_scale: float = 0.0

@export_group("Chain and long jump")
## Seconds after touchdown in which the next ground jump advances the chain or the next ground dash keeps the long-jump stack.
@export_range(0.05, 1.5, 0.01) var landing_window: float = 0.35
## Seconds after a dash in which a jump still counts as a long jump.
@export_range(0.0, 0.5, 0.01) var dash_jump_grace: float = 0.15
## Ground speed under which the chain and the long-jump stack reset in m/s.
@export_range(0.0, 5.0, 0.1) var combo_reset_speed: float = 0.5
## Long jump height at stage 1 (the first dash hop) in m.
@export_range(0.5, 6.0, 0.05) var long_jump_height_1: float = 2.0
## Long jump height at stage 2 in m.
@export_range(0.5, 6.0, 0.05) var long_jump_height_2: float = 2.5
## Long jump height at stage 3 (top of the stack) in m.
@export_range(0.5, 6.0, 0.05) var long_jump_height_3: float = 3.0
## Take-off speed of the stage 1 long jump in m/s.
@export_range(5.0, 22.0, 0.5) var long_jump_speed_1: float = 14.0
## Take-off speed of the stage 2 long jump in m/s.
@export_range(5.0, 22.0, 0.5) var long_jump_speed_2: float = 16.0
## Take-off speed of the stage 3 long jump in m/s. 22 m/s is the speed the camera and tunnelling tests cover; do not raise it without re-running them.
@export_range(5.0, 22.0, 0.5) var long_jump_speed_3: float = 18.0

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


## Full-hold height of ground jump `stage` (1, 2 or 3, clamped).
func jump_height_for_stage(stage: int) -> float:
	match clampi(stage, 1, 3):
		1:
			return jump_height
		2:
			return jump_2_height
		_:
			return jump_3_height


## Long jump height for stage 1, 2 or 3 (clamped).
func long_jump_height(stage: int) -> float:
	match clampi(stage, 1, 3):
		1:
			return long_jump_height_1
		2:
			return long_jump_height_2
		_:
			return long_jump_height_3


## Long jump take-off speed in m/s for stage 1, 2 or 3 (clamped).
func long_jump_speed(stage: int) -> float:
	match clampi(stage, 1, 3):
		1:
			return long_jump_speed_1
		2:
			return long_jump_speed_2
		_:
			return long_jump_speed_3
